import Foundation
import Testing
@testable import Lippi

struct AdaptiveVoiceEngineTests {

    @Test("Preview exposes every adaptive voice state")
    func previewExposesEveryState() {
        for state in PhysiologicalVoiceState.allCases {
            let decision = VoicePolicy.previewDecision(for: state)
            #expect(decision.estimate.state == state)
            if state == .neutral {
                #expect(!decision.isAdaptive)
                #expect(decision.prosody == .neutral)
            } else {
                #expect(decision.isAdaptive)
                #expect(decision.prosody != .neutral)
            }
        }
    }
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Insufficient physiological evidence keeps the neutral voice")
    func lowConfidenceFallsBackToNeutral() {
        let snapshot = HealthWellnessSnapshot(
            generatedAt: now,
            stepsToday: 2_000
        )
        let estimate = PhysiologicalStateEstimator.estimate(
            PhysiologicalContextBuilder.build(from: snapshot)
        )
        let decision = VoicePolicy.decision(for: estimate, isEnabled: true)

        #expect(estimate.state == .neutral)
        #expect(estimate.confidence < PhysiologicalStateEstimator.confidenceThreshold)
        #expect(decision.prosody == .neutral)
        #expect(!decision.isAdaptive)
    }

    @Test("A high pulse with fresh movement context is treated as activity")
    func highHeartRateAfterMovementIsNotElevatedLoad() {
        let snapshot = HealthWellnessSnapshot(
            generatedAt: now,
            stepsLast90Minutes: 1_000,
            lastMovementAt: now.addingTimeInterval(-60),
            heartRate: 120,
            heartRateSampleDate: now.addingTimeInterval(-30),
            recentSleepHours: 8,
            baselineSleepHours: 8,
            restingHeartRate: 60,
            baselineRestingHeartRate: 60,
            restingHeartRateSampleDate: now.addingTimeInterval(-3_600),
            hrvSDNN: 50,
            baselineHRVSDNN: 50,
            hrvSampleDate: now.addingTimeInterval(-3_600),
            hasAppleWatchData: true
        )
        let estimate = estimate(snapshot)

        #expect(estimate.state == .focused)
        #expect(estimate.state != .elevated)
        #expect(estimate.confidence >= 0.85)
    }

    @Test("Elevated pulse at rest requires corroborating baseline signals")
    func detectsElevatedContextAtRest() {
        let snapshot = HealthWellnessSnapshot(
            generatedAt: now,
            stepsLast90Minutes: 0,
            lastMovementAt: now.addingTimeInterval(-7_200),
            heartRate: 92,
            heartRateSampleDate: now.addingTimeInterval(-60),
            recentSleepHours: 8,
            baselineSleepHours: 8,
            restingHeartRate: 69,
            baselineRestingHeartRate: 60,
            restingHeartRateSampleDate: now.addingTimeInterval(-3_600),
            hrvSDNN: 50,
            baselineHRVSDNN: 50,
            hrvSampleDate: now.addingTimeInterval(-3_600),
            hasAppleWatchData: true
        )
        let estimate = estimate(snapshot)

        #expect(estimate.state == .elevated)
        #expect(estimate.arousal >= 0.64)
    }

    @Test("Sleep, HRV and resting heart rate combine into fatigue")
    func combinesSignalsIntoFatigue() {
        let snapshot = fatiguedSnapshot(lastWorkoutEndDate: nil)
        let estimate = estimate(snapshot)

        #expect(estimate.state == .fatigued)
        #expect(estimate.fatigue >= 0.58)
        #expect(estimate.confidence >= 0.85)
    }

    @Test("Recent workout shifts fatigue toward recovery")
    func identifiesRecoveryAfterWorkout() {
        let snapshot = fatiguedSnapshot(
            lastWorkoutEndDate: now.addingTimeInterval(-20 * 60)
        )
        let estimate = estimate(snapshot)

        #expect(estimate.state == .recovering)
        #expect(estimate.recovery >= 0.66)
    }

