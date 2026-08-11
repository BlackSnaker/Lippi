import Foundation
import Testing
@testable import Lippi

struct ExpressiveSpeechPlannerTests {
    @Test("Questions rise while statements resolve")
    func punctuationShapesPitch() {
        let question = ExpressiveSpeechPlanner.plan(
            text: "Мы продолжим?",
            language: .ru,
            prosody: .neutral
        )[0]
        let statement = ExpressiveSpeechPlanner.plan(
            text: "Мы продолжим.",
            language: .ru,
            prosody: .neutral
        )[0]

        #expect(question.pitch.end > question.pitch.start)
        #expect(statement.pitch.end < statement.pitch.start)
        #expect(question.pitch.end > statement.pitch.end)
    }

    @Test("Open questions resolve while yes-no questions rise")
    func distinguishesQuestionMelody() {
        let openQuestion = ExpressiveSpeechPlanner.plan(
            text: "Почему мы остановились?",
            language: .ru,
            prosody: .neutral
        )[0]
        let yesNoQuestion = ExpressiveSpeechPlanner.plan(
            text: "Мы продолжим?",
            language: .ru,
            prosody: .neutral
        )[0]

        #expect(openQuestion.pitch.end < openQuestion.pitch.start)
        #expect(yesNoQuestion.pitch.end > yesNoQuestion.pitch.start)
    }

    @Test("Relaxed delivery adds only sparse native breaths")
    func insertsSparseBreaths() {
        var relaxed = VoiceProsodyProfile.neutral
        relaxed.pauseScale = 1.18
        let segments = ExpressiveSpeechPlanner.plan(
            text: "Сначала посмотрим на итог. Затем выберем главное. После этого продолжим. И спокойно завершим.",
            language: .ru,
            prosody: relaxed
        )

        #expect(segments.count == 4)
        #expect(segments.filter(\.usesExpressionTag).count == 1)
        #expect(segments[2].text.hasPrefix("<breath>"))
    }

    @Test("Planner keeps phonetic phrasing bounded")
    func keepsPhrasesBounded() {
        let text = Array(repeating: "Короткая осмысленная фраза с точной артикуляцией", count: 20)
            .joined(separator: ", ") + "."
        let segments = ExpressiveSpeechPlanner.plan(
            text: text,
            language: .ru,
            prosody: .neutral
        )

        #expect(!segments.isEmpty)
        #expect(segments.count <= 8)
        #expect(segments.allSatisfy { $0.syllableCount > 0 })
    }

    @Test("Natural comma phrasing avoids tiny independent utterances")
    func avoidsCommaMicrosegments() {
        let segments = ExpressiveSpeechPlanner.plan(
            text: "Спокойно проверим план, выберем главное, а затем продолжим работу.",
            language: .ru,
            prosody: .neutral
        )

        #expect(segments.count == 1)
        #expect(segments[0].text.contains(","))
    }

    @Test("Short previews use the highest Supertonic quality")
    func qualityIsAdaptive() {
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 100) == 12)
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 250) == 10)
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 450) == 9)
        #expect(
            LocalNeuralVoiceProvider.qualitySteps(
                forCharacterCount: 450,
                quality: .maximum
            ) == 12
        )
    }

    @Test("Renderer creates playable PCM WAV")
    func rendererCreatesWAV() {
        let sampleRate = 44_100
        let samples = (0..<(sampleRate / 2)).map { index in
            sin(Float(index) * 2 * .pi * 220 / Float(sampleRate)) * 0.15
        }
        let segment = ExpressiveSpeechPlanner.plan(
            text: "Проверяем живую интонацию?",
            language: .ru,
            prosody: .neutral
        )[0]
        let rendered = ExpressiveAudioRenderer.render(
            VoicePCM(samples: samples, sampleRate: sampleRate),
            segment: segment
        )
        let wav = ExpressiveAudioRenderer.wavData(rendered)

        #expect(rendered.sampleRate == sampleRate)
        #expect(!rendered.samples.isEmpty)
        #expect(wav.prefix(4) == Data("RIFF".utf8))
        #expect(wav.count > 44)
    }

    @Test("Vowel duration is rendered locally")
    func stretchesVowelRegions() {
        let sampleRate = 8_000
        let samples = (0..<sampleRate).map { index in
            sin(Float(index) * 2 * .pi * 180 / Float(sampleRate)) * 0.12
        }
        var profile = VoiceProsodyProfile.neutral
        profile.vowelDurationScale = 1.08
        let segment = ExpressiveSpeechPlanner.plan(
            text: "Мелодичная интонация.",
            language: .ru,
            prosody: profile
        )[0]
        let rendered = ExpressiveAudioRenderer.render(
            VoicePCM(samples: samples, sampleRate: sampleRate),
            segment: segment
        )

        #expect(!segment.vowelPositions.isEmpty)
        #expect(rendered.samples.count > samples.count)
    }

    @Test("Explicit word stress reaches the phoneme timing layer")
    func carriesStressIntoTiming() {
        let modelInput = LocalVoicePronunciation.modelInput(
            "Ещё каталог готов.",
            language: .ru
        )
        let segment = ExpressiveSpeechPlanner.plan(
            text: modelInput,
            language: .ru,
            prosody: .neutral
        )[0]

        #expect(segment.stressedVowelPositions.count == 2)
        #expect(segment.stressedVowelPositions.allSatisfy { 0...1 ~= $0 })
    }

    @Test("Russian й remains a consonant in syllable timing")
    func treatsRussianShortIAsConsonant() {
        let modelInput = LocalVoicePronunciation.modelInput(
            "Следующий шаг.",
            language: .ru
        )
        let segment = ExpressiveSpeechPlanner.plan(
            text: modelInput,
            language: .ru,
            prosody: .neutral
        )[0]

        #expect(segment.syllableCount == 5)
    }

    @Test("Pitch contour stays continuous without resampling seams")
    func rendersContinuousPitchContour() {
        let sampleRate = 8_000
        let samples = (0..<sampleRate).map { index in
            sin(Float(index) * 2 * .pi * 180 / Float(sampleRate)) * 0.12
        }
        let segment = ExpressiveSpeechPlanner.plan(
            text: "Мы продолжим?",
            language: .ru,
            prosody: .neutral
        )[0]
        let rendered = ExpressiveAudioRenderer.render(
            VoicePCM(samples: samples, sampleRate: sampleRate),
            segment: segment
        )
        let largestStep = zip(rendered.samples, rendered.samples.dropFirst())
            .map { abs($1 - $0) }
            .max() ?? 0

        #expect(largestStep < 0.06)
    }
}
