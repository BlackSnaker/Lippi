import Foundation
import AVFoundation

enum HealthVoicePreferences {
    static let isEnabledKey = "health.voice.enabled"
    static let autoSpeakKey = "health.voice.auto"
    static let defaultEnabled = true
    static let defaultAutoSpeak = false
}

enum HealthVoicePlaybackSpeed: String, CaseIterable, Identifiable, Codable {
    case calm
    case balanced
    case energetic

    static let storageKey = "health.voice.speed"
    static let defaultSpeed: HealthVoicePlaybackSpeed = .balanced

    var id: String { rawValue }

    func title(_ lang: AppLang) -> String {
        L10n.tr("health.voice.speed.\(rawValue)", lang)
    }
}

@MainActor
final class HealthVoiceAssistant: NSObject, ObservableObject {
    @Published private(set) var isSpeaking: Bool = false

    private var neuralPlayer: AVAudioPlayer?
    private var neuralSpeechTask: Task<Void, Never>?
    private var speechRequestID = UUID()

    func speak(
        _ text: String,
        language: AppLang,
        speed: HealthVoicePlaybackSpeed
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stopCurrentPlayback()
        let requestID = UUID()
        speechRequestID = requestID
        let configuration = NeuralVoiceConfiguration.stored

        guard configuration.isEnabled, configuration.supports(language) else {
            isSpeaking = false
            return
        }
        guard configuration.isConfigured else {
            LocalVoiceModelStore.shared.ensureDownloadStarted()
            isSpeaking = false
            return
        }

        isSpeaking = true
        neuralSpeechTask = Task { [weak self] in
            do {
                let audio = try await LocalNeuralVoiceProvider.shared.synthesize(
                    trimmed,
                    language: language,
                    speed: speed.neuralSpeed,
                    profile: configuration.profile
                )
                guard !Task.isCancelled, let self, self.speechRequestID == requestID else { return }
                self.playNeuralAudio(audio)
            } catch {
                guard !Task.isCancelled, let self, self.speechRequestID == requestID else { return }
                self.isSpeaking = false
            }
        }
    }

    func stop() {
        speechRequestID = UUID()
        stopCurrentPlayback()
        isSpeaking = false
    }

    private func playNeuralAudio(_ audio: Data) {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            // Simulator can temporarily report no host audio route while its
            // CoreAudio device is reconfiguring. AVAudioPlayer can still recover,
            // so audio-session preparation must not suppress otherwise valid WAV.
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.setActive(true)
            #endif

            let player = try AVAudioPlayer(data: audio)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { throw NSError(domain: "Lippi.NeuralVoice", code: 1) }
            neuralPlayer = player
            isSpeaking = true
        } catch {
            isSpeaking = false
        }
    }

    private func stopCurrentPlayback() {
        neuralSpeechTask?.cancel()
        neuralSpeechTask = nil
        neuralPlayer?.stop()
        neuralPlayer = nil
    }
}

extension HealthVoiceAssistant: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.neuralPlayer === player else { return }
            self.neuralPlayer = nil
            self.isSpeaking = false
        }
    }
}
