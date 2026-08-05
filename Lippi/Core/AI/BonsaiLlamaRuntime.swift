import Foundation

#if canImport(llama)
import llama
#endif

enum BonsaiRuntimeError: Error, Equatable {
    case runtimeUnavailable
    case modelMissing
    case modelLoadFailed
    case contextCreationFailed
    case lowPowerMode
    case thermalLimitReached
    case timeLimitReached
    case promptTooLong
    case tokenizationFailed
    case evaluationFailed
    case emptyResponse
}

enum BonsaiDeviceThermalLevel: Int, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

enum BonsaiGenerationSafetyStopReason: Equatable, Sendable {
    case lowPowerMode
    case thermal
    case timeLimit
}

struct BonsaiGenerationWorkloadProfile: Equatable, Sendable {
    let outputTokenLimit: Int32
    let decodeThreads: Int32
    let promptThreads: Int32
    let promptChunkSize: Int
    let safetyCheckInterval: Int
    let tokenPauseInterval: Int
    let tokenPause: TimeInterval
    let promptChunkPause: TimeInterval
}

struct BonsaiDeviceState: Equatable, Sendable {
    let thermalLevel: BonsaiDeviceThermalLevel
    let isLowPowerModeEnabled: Bool

    static var current: BonsaiDeviceState {
        let processInfo = ProcessInfo.processInfo
        return BonsaiDeviceState(
            thermalLevel: processInfo.bonsaiThermalLevel,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled
        )
    }
}

enum BonsaiGenerationSafetyPolicy {
    // The compact roadmap contract should finish comfortably inside this
    // window. A shorter hard ceiling prevents a stalled local decode from
    // keeping the device under sustained load.
    static let roadmapMaximumDuration: TimeInterval = 72
    static let progressMaximumDuration: TimeInterval = 45
    static let personalRecommendationMaximumDuration: TimeInterval = 24
    static let eyeHealthMaximumDuration: TimeInterval = 18
    static let minimumUsefulPartialTokens = 24
    static let contextTokenCapacity: UInt32 = 3_072
    static let batchTokenCapacity: UInt32 = 256
    static let microBatchTokenCapacity: UInt32 = 128

    static func roadmapOutputTokenBudget(forWeeks weeks: Int) -> Int32 {
        weeks == 12 ? 640 : 520
    }

    static func effectiveOutputTokenLimit(requested: Int32, thermalLevel: BonsaiDeviceThermalLevel) -> Int32 {
        guard thermalLevel == .fair else { return requested }
        return max(160, Int32((Double(requested) * 0.82).rounded(.down)))
    }

    static func workloadProfile(
        requestedOutputTokens: Int32,
        thermalLevel: BonsaiDeviceThermalLevel,
        processorCount: Int
    ) -> BonsaiGenerationWorkloadProfile {
        let availableThreads = max(1, processorCount - 2)
        let preferredThreads = thermalLevel == .nominal ? 3 : 2
        let threads = Int32(max(1, min(preferredThreads, availableThreads)))

        if thermalLevel == .fair {
            return BonsaiGenerationWorkloadProfile(
                outputTokenLimit: effectiveOutputTokenLimit(
                    requested: requestedOutputTokens,
                    thermalLevel: thermalLevel
                ),
                decodeThreads: threads,
                promptThreads: threads,
                promptChunkSize: 96,
                safetyCheckInterval: 2,
                tokenPauseInterval: 4,
                tokenPause: 0.018,
                promptChunkPause: 0.016
            )
        }

        return BonsaiGenerationWorkloadProfile(
            outputTokenLimit: requestedOutputTokens,
            decodeThreads: threads,
            promptThreads: threads,
            promptChunkSize: 192,
            safetyCheckInterval: 4,
            tokenPauseInterval: 16,
            tokenPause: 0.002,
            promptChunkPause: 0.004
        )
    }

    static func shouldRetrieveSupplementalEvidence(
        thermalLevel: BonsaiDeviceThermalLevel,
        isLowPowerModeEnabled: Bool
    ) -> Bool {
        !isLowPowerModeEnabled && thermalLevel == .nominal
    }

