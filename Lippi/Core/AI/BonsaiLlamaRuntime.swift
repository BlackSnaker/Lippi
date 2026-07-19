import Foundation

#if canImport(llama)
import llama
#endif

enum BonsaiRuntimeError: Error, Equatable {
    case runtimeUnavailable
    case modelMissing
    case modelLoadFailed
    case contextCreationFailed
    case promptTooLong
    case tokenizationFailed
    case evaluationFailed
    case emptyResponse
}

struct BonsaiGenerationOptions: Sendable {
    var maximumOutputTokens: Int32
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

        #if canImport(llama)
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
        defer { scheduleIdleUnload() }

        let modelURL = BonsaiModelStorage.modelURL
        if loadedContext == nil || loadedModelURL != modelURL {
            loadedContext = nil
            loadedContext = try BonsaiLlamaContext(modelURL: modelURL)
            loadedModelURL = modelURL
        }
        guard let loadedContext else { throw BonsaiRuntimeError.contextCreationFailed }

        let prompt = BonsaiPromptTemplate.chat(system: systemPrompt, user: userPrompt)
        let response = try loadedContext.generate(prompt: prompt, options: options)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else { throw BonsaiRuntimeError.emptyResponse }
        return response
        #else
        throw BonsaiRuntimeError.runtimeUnavailable
        #endif
    }

    func unload() {
        #if canImport(llama)
        idleUnloadTask?.cancel()
        idleUnloadTask = nil
        loadedContext = nil
        loadedModelURL = nil
        #endif
    }

    #if canImport(llama)
    private func scheduleIdleUnload() {
        idleUnloadTask?.cancel()
        idleUnloadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(90))
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

private final class BonsaiLlamaContext {
    private static let contextSize: UInt32 = 8_192
    private static let batchSize: UInt32 = 512

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var pendingUTF8: [CChar] = []

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
        let isThermallyConstrained: Bool
        switch processInfo.thermalState {
        case .serious, .critical:
            isThermallyConstrained = true
        default:
            isThermallyConstrained = false
        }
        let preferredThreads = (processInfo.isLowPowerModeEnabled || isThermallyConstrained) ? 2 : 4
        let threads = Int32(max(2, min(preferredThreads, processInfo.processorCount - 2)))
        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = Self.contextSize
        contextParameters.n_batch = Self.batchSize
        contextParameters.n_ubatch = Self.batchSize
        contextParameters.n_threads = threads
        contextParameters.n_threads_batch = threads

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
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(20))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.85, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.5))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(0xB05A1))

        self.model = model
        self.context = context
        self.vocab = llama_model_get_vocab(model)
        self.sampler = sampler
        self.batch = llama_batch_init(Int32(Self.batchSize), 0, 1)
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_free(context)
        llama_model_free(model)
        llama_backend_free()
    }

    func generate(prompt: String, options: BonsaiGenerationOptions) throws -> String {
        let promptTokens = try tokenize(prompt)
        let availablePromptTokens = Int(Self.contextSize) - Int(options.maximumOutputTokens) - 8
        guard promptTokens.count <= availablePromptTokens else {
            throw BonsaiRuntimeError.promptTooLong
        }

        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)
        pendingUTF8.removeAll(keepingCapacity: true)

        try evaluatePrompt(promptTokens)
        var currentPosition = Int32(promptTokens.count)
        var result = ""

        for _ in 0..<options.maximumOutputTokens {
            if Task.isCancelled { throw CancellationError() }

            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            llama_sampler_accept(sampler, token)
            result += piece(for: token)

            bonsaiBatchClear(&batch)
            bonsaiBatchAdd(&batch, token: token, position: currentPosition, logits: true)
            guard llama_decode(context, batch) == 0 else {
                throw BonsaiRuntimeError.evaluationFailed
            }
            currentPosition += 1
        }

        if !pendingUTF8.isEmpty {
            result += String(decoding: pendingUTF8.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            pendingUTF8.removeAll(keepingCapacity: true)
        }

        let cleaned = result
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw BonsaiRuntimeError.emptyResponse }
        return cleaned
    }

    private func evaluatePrompt(_ tokens: [llama_token]) throws {
        var offset = 0
        while offset < tokens.count {
            let end = min(offset + Int(Self.batchSize), tokens.count)
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
#endif
