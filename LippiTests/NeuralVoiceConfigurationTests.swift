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
        #expect(
            LocalNeuralVoiceProvider.optimizedSpeed(1, language: .ru)
                == 0.96
        )
        #expect(
            LocalNeuralVoiceProvider.optimizedSpeed(1, language: .en)
                == 1
        )
        #expect(LocalNeuralVoiceProvider.silenceScale(for: .ru) == 0.28)
        #expect(LocalNeuralVoiceProvider.silenceScale(for: .en) == 0.22)
    }

    @Test("Russian speech expands time, percentages, identifiers, and counters")
    func normalizesRussianSpeechValues() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "В 15:30 готово 64%, профиль F2, осталось 3 задачи.",
            language: .ru
        )

        #expect(
            spoken
                == "В пятнадцать часов тридцать минут готово шестьдесят четыре процента, профиль эф два, осталось три задачи."
        )
    }

    @Test("English speech handles leading-zero time and progress")
    func normalizesEnglishSpeechValues() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "At 9:05, progress is 27% and 2 tasks remain.",
            language: .en
        )

        #expect(spoken == "At nine oh five, progress is twenty seven percent and two tasks remain.")
    }

    @Test("Russian product names and dates become pronounceable")
    func normalizesRussianProductNamesAndDates() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Lippi на iPhone: встреча 30.07.2026, версия R1.",
            language: .ru
        )

        #expect(spoken.contains("Липпи на айфон"))
        #expect(spoken.contains("тридцатое июля две тысячи двадцать шестого года"))
        #expect(spoken.contains("ар один"))
        let containsNumber = spoken.contains(where: { $0.isNumber })
        #expect(!containsNumber)
    }

    @Test("Health measurements are expanded with natural Russian forms")
    func normalizesHealthMeasurements() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Пройдено 4,8 км и 572 шага за 25 мин. Пульс — 64 BPM.",
            language: .ru
        )

        #expect(spoken.contains("четыре целых восемь десятых километра"))
        #expect(spoken.contains("пятьсот семьдесят два шага"))
        #expect(spoken.contains("двадцать пять минут"))
        #expect(spoken.contains("шестьдесят четыре удара в минуту"))
    }

    @Test("Russian counters agree with feminine and neuter nouns")
    func inflectsRussianCountersByGender() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Запустил фокус на 1 минут. Осталось 2 задачи, 21 цель и 1 действие.",
            language: .ru
        )

        #expect(spoken.contains("на одну минуту"))
        #expect(spoken.contains("две задачи"))
        #expect(spoken.contains("двадцать одна цель"))
        #expect(spoken.contains("одно действие"))
    }

    @Test("Russian counted nouns support common genitive phrases")
    func inflectsRussianGenitiveCounters() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Активность есть в 3 из 7 дней. До 2 целей осталось немного.",
            language: .ru
        )

        #expect(spoken.contains("в трёх из семи дней"))
        #expect(spoken.contains("до двух целей"))
    }

    @Test("Russian ranges and fractions use the genitive case")
    func inflectsRussianRangesAndFractions() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Сделай 2-3 коротких сессий по 2-4 минуты. Выполнено 3/7.",
            language: .ru
        )

        #expect(spoken.contains("от двух до трёх коротких сессий"))
        #expect(spoken.contains("от двух до четырёх минут"))
        #expect(spoken.contains("три из семи"))
    }

    @Test("Russian decimals include a spoken denominator")
    func speaksNaturalRussianDecimals() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Пройдено 1,5 км, прогресс 0,25%.",
            language: .ru
        )

        #expect(spoken.contains("одна целая пять десятых километра"))
        #expect(spoken.contains("ноль целых двадцать пять сотых процента"))
    }

    @Test("Russian one-minute time uses feminine agreement")
    func speaksRussianTimeWithAgreement() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Напоминание на 1:01.",
            language: .ru
        )

        #expect(spoken == "Напоминание на один час одна минута.")
    }

    @Test("Russian pronunciation hints add pauses and restore yo")
    func preparesRussianProsodyAndYo() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "План обновлен — еще 2 действия • прием воды.",
            language: .ru
        )

        #expect(spoken == "План обновлён. ещё два действия. приём воды.")
    }

    @Test("Russian letter names distinguish е, ё, и, and й")
    func distinguishesRussianLetterNames() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Назови буквы е, ё, й и и. Новый план и идея остаются без изменений.",
            language: .ru
        )

        #expect(
            spoken.contains(
                "буква е, буква ё, буква и краткое, буква и"
            )
        )
        #expect(spoken.contains("Новый план и идея"))
    }

    @Test("Russian pronunciation restores common ё forms without changing meaning")
    func restoresCommonRussianYoForms() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Всё учтем: еще раз начнем, затем найдем твое сохраненное действие.",
            language: .ru
        )

        #expect(
            spoken
                == "Всё учтём: ещё раз начнём, затем найдём твоё сохранённое действие."
        )
    }

    @Test("Russian model input carries explicit stress and supported combining marks")
    func preparesRussianModelInput() {
        let normalized = LocalVoiceTextNormalizer.normalize(
            "Lippi ещё раз проверит следующий шаг.",
            language: .ru
        )
        let modelInput = LocalVoicePronunciation.modelInput(
            normalized,
            language: .ru
        )

        #expect(modelInput.contains("Ли\u{301}ппи"))
        #expect(modelInput.contains("е\u{308}"))
        #expect(modelInput.contains("и\u{306}"))
        #expect(modelInput.unicodeScalars.contains { $0.value == 0x0301 })
        #expect(!modelInput.unicodeScalars.contains("ё"))
        #expect(!modelInput.unicodeScalars.contains("й"))
    }

    @Test("Russian orthoepic traps receive deterministic stress")
    func stressesRussianOrthoepicTraps() {
        let modelInput = LocalVoicePronunciation.modelInput(
            "Каталог, договор и жалюзи готовы.",
            language: .ru
        ).lowercased()

        #expect(modelInput.contains("катало\u{301}г"))
        #expect(modelInput.contains("догово\u{301}р"))
        #expect(modelInput.contains("жалюзи\u{301}"))
        #expect(modelInput.contains("гото\u{301}вы"))
    }

    @Test("Russian homographs use nearby meaning cues")
    func resolvesRussianHomographs() {
        let doorLock = LocalVoicePronunciation.modelInput(
            "Открой замок двери.",
            language: .ru
        ).lowercased()
        let oldCastle = LocalVoicePronunciation.modelInput(
            "Открой старинный замок.",
            language: .ru
        ).lowercased()
        let payment = LocalVoicePronunciation.modelInput(
            "Я плачу картой за покупку.",
            language: .ru
        ).lowercased()
        let tears = LocalVoicePronunciation.modelInput(
            "Я плачу от грусти и боли.",
            language: .ru
        ).lowercased()

        #expect(doorLock.contains("замо\u{301}к"))
        #expect(oldCastle.contains("за\u{301}мок"))
        #expect(payment.contains("плачу\u{301}"))
        #expect(tears.contains("пла\u{301}чу"))
    }

    @Test("Calendar vocabulary uses verified lexical stress")
    func stressesRussianCalendarVocabulary() {
        let modelInput = LocalVoicePronunciation.modelInput(
            "Послезавтра будет встреча.",
            language: .ru
        ).lowercased()

        #expect(modelInput.contains("послеза\u{301}втра"))
    }

    @Test("An explicit author stress is preserved without duplication")
    func preservesExplicitStress() {
        let modelInput = LocalVoicePronunciation.modelInput(
            "Проверь катало\u{301}г.",
            language: .ru
        )

        #expect(
            modelInput.unicodeScalars.filter { $0.value == 0x0301 }.count == 1
        )
    }

    @Test("Russian speech adds measured pauses and a final boundary")
    func preparesRussianPausesAndEndings() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Хорошо начнем; затем проверим результат",
            language: .ru
        )

        #expect(spoken == "Хорошо, начнём. затем проверим результат.")
    }

    @Test("Phone numbers are spoken digit by digit")
    func normalizesPhoneNumberDigitByDigit() {
        let spoken = LocalVoiceTextNormalizer.normalize(
            "Позвони +7 901 205-04-03.",
            language: .ru
        )

        #expect(spoken.contains("плюс, семь, девять, ноль, один"))
        let containsNumber = spoken.contains(where: { $0.isNumber })
        #expect(!containsNumber)
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
