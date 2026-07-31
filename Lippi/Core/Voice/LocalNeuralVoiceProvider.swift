import Foundation

final class LocalNeuralVoiceProvider: @unchecked Sendable {
    static let shared = LocalNeuralVoiceProvider()

    private let queue = DispatchQueue(
        label: "app.lippi.voice.supertonic",
        qos: .utility
    )
    private let runtimeLock = NSLock()
    private var runtime: SupertonicRuntime?
    private var lastLongGenerationFinishedAt: Date?
    private var unloadWorkItem: DispatchWorkItem?

    private init() {}

    func synthesize(
        _ text: String,
        language: AppLang,
        speed: Float,
        profile: LocalNeuralVoiceProfile
    ) async throws -> Data {
        guard NeuralVoiceConfiguration.stored.isEnabled else {
            throw NeuralVoiceProviderError.disabled
        }
        guard LocalVoiceModelStorage.isInstalled else {
            throw NeuralVoiceProviderError.modelUnavailable
        }
        try Self.checkPowerPolicy()

        let preparedText = Self.preparedText(text, language: language)
        guard !preparedText.isEmpty else {
            throw NeuralVoiceProviderError.generation
        }

        let cancellation = VoiceGenerationCancellation(
            deadline: Date().addingTimeInterval(20)
        )
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { [weak self] in
                    guard let self else {
                        continuation.resume(
                            throwing: NeuralVoiceProviderError.generation
                        )
                        return
                    }
                    self.unloadWorkItem?.cancel()
                    self.unloadWorkItem = nil
                    do {
                        try Self.checkPowerPolicy()
                        try self.checkCooldown()
                        let startedAt = Date()
                        let runtime = try self.loadedRuntime()
                        defer { self.scheduleRuntimeUnload() }
                        let data = try runtime.generate(
                            text: preparedText,
                            language: language,
                            speed: Self.optimizedSpeed(speed, language: language),
                            profile: profile,
                            cancellation: cancellation
                        )
                        let duration = Date().timeIntervalSince(startedAt)
                        if duration >= 12 {
                            self.lastLongGenerationFinishedAt = Date()
                        }
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    func unload() {
        queue.async { [weak self] in
            self?.unloadWorkItem?.cancel()
            self?.unloadWorkItem = nil
            self?.runtimeLock.lock()
            self?.runtime = nil
            self?.runtimeLock.unlock()
        }
    }

    private func loadedRuntime() throws -> SupertonicRuntime {
        runtimeLock.lock()
        defer { runtimeLock.unlock() }
        if let runtime { return runtime }
        let created = try SupertonicRuntime()
        runtime = created
        return created
    }

    private func scheduleRuntimeUnload() {
        unloadWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.runtimeLock.lock()
            self.runtime = nil
            self.runtimeLock.unlock()
            self.unloadWorkItem = nil
        }
        unloadWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 45, execute: workItem)
    }

    private func checkCooldown() throws {
        guard let lastLongGenerationFinishedAt else { return }
        if Date().timeIntervalSince(lastLongGenerationFinishedAt) < 15 {
            throw NeuralVoiceProviderError.cooldown
        }
    }

    private static func preparedText(_ text: String, language: AppLang) -> String {
        let normalized = LocalVoiceTextNormalizer.normalize(text, language: language)
        guard normalized.count > 480 else { return normalized }

        let end = normalized.index(normalized.startIndex, offsetBy: 480)
        let prefix = String(normalized[..<end])
        if let sentenceEnd = prefix.lastIndex(where: { ".!?…".contains($0) }),
           prefix.distance(from: sentenceEnd, to: prefix.endIndex) < 140 {
            return String(prefix[...sentenceEnd])
        }
        if let wordEnd = prefix.lastIndex(where: \.isWhitespace) {
            return String(prefix[..<wordEnd]).trimmingCharacters(in: .whitespaces) + "…"
        }
        return prefix + "…"
    }

    static func optimizedSpeed(
        _ requestedSpeed: Float,
        language: AppLang
    ) -> Float {
        let safeSpeed = min(max(requestedSpeed, 0.82), 1.12)
        guard language == .ru else { return safeSpeed }

        // Compact multilingual voices articulate Russian consonant clusters
        // more clearly with a small amount of extra time per phoneme.
        return min(max(safeSpeed - 0.04, 0.84), 1.04)
    }

    private static func checkPowerPolicy() throws {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            throw NeuralVoiceProviderError.lowPowerMode
        }
    }
}

