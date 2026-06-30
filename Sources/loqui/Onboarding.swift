import AppKit
import AVFoundation
import Speech
import SwiftUI

private let brandMagenta = Color.loquiMagenta

/// Tracks the live permission state for the welcome flow and exposes the actions
/// that request them. Polls once a second so a grant made in System Settings
/// checks off here on its own (no relaunch, no guessing).
@MainActor
final class OnboardingState: ObservableObject {
    @Published var micGranted = false
    @Published var micDenied = false
    @Published var speechGranted = false
    @Published var speechDenied = false
    @Published var accessibilityGranted = false

    private var timer: Timer?

    init() {
        refresh()
        startPolling()
    }

    /// (Re)start the 1s permission poll. Idempotent, so re-opening the window
    /// (which stops polling on close) resumes live check-off.
    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        micGranted = mic == .authorized
        micDenied = mic == .denied || mic == .restricted
        let speech = SFSpeechRecognizer.authorizationStatus()
        speechGranted = speech == .authorized
        speechDenied = speech == .denied || speech == .restricted
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Both microphone and on-device speech are needed to transcribe.
    var voiceReady: Bool { micGranted && speechGranted }
    var voiceDenied: Bool { micDenied || speechDenied }
    var allReady: Bool { voiceReady && accessibilityGranted }

    /// Ask for the microphone, then speech recognition (the on-device transcriber
    /// uses both). If already decided, this is a no-op the OS resolves instantly.
    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            SFSpeechRecognizer.requestAuthorization { _ in
                Task { @MainActor in self.refresh() }
            }
        }
    }

    /// Fire the system Accessibility prompt AND open the pane, so the user can
    /// flip the toggle right away. Polling flips our checkmark when it lands.
    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }
}

struct OnboardingView: View {
    @ObservedObject var state: OnboardingState
    @ObservedObject private var shortcuts = ShortcutStore.shared
    var onDone: () -> Void

    private var appIcon: NSImage {
        NSImage(named: "AppIcon")
            ?? NSImage(systemSymbolName: "quote.opening", accessibilityDescription: nil)
            ?? NSImage()
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: appIcon)
                    .resizable().frame(width: 76, height: 76)
                Text("Welcome to loqui").font(.system(size: 22, weight: .semibold))
                Text("Talk, and it’s text — anywhere on your Mac.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(.top, 28).padding(.bottom, 22)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                micRow
                accessibilityRow
                shortcutRow
            }
            .padding(24)

            Spacer(minLength: 0)
            Divider()
            footer.padding(20)
        }
        .frame(width: 480, height: 600)
        .onAppear { state.refresh(); state.startPolling() }
        .onDisappear {
            state.stopPolling()
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: rows

    private func rowHeader(_ done: Bool, _ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? AnyShapeStyle(brandMagenta) : AnyShapeStyle(.tertiary))
                .font(.system(size: 16))
            Text(title).font(.headline)
        }
    }

    private var micRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowHeader(state.voiceReady, "Microphone & Speech")
            if state.voiceReady {
                detail("Allowed — loqui can hear you and transcribe on-device.")
            } else if state.voiceDenied {
                detail("Denied. Turn on Microphone and Speech Recognition in System Settings → Privacy.")
                Button("Open Microphone Settings") { state.openMicrophoneSettings() }
            } else {
                detail("loqui listens only while you’re dictating, and transcribes on-device — audio never leaves your Mac.")
                Button("Allow Microphone & Speech") { state.requestMicrophone() }
            }
        }
    }

    private var accessibilityRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowHeader(state.accessibilityGranted, "Accessibility")
            if state.accessibilityGranted {
                detail("On — your shortcut works everywhere and text pastes at the cursor.")
            } else {
                detail("Lets your shortcut work in any app and paste your text. Click below, then flip loqui on in the list — it’ll check off here automatically.")
                Button("Open Accessibility Settings") { state.requestAccessibility() }
            }
        }
    }

    private var shortcutRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowHeader(true, "Your shortcut")
            detail("Tap to start and stop, or hold to push-to-talk. Change it anytime in Settings.")
            ShortcutRecorderView()
        }
    }

    private func detail(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: footer

    private var footer: some View {
        HStack {
            if state.allReady {
                Text("You’re all set — press \(shortcuts.shortcut.display) and start talking.")
                    .font(.callout).foregroundStyle(brandMagenta)
            } else {
                Text("Allow Microphone and Accessibility to finish.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button(state.allReady ? "Done" : "Finish later") { onDone() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
