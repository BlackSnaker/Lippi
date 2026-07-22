import Testing
@testable import Lippi

struct BonsaiGenerationSafetyTests {
    @Test("Uses a compact horizon-specific output budget")
    func compactRoadmapBudgets() {
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 4) == 640)
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 8) == 640)
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 12) == 760)
        #expect(BonsaiGenerationSafetyPolicy.effectiveOutputTokenLimit(
            requested: 640,
            thermalLevel: .fair
        ) == 480)
    }

    @Test("Stops before heavy work in low power or serious thermal states")
    func blocksConstrainedGeneration() {
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .nominal,
            isLowPowerModeEnabled: true,
            elapsed: 0,
            maximumDuration: 80
        ) == .lowPowerMode)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .serious,
            isLowPowerModeEnabled: false,
            elapsed: 0,
            maximumDuration: 80
        ) == .thermal)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .critical,
            isLowPowerModeEnabled: false,
            elapsed: 0,
            maximumDuration: 80
        ) == .thermal)
    }

    @Test("Shortens a warm run and always enforces the wall-clock limit")
    func enforcesTimeLimits() {
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .fair,
            isLowPowerModeEnabled: false,
            elapsed: 44,
            maximumDuration: 80
        ) == nil)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .fair,
            isLowPowerModeEnabled: false,
            elapsed: 45,
            maximumDuration: 80
        ) == .timeLimit)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .nominal,
            isLowPowerModeEnabled: false,
            elapsed: 80,
            maximumDuration: 80
        ) == .timeLimit)
    }

    @Test("Keeps a useful partial JSON response for deterministic completion")
    func partialResponsePolicy() {
        #expect(!BonsaiGenerationSafetyPolicy.canReturnPartial("planning", generatedTokens: 80))
        #expect(!BonsaiGenerationSafetyPolicy.canReturnPartial("{\"title\":\"Plan", generatedTokens: 12))
        #expect(BonsaiGenerationSafetyPolicy.canReturnPartial("{\"title\":\"Plan", generatedTokens: 24))
    }
}
