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

    @Test("Short previews use the highest Supertonic quality")
    func qualityIsAdaptive() {
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 100) == 10)
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 250) == 8)
        #expect(LocalNeuralVoiceProvider.qualitySteps(forCharacterCount: 450) == 7)
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
}
