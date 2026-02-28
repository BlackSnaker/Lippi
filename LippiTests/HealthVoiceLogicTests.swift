import Testing
@testable import Lippi

struct HealthVoiceLogicTests {

    @Test("Voice speed rates are ordered")
    func voiceSpeedRatesAreOrdered() {
        #expect(HealthVoicePlaybackSpeed.calm.speechRate < HealthVoicePlaybackSpeed.balanced.speechRate)
        #expect(HealthVoicePlaybackSpeed.balanced.speechRate < HealthVoicePlaybackSpeed.energetic.speechRate)
    }

    @Test("Speech language code mapping is stable")
    func speechLanguageCodeMapping() {
        #expect(AppLang.ru.speechLanguageCode == "ru-RU")
        #expect(AppLang.en.speechLanguageCode == "en-US")
        #expect(AppLang.de.speechLanguageCode == "de-DE")
        #expect(AppLang.es.speechLanguageCode == "es-ES")
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
            "settings.voice.preview"
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
