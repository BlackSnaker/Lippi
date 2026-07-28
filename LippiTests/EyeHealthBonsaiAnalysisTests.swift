import Foundation
import Testing
@testable import Lippi

struct EyeHealthBonsaiAnalysisTests {
    @Test("Strong observable signals select an extended screen break")
    func strongSignalsProtectRest() {
        let report = EyeHealthAnalysisPolicy.fallback(for: input(
            fatigue: 0.74,
            appearance: 0.71
        ))

        #expect(report.level == .extendedRest)
        #expect(report.restMinutes >= 20)
        #expect(report.source == .localAnalysis)
        #expect(!report.safetyNote.isEmpty)
    }

    @Test("Limited lighting keeps the result local and avoids false confidence")
    func limitedLightingCannotBeOverridden() {
        let fallback = EyeHealthAnalysisPolicy.fallback(for: input(
            appearance: nil,
            usableLight: false
        ))
        let payload = BonsaiEyeHealthPayload(
            title: "Everything is perfect",
            summary: "No concern",
            action: "Return to the screen",
            restMinutes: 0,
            confidence: 1
        )
        let validated = EyeHealthAnalysisPolicy.validated(payload, fallback: fallback)

        #expect(fallback.level == .limitedReading)
        #expect(validated == fallback)
        #expect(validated.source == .localAnalysis)
    }

    @Test("Bonsai can explain the result but cannot weaken local safety")
    func bonsaiCannotReduceSafety() {
        let fallback = EyeHealthAnalysisPolicy.fallback(for: input(
            fatigue: 0.48,
            appearance: 0.42
        ))
        let payload = BonsaiEyeHealthPayload(
            title: "Personal pause",
            summary: "A calm explanation based on aggregate signals.",
            action: "Take a short screen break.",
            restMinutes: 2,
            confidence: 4
        )
        let validated = EyeHealthAnalysisPolicy.validated(payload, fallback: fallback)

        #expect(validated.source == .bonsai)
        #expect(validated.level == fallback.level)
        #expect(validated.restMinutes == fallback.restMinutes)
        #expect(validated.observations == fallback.observations)
        #expect(validated.safetyNote == fallback.safetyNote)
        #expect(validated.action == fallback.action)
        #expect(validated.confidence == fallback.confidence)
    }

    @Test("Medical claims from generated text are discarded")
    func generatedDiagnosisIsDiscarded() {
        let fallback = EyeHealthAnalysisPolicy.fallback(for: input(
            fatigue: 0.48,
            appearance: 0.42
        ))
        let payload = BonsaiEyeHealthPayload(
            title: "Conjunctivitis detected",
            summary: "This is a diagnosis based on the signals.",
            action: nil,
            restMinutes: 15,
            confidence: 0.7
        )
        let validated = EyeHealthAnalysisPolicy.validated(payload, fallback: fallback)

        #expect(validated.title == fallback.title)
        #expect(validated.summary == fallback.summary)
    }

    @Test("Bonsai prompt contains aggregates and explicitly excludes camera frames")
    func promptDoesNotExposeFrames() {
        let value = input(fatigue: 0.52, appearance: 0.43)
        let fallback = EyeHealthAnalysisPolicy.fallback(for: value)
        let prompt = EyeHealthBonsaiPrompt.make(input: value, safety: fallback)

        #expect(prompt.contains("Relative eyelid fatigue signal: moderate"))
        #expect(prompt.contains("Camera appearance signal around the eyes: moderate"))
        #expect(prompt.contains("Images and video are not available to you."))
        #expect(!prompt.contains("0.52"))
        #expect(!prompt.contains("0.43"))
    }

    @Test("Eye analysis copy is available in every app language")
    func localizationCoverage() {
        let keys = [
            "eye.analysis.card.title",
            "eye.analysis.card.private",
            "eye.analysis.comfortable.title",
            "eye.analysis.gentleRest.title",
            "eye.analysis.extendedRest.title",
            "eye.analysis.limited.title",
            "eye.analysis.safety"
        ]

        for language in AppLang.allCases {
            for key in keys {
                #expect(L10n.tr(key, language) != key)
            }
        }
    }

    @Test("Existing eye exercise history decodes without analysis fields")
    func legacyHistoryMigration() throws {
        let legacy = LegacyEyeSessionHistory(
            id: UUID(),
            date: Date(timeIntervalSinceReferenceDate: 100),
            mode: .tracking,
            hits: 6,
            misses: 2,
            total: 8,
            avgReaction: 1.2,
            bestReaction: 0.9,
            bestStreak: 4
        )
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(EyeSessionHistory.self, from: data)

        #expect(decoded.id == legacy.id)
        #expect(decoded.cameraFatigueEstimate == nil)
        #expect(decoded.healthAnalysis == nil)
    }

    private func input(
        fatigue: Double = 0.22,
        appearance: Double? = 0.18,
        usableLight: Bool = true
    ) -> EyeHealthAnalysisInput {
        EyeHealthAnalysisInput(
            completedTargets: 7,
            missedTargets: 1,
            totalTargets: 8,
            averageTargetTime: 1.4,
            detectedBlinks: 3,
            fatigueEstimate: fatigue,
            appearanceEstimate: appearance,
            lightLevel: usableLight ? 0.56 : 0.08,
            hasUsableLight: usableLight,
            recentSessions: [
                EyeHealthTrendPoint(
                    fatigueEstimate: 0.25,
                    appearanceEstimate: 0.2,
                    exerciseCompletion: 0.88
                ),
                EyeHealthTrendPoint(
                    fatigueEstimate: 0.28,
                    appearanceEstimate: 0.24,
                    exerciseCompletion: 0.75
                )
            ],
            lang: .en
        )
    }
}

private struct LegacyEyeSessionHistory: Codable {
    var id: UUID
    var date: Date
    var mode: EyeGameMode
    var hits: Int
    var misses: Int
    var total: Int
    var avgReaction: Double?
    var bestReaction: Double?
    var bestStreak: Int
}
