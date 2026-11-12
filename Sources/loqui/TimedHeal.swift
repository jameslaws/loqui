import Foundation

/// The timed half of sentence healing, as a pure decision so it can be tested
/// against `shared/cleanup-cases.json` without a microphone.
///
/// When a finalized segment arrives after text that ends in a period, the
/// measured pause between them decides whether that period was a real full
/// stop or a hesitation the recognizer read as one. Only words in
/// `timedHealWords` qualify, and only when a gap was measured and it is no
/// longer than `maxPauseSeconds`.
enum TimedHeal {
    /// What a sentence boundary looked like, for the cleanup audit log.
    struct Boundary: Equatable {
        let gap: Double
        let word: String
        let healed: Bool
    }

    /// The banked text after adding `segment`, plus the boundary it crossed
    /// when a gap was measured across a period.
    static func bank(_ segment: String, after finalized: String, gap: Double?,
                     config cfg: CleanupConfig) -> (text: String, boundary: Boundary?) {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (finalized, nil) }
        guard !finalized.isEmpty, finalized.hasSuffix(".") else {
            return (append(trimmed, to: finalized), nil)
        }

        let firstWord = trimmed.prefix(while: { !$0.isWhitespace })
            .lowercased().trimmingCharacters(in: .punctuationCharacters)
        let eligible = cfg.healSentenceSplits
            && cfg.timedHealWords.contains(firstWord)
            && (gap.map { $0 <= cfg.maxPauseSeconds } ?? false)
        let boundary = gap.map { Boundary(gap: $0, word: firstWord, healed: eligible) }

        guard eligible else { return (append(trimmed, to: finalized), boundary) }
        // Drop the period the pause caused and carry on mid-sentence.
        return (String(finalized.dropLast()) + " " + lowercasingFirst(trimmed), boundary)
    }

    private static func append(_ trimmed: String, to finalized: String) -> String {
        finalized.isEmpty ? trimmed : finalized + " " + trimmed
    }

    private static func lowercasingFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.lowercased() + s.dropFirst()
    }
}
