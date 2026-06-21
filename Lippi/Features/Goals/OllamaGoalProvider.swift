import Foundation

struct OllamaConfiguration: Equatable {
    static let enabledKey = "ollama.provider.enabled"
    static let endpointKey = "ollama.provider.endpoint"
    static let modelKey = "ollama.provider.model"
    static let defaultModel = "qwen3:1.7b"

    var isEnabled: Bool
    var endpoint: String
    var model: String

    static var stored: OllamaConfiguration {
        OllamaConfiguration(
            isEnabled: UserDefaults.standard.bool(forKey: enabledKey),
            endpoint: UserDefaults.standard.string(forKey: endpointKey) ?? "",
            model: UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
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
        request.timeoutInterval = 80
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
    let stream = false
    let think = false
    let format = "json"
    private let options = GenerateOptions()

    private struct GenerateOptions: Encodable {
        let temperature = 0.1
        let numPredict = 1_000
        let repeatPenalty = 1.12
        let repeatLastN = 128

        enum CodingKeys: String, CodingKey {
            case temperature
            case numPredict = "num_predict"
            case repeatPenalty = "repeat_penalty"
            case repeatLastN = "repeat_last_n"
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