    @Test("Elevated policy becomes slower, quieter and more concise")
    func mapsElevatedStateToProsody() {
        let estimate = PhysiologicalVoiceEstimate(
            state: .elevated,
            arousal: 0.82,
            fatigue: 0.42,
            recovery: 0.44,
            confidence: 0.90,
            generatedAt: now
        )
        let decision = VoicePolicy.decision(for: estimate, isEnabled: true)

        #expect(decision.isAdaptive)
        #expect(decision.prosody.tempoScale < 1)
        #expect(decision.prosody.pauseScale > 1)
        #expect(decision.prosody.pitchSemitones < 0)
        #expect(decision.prosody.dynamicRangeScale < 1)
        #expect(decision.prosody.utteranceLengthScale < 1)
    }

    @Test("Turning adaptation off always restores the base profile")
    func disabledPolicyIsNeutral() {
        let estimate = PhysiologicalVoiceEstimate(
            state: .recovering,
            arousal: 0.50,
            fatigue: 0.72,
            recovery: 0.80,
            confidence: 0.92,
            generatedAt: now
        )
        let decision = VoicePolicy.decision(for: estimate, isEnabled: false)

        #expect(!decision.isAdaptive)
        #expect(decision.prosody == .neutral)
    }

    @Test("Stale physiological context decays to the neutral voice")
    func staleContextIsNeutral() {
        let estimate = PhysiologicalVoiceEstimate(
            state: .elevated,
            arousal: 0.85,
            fatigue: 0.40,
            recovery: 0.35,
            confidence: 0.92,
            generatedAt: now.addingTimeInterval(-24 * 60 * 60)
        )
        let decision = VoicePolicy.decision(
            for: estimate,
            isEnabled: true,
            reference: now
        )

        #expect(!decision.isAdaptive)
        #expect(decision.estimate.state == .neutral)
        #expect(decision.prosody == .neutral)
    }

    @Test("Temporal smoothing limits sudden changes and uses hysteresis")
    func smoothsTransitions() {
        var smoother = TemporalVoiceStateSmoother()
        let calm = PhysiologicalVoiceEstimate(
            state: .calm,
            arousal: 0.25,
            fatigue: 0.25,
            recovery: 0.20,
            confidence: 0.80,
            generatedAt: now
        )
        let elevated = PhysiologicalVoiceEstimate(
            state: .elevated,
            arousal: 0.90,
            fatigue: 0.45,
            recovery: 0.42,
            confidence: 0.80,
            generatedAt: now.addingTimeInterval(30)
        )

        _ = smoother.update(with: calm)
        let firstTransition = smoother.update(with: elevated)
        #expect(firstTransition.state == .calm)
        #expect(firstTransition.arousal - calm.arousal <= 0.18)

        var sustained = elevated
        sustained.generatedAt = now.addingTimeInterval(180)
        let completedTransition = smoother.update(with: sustained)
        #expect(completedTransition.state == .elevated)
    }

    private func estimate(_ snapshot: HealthWellnessSnapshot) -> PhysiologicalVoiceEstimate {
        PhysiologicalStateEstimator.estimate(
            PhysiologicalContextBuilder.build(from: snapshot)
        )
    }

    private func fatiguedSnapshot(lastWorkoutEndDate: Date?) -> HealthWellnessSnapshot {
        HealthWellnessSnapshot(
            generatedAt: now,
            stepsLast90Minutes: 20,
            lastMovementAt: now.addingTimeInterval(-30 * 60),
            recentSleepHours: 5,
            baselineSleepHours: 8,
            restingHeartRate: 63,
            baselineRestingHeartRate: 60,
            restingHeartRateSampleDate: now.addingTimeInterval(-3_600),
            hrvSDNN: 30,
            baselineHRVSDNN: 50,
            hrvSampleDate: now.addingTimeInterval(-3_600),
            workoutMinutesLast7Days: lastWorkoutEndDate == nil ? nil : 35,
            lastWorkoutEndDate: lastWorkoutEndDate,
            hasAppleWatchData: true
        )
    }
}
