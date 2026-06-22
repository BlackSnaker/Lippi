import Testing
@testable import Lippi

struct NeuralVoiceConfigurationTests {
    @Test("Builds the neural voice endpoint from a local Mac address")
    func buildsLocalEndpoint() throws {
        let configuration = NeuralVoiceConfiguration(
            isEnabled: true,
            endpoint: "http://192.168.1.5:8158"
        )

        let url = try configuration.endpointURL(path: "v1/audio/speech")
        #expect(url.absoluteString == "http://192.168.1.5:8158/v1/audio/speech")
        #expect(configuration.isConfigured)
    }

    @Test("Rejects loopback because it points to the iPhone")
    func rejectsLoopbackEndpoint() {
        let configuration = NeuralVoiceConfiguration(isEnabled: true, endpoint: "http://127.0.0.1:8158")

        do {
            _ = try configuration.endpointURL(path: "health")
            Issue.record("Expected loopback endpoint to be rejected")
        } catch let error as NeuralVoiceProviderError {
            guard case .loopbackEndpoint = error else {
                Issue.record("Expected loopbackEndpoint, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Maps a calm voice setting to a slower neural delivery")
    func mapsSpeechSpeedToLengthScale() {
        #expect(HealthVoicePlaybackSpeed.calm.neuralLengthScale > HealthVoicePlaybackSpeed.balanced.neuralLengthScale)
        #expect(HealthVoicePlaybackSpeed.energetic.neuralLengthScale < HealthVoicePlaybackSpeed.balanced.neuralLengthScale)
    }
}
