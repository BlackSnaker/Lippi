import Foundation
import Testing
@testable import Lippi

struct LippiCareEngineTests {
    @Test func longFocusPrioritizesEyeBreak() {
        let now = date(hour: 15)
        let input = LippiCareInput(
            now: now,
            healthSnapshot: nil,
            healthRecommendation: nil,
            goalAudit: nil,
            fallbackGoalStep: "Write the first outline",
            userState: .calm,
            focusElapsed: 46 * 60,
            isFocusRunning: true,
            history: LippiCareHistory(),
            lang: .en
        )

        #expect(LippiCareEngine.evaluate(input).first?.kind == .eyeBreak)
    }

    @Test func mealPromptRequiresMealWindowAndReliableInactivity() {
        let now = date(hour: 13)
        let snapshot = HealthWellnessSnapshot(
            generatedAt: now,
            stepsToday: 320,
            stepsLast90Minutes: 12,
            lastMovementAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        let input = LippiCareInput(
            now: now,
            healthSnapshot: snapshot,
            healthRecommendation: nil,
            goalAudit: nil,
            fallbackGoalStep: nil,
            userState: .calm,
            focusElapsed: 0,
            isFocusRunning: false,
            history: LippiCareHistory(),
            lang: .en
        )

        #expect(LippiCareEngine.evaluate(input).first?.kind == .mealCheck)

        var outsideWindow = input
        outsideWindow.now = date(hour: 9)
        outsideWindow.healthSnapshot?.generatedAt = outsideWindow.now
        outsideWindow.healthSnapshot?.lastMovementAt = outsideWindow.now.addingTimeInterval(-2 * 60 * 60)
        #expect(LippiCareEngine.evaluate(outsideWindow).contains { $0.kind == .mealCheck } == false)
    }

    @Test func recoveryOutranksGoalAndDoesNotMutateIt() {
        let now = date(hour: 16)
        let recommendation = HealthWellnessRecommendation(
            band: .recovery,
            confidence: 0.8,
            signals: [.sleepBelowBaseline],
            suggestedFocusMinutes: 15,
            planLoadScale: 0.65,
            suggestsBreathing: true,
            suggestsEyeBreak: true
        )
        let input = LippiCareInput(
            now: now,
            healthSnapshot: nil,
            healthRecommendation: recommendation,
            goalAudit: nil,
            fallbackGoalStep: "Keep the original goal intact",
            userState: .tired,
            focusElapsed: 0,
            isFocusRunning: false,
            history: LippiCareHistory(),
            lang: .en
        )

        let suggestions = LippiCareEngine.evaluate(input)
        #expect(suggestions.first?.kind == .recovery)
        #expect(suggestions.contains { $0.kind == .goalStep } == false)
        #expect(input.fallbackGoalStep == "Keep the original goal intact")
    }

    @Test func recentCheckInSuppressesDuplicateHydrationPrompt() {
        let now = date(hour: 14)
        var history = LippiCareHistory()
        history.record(.logWater, at: now.addingTimeInterval(-20 * 60))
        let snapshot = HealthWellnessSnapshot(
            generatedAt: now,
            stepsToday: 400,
            stepsLast90Minutes: 20,
            lastMovementAt: now.addingTimeInterval(-2 * 60 * 60)
        )
        let input = LippiCareInput(
            now: now,
            healthSnapshot: snapshot,
            healthRecommendation: nil,
            goalAudit: nil,
            fallbackGoalStep: nil,
            userState: .calm,
            focusElapsed: 30 * 60,
            isFocusRunning: true,
            history: history,
            lang: .en
        )

        #expect(LippiCareEngine.evaluate(input).contains { $0.kind == .hydration } == false)
    }

    private func date(hour: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 27, hour: hour)
        )!
    }
}