private final class VoiceGenerationCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false
    private let deadline: Date

    init(deadline: Date) {
        self.deadline = deadline
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    func shouldContinue() -> Bool {
        lock.lock()
        let cancelled = isCancelled
        lock.unlock()
        return !cancelled && Date() < deadline
    }
}

private final class SupertonicRuntime {
    private let tts: OpaquePointer

    init() throws {
        let supertonic = SherpaOnnxOfflineTtsSupertonicModelConfig(
            duration_predictor: Self.cString(
                LocalVoiceModelStorage.fileURL("duration_predictor.int8.onnx").path
            ),
            text_encoder: Self.cString(
                LocalVoiceModelStorage.fileURL("text_encoder.int8.onnx").path
            ),
            vector_estimator: Self.cString(
                LocalVoiceModelStorage.fileURL("vector_estimator.int8.onnx").path
            ),
            vocoder: Self.cString(
                LocalVoiceModelStorage.fileURL("vocoder.int8.onnx").path
            ),
            tts_json: Self.cString(
                LocalVoiceModelStorage.fileURL("tts.json").path
            ),
            unicode_indexer: Self.cString(
                LocalVoiceModelStorage.fileURL("unicode_indexer.bin").path
            ),
            voice_style: Self.cString(
                LocalVoiceModelStorage.fileURL("voice.bin").path
            )
        )
        let model = SherpaOnnxOfflineTtsModelConfig(
            vits: Self.emptyVits(),
            num_threads: 2,
            debug: 0,
            provider: Self.cString("cpu"),
            matcha: Self.emptyMatcha(),
            kokoro: Self.emptyKokoro(),
            kitten: Self.emptyKitten(),
            zipvoice: Self.emptyZipvoice(),
            pocket: Self.emptyPocket(),
            supertonic: supertonic
        )
        var config = SherpaOnnxOfflineTtsConfig(
            model: model,
            rule_fsts: Self.cString(""),
            max_num_sentences: 1,
            rule_fars: Self.cString(""),
            silence_scale: 0.22
        )
        guard let created = SherpaOnnxCreateOfflineTts(&config) else {
            throw NeuralVoiceProviderError.initialization
        }
        tts = created
    }

    deinit {
        SherpaOnnxDestroyOfflineTts(tts)
    }

    func generate(
        text: String,
        language: AppLang,
        speed: Float,
        profile: LocalNeuralVoiceProfile,
        cancellation: VoiceGenerationCancellation
    ) throws -> Data {
        let extra = #"{"lang":"\#(language.rawValue)"}"#
        var config = SherpaOnnxGenerationConfig(
            silence_scale: 0.22,
            speed: speed,
            sid: Int32(profile.speakerID),
            reference_audio: nil,
            reference_audio_len: 0,
            reference_sample_rate: 16_000,
            reference_text: Self.cString(""),
            num_steps: 5,
            extra: Self.cString(extra)
        )
        let retainedCancellation = Unmanaged.passRetained(cancellation)
        defer { retainedCancellation.release() }

        let callback: @convention(c) (
            UnsafePointer<Float>?,
            Int32,
            Float,
            UnsafeMutableRawPointer?
        ) -> Int32 = { _, _, _, context in
            guard let context else { return 0 }
            let token = Unmanaged<VoiceGenerationCancellation>
                .fromOpaque(context)
                .takeUnretainedValue()
            return token.shouldContinue() ? 1 : 0
        }

        let audio = withUnsafePointer(to: &config) { configPointer in
            SherpaOnnxOfflineTtsGenerateWithConfig(
                tts,
                Self.cString(text),
                configPointer,
                callback,
                retainedCancellation.toOpaque()
            )
        }
        guard let audio else {
            if !cancellation.shouldContinue() {
                throw NeuralVoiceProviderError.cancelled
            }
            throw NeuralVoiceProviderError.generation
        }
        defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }
        guard cancellation.shouldContinue() else {
            throw NeuralVoiceProviderError.cancelled
        }

