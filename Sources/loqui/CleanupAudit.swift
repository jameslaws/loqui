import Foundation

/// A record of what cleanup actually changed, at `~/Library/Logs/LoquiCleanup.log`.
///
/// Transcript history only keeps the CLEANED text, so there was no way to see
/// what the recognizer produced versus what the rules rewrote — which makes a
/// bad rule invisible until it has been quietly mangling your writing for
/// weeks. This closes that gap: every dictation whose text the rules altered is
/// written out raw-then-cleaned, and every sentence boundary is logged with the
/// pause that preceded it.
///
/// Local file, no network, and it can be turned off with `"auditLog": false` in
/// cleanup.json. It holds transcript text, so it prunes itself rather than
/// growing without bound.
enum CleanupAudit {
    private static let maxBytes = 2_000_000

    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/LoquiCleanup.log")
    }

    /// Both versions of a dictation, written only when they actually differ.
    static func diff(raw: String, cleaned: String) {
        guard CleanupConfigFile.load().auditLog, raw != cleaned else { return }
        let stamp = Date().formatted(date: .abbreviated, time: .standard)
        append("""
        ── \(stamp)
        RAW:     \(raw)
        CLEANED: \(cleaned)

        """)
    }

    /// One sentence boundary and the silence in front of it. Collecting these
    /// is the point: `maxPauseSeconds` is currently a guess, and the only way
    /// to set it honestly is against the distribution of your own speech.
    static func boundary(gap: Double, word: String, healed: Bool) {
        guard CleanupConfigFile.load().auditLog else { return }
        append(String(format: "   gap %.2fs before \"%@\"%@\n",
                      gap, word, healed ? "  → HEALED" : ""))
    }

    private static func append(_ text: String) {
        let u = url
        guard let data = text.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: u.path) {
            try? data.write(to: u)
            return
        }
        if let handle = try? FileHandle(forWritingTo: u) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
        prune()
    }

    /// Keep the tail. A cleanup log that fills the disk is a worse bug than the
    /// one it exists to find.
    private static func prune() {
        let u = url
        guard let size = try? FileManager.default
            .attributesOfItem(atPath: u.path)[.size] as? Int, size > maxBytes,
            let content = try? String(contentsOf: u, encoding: .utf8)
        else { return }
        let kept = content.suffix(maxBytes / 2)
        // Resume at a record boundary so the file never starts mid-entry.
        let tidy = kept.range(of: "── ").map { String(kept[$0.lowerBound...]) } ?? String(kept)
        try? tidy.write(to: u, atomically: true, encoding: .utf8)
    }
}