    static func stopReason(
        thermalLevel: BonsaiDeviceThermalLevel,
        isLowPowerModeEnabled: Bool,
        elapsed: TimeInterval,
        maximumDuration: TimeInterval
    ) -> BonsaiGenerationSafetyStopReason? {
        if isLowPowerModeEnabled { return .lowPowerMode }
        if thermalLevel == .serious || thermalLevel == .critical { return .thermal }
        // Fair is a signal to slow down, not to discard useful work. Serious
        // and critical states still stop immediately above. The extra time lets
        // paced decoding finish the compact core without defeating protection.
        let effectiveDuration = thermalLevel == .fair ? min(maximumDuration, 62) : maximumDuration
        return elapsed >= effectiveDuration ? .timeLimit : nil
    }

    static func canReturnPartial(_ text: String, generatedTokens: Int) -> Bool {
        generatedTokens >= minimumUsefulPartialTokens && text.contains("{")
    }
}

struct BonsaiGenerationOptions: Sendable {
    var maximumOutputTokens: Int32
    var maximumDuration: TimeInterval = BonsaiGenerationSafetyPolicy.roadmapMaximumDuration
    var stopsAtCompleteJSONObject = true
}

private extension ProcessInfo {
    var bonsaiThermalLevel: BonsaiDeviceThermalLevel {
        switch thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
    }

    var bonsaiSafetyStopReason: BonsaiGenerationSafetyStopReason? {
        BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: bonsaiThermalLevel,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            elapsed: 0,
            maximumDuration: .greatestFiniteMagnitude
        )
    }
}

actor BonsaiInferenceEngine {
    static let shared = BonsaiInferenceEngine()

    #if canImport(llama)
    private var loadedContext: BonsaiLlamaContext?
    private var loadedModelURL: URL?
    private var idleUnloadTask: Task<Void, Never>?
    #endif

    func generate(
        systemPrompt: String,
        userPrompt: String,
        options: BonsaiGenerationOptions
    ) throws -> String {
        guard BonsaiModelStorage.isInstalled else { throw BonsaiRuntimeError.modelMissing }
        try Self.ensureDeviceCanStartGeneration()

        #if canImport(llama)
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
        let loadedContext = try loadContextIfNeeded()
        do {
            let prompt = BonsaiPromptTemplate.chat(system: systemPrompt, user: userPrompt)
            let output = try loadedContext.generate(prompt: prompt, options: options)
            let response = output.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !response.isEmpty else { throw BonsaiRuntimeError.emptyResponse }

            if output.stoppedForSafety {
                releaseLoadedContext()
            } else {
                scheduleIdleUnload()
            }
            return response
        } catch {
            if Self.isSafetyError(error) {
                releaseLoadedContext()
            } else {
                scheduleIdleUnload()
            }
            throw error
        }
        #else
        throw BonsaiRuntimeError.runtimeUnavailable
        #endif
    }

    /// Loads the model without spending output tokens. Callers keep retrieval
    /// separate from this cold-start work to avoid stacking their peak loads.
    func prepare() throws {
        guard BonsaiModelStorage.isInstalled else { throw BonsaiRuntimeError.modelMissing }
        try Self.ensureDeviceCanStartGeneration()

        #if canImport(llama)
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
        _ = try loadContextIfNeeded()
        scheduleIdleUnload()
        #else
        throw BonsaiRuntimeError.runtimeUnavailable
        #endif
    }

    func unload() {
        #if canImport(llama)
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
        releaseLoadedContext()
        #endif
    }

    private static func ensureDeviceCanStartGeneration() throws {
        switch ProcessInfo.processInfo.bonsaiSafetyStopReason {
        case .lowPowerMode:
            throw BonsaiRuntimeError.lowPowerMode
        case .thermal:
            throw BonsaiRuntimeError.thermalLimitReached
        case .timeLimit, .none:
            return
        }
    }

    private static func isSafetyError(_ error: Error) -> Bool {
        guard let runtimeError = error as? BonsaiRuntimeError else { return false }
        return runtimeError == .lowPowerMode
            || runtimeError == .thermalLimitReached
            || runtimeError == .timeLimitReached
    }

    #if canImport(llama)
    private func loadContextIfNeeded() throws -> BonsaiLlamaContext {
        let modelURL = BonsaiModelStorage.modelURL
        if loadedContext == nil || loadedModelURL != modelURL {
            loadedContext = nil
            loadedContext = try BonsaiLlamaContext(modelURL: modelURL)
            loadedModelURL = modelURL
        }
        guard let loadedContext else { throw BonsaiRuntimeError.contextCreationFailed }
        return loadedContext
    }

    private func releaseLoadedContext() {
        loadedContext = nil
        loadedModelURL = nil
    }

    private func scheduleIdleUnload() {
        idleUnloadTask?.cancel()
        idleUnloadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled else { return }
            await self?.unload()
        }
    }
    #endif
}

