import AVFoundation
import Foundation
import Testing
@testable import Lippi

struct NeuralVoiceConfigurationTests {
    @Test("F2 is the default female Supertonic voice")
    func mapsDefaultFemaleProfile() {
        #expect(LocalNeuralVoiceProfile.defaultProfile == .f2)
        #expect(LocalNeuralVoiceProfile.f2.speakerID == 1)
    }

    @Test("M3 maps to the third male voice in the packed voice file")
    func mapsMaleProfile() {
        #expect(LocalNeuralVoiceProfile.m3.speakerID == 7)
    }

    @Test("Local voice supports every language exposed by Lippi")
    func supportsAppLanguages() {
        let configuration = NeuralVoiceConfiguration(isEnabled: true, profile: .f2)
        for language in AppLang.allCases {
            #expect(configuration.supports(language))
        }
    }

    @Test("Maps playback preference to Supertonic speed")
    func mapsSpeechSpeed() {
        #expect(
            HealthVoicePlaybackSpeed.calm.neuralSpeed
                < HealthVoicePlaybackSpeed.balanced.neuralSpeed
        )
        #expect(
            HealthVoicePlaybackSpeed.energetic.neuralSpeed
                > HealthVoicePlaybackSpeed.balanced.neuralSpeed
        )
    }

    @Test("Voice archive metadata stays pinned")
    func pinsVoiceArchive() {
        let descriptor = LocalVoiceModelDescriptor.recommended
        #expect(descriptor.archiveByteCount == 128_774_318)
        #expect(
            descriptor.archiveSHA256
                == "82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427"
        )
        #expect(LocalVoiceModelStorage.requiredFiles.count == 7)
        #expect(LocalVoiceModelStorage.installedByteCount == 145_295_768)
        #expect(LocalVoiceModelStorage.requiredFiles["voice.bin"] == 517_168)
    }

    @Test("Installed Supertonic runtime synthesizes both selected profiles")
    @MainActor
    func synthesizesSelectedProfilesWhenModelIsAvailable() async throws {
        guard LocalVoiceModelStorage.isInstalled else { return }
        #expect(LocalVoiceModelStorage.isVerified)
        UserDefaults.standard.set(true, forKey: NeuralVoiceConfiguration.enabledKey)
        #expect(NeuralVoiceConfiguration.stored.isConfigured)
        LocalVoiceModelStore.shared.refresh()
        #expect(LocalVoiceModelStore.shared.isReady)

        for profile in [LocalNeuralVoiceProfile.f2, .m3] {
            let audio = try await LocalNeuralVoiceProvider.shared.synthesize(
                "Привет! Это голос Lippi.",
                language: .ru,
                speed: 1,
                profile: profile
            )
            #expect(audio.count > 44)
            #expect(audio.prefix(4) == Data("RIFF".utf8))

            let player = try AVAudioPlayer(data: audio)
            #expect(player.prepareToPlay())
            #expect(player.play())
            player.stop()
        }
    }
}
