import AppKit
import ApplicationServices
import Combine
import SwiftUI

/// The transcription hotkey — a user-configurable shortcut (default ⌘R),
/// captured system-wide. One key, two gestures:
///
///   single press   → start transcribing; press again to stop. The text lands
///                    on the clipboard AND auto-pastes at the cursor.
///   press-and-hold → push-to-talk: transcribe while held, release stops + pastes.
///
/// Recording begins the instant the key goes down — no double-press window, no
/// disambiguation delay. The hold threshold only decides what *release* does:
/// a quick tap leaves it running (toggle, stop on next press); a hold stops it
/// on release.
///
/// Pieces: `VoiceKeyService` owns the CGEvent tap (needs Accessibility);
/// `VoiceKeyGestureMachine` turns raw key edges into start/stop;
/// `VoiceKeyCenter` runs transcribe-anywhere itself, with a floating
/// non-activating HUD so you can see the live transcript without the frontmost
/// app losing focus.

// MARK: - Event tap

private func voiceKeyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<VoiceKeyService>.fromOpaque(refcon).takeUnretainedValue()
    return service.handle(type: type, event: event)
}

/// Diagnostic logger: NSLog goes to Xcode's console under the debugger and
/// the unified log otherwise — neither is readable in both worlds, so ALSO
/// append to ~/Library/Logs/LoquiVoiceKey.log. Cheap, local, greppable.
func voiceKeyLog(_ message: String) {
    NSLog("VoiceKey: %@", message)
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/LoquiVoiceKey.log")
    let stamp = Date().formatted(date: .abbreviated, time: .standard)
    guard let data = "\(stamp)  \(message)\n".data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: url)
    }
}

final class VoiceKeyService {
    static let shared = VoiceKeyService()

    private var tap: CFMachPort?
    private var retryTimer: Timer?

    /// Call once at launch. Without Accessibility the tap can't be created —
    /// prompt, then poll until the grant lands (System Settings stays open
    /// while the user flips the toggle; no relaunch needed).
    func start() {
        guard tap == nil else { return }
        if AXIsProcessTrusted() {
            voiceKeyLog("trusted at launch")
            createTap()
            return
        }
        voiceKeyLog("NOT trusted for Accessibility — prompting and polling. Binary: \(Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0])")
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            voiceKeyLog("Accessibility granted — starting the key tap")
            timer.invalidate()
            self?.createTap()
        }
    }

    /// Pause/resume the global tap — used while the shortcut recorder is armed,
    /// so the currently-bound shortcut doesn't fire (or get swallowed) mid-rebind.
    func suspend() { if let tap { CGEvent.tapEnable(tap: tap, enable: false) } }
    func resume()  { if let tap { CGEvent.tapEnable(tap: tap, enable: true) } }

    private func createTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: voiceKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            voiceKeyLog("event tap creation FAILED (Accessibility not granted?)")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        voiceKeyLog("listening for \(ShortcutStore.shared.shortcut.display)")
    }

    /// Runs on the main runloop (that's where the tap source lives), so
    /// MainActor state is safe to touch synchronously — and it must be:
    /// the consume/pass-through decision can't be deferred.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            voiceKeyLog("tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input") — re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // A key-up can be lost while the tap is down — reset the gesture
            // machine so the next press isn't a no-op (the wedge fix).
            MainActor.assumeIsolated { VoiceKeyCenter.shared.machine.reset() }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        return MainActor.assumeIsolated {
            // The trigger is user-configurable (Settings → Shortcut). Match its
            // keycode; for key-down require an EXACT modifier match so e.g. ⌘⇧R
            // passes through when the shortcut is ⌘R. fn is ignored, so bare
            // function keys (which arrive carrying the fn flag) still match.
            let sc = ShortcutStore.shared.shortcut
            guard keycode == sc.keyCode else { return Unmanaged.passUnretained(event) }
            let machine = VoiceKeyCenter.shared.machine
            switch type {
            case .keyDown:
                guard sc.modifiersMatch(flags) else { return Unmanaged.passUnretained(event) }
                // Holding the key autorepeats — swallow repeats; the machine
                // only cares about the edge transitions.
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
                machine.keyDown()
                return nil
            case .keyUp:
                // Match the up by keycode, not flags — a modifier may already be
                // released by the time the key comes up. Only claim an up while a
                // gesture is in flight, so passed-through downs keep their ups.
                guard machine.expectsKeyUp else {
                    return Unmanaged.passUnretained(event)
                }
                machine.keyUp()
                return nil
            default:
                return Unmanaged.passUnretained(event)
            }
        }
    }
}

// MARK: - Gesture machine

/// Raw key edges → start/stop. Recording starts on key-DOWN (zero latency);
/// the hold threshold only classifies the release. A press while a capture is
/// already live is an instant stop.
@MainActor
final class VoiceKeyGestureMachine {
    private enum S {
        case idle
        case down        // pressed; recording started; hold timer running
        case hold        // outlived the threshold → push-to-talk
        case swallowUp   // this press was consumed as a stop — eat its key-up
    }

