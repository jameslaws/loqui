import AppKit
import SwiftUI

/// Backing store for the cleanup-related settings (the front end to cleanup.json).
/// Edits save to disk immediately; `TextCleanup` re-reads on the next dictation.
@MainActor
final class SettingsModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        var heard: String
        var replacement: String
    }

    @Published var rows: [Row] { didSet { save() } }
    @Published var removeFillers: Bool { didSet { save() } }
    @Published var fillers: [String] { didSet { save() } }
    @Published var spokenFormatting: Bool { didSet { save() } }

    init() {
        let cfg = CleanupConfigFile.load()
        rows = cfg.dictionary.sorted { $0.key < $1.key }.map { Row(heard: $0.key, replacement: $0.value) }
        removeFillers = cfg.removeFillers
        fillers = cfg.fillers
        spokenFormatting = cfg.spokenFormatting
    }

    func save() {
        var dict: [String: String] = [:]
        for r in rows {
            let h = r.heard.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let v = r.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !h.isEmpty, !v.isEmpty else { continue }
            dict[h] = v
        }
        let cleanFillers = fillers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        CleanupConfigFile.save(CleanupConfig(
            dictionary: dict, removeFillers: removeFillers,
            fillers: cleanFillers, spokenFormatting: spokenFormatting))
    }

    func addRow() { rows.insert(Row(heard: "", replacement: ""), at: 0) }
    func delete(_ row: Row) { rows.removeAll { $0.id == row.id } }

    func addFiller(_ word: String) {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty, !fillers.contains(w) else { return }
        fillers.append(w)
    }
    func removeFiller(_ word: String) { fillers.removeAll { $0 == word } }
}

// MARK: - General tab (shortcut + cleanup + history)
// Hosted by an NSTabViewController in LoquiApp. `.frame(width:)` plus the hosting
// controller's `.preferredContentSize` sizing make the window hug this pane.

struct GeneralSettings: View {
    @ObservedObject var model: SettingsModel
    @AppStorage(TranscriptionHistory.retentionKey) private var historyRetentionDays = 0
    @State private var newFiller = ""
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("Shortcut") {
                ShortcutRecorderView()
            }

            Section("Cleanup") {
                Toggle("Remove filler words", isOn: $model.removeFillers.animation())
                if model.removeFillers {
                    fillerEditor
                }
                Toggle("Spoken commands — “new paragraph”, “new line”", isOn: $model.spokenFormatting)
            }

            Section("History") {
                Picker("Keep history", selection: $historyRetentionDays) {
                    Text("Off — don’t store").tag(-1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Forever").tag(0)
                }
                Button("Clear History…") { confirmClear = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onChange(of: historyRetentionDays) { TranscriptionHistory.shared.prune() }
        .alert("Clear all transcription history?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { TranscriptionHistory.shared.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every saved transcription. It can’t be undone.")
        }
    }

    private var fillerEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.fillers.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    ForEach(model.fillers, id: \.self) { word in
                        HStack(spacing: 4) {
                            Text(word).font(.callout)
                            Button { model.removeFiller(word) } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                    }
                }
            }
            HStack {
                TextField("Add a filler word", text: $newFiller)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addFiller)
                Button("Add", action: addFiller)
                    .disabled(newFiller.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 2)
    }

    private func addFiller() {
        model.addFiller(newFiller)
        newFiller = ""
    }
}

// MARK: - Dictionary tab

struct DictionarySettings: View {
    @ObservedObject var model: SettingsModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $query).textFieldStyle(.plain)
                Spacer()
                Button { model.addRow() } label: { Label("Add term", systemImage: "plus") }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            Divider()

            if model.rows.isEmpty {
                dictEmpty("No vocabulary yet",
                          "Add a term to fix words Apple mishears — names, brands, jargon.")
            } else if !model.rows.contains(where: matches) {
                dictEmpty("No matches", "Try a different search.")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                            if matches(row) {
                                rowEditor($model.rows[index])
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
            Text("Anything Apple mishears → the spelling you want. Matched as whole words, any case.")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 520, height: 460)
    }

    private func matches(_ row: SettingsModel.Row) -> Bool {
        query.isEmpty
            || row.heard.localizedCaseInsensitiveContains(query)
            || row.replacement.localizedCaseInsensitiveContains(query)
    }

    private func rowEditor(_ row: Binding<SettingsModel.Row>) -> some View {
        HStack(spacing: 10) {
            TextField("heard", text: row.heard).textFieldStyle(.roundedBorder)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
            TextField("replacement", text: row.replacement).textFieldStyle(.roundedBorder)
            Button { model.delete(row.wrappedValue) } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
    }

    private func dictEmpty(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 30)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
    }
}

// MARK: - Shortcut recorder (shared with onboarding)

/// Records a new global trigger. While armed, it captures the next key combo via
/// a local event monitor and saves it — rejecting bare keys that would hijack
/// typing. Esc cancels.
struct ShortcutRecorderView: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("Dictation shortcut")
                Spacer()
                Button {
                    recording ? stop() : start()
                } label: {
                    Text(recording ? "Press a key combo…  (Esc cancels)" : store.shortcut.display)
                        .frame(minWidth: 150)
                }
            }
            if let hint {
                Text(hint).font(.caption).foregroundStyle(.orange)
            }
            Text("Tap to start and stop, or press and hold for push-to-talk. Use a key with ⌘ / ⌃ / ⌥, or a function key.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear { stop() }
    }

    private func start() {
        hint = nil
        recording = true
        VoiceKeyService.shared.suspend()   // don't let the current shortcut fire while rebinding
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = Int64(event.keyCode)
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if code == 53 { stop(); return nil }   // Esc cancels
            if HotShortcut.isAcceptable(keyCode: code, modifiers: mods) {
                store.shortcut = HotShortcut(keyCode: code, modifiers: mods.rawValue)
                stop()
            } else {
                hint = "Add ⌘, ⌃, or ⌥ — or use a function key."
            }
            return nil   // swallow keys while recording
        }
    }

    private func stop() {
        recording = false
        VoiceKeyService.shared.resume()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}
