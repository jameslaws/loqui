import Foundation

/// Instant, on-device cleanup applied to a finished transcript right before it
/// hits the clipboard: a personal spelling dictionary, optional filler removal,
/// optional spoken formatting, capitalization, and spacing/punctuation tidy.
/// Pure string work over a few sentences — microseconds, no model, no network,
/// no perceptible delay. This is the whole point: keep the speed of raw Apple
/// dictation, just cleaner.
///
/// Config lives at `~/Library/Application Support/Loqui/cleanup.json`, seeded
/// with defaults on first launch. Edit it in any text editor to add jargon or
/// flip toggles; it's re-read on every cleanup, so changes are live. Every rule
/// is conservative — it only makes safe edits, never restructures — so the
/// output is predictable and trustworthy.
final class TextCleanup {
    static let shared = TextCleanup()

    // MARK: - Public

    /// Re-reads the config file each call so edits (from the Settings window or
    /// the JSON directly) take effect on the next dictation.
    func process(_ raw: String) -> String {
        process(raw, config: CleanupConfigFile.load())
    }

    func process(_ raw: String, config cfg: CleanupConfig) -> String {
        var text = raw
        if cfg.spokenFormatting {
            text = replaceWord(in: text, "new paragraph", with: "\n\n")
            text = replaceWord(in: text, "new line", with: "\n")
        }
        if cfg.removeFillers, !cfg.fillers.isEmpty {
            text = removeFillers(text, cfg.fillers)
        }
        // Longest keys first so multi-word phrases win over their fragments.
        for (key, value) in cfg.dictionary.sorted(by: { $0.key.count > $1.key.count }) {
            text = replaceWord(in: text, key, with: value)
        }
        text = tidy(text)
        text = regexReplace(text, "\\bi\\b", "I")   // standalone i (and i'm, i'll…) → I
        text = capitalizeSentences(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Passes (validated in isolation)

    private func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private func regexReplace(_ text: String, _ pattern: String, _ template: String) -> String {
        guard let re = regex(pattern) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    /// Whole-word/phrase, case-insensitive replacement.
    private func replaceWord(in text: String, _ phrase: String, with repl: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        guard let re = regex("\\b\(escaped)\\b") else { return text }
        let tmpl = NSRegularExpression.escapedTemplate(for: repl)
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: tmpl)
    }

    private func removeFillers(_ text: String, _ fillers: [String]) -> String {
        let alt = fillers.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        guard let re = regex("\\b(?:\(alt))\\b,?") else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    /// Collapse runs of spaces, drop space before punctuation, trim trailing
    /// spaces before a newline, and strip leading spaces/commas per line
    /// (artifacts of filler removal). Newlines are preserved.
    private func tidy(_ text: String) -> String {
        var t = text
        t = regexReplace(t, "[ \\t]{2,}", " ")
        t = regexReplace(t, " +([,.!?;:])", "$1")
        t = regexReplace(t, "[ \\t]+\n", "\n")
        t = regexReplace(t, "(?m)^[ \\t,]+", "")
        return t
    }

    /// Capitalize the first letter of the text and the start of each sentence
    /// (after . ! ? or a paragraph break).
    private func capitalizeSentences(_ text: String) -> String {
        guard let re = regex("(^|[.!?]\\s+|\\n+)([a-z])") else { return text }
        let ns = text as NSString
        let result = NSMutableString(string: text)
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let r = m.range(at: 2)
            result.replaceCharacters(in: r, with: ns.substring(with: r).uppercased())
        }
        return result as String
    }
}
