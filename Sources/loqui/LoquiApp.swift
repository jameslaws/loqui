import AppKit
import Combine
import Sparkle
import SwiftUI

/// loqui is a menu-bar-only dictation utility. We manage the `NSStatusItem`
/// ourselves (rather than SwiftUI's `MenuBarExtra`) so the recording state can
/// be a *colored, animated* indicator — SwiftUI's menu-bar label is forced to a
/// monochrome template, which can't show the magenta or the pulse. Settings and
/// Stats are SwiftUI views hosted in plain AppKit windows on demand.
@main
enum LoquiMain {
    static func main() {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var statsWindow: NSWindow?
    private var recordingCancellable: AnyCancellable?
    private var pulseTimer: Timer?
    private var pulseDim = true
    private var onboardingWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var recentMenu: NSMenu!

    // Sparkle auto-update. Reads SUFeedURL / SUPublicEDKey from Info.plist;
    // checks automatically (SUEnableAutomaticChecks) and on demand.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    private static let onboardedKey = "loqui.onboarded"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon, no app-switcher entry.
        NSApp.setActivationPolicy(.accessory)
        setUpMainMenu()
        setUpStatusItem()
        observeRecording()
        TranscriptionHistory.shared.prune()   // apply retention on launch

        if UserDefaults.standard.bool(forKey: Self.onboardedKey) {
            // Returning user: start the global voice key (it prompts + polls for
            // Accessibility itself if a grant was revoked).
            VoiceKeyService.shared.start()
        } else {
            // First run: let onboarding guide the permissions, then start the key.
            showOnboarding()
        }
    }

    // MARK: - Status item + menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = symbol("mic", template: true)

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        statusLine = NSMenuItem(
            title: "Press \(ShortcutStore.shared.shortcut.display) to transcribe",
            action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(item("Dictation Stats…", #selector(openStats)))
        menu.addItem(item("Transcription History…", #selector(openHistory)))
        let recentItem = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recentMenu = NSMenu()
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Welcome & Setup…", #selector(showOnboarding)))
        let updates = NSMenuItem(title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = updaterController
        menu.addItem(updates)
        menu.addItem(.separator())
        menu.addItem(item("Quit loqui", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    /// A minimal app main menu. Without it (an LSUIElement app), there's no Edit
    /// menu, so ⌘C/⌘V/⌘X/⌘A have no key equivalents and don't work in the
    /// Dictionary / filler / search text fields. Also hosts About (with version)
    /// and standard Window commands (⌘W / ⌘M).
    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let about = appMenu.addItem(withTitle: "About loqui", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        let updates = appMenu.addItem(withTitle: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = updaterController
        appMenu.addItem(.separator())
        let quit = appMenu.addItem(withTitle: "Quit loqui", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let info = Bundle.main.infoDictionary
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "loqui",
            .applicationVersion: (info?["CFBundleShortVersionString"] as? String) ?? "—",
            .version: (info?["CFBundleVersion"] as? String) ?? "",
            .credits: NSAttributedString(
                string: "Talk, and it’s text.",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]),
        ])
    }

    /// Refresh the status line to reflect the live shortcut + recording state
    /// whenever the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        let shortcut = ShortcutStore.shared.shortcut.display
        statusLine.title = TranscriberState.shared.recording
            ? "Recording — press \(shortcut) to stop"
            : "Press \(shortcut) to transcribe"
        rebuildRecentMenu()
    }

    /// Repopulate the Recent submenu with the last few transcriptions; clicking
    /// one re-copies it to the clipboard.
    private func rebuildRecentMenu() {
        recentMenu.removeAllItems()
        let items = TranscriptionHistory.shared.recent(5)
        guard !items.isEmpty else {
            let none = NSMenuItem(title: "No transcriptions yet", action: nil, keyEquivalent: "")
            none.isEnabled = false
            recentMenu.addItem(none)
            return
        }
        for entry in items {
            // Collapse newlines/runs of whitespace so the menu title is one clean line.
            let oneLine = entry.text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.joined(separator: " ")
            let preview = oneLine.count > 48 ? String(oneLine.prefix(48)) + "…" : oneLine
            let mi = NSMenuItem(title: preview, action: #selector(copyRecent(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = entry.text
            mi.toolTip = "Copy to clipboard"
            recentMenu.addItem(mi)
        }
    }

    private func symbol(_ name: String, template: Bool) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "loqui")?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = template
        return img
    }

    // MARK: - Recording indicator (magenta + pulse)

    private func observeRecording() {
        recordingCancellable = TranscriberState.shared.$recording
            .receive(on: RunLoop.main)
            .sink { [weak self] recording in
                MainActor.assumeIsolated { self?.updateIndicator(recording: recording) }
            }
    }

    private func updateIndicator(recording: Bool) {
        guard let button = statusItem.button else { return }
        pulseTimer?.invalidate()
        pulseTimer = nil
        button.alphaValue = 1

        if recording {
            // Filled mic + a slow alpha pulse. The blink is the clear "live"
            // signal; the menu bar force-tints template images, so color isn't
            // reliable here — the pulse does the work.
            button.image = symbol("mic.fill", template: true)
            startPulse()
        } else {
            button.image = symbol("mic", template: true)
        }
    }

    private func startPulse() {
        pulseDim = true
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.55
                    button.animator().alphaValue = self.pulseDim ? 0.3 : 1.0
                }
                self.pulseDim.toggle()
            }
        }
    }

    // MARK: - Windows (SwiftUI views hosted in AppKit windows)

    @objc private func openStats() { show(&statsWindow, "loqui — Dictation Stats", StatsView()) }
    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        // Native tabbed preferences: an NSTabViewController with toolbar tabs,
        // each pane a hosted SwiftUI view. The controller resizes the window to
        // fit the selected pane — what SwiftUI's TabView-in-a-window wouldn't do.
        let model = SettingsModel()
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = false   // keep our window title
        tabs.addTabViewItem(settingsTab("General", "gearshape",
            NSHostingController(rootView: GeneralSettings(model: model))))
        tabs.addTabViewItem(settingsTab("Dictionary", "character.book.closed",
            NSHostingController(rootView: DictionarySettings(model: model))))

        let window = NSWindow(contentViewController: tabs)
        window.title = "loqui — Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    private func settingsTab<V: View>(_ label: String, _ symbol: String,
                                      _ vc: NSHostingController<V>) -> NSTabViewItem {
        vc.sizingOptions = .preferredContentSize   // report SwiftUI size → window hugs each pane
        let item = NSTabViewItem(viewController: vc)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }

    /// Settings reverts to menu-bar-only when its window closes. (Its SwiftUI
    /// tabs can't drive this via onDisappear — that fires on tab switches too.)
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    @objc private func openHistory() { show(&historyWindow, "loqui — Transcription History", HistoryView(), resizable: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc private func showOnboarding() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let state = OnboardingState()
        let view = OnboardingView(state: state) { [weak self] in
            UserDefaults.standard.set(true, forKey: AppDelegate.onboardedKey)
            VoiceKeyService.shared.start()   // idempotent; starts the tap once granted
            self?.onboardingWindow?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to loqui"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
    }

    private func show<V: View>(_ slot: inout NSWindow?, _ title: String, _ view: V, resizable: Bool = false) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = slot {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = title
        window.styleMask = resizable
            ? [.titled, .closable, .miniaturizable, .resizable]
            : [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        slot = window
    }
}