private enum BonsaiPromptTemplate {
    static func chat(system: String, user: String) -> String {
        // Bonsai 4B inherits Qwen's ChatML template. Prefilling the closed
        // thinking block keeps structured app responses concise and parseable.
        """
        <|im_start|>system
        \(system)<|im_end|>
        <|im_start|>user
        \(user)<|im_end|>
        <|im_start|>assistant
        <think>

        </think>

        """
    }
}

#if canImport(llama)
private func bonsaiBatchClear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

private func bonsaiBatchAdd(
    _ batch: inout llama_batch,
    token: llama_token,
    position: llama_pos,
    logits: Bool
) {
    let index = Int(batch.n_tokens)
    batch.token[index] = token
    batch.pos[index] = position
    batch.n_seq_id[index] = 1
    batch.seq_id[index]![0] = 0
    batch.logits[index] = logits ? 1 : 0
    batch.n_tokens += 1
}

private struct BonsaiGeneratedText {
    var text: String
    var generatedTokens: Int
    var stopReason: BonsaiGenerationSafetyStopReason?

    var stoppedForSafety: Bool { stopReason != nil }
}

private final class BonsaiLlamaContext {
    // The planner uses a compact contract and lets deterministic Swift code
    // complete support fields. A 3K context and a smaller micro-batch reduce
    // KV-cache and prompt-evaluation peaks on iPhone without reducing the
    // amount of user context that reaches the model.
    private static let contextSize = BonsaiGenerationSafetyPolicy.contextTokenCapacity
    private static let batchSize = BonsaiGenerationSafetyPolicy.batchTokenCapacity

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var pendingUTF8: [CChar] = []
    private var activeDecodeThreads: Int32 = 0
    private var activePromptThreads: Int32 = 0

    init(modelURL: URL) throws {
        llama_backend_init()

        var modelParameters = llama_model_default_params()
        modelParameters.use_mmap = true
        modelParameters.use_mlock = false
        #if targetEnvironment(simulator)
        modelParameters.n_gpu_layers = 0
        #else
        modelParameters.n_gpu_layers = 99
        #endif

        guard let model = llama_model_load_from_file(modelURL.path, modelParameters) else {
            llama_backend_free()
            throw BonsaiRuntimeError.modelLoadFailed
        }

        let processInfo = ProcessInfo.processInfo
        let workload = BonsaiGenerationSafetyPolicy.workloadProfile(
            requestedOutputTokens: 1,
            thermalLevel: processInfo.bonsaiThermalLevel,
            processorCount: processInfo.processorCount
        )
        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = Self.contextSize
        contextParameters.n_batch = Self.batchSize
        contextParameters.n_ubatch = BonsaiGenerationSafetyPolicy.microBatchTokenCapacity
        contextParameters.n_threads = workload.decodeThreads
        contextParameters.n_threads_batch = workload.promptThreads

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            llama_backend_free()
            throw BonsaiRuntimeError.contextCreationFailed
        }

