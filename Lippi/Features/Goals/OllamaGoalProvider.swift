import Foundation

struct OllamaConfiguration: Equatable {
    static let enabledKey = "ollama.provider.enabled"
    static let endpointKey = "ollama.provider.endpoint"
    static let modelKey = "ollama.provider.model"
    static let defaultModel = "qwen3:4b"
    private static let legacyDefaultModel = "qwen3:1.7b"
    private static let modelUpgradeKey = "ollama.provider.modelUpgrade.4b"

    var isEnabled: Bool
    var endpoint: String
    var model: String

    static var stored: OllamaConfiguration {
        let defaults = UserDefaults.standard
        let storedModel = defaults.string(forKey: modelKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model: String
        if storedModel == legacyDefaultModel, !defaults.bool(forKey: modelUpgradeKey) {
            model = defaultModel
            defaults.set(model, forKey: modelKey)
            defaults.set(true, forKey: modelUpgradeKey)
        } else {
            model = (storedModel?.isEmpty == false) ? storedModel! : defaultModel
        }

        return OllamaConfiguration(
            isEnabled: defaults.bool(forKey: enabledKey),
            endpoint: defaults.string(forKey: endpointKey) ?? "",
            model: model
        )
    }

    var isConfigured: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func baseURL() throws -> URL {
        let raw = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw OllamaProviderError.invalidEndpoint
        }

        guard !OllamaConfiguration.isLoopbackHost(host) else {
            throw OllamaProviderError.loopbackEndpoint
        }
        if scheme == "http", !OllamaConfiguration.isLocalNetworkHost(host) {
            throw OllamaProviderError.insecureRemoteEndpoint
        }

        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw OllamaProviderError.invalidEndpoint }
        return url
    }

    func endpointURL(path: String) throws -> URL {
        try baseURL().appendingPathComponent(path)
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        host == "localhost" || host == "::1" || host.hasPrefix("127.")
    }

    private static func isLocalNetworkHost(_ host: String) -> Bool {
        if host.hasSuffix(".local") { return true }
        let numbers = host.split(separator: ".").compactMap { Int($0) }
        guard numbers.count == 4 else { return false }
        if numbers[0] == 10 || numbers[0] == 127 { return true }
        if numbers[0] == 192, numbers[1] == 168 { return true }
        if numbers[0] == 172, (16...31).contains(numbers[1]) { return true }
        return numbers[0] == 169 && numbers[1] == 254
    }
}

enum OllamaProviderError: Error {
    case notConfigured
    case invalidEndpoint
    case loopbackEndpoint
    case insecureRemoteEndpoint
    case transport
    case server(status: Int)
    case malformedResponse
    case incompleteRoadmap
    case modelMissing

    func message(lang: AppLang) -> String {
        switch self {
        case .notConfigured:
            return L10n.tr("ollama.error.not_configured", lang)
        case .invalidEndpoint:
            return L10n.tr("ollama.error.invalid_endpoint", lang)
        case .loopbackEndpoint:
            return L10n.tr("ollama.error.loopback", lang)
        case .insecureRemoteEndpoint:
            return L10n.tr("ollama.error.insecure_remote", lang)
        case .transport:
            return L10n.tr("ollama.error.transport", lang)
        case .server(let status):
            return L10n.fmt("ollama.error.server", lang, status)
        case .malformedResponse:
            return L10n.tr("ollama.error.malformed", lang)
        case .incompleteRoadmap:
            return L10n.tr("ollama.error.incomplete_plan", lang)
        case .modelMissing:
            return L10n.tr("ollama.error.model_missing", lang)
        }
    }
}

struct OllamaConnectionReport: Equatable {
    let availableModels: [String]
    let configuredModelIsAvailable: Bool
}

struct OllamaGoalProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(configuration: OllamaConfiguration) async throws -> OllamaConnectionReport {
        guard configuration.isConfigured else { throw OllamaProviderError.notConfigured }
        let url = try configuration.endpointURL(path: "api/tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let data = try await perform(request)
        let response: TagsResponse
        do {
            response = try JSONDecoder().decode(TagsResponse.self, from: data)
        } catch {
            throw OllamaProviderError.malformedResponse
        }

        let models = response.models.map(\.name)
        let selected = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAvailable = models.contains { name in
            name == selected || name == "\(selected):latest" || selected == "\(name):latest"
        }
        return OllamaConnectionReport(availableModels: models, configuredModelIsAvailable: isAvailable)
    }