    private var state: S = .idle
    private var holdTimer: Task<Void, Never>?
    private let holdThreshold: Double = 0.35

    var expectsKeyUp: Bool {
        switch state {
        case .down, .hold, .swallowUp: return true
        case .idle: return false
        }
    }

    func keyDown() {
        let center = VoiceKeyCenter.shared
        switch state {
        case .idle:
            // A live capture turns the next press into an instant stop.
            if center.recordingActive {
                center.stopRecording()
                state = .swallowUp
                return
            }
            // Start transcribing immediately. The hold timer only promotes the
            // gesture to push-to-talk if the key is still down at the threshold.
            center.startRecording()
            state = .down
            holdTimer?.cancel()
            holdTimer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(self?.holdThreshold ?? 0.35))
                guard !Task.isCancelled, let self else { return }
                if self.state == .down { self.state = .hold }
            }
        case .down, .hold, .swallowUp:
            break   // autorepeat is filtered upstream; anything else is noise
        }
    }

    func keyUp() {
        let center = VoiceKeyCenter.shared
        holdTimer?.cancel()
        switch state {
        case .down:
            // Released before the threshold → a TAP. Toggle mode: leave it
            // recording; the next press stops it.
            state = .idle
        case .hold:
            // Held past the threshold → push-to-talk. Release stops + pastes.
            state = .idle
            center.stopRecording()
        case .swallowUp:
            state = .idle
        case .idle:
            break
        }
    }

    /// Force back to idle — recovers if a key-up was ever lost (e.g. the event
    /// tap was disabled mid-gesture), so the next press isn't a dead no-op.
    func reset() {
        holdTimer?.cancel()
        holdTimer = nil
        state = .idle
    }
}

// MARK: - Transcribe-anywhere

/// Observable recording state for the menu-bar item (icon flips while live).
@MainActor
final class TranscriberState: ObservableObject {
    static let shared = TranscriberState()
    @Published var recording = false
}

@MainActor
final class VoiceKeyCenter {
    static let shared = VoiceKeyCenter()
    let machine = VoiceKeyGestureMachine()

    private let transcriber = VoiceTranscriber()
    private(set) var recordingActive = false
    private var finishing = false                 // stop()'s async drain is still in flight
    private var watchdog: Task<Void, Never>?      // max-duration safety auto-stop
    private let hud = VoiceKeyHUD()
    private var levelSink: AnyCancellable?

    func startRecording() {
        // Reject a start while a prior stop is still draining/tearing down —
        // otherwise the in-flight teardown would corrupt this new session.
        guard !recordingActive, !finishing else { return }
        recordingActive = true
        TranscriberState.shared.recording = true
        hud.show()
        // Drive the HUD waveform off the live mic level.
        levelSink = transcriber.$level
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.hud.push(level: $0) }
        // Safety net: auto-stop a runaway session (e.g. if a key-up was lost).
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(300))
            guard !Task.isCancelled, let self, self.recordingActive else { return }
            voiceKeyLog("watchdog: max recording duration reached — auto-stopping")
            self.machine.reset()
            self.stopRecording()
        }
        Task { @MainActor in
            if !(await transcriber.begin()) {
                recordingActive = false
                TranscriberState.shared.recording = false
                levelSink = nil
                watchdog?.cancel(); watchdog = nil
                hud.notice("loqui needs microphone access to hear you")
            }
        }
    }

    /// Stop, clean the transcript, put it on the clipboard, and paste it where
    /// the cursor already is. Loqui is never activated — the HUD is a
    /// non-activating panel, so the frontmost app keeps focus and gets the ⌘V.
    func stopRecording() {
        guard recordingActive else { return }
        recordingActive = false
        finishing = true            // block a restart until the drain/teardown finishes
        watchdog?.cancel(); watchdog = nil
        TranscriberState.shared.recording = false
        levelSink = nil
        hud.finishing()
        Task { @MainActor in
            defer { finishing = false }   // clears on every exit, freeing the next start
            // end() finalizes the analyzer so the tail of the dictation lands
            // in the paste — usually well under a second.
            let raw = await transcriber.end().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { hud.hide(); return }
            // Instant on-device cleanup (dictionary, fillers, punctuation/caps)
            // — microseconds, so the paste still feels immediate.
            let text = TextCleanup.shared.process(raw)
            DictationLog.shared.record(words: text.split(whereSeparator: { $0.isWhitespace }).count)
            TranscriptionHistory.shared.record(text: text)   // local history (respects retention)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            // The text is on the clipboard and we paste it at the cursor, so a
            // quick "Pasted" is all the HUD needs — showing the text again is
            // redundant clutter (and the focused-field detection that gated it
            // was unreliable, especially for web inputs). Clipboard is the
            // fallback if a paste ever doesn't land.
            hud.finished()
            // Give the pasteboard a beat to settle before the ⌘V lands.
            try? await Task.sleep(for: .milliseconds(80))
            Self.synthesizePaste()
        }
    }

    private static func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyV: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

// MARK: - Floating HUD

/// JamesLaws.com magenta (#E91E63).
private let hudMagenta = Color.loquiMagenta

private enum VoiceKeyHUDPhase { case listening, finishing, done }

