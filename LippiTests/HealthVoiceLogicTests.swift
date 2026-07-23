import Testing
@testable import Lippi

struct HealthVoiceLogicTests {

    @Test("Voice speed rates are ordered")
    func voiceSpeedRatesAreOrdered() {
        #expect(HealthVoicePlaybackSpeed.calm.neuralSpeed < HealthVoicePlaybackSpeed.balanced.neuralSpeed)
        #expect(HealthVoicePlaybackSpeed.balanced.neuralSpeed < HealthVoicePlaybackSpeed.energetic.neuralSpeed)
    }

    @Test("Only local neural voice profiles are exposed")
    func onlyLocalNeuralVoiceProfilesAreExposed() {
        #expect(LocalNeuralVoiceProfile.allCases == [.f2, .m3])
    }

    @Test("Voice preferences defaults")
    func voicePreferencesDefaults() {
        #expect(HealthVoicePreferences.defaultEnabled == true)
        #expect(HealthVoicePreferences.defaultAutoSpeak == false)
        #expect(HealthVoicePlaybackSpeed.defaultSpeed == .balanced)
    }

    @Test("Voice localization keys resolve for all languages")
    func voiceLocalizationKeysResolve() {
        let keys = [
            "health.voice.title",
            "health.voice.subtitle",
            "health.voice.button.play",
            "health.voice.button.stop",
            "health.voice.status.ready",
            "health.voice.report.summary",
            "health.voice.speed.calm",
            "health.voice.speed.balanced",
            "health.voice.speed.energetic",
            "settings.voice.title",
            "settings.voice.enabled_title",
            "settings.voice.auto_title",
            "settings.voice.speed_title",
            "settings.neural_voice.enabled_hint",
            "settings.neural_voice.profile.f2",
            "settings.neural_voice.profile.m3",
            "settings.neural_voice.thermal_hint",
            "settings.neural_voice.ready_hint",
            "settings.neural_voice.installation_complete",
            "settings.neural_voice.installation_complete_hint",
            "settings.neural_voice.preview_playing",
            "settings.neural_voice.preview_error",
            "settings.neural_voice.downloading_hint",
            "settings.neural_voice.paused_hint",
            "settings.neural_voice.retrying",
            "settings.neural_voice.retrying_hint",
            "settings.neural_voice.retry_now",
            "settings.neural_voice.decompressing",
            "settings.neural_voice.decompressing_hint",
            "settings.neural_voice.download_speed",
            "settings.neural_voice.time_remaining",
            "settings.neural_voice.install_progress",
            "settings.neural_voice.elapsed",
            "settings.neural_voice.phase.download",
            "settings.neural_voice.phase.verify",
            "settings.neural_voice.phase.unpack",
            "settings.neural_voice.phase.install"
        ]

        for lang in AppLang.allCases {
            for key in keys {
                let value = L10n.tr(key, lang).trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(!value.isEmpty)
                #expect(value != key)
            }
        }
    }
}
