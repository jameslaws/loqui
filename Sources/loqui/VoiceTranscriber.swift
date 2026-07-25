import AVFoundation
import Speech
import SwiftUI

/// On-device Apple transcription for the global voice key's transcribe-anywhere
/// mode (press the shortcut, speak, and the cleaned text pastes at the cursor).
///
/// Primary path: the macOS 26 SpeechAnalyzer/SpeechTranscriber API — built
/// for continuous dictation: punctuated results, volatile partials that
/// firm up into finalized text, no per-utterance resets, no time cap. The
/// legacy SFSpeechRecognizer path (which never punctuates on this OS and
/// resets mid-task on pauses) survives only as a fallback for when the new
/// stack can't initialize (unsupported locale, missing model assets).
@MainActor
final class VoiceTranscriber: ObservableObject {
    @Published var transcript = ""
    /// Live mic amplitude 0…1 (RMS, fast attack / slow decay) — the HUD waveform
    /// pulses with YOUR speech while listening.
    @Published var level: Double = 0

    private var smoothedLevel: Double = 0
    private var peak: Double = 0.02
    private var engine: AVAudioEngine?
    private var finalized = ""
    private var partial = ""
    private var running = false
    private var startedAt: Date?

    /// When a buffer last reached the main actor, and when one last carried
    /// actual speech. The service's watchdog reads both: prolonged silence
    /// means a lost key-up, while buffers stopping entirely means the audio
    /// graph died under us and the rest of the session would be lost.
    private(set) var lastBufferAt = Date.distantPast
    private(set) var lastSpeechAt = Date.distantPast

    private var configObserver: NSObjectProtocol?

    // MARK: SpeechAnalyzer path

    // Held as `Any?` so this file compiles at the macOS 15 deployment target —
    // the concrete types (SpeechAnalyzer / SpeechTranscriber / AnalyzerInput) are
    // macOS 26+ and only ever touched inside `if #available(macOS 26, *)`.
    private var analyzer: Any?               // SpeechAnalyzer (macOS 26+)
    private var analyzerTranscriber: Any?    // SpeechTranscriber (macOS 26+)
    private var inputBuilder: Any?           // AsyncStream<AnalyzerInput>.Continuation (26+)
    private var analyzerFormat: AVAudioFormat?
    private var resultsTask: Task<Void, Never>?

    // MARK: Legacy path

    private let recognizer = SFSpeechRecognizer()
    private var legacyTask: SFSpeechRecognitionTask?
    private let requestBox = RequestBox()
    private var usingLegacy = false
    private var lastVoiceAt: TimeInterval = 0
    private var segmentClosing = false
    private let silenceWindow: TimeInterval = 1.3

    func begin() async -> Bool {
        transcript = ""
        finalized = ""
        partial = ""
        startedAt = Date()
        lastBufferAt = Date()
        lastSpeechAt = Date()
        if #available(macOS 26, *), await beginAnalyzer() { return true }
        voiceKeyLog("SpeechAnalyzer unavailable — falling back to legacy recognizer")
        return await beginLegacy()
    }