/// Non-activating borderless panel pinned bottom-center. Presence-forward: a
/// magenta dot + a live waveform driven by the mic level while listening, then
/// a brief checkmark + the cleaned, pasted text. Never takes focus, so the
/// frontmost app keeps it and receives the synthesized ⌘V.
@MainActor
private final class VoiceKeyHUD {
    private var panel: NSPanel?
    private let model = VoiceKeyHUDModel()
    private var hideWork: Task<Void, Never>?

    func show() {
        hideWork?.cancel()
        model.reset()
        model.phase = .listening
        ensurePanel()
        position()
        panel?.orderFrontRegardless()
    }

    func push(level: Double) { model.push(level) }

    func finishing() {
        hideWork?.cancel()
        model.phase = .finishing
        ensurePanel()
        panel?.orderFrontRegardless()
    }

    /// Confirm the dictation. When it pasted into a real text field, the text is
    /// already on screen — so just a quick checkmark, no redundant copy. Only
    /// when there was no paste target do we surface the text (it's on the
    /// clipboard) so it isn't lost.
    func finished() {
        present(text: "", label: "Pasted", error: false, seconds: 0.9)
    }

    /// A brief notice (e.g. a permission problem), then fade.
    func notice(_ message: String) {
        present(text: message, label: "", error: true, seconds: 1.8)
    }

    private func present(text: String, label: String, error: Bool, seconds: Double) {
        hideWork?.cancel()
        model.resultText = text
        model.doneLabel = label
        model.doneIsError = error
        model.phase = .done
        ensurePanel()
        position()
        panel?.orderFrontRegardless()
        hideWork = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    func hide() { panel?.orderOut(nil) }

    private func ensurePanel() {
        guard panel == nil else { return }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: VoiceKeyHUDView(model: model))
        panel = p
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.minY + 56
        ))
    }
}

@MainActor
private final class VoiceKeyHUDModel: ObservableObject {
    static let barCount = 21   // odd, so there's a true center

    @Published var phase: VoiceKeyHUDPhase = .listening
    @Published var level: Double = 0
    @Published var resultText = ""      // shown only when there's no paste target
    @Published var doneLabel = ""       // "Pasted" / "On clipboard"
    @Published var doneIsError = false

    func reset() {
        level = 0
        resultText = ""
    }

    /// Latest mic amplitude (0…1), lightly smoothed so the waveform swells and
    /// settles instead of snapping frame to frame.
    func push(_ newLevel: Double) {
        let l = min(1, max(0, newLevel))
        level = level * 0.25 + l * 0.75   // responsive, only light smoothing
    }
}

private struct VoiceKeyHUDView: View {
    @ObservedObject var model: VoiceKeyHUDModel
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            pill
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .environment(\.colorScheme, .dark)
    }

    private var pill: some View {
        HStack(spacing: 14) {
            switch model.phase {
            case .listening, .finishing:
                // Brand-cohesive: the live waveform sits between magenta quote
                // marks — your voice, captured as a quote (echoes the app icon).
                Image(systemName: "quote.opening")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(hudMagenta)
                    .opacity(pulse ? 0.5 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                if model.phase == .finishing {
                    // Distinct "processing" look so it doesn't read as still-listening.
                    ProgressView().controlSize(.small).tint(hudMagenta).frame(width: 56, height: 28)
                } else {
                    waveform
                }
                Image(systemName: "quote.closing")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(hudMagenta)
                    .opacity(pulse ? 0.5 : 1)
            case .done:
                Image(systemName: model.doneIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(hudMagenta)
                if !model.resultText.isEmpty {
                    Text(model.resultText)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 480, alignment: .leading)
                }
                if !model.doneLabel.isEmpty {
                    Text(model.doneLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(hudMagenta.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(hudMagenta.opacity(0.22), lineWidth: 1)
        )
        .fixedSize()
    }

    private var waveform: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<VoiceKeyHUDModel.barCount, id: \.self) { i in
                    Capsule()
                        .fill(hudMagenta)
                        .frame(width: 3.5, height: barHeight(i, t))
                }
            }
            .frame(height: 32)
        }
    }

    /// Symmetric, center-weighted waveform: a bell envelope (tallest in the
    /// middle, shorter at the edges) whose overall amplitude swells with your
    /// live mic level, plus a per-bar oscillation so it shimmers like a real
    /// voice instead of scrolling past. 3pt floor reads as a baseline at rest.
    private func barHeight(_ i: Int, _ t: Double) -> CGFloat {
        let n = Double(VoiceKeyHUDModel.barCount)
        let c = (n - 1) / 2
        let d = abs(Double(i) - c) / c                  // 0 at center → 1 at edges
        let env = 0.3 + 0.7 * cos(d * .pi / 2)          // bell: 1 center, 0.3 edges
        let osc = 0.2 + 0.8 * (0.5 + 0.5 * sin(t * 9 + Double(i) * 0.85))
        let amp = pow(model.level, 0.45)                // gamma-boosted live level
        return CGFloat(3 + 33 * env * (0.05 + amp * 0.95) * osc)
    }
}
