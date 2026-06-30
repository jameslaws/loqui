import AppKit
import SwiftUI

private let historyMagenta = Color.loquiMagenta

/// Loads the transcription history and keeps an open window in sync.
@MainActor
final class HistoryModel: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var query = ""
    @Published var justCopied: HistoryEntry.ID?

    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .transcriptionHistoryChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func reload() { entries = TranscriptionHistory.shared.load() }

    var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    func copy(_ entry: HistoryEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.text, forType: .string)
        justCopied = entry.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            if justCopied == entry.id { justCopied = nil }
        }
    }

    func delete(_ entry: HistoryEntry) { TranscriptionHistory.shared.delete(entry) }
    func clearAll() { TranscriptionHistory.shared.deleteAll() }
}

struct HistoryView: View {
    @StateObject private var model = HistoryModel()
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search transcriptions", text: $model.query)
                    .textFieldStyle(.plain)
                Spacer()
                if !model.entries.isEmpty {
                    Button("Clear All") { confirmClear = true }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            Divider()

            if model.filtered.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filtered) { entry in
                            row(entry)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 560, maxWidth: .infinity,
               minHeight: 380, idealHeight: 640, maxHeight: .infinity)
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
        .alert("Clear all transcription history?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { model.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every saved transcription. It can’t be undone.")
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Text(entry.at.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.justCopied == entry.id {
                    Text("Copied").font(.caption.weight(.semibold)).foregroundStyle(historyMagenta)
                }
                Button { model.copy(entry) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless).font(.caption)
                Button { model.delete(entry) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.copy(entry) }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32)).foregroundStyle(historyMagenta)
            Text(model.entries.isEmpty ? "No transcriptions yet" : "No matches")
                .font(.title3.weight(.semibold))
            Text(model.entries.isEmpty
                 ? "What you dictate shows up here — copy any of it again with a click."
                 : "Try a different search.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}