    /// Stop and return everything heard. The analyzer runs a beat behind the
    /// voice — returning immediately dropped the last seconds of speech. So:
    /// stop the mic, ask the analyzer to finalize THROUGH the end of input,
    /// drain the results stream, then hand back the complete text (bounded so
    /// a wedged analyzer can't hold the send hostage).
    func end() async -> String {
        running = false
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        if !usingLegacy, #available(macOS 26, *), let analyzer = analyzer as? SpeechAnalyzer {
            (inputBuilder as? AsyncStream<AnalyzerInput>.Continuation)?.finish()
            inputBuilder = nil
            let drain = resultsTask
            // The drain budget has to scale with the session: a long dictation
            // leaves a proportionally bigger backlog to flush, so the old flat
            // 3s ceiling silently truncated the tail of exactly the sessions
            // that mattered most. Finalizing normally takes well under a
            // second, so a roomier bound costs nothing in the common case.
            let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
            let budget = min(20, max(5, elapsed / 20))
            let drained = await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    try? await analyzer.finalizeAndFinishThroughEndOfInput()
                    await drain?.value   // trailing finals land in the loop
                    return true
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(budget))
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
            if !drained {
                voiceKeyLog("WARNING: drain exceeded \(Int(budget))s after \(Int(elapsed))s of audio — tail may be truncated")
            }
        }
        bank(partial)
        partial = ""
        publish()
        tearDown()
        return transcript
    }

    func cancel() {
        tearDown()
        transcript = ""
        finalized = ""
        partial = ""
    }

    private func tearDown() {
        running = false
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        analyzerFormat = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        level = 0
        smoothedLevel = 0
        peak = 0.02   // reset auto-gain so the next session meters fresh
        // analyzer path (end() already finalized; cancel() lands here cold)
        if #available(macOS 26, *) {
            (inputBuilder as? AsyncStream<AnalyzerInput>.Continuation)?.finish()
            if let analyzer = analyzer as? SpeechAnalyzer {
                Task { try? await analyzer.finalizeAndFinishThroughEndOfInput() }
            }
        }
        inputBuilder = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        analyzerTranscriber = nil
        // legacy path
        requestBox.endAudio()
        requestBox.set(nil)
        legacyTask?.finish()
        legacyTask = nil
        usingLegacy = false
    }

    private func bank(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        finalized = finalized.isEmpty ? trimmed : finalized + " " + trimmed
    }

    private func publish() {
        transcript = partial.isEmpty
            ? finalized
            : (finalized.isEmpty ? partial : finalized + " " + partial)
    }

    /// Shared mic metering — drives the HUD waveform (and, on the legacy
    /// path, the silence-segmentation clock).
    private func meter(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = n > 0 ? Double(sqrt(sum / Float(n))) : 0
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastBufferAt = Date()
            // AUTO-GAIN: normalize against the loudest thing heard recently,
            // so it tracks YOUR voice at YOUR mic level.
            self.peak = max(rms, self.peak * 0.995)
            var raw = self.peak > 0.004 ? min(1.0, rms / self.peak) : 0
            // NOISE GATE: room rumble and breath don't move the HUD waveform.
            raw = raw < 0.22 ? 0 : (raw - 0.22) / 0.78
            if raw > 0 { self.lastSpeechAt = Date() }
            // shaped attack + slow release — syllables, not flicker
            if raw > self.smoothedLevel {
                self.smoothedLevel += (raw - self.smoothedLevel) * 0.65
            } else {
                self.smoothedLevel *= 0.88
            }
            if abs(self.smoothedLevel - self.level) > 0.01 {
                self.level = self.smoothedLevel
            }
            if self.usingLegacy { self.observeSilence(speaking: raw > 0) }
        }
    }

    // MARK: - SpeechAnalyzer (macOS 26)

    @available(macOS 26, *)
    private func beginAnalyzer() async -> Bool {
        guard let locale = await supportedAnalyzerLocale() else { return false }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        do {
            // First ever run may need the dictation model — install is a
            // one-time download, instant when already present.
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                return false
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            let (sequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
            try await analyzer.start(inputSequence: sequence)

            self.analyzerFormat = format
            try startAnalyzerEngine(format: format, builder: builder)
            observeConfigChange()

            self.analyzer = analyzer
            self.analyzerTranscriber = transcriber
            self.inputBuilder = builder
            self.usingLegacy = false
            self.running = true

            resultsTask = Task { @MainActor [weak self] in
                do {
                    for try await result in transcriber.results {
                        guard let self else { return }
                        let text = String(result.text.characters)
                        if result.isFinal {
                            self.bank(text)
                            self.partial = ""
                        } else {
                            self.partial = text
                        }
                        self.publish()
                    }
                } catch {
                    voiceKeyLog("SpeechAnalyzer results stream ended: \(error.localizedDescription)")
                }
            }
            voiceKeyLog("transcribing via SpeechAnalyzer (\(locale.identifier))")
            return true
        } catch {
            voiceKeyLog("SpeechAnalyzer setup failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Build the mic graph and pump converted buffers into the analyzer. Split
    /// out of `beginAnalyzer` so it can be re-run mid-dictation when the audio
    /// device changes underneath us.
    @available(macOS 26, *)
    private func startAnalyzerEngine(
        format: AVAudioFormat, builder: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: tapFormat, to: format) else {
            throw TranscriberError.noConverter
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            self?.meter(buffer)
            if let converted = Self.convert(buffer, with: converter, to: format) {
                builder.yield(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    /// AVAudioEngine STOPS itself whenever the audio hardware is reconfigured —
    /// AirPods connecting, a dock or monitor mic appearing, another app seizing
    /// the input, a sample-rate change. Nothing throws and nothing logs: the tap
    /// simply stops delivering, so the session looks live while capturing
    /// silence, and you paste only what was said before the change. Rebuilding
    /// the graph on the same analyzer keeps the dictation going.
    private func observeConfigChange() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.rebuildInputGraph() }
        }
    }

    private func rebuildInputGraph() {
        guard running, !usingLegacy, #available(macOS 26, *),
              let format = analyzerFormat,
              let builder = inputBuilder as? AsyncStream<AnalyzerInput>.Continuation
        else { return }
        voiceKeyLog("audio configuration changed mid-dictation — rebuilding the input tap")
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        do {
            try startAnalyzerEngine(format: format, builder: builder)
            voiceKeyLog("input tap rebuilt — dictation continues")
        } catch {
            voiceKeyLog("input tap rebuild FAILED: \(error.localizedDescription) — audio is dead for the rest of this dictation")
        }
    }

    @available(macOS 26, *)
    private func supportedAnalyzerLocale() async -> Locale? {
        let supported = await SpeechTranscriber.supportedLocales
        let current = Locale.current
        if let exact = supported.first(where: {
            $0.identifier(.bcp47) == current.identifier(.bcp47)
        }) { return exact }
        // Same language, different region beats nothing.
        return supported.first {
            $0.language.languageCode == current.language.languageCode
        }
    }

    /// Tap-thread sample-rate conversion into the analyzer's preferred format.
    private static func convert(
        _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }

    // MARK: - Legacy fallback (SFSpeechRecognizer)

    private func beginLegacy() async -> Bool {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized, let recognizer, recognizer.isAvailable else { return false }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, requestBox] buffer, _ in
            requestBox.append(buffer)
            self?.meter(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { return false }
        self.engine = engine
        usingLegacy = true
        running = true
        startLegacySegment()
        return true
    }

    /// Close the live segment after a beat of silence so its text banks NOW,
    /// deterministically — the legacy recognizer handles a pause by resetting
    /// to a new utterance mid-task with no isFinal and no error.
    private func observeSilence(speaking: Bool) {
        guard running, usingLegacy else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if speaking { lastVoiceAt = now; return }
        if !segmentClosing, !partial.isEmpty, now - lastVoiceAt > silenceWindow {
            segmentClosing = true
            requestBox.endAudio()   // forces isFinal → bank → fresh segment
        }
    }

    private func startLegacySegment() {
        guard running, let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true   // ignored in practice, but free
        requestBox.set(request)
        segmentClosing = false
        legacyTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleLegacySegment(result: result, error: error)
            }
        }
    }

    private func handleLegacySegment(result: SFSpeechRecognitionResult?, error: Error?) {
        guard usingLegacy else { return }
        if let result {
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                bank(text)
                partial = ""
                if running { startLegacySegment() }
            } else {
                // A sharp shrink means the decoder reset to a new utterance —
                // bank the old text instead of letting it be overwritten.
                if text.count + 8 < partial.count { bank(partial) }
                partial = text
            }
            publish()
        } else if error != nil, running {
            bank(partial)
            partial = ""
            publish()
            startLegacySegment()
        }
    }
}

enum TranscriberError: Error {
    case noConverter
}

/// Lock-guarded handle to the current legacy recognition request — the audio
/// tap appends from a realtime thread while the main actor swaps segments.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ new: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); defer { lock.unlock() }
        request = new
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        request?.append(buffer)
    }

    func endAudio() {
        lock.lock(); defer { lock.unlock() }
        request?.endAudio()
    }
}