        let samplerParameters = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParameters) else {
            llama_free(context)
            llama_model_free(model)
            llama_backend_free()
            throw BonsaiRuntimeError.contextCreationFailed
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(12))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.82, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.3))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(0xB05A1))

        self.model = model
        self.context = context
        self.vocab = llama_model_get_vocab(model)
        self.sampler = sampler
        self.batch = llama_batch_init(Int32(Self.batchSize), 0, 1)
        self.activeDecodeThreads = workload.decodeThreads
        self.activePromptThreads = workload.promptThreads
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    func generate(prompt: String, options: BonsaiGenerationOptions) throws -> BonsaiGeneratedText {
        let startedAt = Date()
        let processInfo = ProcessInfo.processInfo
        var workload = BonsaiGenerationSafetyPolicy.workloadProfile(
            requestedOutputTokens: options.maximumOutputTokens,
            thermalLevel: processInfo.bonsaiThermalLevel,
            processorCount: processInfo.processorCount
        )
        var effectiveOutputTokens = workload.outputTokenLimit
        apply(workload)
        let promptTokens = try tokenize(prompt)
        let availablePromptTokens = Int(Self.contextSize) - Int(effectiveOutputTokens) - 8
        guard promptTokens.count <= availablePromptTokens else {
            throw BonsaiRuntimeError.promptTooLong
        }

        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)
        pendingUTF8.removeAll(keepingCapacity: true)

        try evaluatePrompt(
            promptTokens,
            startedAt: startedAt,
            maximumDuration: options.maximumDuration
        )
        var currentPosition = Int32(promptTokens.count)
        var result = ""
        var jsonTracker = BonsaiJSONObjectTracker()
        var generatedTokens = 0
        var safetyStopReason: BonsaiGenerationSafetyStopReason?

        for tokenIndex in 0..<options.maximumOutputTokens {
            if Task.isCancelled { throw CancellationError() }
            if tokenIndex >= effectiveOutputTokens {
                break
            }

            if tokenIndex.isMultiple(of: Int32(workload.safetyCheckInterval)) {
                if let stopReason = currentSafetyStopReason(
                   startedAt: startedAt,
                   maximumDuration: options.maximumDuration
                ) {
                    guard BonsaiGenerationSafetyPolicy.canReturnPartial(result, generatedTokens: generatedTokens) else {
                        throw runtimeError(for: stopReason)
                    }
                    safetyStopReason = stopReason
                    break
                }

                let currentProcessInfo = ProcessInfo.processInfo
                let currentWorkload = BonsaiGenerationSafetyPolicy.workloadProfile(
                    requestedOutputTokens: options.maximumOutputTokens,
                    thermalLevel: currentProcessInfo.bonsaiThermalLevel,
                    processorCount: currentProcessInfo.processorCount
                )
                // A run may become warmer, but never expands again after it has
                // entered the paced profile. This avoids a second thermal peak.
                effectiveOutputTokens = min(effectiveOutputTokens, currentWorkload.outputTokenLimit)
                workload = currentWorkload
                apply(workload)
            }

            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            llama_sampler_accept(sampler, token)
            let tokenPiece = piece(for: token)
            result.append(contentsOf: tokenPiece)
            generatedTokens += 1

            // Structured Lippi requests need one root JSON object. Stop on its
            // closing brace instead of letting the model generate trailing
            // prose or whitespace for hundreds of additional tokens.
            if options.stopsAtCompleteJSONObject, jsonTracker.consume(tokenPiece) {
                break
            }

            bonsaiBatchClear(&batch)
            bonsaiBatchAdd(&batch, token: token, position: currentPosition, logits: true)
            guard llama_decode(context, batch) == 0 else {
                throw BonsaiRuntimeError.evaluationFailed
            }
            currentPosition += 1

            if generatedTokens.isMultiple(of: workload.tokenPauseInterval) {
                Thread.sleep(forTimeInterval: workload.tokenPause)
            }
        }

        if !pendingUTF8.isEmpty {
            result.append(contentsOf: String(decoding: pendingUTF8.map { UInt8(bitPattern: $0) }, as: UTF8.self))
            pendingUTF8.removeAll(keepingCapacity: true)
        }

        let cleaned = result
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw BonsaiRuntimeError.emptyResponse }
        return BonsaiGeneratedText(
            text: cleaned,
            generatedTokens: generatedTokens,
            stopReason: safetyStopReason
        )
    }

    private func evaluatePrompt(
        _ tokens: [llama_token],
        startedAt: Date,
        maximumDuration: TimeInterval
    ) throws {
        var offset = 0
        while offset < tokens.count {
            if let stopReason = currentSafetyStopReason(
                startedAt: startedAt,
                maximumDuration: maximumDuration
            ) {
                throw runtimeError(for: stopReason)
            }
            let processInfo = ProcessInfo.processInfo
            let workload = BonsaiGenerationSafetyPolicy.workloadProfile(
                requestedOutputTokens: 1,
                thermalLevel: processInfo.bonsaiThermalLevel,
                processorCount: processInfo.processorCount
            )
            apply(workload)
            let end = min(offset + workload.promptChunkSize, tokens.count)
            bonsaiBatchClear(&batch)

            for index in offset..<end {
                bonsaiBatchAdd(
                    &batch,
                    token: tokens[index],
                    position: Int32(index),
                    logits: index == tokens.count - 1
                )
            }

            guard llama_decode(context, batch) == 0 else {
                throw BonsaiRuntimeError.evaluationFailed
            }
            offset = end
            if offset < tokens.count {
                Thread.sleep(forTimeInterval: workload.promptChunkPause)
            }
        }
    }

    private func apply(_ workload: BonsaiGenerationWorkloadProfile) {
        guard workload.decodeThreads != activeDecodeThreads
                || workload.promptThreads != activePromptThreads else { return }
        llama_set_n_threads(context, workload.decodeThreads, workload.promptThreads)
        activeDecodeThreads = workload.decodeThreads
        activePromptThreads = workload.promptThreads
    }

    private func currentSafetyStopReason(
        startedAt: Date,
        maximumDuration: TimeInterval
    ) -> BonsaiGenerationSafetyStopReason? {
        let processInfo = ProcessInfo.processInfo
        return BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: processInfo.bonsaiThermalLevel,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            elapsed: Date().timeIntervalSince(startedAt),
            maximumDuration: maximumDuration
        )
    }

    private func runtimeError(for stopReason: BonsaiGenerationSafetyStopReason) -> BonsaiRuntimeError {
        switch stopReason {
        case .lowPowerMode: return .lowPowerMode
        case .thermal: return .thermalLimitReached
        case .timeLimit: return .timeLimitReached
        }
    }

    private func tokenize(_ text: String) throws -> [llama_token] {
        var capacity = max(32, text.utf8.count + 16)

        while true {
            var tokens = Array(repeating: llama_token(0), count: capacity)
            let count = tokens.withUnsafeMutableBufferPointer { buffer in
                llama_tokenize(
                    vocab,
                    text,
                    Int32(text.utf8.count),
                    buffer.baseAddress,
                    Int32(buffer.count),
                    false,
                    true
                )
            }

            if count >= 0 {
                return Array(tokens.prefix(Int(count)))
            }
            let required = Int(-count)
            guard required > capacity else { throw BonsaiRuntimeError.tokenizationFailed }
            capacity = required
        }
    }

    private func piece(for token: llama_token) -> String {
        var capacity = 32

        while true {
            var buffer = Array(repeating: CChar(0), count: capacity)
            let count = buffer.withUnsafeMutableBufferPointer { pointer in
                llama_token_to_piece(vocab, token, pointer.baseAddress, Int32(pointer.count), 0, false)
            }

            if count < 0 {
                capacity = Int(-count)
                continue
            }

            pendingUTF8.append(contentsOf: buffer.prefix(Int(count)))
            let bytes = pendingUTF8.map { UInt8(bitPattern: $0) }
            guard let value = String(bytes: bytes, encoding: .utf8) else { return "" }
            pendingUTF8.removeAll(keepingCapacity: true)
            return value
        }
    }
}

private struct BonsaiJSONObjectTracker {
    private var hasStarted = false
    private var depth = 0
    private var isInsideString = false
    private var isEscaping = false

    mutating func consume(_ piece: String) -> Bool {
        for scalar in piece.unicodeScalars {
            let value = scalar.value

            if !hasStarted {
                guard value == 123 else { continue } // {
                hasStarted = true
                depth = 1
                continue
            }

            if isInsideString {
                if isEscaping {
                    isEscaping = false
                } else if value == 92 { // \\
                    isEscaping = true
                } else if value == 34 { // "
                    isInsideString = false
                }
                continue
            }

            switch value {
            case 34: // "
                isInsideString = true
            case 123: // {
                depth += 1
            case 125: // }
                depth -= 1
                if depth == 0 { return true }
            default:
                break
            }
        }
        return false
    }
}
#endif
