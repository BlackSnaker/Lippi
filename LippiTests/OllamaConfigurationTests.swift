import Testing
@testable import Lippi

struct OllamaConfigurationTests {
    @Test("Builds the Ollama endpoint from a local Mac address")
    func buildsLocalEndpoint() throws {
        let configuration = OllamaConfiguration(
            isEnabled: true,
            endpoint: "http://192.168.1.5:11434",
            model: "qwen3:0.6b"
        )

        let url = try configuration.endpointURL(path: "api/generate")
        #expect(url.absoluteString == "http://192.168.1.5:11434/api/generate")
        #expect(configuration.isConfigured)
    }

    @Test("Rejects localhost because it points to the iPhone")
    func rejectsLoopbackEndpoint() {
        let configuration = OllamaConfiguration(
            isEnabled: true,
            endpoint: "http://127.0.0.1:11434",
            model: "qwen3:0.6b"
        )

        do {
            _ = try configuration.baseURL()
            Issue.record("Expected loopback endpoint to be rejected")
        } catch let error as OllamaProviderError {
            guard case .loopbackEndpoint = error else {
                Issue.record("Expected loopbackEndpoint, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects insecure external HTTP endpoint")
    func rejectsInsecureExternalEndpoint() {
        let configuration = OllamaConfiguration(
            isEnabled: true,
            endpoint: "http://example.com:11434",
            model: "qwen3:0.6b"
        )

        do {
            _ = try configuration.baseURL()
            Issue.record("Expected external HTTP endpoint to be rejected")
        } catch let error as OllamaProviderError {
            guard case .insecureRemoteEndpoint = error else {
                Issue.record("Expected insecureRemoteEndpoint, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