    func generate(prompt: String, configuration: OllamaConfiguration) async throws -> String {
        guard configuration.isConfigured else { throw OllamaProviderError.notConfigured }
        let url = try configuration.endpointURL(path: "api/generate")
        let body = GenerateRequest(
            model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: prompt
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await perform(request)
        let response: GenerateResponse
        do {
            response = try JSONDecoder().decode(GenerateResponse.self, from: data)
        } catch {
            throw OllamaProviderError.malformedResponse
        }
        let content = response.response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw OllamaProviderError.malformedResponse }
        return content
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw OllamaProviderError.transport }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 404 { throw OllamaProviderError.modelMissing }
                throw OllamaProviderError.server(status: http.statusCode)
            }
            return data
        } catch let error as OllamaProviderError {
            throw error
        } catch {
            throw OllamaProviderError.transport
        }
    }
}

private struct GenerateRequest: Encodable {
    let model: String
    let prompt: String
    let system = OllamaPlannerSystemPrompt.value
    let stream = false
    let think = false
    let keepAlive = "15m"
    let format = OllamaRoadmapSchema.response
    private let options = GenerateOptions()

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case system
        case stream
        case think
        case keepAlive = "keep_alive"
        case format
        case options
    }

    private struct GenerateOptions: Encodable {
        let temperature = 0.05
        let numPredict = 1_200
        let repeatPenalty = 1.08
        let repeatLastN = 96

        enum CodingKeys: String, CodingKey {
            case temperature
            case numPredict = "num_predict"
            case repeatPenalty = "repeat_penalty"
            case repeatLastN = "repeat_last_n"
        }
    }
}

private enum OllamaPlannerSystemPrompt {
    static let value = """
    You are Lippi's grounded goal-roadmap planner. Your job is to turn a user's stated goal and constraints into a practical route, not to predict success.
    Treat only the user brief and supplied excerpts as facts. Unknown details must be assumptions or clarifying questions.
    Never invent users, demand, feedback, downloads, revenue, conversion, prices, health outcomes, legal outcomes, deadlines, resources, or personal circumstances.
    Return only valid JSON that matches the supplied schema. Do not add Markdown or explanations.
    """
}

private enum OllamaRoadmapSchema {
    static let response: OllamaJSONSchema = .object(
        properties: [
            "title": .string,
            "summary": .string,
            "confidence": .number,
            "successCriteria": .array(items: .string, minItems: 2, maxItems: 2),
            "firstActions": .array(items: .string, minItems: 2, maxItems: 2),
            "assumptions": .array(items: .string, minItems: 0, maxItems: 3),
            "clarifyingQuestions": .array(items: .string, minItems: 0, maxItems: 3),
            "milestones": .array(items: milestone, minItems: 3, maxItems: 4),
            "habits": .array(items: support, minItems: 1, maxItems: 2),
            "risks": .array(items: risk, minItems: 1, maxItems: 2)
        ],
        required: [
            "title", "summary", "confidence", "successCriteria", "firstActions", "assumptions",
            "clarifyingQuestions", "milestones", "habits", "risks"
        ]
    )

    private static let milestone: OllamaJSONSchema = .object(
        properties: [
            "title": .string,
            "timeframe": .string,
            "target": .string,
            "tasks": .array(items: .string, minItems: 2, maxItems: 3),
            "category": .stringEnum(["work", "study", "health", "rest", "home", "other"])
        ],
        required: ["title", "timeframe", "target", "tasks", "category"]
    )

    private static let support: OllamaJSONSchema = .object(
        properties: ["title": .string, "detail": .string],
        required: ["title", "detail"]
    )

    private static let risk: OllamaJSONSchema = .object(
        properties: ["title": .string, "mitigation": .string],
        required: ["title", "mitigation"]
    )
}

private indirect enum OllamaJSONSchema: Encodable {
    case string
    case number
    case stringEnum([String])
    case array(items: OllamaJSONSchema, minItems: Int?, maxItems: Int?)
    case object(properties: [String: OllamaJSONSchema], required: [String])

    private enum CodingKeys: String, CodingKey {
        case type
        case properties
        case required
        case items
        case minItems = "minItems"
        case maxItems = "maxItems"
        case enumValues = "enum"
        case additionalProperties
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string:
            try container.encode("string", forKey: .type)
        case .number:
            try container.encode("number", forKey: .type)
        case .stringEnum(let values):
            try container.encode("string", forKey: .type)
            try container.encode(values, forKey: .enumValues)
        case .array(let items, let minItems, let maxItems):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encodeIfPresent(minItems, forKey: .minItems)
            try container.encodeIfPresent(maxItems, forKey: .maxItems)
        case .object(let properties, let required):
            try container.encode("object", forKey: .type)
            try container.encode(properties, forKey: .properties)
            try container.encode(required, forKey: .required)
            try container.encode(false, forKey: .additionalProperties)
        }
    }
}

private struct GenerateResponse: Decodable {
    let response: String
}

private struct TagsResponse: Decodable {
    let models: [Model]

    struct Model: Decodable {
        let name: String
    }
}