        let count = Int(audio.pointee.n)
        guard count > 0, let samples = audio.pointee.samples else {
            throw NeuralVoiceProviderError.generation
        }
        return Self.wavData(
            samples: UnsafeBufferPointer(start: samples, count: count),
            sampleRate: Int(audio.pointee.sample_rate)
        )
    }

    private static func cString(_ string: String) -> UnsafePointer<CChar>? {
        (string as NSString).utf8String
    }

    private static func emptyVits() -> SherpaOnnxOfflineTtsVitsModelConfig {
        SherpaOnnxOfflineTtsVitsModelConfig(
            model: cString(""), lexicon: cString(""), tokens: cString(""),
            data_dir: cString(""), noise_scale: 0.667, noise_scale_w: 0.8,
            length_scale: 1, dict_dir: cString("")
        )
    }

    private static func emptyMatcha() -> SherpaOnnxOfflineTtsMatchaModelConfig {
        SherpaOnnxOfflineTtsMatchaModelConfig(
            acoustic_model: cString(""), vocoder: cString(""),
            lexicon: cString(""), tokens: cString(""), data_dir: cString(""),
            noise_scale: 0.667, length_scale: 1, dict_dir: cString("")
        )
    }

    private static func emptyKokoro() -> SherpaOnnxOfflineTtsKokoroModelConfig {
        SherpaOnnxOfflineTtsKokoroModelConfig(
            model: cString(""), voices: cString(""), tokens: cString(""),
            data_dir: cString(""), length_scale: 1, dict_dir: cString(""),
            lexicon: cString(""), lang: cString("")
        )
    }

    private static func emptyKitten() -> SherpaOnnxOfflineTtsKittenModelConfig {
        SherpaOnnxOfflineTtsKittenModelConfig(
            model: cString(""), voices: cString(""), tokens: cString(""),
            data_dir: cString(""), length_scale: 1
        )
    }

    private static func emptyZipvoice() -> SherpaOnnxOfflineTtsZipvoiceModelConfig {
        SherpaOnnxOfflineTtsZipvoiceModelConfig(
            tokens: cString(""), encoder: cString(""), decoder: cString(""),
            vocoder: cString(""), data_dir: cString(""), lexicon: cString(""),
            feat_scale: 0.1, t_shift: 0.5, target_rms: 0.1,
            guidance_scale: 1
        )
    }

    private static func emptyPocket() -> SherpaOnnxOfflineTtsPocketModelConfig {
        SherpaOnnxOfflineTtsPocketModelConfig(
            lm_flow: cString(""), lm_main: cString(""), encoder: cString(""),
            decoder: cString(""), text_conditioner: cString(""),
            vocab_json: cString(""), token_scores_json: cString(""),
            voice_embedding_cache_capacity: 2
        )
    }

    private static func wavData(
        samples: UnsafeBufferPointer<Float>,
        sampleRate: Int
    ) -> Data {
        var pcm = [Int16]()
        pcm.reserveCapacity(samples.count)
        for sample in samples {
            let clamped = min(max(sample, -1), 1)
            pcm.append(Int16(clamped * Float(Int16.max)))
        }

        let pcmByteCount = pcm.count * MemoryLayout<Int16>.size
        var data = Data(capacity: 44 + pcmByteCount)
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + pcmByteCount))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(pcmByteCount))
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
