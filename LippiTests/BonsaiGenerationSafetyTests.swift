import Testing
@testable import Lippi

struct BonsaiGenerationSafetyTests {
    @Test("Uses a compact horizon-specific output budget")
    func compactRoadmapBudgets() {
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 4) == 520)
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 8) == 520)
        #expect(BonsaiGenerationSafetyPolicy.roadmapOutputTokenBudget(forWeeks: 12) == 640)
        #expect(BonsaiGenerationSafetyPolicy.effectiveOutputTokenLimit(
            requested: 520,
            thermalLevel: .fair
        ) == 426)
        #expect(BonsaiGenerationSafetyPolicy.contextTokenCapacity == 3_072)
        #expect(BonsaiGenerationSafetyPolicy.batchTokenCapacity == 256)
        #expect(BonsaiGenerationSafetyPolicy.microBatchTokenCapacity == 128)
        #expect(BonsaiGenerationSafetyPolicy.personalRecommendationMaximumDuration == 24)
        #expect(BonsaiGenerationSafetyPolicy.eyeHealthMaximumDuration == 18)
    }

    @Test("Paces work as the device warms without disabling generation")
    func thermalWorkloadProfiles() {
        let nominal = BonsaiGenerationSafetyPolicy.workloadProfile(
            requestedOutputTokens: 520,
            thermalLevel: .nominal,
            processorCount: 8
        )
        let fair = BonsaiGenerationSafetyPolicy.workloadProfile(
            requestedOutputTokens: 520,
            thermalLevel: .fair,
            processorCount: 8
        )

        #expect(nominal.outputTokenLimit == 520)
        #expect(nominal.decodeThreads == 3)
        #expect(nominal.promptChunkSize == 192)
        #expect(fair.outputTokenLimit == 426)
        #expect(fair.decodeThreads == 2)
        #expect(fair.promptChunkSize == 96)
        #expect(fair.safetyCheckInterval < nominal.safetyCheckInterval)
        #expect(fair.tokenPause > nominal.tokenPause)
    }

    @Test("Skips supplemental research when the device is already constrained")
    func evidenceResearchPolicy() {
        #expect(BonsaiGenerationSafetyPolicy.shouldRetrieveSupplementalEvidence(
            thermalLevel: .nominal,
            isLowPowerModeEnabled: false
        ))
        #expect(!BonsaiGenerationSafetyPolicy.shouldRetrieveSupplementalEvidence(
            thermalLevel: .fair,
            isLowPowerModeEnabled: false
        ))
        #expect(!BonsaiGenerationSafetyPolicy.shouldRetrieveSupplementalEvidence(
            thermalLevel: .nominal,
            isLowPowerModeEnabled: true
        ))
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

    @Test("Paces a warm run and always enforces the wall-clock limit")
    func enforcesTimeLimits() {
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .fair,
            isLowPowerModeEnabled: false,
            elapsed: 61,
            maximumDuration: 72
        ) == nil)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .fair,
            isLowPowerModeEnabled: false,
            elapsed: 62,
            maximumDuration: 72
        ) == .timeLimit)
        #expect(BonsaiGenerationSafetyPolicy.stopReason(
            thermalLevel: .nominal,
            isLowPowerModeEnabled: false,
            elapsed: 72,
            maximumDuration: 72
        ) == .timeLimit)
    }

    @Test("Keeps a useful partial JSON response for deterministic completion")
    func partialResponsePolicy() {
        #expect(!BonsaiGenerationSafetyPolicy.canReturnPartial("planning", generatedTokens: 80))
        #expect(!BonsaiGenerationSafetyPolicy.canReturnPartial("{\"title\":\"Plan", generatedTokens: 12))
        #expect(BonsaiGenerationSafetyPolicy.canReturnPartial("{\"title\":\"Plan", generatedTokens: 24))
    }
}
