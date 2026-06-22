import Foundation

struct NeuralVoiceConfiguration: Equatable {
    static let enabledKey = "neural.voice.provider.enabled"
    static let endpointKey = "neural.voice.provider.endpoint"
    static let defaultPort = 8158

    var isEnabled: Bool
    var endpoint: String

    static var stored: NeuralVoiceConfiguration {
        let defaults = UserDefaults.standard
        let savedEndpoint = defaults.string(forKey: endpointKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return NeuralVoiceConfiguration(
            isEnabled: defaults.object(forKey: enabledKey) as? Bool ?? true,
            endpoint: savedEndpoint.isEmpty ? suggestedEndpoint : savedEndpoint
        )
    }

    static var suggestedEndpoint: String {
        let ollamaEndpoint = UserDefaults.standard.string(forKey: OllamaConfiguration.endpointKey) ?? ""
        guard var components = URLComponents(string: ollamaEndpoint), components.host != nil else {
            return ""
        }
        components.port = defaultPort
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.string ?? ""
    }

    var isConfigured: Bool {
        isEnabled && !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func supports(_ language: AppLang) -> Bool {
        language == .ru
    }

    func endpointURL(path: String) throws -> URL {
        let raw = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw NeuralVoiceProviderError.invalidEndpoint
        }

        guard !Self.isLoopbackHost(host) else {
            throw NeuralVoiceProviderError.loopbackEndpoint
        }
        if scheme == "http", !Self.isLocalNetworkHost(host) {
            throw NeuralVoiceProviderError.insecureRemoteEndpoint
        }

        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let baseURL = components.url else {
            throw NeuralVoiceProviderError.invalidEndpoint
        }
        return baseURL.appendingPathComponent(path)
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

enum NeuralVoiceProviderError: Error {
    case notConfigured
    case invalidEndpoint
    case loopbackEndpoint
    case insecureRemoteEndpoint
    case transport
    case server(status: Int)
    case malformedResponse
    case modelUnavailable

    func message(lang: AppLang) -> String {
        switch self {
        case .notConfigured:
            return L10n.tr("voice.neural.error.not_configured", lang)
        case .invalidEndpoint:
            return L10n.tr("voice.neural.error.invalid_endpoint", lang)
        case .loopbackEndpoint:
            return L10n.tr("voice.neural.error.loopback", lang)
        case .insecureRemoteEndpoint:
            return L10n.tr("voice.neural.error.insecure_remote", lang)
        case .transport:
            return L10n.tr("voice.neural.error.transport", lang)
        case .server(let status):
            return L10n.fmt("voice.neural.error.server", lang, status)
        case .malformedResponse:
            return L10n.tr("voice.neural.error.malformed", lang)
        case .modelUnavailable:
            return L10n.tr("voice.neural.error.model_unavailable", lang)
        }
    }
}

struct NeuralVoiceConnectionReport: Equatable {
    let isReady: Bool
    let voice: String
}

struct MacNeuralVoiceProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func check(configuration: NeuralVoiceConfiguration) async throws -> NeuralVoiceConnectionReport {
        guard configuration.isConfigured else { throw NeuralVoiceProviderError.notConfigured }
        var request = URLRequest(url: try configuration.endpointURL(path: "health"))
        request.httpMethod = "GET"
        request.timeoutInterval = 4

        let data = try await perform(request)
        guard let health = try? JSONDecoder().decode(HealthResponse.self, from: data) else {
            throw NeuralVoiceProviderError.malformedResponse
        }
        return NeuralVoiceConnectionReport(isReady: health.ready, voice: health.voice)
    }

    func synthesize(
        _ text: String,
        language: AppLang,
        lengthScale: Double,
        configuration: NeuralVoiceConfiguration
    ) async throws -> Data {
        guard configuration.isConfigured else { throw NeuralVoiceProviderError.notConfigured }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NeuralVoiceProviderError.malformedResponse }

        var request = URLRequest(url: try configuration.endpointURL(path: "v1/audio/speech"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/wav", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            SpeechRequest(text: trimmed, language: language.speechLanguageCode, lengthScale: lengthScale)
        )

        let data = try await perform(request)
        guard data.count > 44 else { throw NeuralVoiceProviderError.malformedResponse }
        return data
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NeuralVoiceProviderError.transport
            }
            guard (200..<300).contains(http.statusCode) else {
                throw NeuralVoiceProviderError.server(status: http.statusCode)
            }
            return data
        } catch let error as NeuralVoiceProviderError {
            throw error
        } catch {
            throw NeuralVoiceProviderError.transport
        }
    }

    private struct SpeechRequest: Encodable {
        let text: String
        let language: String
        let lengthScale: Double

        enum CodingKeys: String, CodingKey {
            case text
            case language
            case lengthScale = "length_scale"
        }
    }

    private struct HealthResponse: Decodable {
        let ready: Bool
        let voice: String
    }
}

extension HealthVoicePlaybackSpeed {
    var neuralLengthScale: Double {
        switch self {
        case .calm: return 1.12
        case .balanced: return 1.0
        case .energetic: return 0.90
        }
    }
}
