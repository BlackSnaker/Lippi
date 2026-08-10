import Combine
import Foundation

enum PhysiologicalVoiceState: String, CaseIterable, Codable, Sendable {
    case calm
    case neutral
    case focused
    case fatigued
    case elevated
    case recovering
}

struct PhysiologicalContext: Equatable, Sendable {
    var generatedAt: Date
    var heartRateElevation: Double?
    var restingHeartRateDeviation: Double?
    var hrvDeviation: Double?
    var sleepDeviation: Double?
    var recentActivity: Double
    var recentWorkout: Bool
    var evidenceWeight: Double
    var hasAppleWatchData: Bool
}

struct PhysiologicalVoiceEstimate: Equatable, Sendable {
    var state: PhysiologicalVoiceState
    var arousal: Double
    var fatigue: Double
    var recovery: Double
    var confidence: Double
    var generatedAt: Date

    static func neutral(at date: Date = .now) -> PhysiologicalVoiceEstimate {
        PhysiologicalVoiceEstimate(
            state: .neutral,
            arousal: 0.45,
            fatigue: 0.35,
            recovery: 0.30,
            confidence: 0,
            generatedAt: date
        )
    }
}

enum PhysiologicalContextBuilder {
    static func build(
        from snapshot: HealthWellnessSnapshot,
        reference: Date? = nil
    ) -> PhysiologicalContext {
        let now = reference ?? snapshot.generatedAt
        let restingDeviation = relativeDeviation(
            snapshot.restingHeartRate,
            baseline: snapshot.baselineRestingHeartRate
        )
        let hrvDeviation = relativeDeviation(
            snapshot.hrvSDNN,
            baseline: snapshot.baselineHRVSDNN
        )
        let sleepDeviation = relativeDeviation(
            snapshot.recentSleepHours,
            baseline: snapshot.baselineSleepHours
        )

        let movementFreshness = freshness(
            of: snapshot.lastMovementAt,
            at: now,
            fullFor: 12 * 60,
            expiresAfter: 75 * 60,
            fallback: snapshot.stepsLast90Minutes == nil ? 0 : 0.35
        )
        let stepActivity = clamp((snapshot.stepsLast90Minutes ?? 0) / 1_200)
            * movementFreshness
        let workoutFreshness = freshness(
            of: snapshot.lastWorkoutEndDate,
            at: now,
            fullFor: 30 * 60,
            expiresAfter: 2 * 60 * 60,
            fallback: 0
        )
        let workoutActivity = workoutFreshness * 0.90
        let recentActivity = max(stepActivity, workoutActivity)

        let heartFreshness = freshness(
            of: snapshot.heartRateSampleDate,
            at: now,
            fullFor: 8 * 60,
            expiresAfter: 45 * 60,
            fallback: snapshot.heartRate == nil ? 0 : 0.45
        )
        let heartRateElevation: Double?
        if let heartRate = snapshot.heartRate,
           let baseline = snapshot.baselineRestingHeartRate,
           baseline > 0,
           heartFreshness > 0 {
            heartRateElevation = ((heartRate / baseline) - 1) * heartFreshness
        } else {
            heartRateElevation = nil
        }

        var evidenceWeight = 0.0
        if sleepDeviation != nil { evidenceWeight += 1.0 }
        if hrvDeviation != nil {
            evidenceWeight += freshness(
                of: snapshot.hrvSampleDate,
                at: now,
                fullFor: 18 * 60 * 60,
                expiresAfter: 72 * 60 * 60,
                fallback: 0.70
            )
        }
        if restingDeviation != nil {
            evidenceWeight += freshness(
                of: snapshot.restingHeartRateSampleDate,
                at: now,
                fullFor: 24 * 60 * 60,
                expiresAfter: 96 * 60 * 60,
                fallback: 0.70
            )
        }
        if heartRateElevation != nil { evidenceWeight += 0.80 * heartFreshness }
        if snapshot.stepsLast90Minutes != nil || snapshot.lastWorkoutEndDate != nil {
            evidenceWeight += 0.25
        }

        return PhysiologicalContext(
            generatedAt: now,
            heartRateElevation: heartRateElevation,
            restingHeartRateDeviation: restingDeviation,
            hrvDeviation: hrvDeviation,
            sleepDeviation: sleepDeviation,
            recentActivity: clamp(recentActivity),
            recentWorkout: workoutFreshness > 0.25,
            evidenceWeight: evidenceWeight,
            hasAppleWatchData: snapshot.hasAppleWatchData
        )
    }

    private static func relativeDeviation(_ value: Double?, baseline: Double?) -> Double? {
        guard let value, let baseline, value.isFinite, baseline.isFinite, baseline > 0 else {
            return nil
        }
        return clamp((value / baseline) - 1, lower: -0.60, upper: 1.50)
    }

    private static func freshness(
        of sampleDate: Date?,
        at reference: Date,
        fullFor: TimeInterval,
        expiresAfter: TimeInterval,
        fallback: Double
    ) -> Double {
        guard let sampleDate else { return fallback }
        let age = max(0, reference.timeIntervalSince(sampleDate))
        guard age < expiresAfter else { return 0 }
        guard age > fullFor else { return 1 }
        return 1 - ((age - fullFor) / max(expiresAfter - fullFor, 1))
    }
}

enum PhysiologicalStateEstimator {
    static let confidenceThreshold = 0.55

    static func estimate(_ context: PhysiologicalContext) -> PhysiologicalVoiceEstimate {
        var arousalSignals: [(value: Double, weight: Double)] = []
        var fatigueSignals: [(value: Double, weight: Double)] = []

        if let deviation = context.restingHeartRateDeviation {
            arousalSignals.append((clamp(0.42 + deviation * 2.0), 1.0))
            fatigueSignals.append((clamp(0.25 + deviation * 2.1), 0.9))
        }
        if let deviation = context.hrvDeviation {
            arousalSignals.append((clamp(0.42 - deviation * 0.85), 0.8))
            fatigueSignals.append((clamp(0.27 - deviation * 1.15), 1.0))
        }
        if let deviation = context.sleepDeviation {
            fatigueSignals.append((clamp(0.24 - deviation * 1.55), 1.1))
        }
        if let elevation = context.heartRateElevation {
            let value: Double
            if context.recentActivity >= 0.25 {
                value = 0.54 + context.recentActivity * 0.36
            } else {
                value = 0.42 + max(0, elevation - 0.10) * 0.85
            }
            arousalSignals.append((clamp(value), 1.0))
        }
        if context.recentActivity > 0.05 {
            arousalSignals.append((0.42 + context.recentActivity * 0.46, 0.65))
        }

        let arousal = weightedAverage(arousalSignals, fallback: 0.45)
        let fatigue = weightedAverage(fatigueSignals, fallback: 0.35)
        let recovery = clamp(
            fatigue * 0.76
                + (context.recentWorkout ? 0.18 : 0.04)
                + max(0, 0.35 - context.recentActivity) * 0.10
        )
        let watchBonus = context.hasAppleWatchData && context.evidenceWeight >= 1.5 ? 0.03 : 0
        let confidence = min(0.94, context.evidenceWeight / 3.0 + watchBonus)
        let state = classify(
            arousal: arousal,
            fatigue: fatigue,
            recovery: recovery,
            activity: context.recentActivity,
            confidence: confidence
        )

        return PhysiologicalVoiceEstimate(
            state: state,
            arousal: arousal,
            fatigue: fatigue,
            recovery: recovery,
            confidence: confidence,
            generatedAt: context.generatedAt
        )
    }

    static func classify(
        arousal: Double,
        fatigue: Double,
        recovery: Double,
        activity: Double,
        confidence: Double
    ) -> PhysiologicalVoiceState {
        guard confidence >= confidenceThreshold else { return .neutral }
        if recovery >= 0.66 { return .recovering }
        if fatigue >= 0.58 { return .fatigued }
        if arousal >= 0.64, activity < 0.25 { return .elevated }
        if activity >= 0.25, arousal >= 0.50 { return .focused }
        if arousal <= 0.40, fatigue <= 0.40 { return .calm }
        return .neutral
    }

    private static func weightedAverage(
        _ signals: [(value: Double, weight: Double)],
        fallback: Double
    ) -> Double {
        let weight = signals.reduce(0) { $0 + $1.weight }
        guard weight > 0 else { return fallback }
        return clamp(signals.reduce(0) { $0 + $1.value * $1.weight } / weight)
    }
}

struct TemporalVoiceStateSmoother {
    private(set) var current = PhysiologicalVoiceEstimate.neutral()
    private var isInitialized = false
    private var pendingState: PhysiologicalVoiceState?
    private var pendingStateSince: Date?

    mutating func update(with estimate: PhysiologicalVoiceEstimate) -> PhysiologicalVoiceEstimate {
        guard isInitialized else {
            isInitialized = true
            current = estimate
            return current
        }

        let elapsed = max(0, estimate.generatedAt.timeIntervalSince(current.generatedAt))
        let alpha = min(0.50, max(0.12, 1 - exp(-elapsed / 900)))
        let maxChange = estimate.confidence >= 0.85 ? 0.24 : 0.18
        let arousal = limitedBlend(current.arousal, estimate.arousal, alpha: alpha, limit: maxChange)
        let fatigue = limitedBlend(current.fatigue, estimate.fatigue, alpha: alpha, limit: maxChange)
        let recovery = limitedBlend(current.recovery, estimate.recovery, alpha: alpha, limit: maxChange)
        let confidence = current.confidence + (estimate.confidence - current.confidence) * max(alpha, 0.25)

        var state = current.state
        if estimate.state == current.state {
            pendingState = nil
            pendingStateSince = nil
        } else if estimate.confidence < PhysiologicalStateEstimator.confidenceThreshold {
            state = .neutral
            pendingState = nil
            pendingStateSince = nil
        } else if current.state == .neutral || estimate.confidence >= 0.88 {
            state = estimate.state
            pendingState = nil
            pendingStateSince = nil
        } else if pendingState == estimate.state, let since = pendingStateSince {
            if estimate.generatedAt.timeIntervalSince(since) >= 120 {
                state = estimate.state
                pendingState = nil
                pendingStateSince = nil
            }
        } else {
            pendingState = estimate.state
            pendingStateSince = estimate.generatedAt
        }

        current = PhysiologicalVoiceEstimate(
            state: state,
            arousal: arousal,
            fatigue: fatigue,
            recovery: recovery,
            confidence: clamp(confidence),
            generatedAt: estimate.generatedAt
        )
        return current
    }

    mutating func reset(at date: Date = .now) {
        current = .neutral(at: date)
        isInitialized = false
        pendingState = nil
        pendingStateSince = nil
    }

    private func limitedBlend(_ old: Double, _ new: Double, alpha: Double, limit: Double) -> Double {
        let delta = min(max((new - old) * alpha, -limit), limit)
        return clamp(old + delta)
    }
}

struct VoiceProsodyProfile: Equatable, Sendable {
    var tempoScale: Float
    var pauseScale: Float
    var pitchSemitones: Float
    var pitchRangeScale: Float
    var intensityScale: Float
    var dynamicRangeScale: Float
    var rhythmVariationScale: Float
    var emphasisScale: Float
    var articulationScale: Float
    var vowelDurationScale: Float
    var consonantAttackScale: Float
    var utteranceLengthScale: Float

    static let neutral = VoiceProsodyProfile(
        tempoScale: 1,
        pauseScale: 1,
        pitchSemitones: 0,
        pitchRangeScale: 1,
        intensityScale: 1,
        dynamicRangeScale: 1,
        rhythmVariationScale: 1,
        emphasisScale: 1,
        articulationScale: 1,
        vowelDurationScale: 1,
        consonantAttackScale: 1,
        utteranceLengthScale: 1
    )

    func interpolated(from base: VoiceProsodyProfile = .neutral, amount: Float) -> VoiceProsodyProfile {
        let factor = min(max(amount, 0), 1)
        func mix(_ start: Float, _ end: Float) -> Float { start + (end - start) * factor }
        return VoiceProsodyProfile(
            tempoScale: mix(base.tempoScale, tempoScale),
            pauseScale: mix(base.pauseScale, pauseScale),
            pitchSemitones: mix(base.pitchSemitones, pitchSemitones),
            pitchRangeScale: mix(base.pitchRangeScale, pitchRangeScale),
            intensityScale: mix(base.intensityScale, intensityScale),
            dynamicRangeScale: mix(base.dynamicRangeScale, dynamicRangeScale),
            rhythmVariationScale: mix(base.rhythmVariationScale, rhythmVariationScale),
            emphasisScale: mix(base.emphasisScale, emphasisScale),
            articulationScale: mix(base.articulationScale, articulationScale),
            vowelDurationScale: mix(base.vowelDurationScale, vowelDurationScale),
            consonantAttackScale: mix(base.consonantAttackScale, consonantAttackScale),
            utteranceLengthScale: mix(base.utteranceLengthScale, utteranceLengthScale)
        )
    }
}

struct AdaptiveVoiceDecision: Equatable, Sendable {
    var estimate: PhysiologicalVoiceEstimate
    var prosody: VoiceProsodyProfile
    var isAdaptive: Bool
}

enum VoicePolicy {
    static func previewDecision(
        for state: PhysiologicalVoiceState,
        at date: Date = .now
    ) -> AdaptiveVoiceDecision {
        let values: (arousal: Double, fatigue: Double, recovery: Double)
        switch state {
        case .calm:
            values = (0.28, 0.24, 0.28)
        case .neutral:
            values = (0.45, 0.35, 0.30)
        case .focused:
            values = (0.72, 0.30, 0.25)
        case .fatigued:
            values = (0.46, 0.72, 0.60)
        case .elevated:
            values = (0.78, 0.48, 0.42)
        case .recovering:
            values = (0.40, 0.67, 0.78)
        }

        return decision(
            for: PhysiologicalVoiceEstimate(
                state: state,
                arousal: values.arousal,
                fatigue: values.fatigue,
                recovery: values.recovery,
                confidence: 0.94,
                generatedAt: date
            ),
            isEnabled: true,
            reference: date
        )
    }

    static func decision(
        for estimate: PhysiologicalVoiceEstimate,
        isEnabled: Bool,
        reference: Date = .now
    ) -> AdaptiveVoiceDecision {
        var effectiveEstimate = estimate
        let age = max(0, reference.timeIntervalSince(estimate.generatedAt))
        if age > 6 * 60 * 60 {
            let freshness = max(0, 1 - (age - 6 * 60 * 60) / (18 * 60 * 60))
            effectiveEstimate.confidence *= freshness
            if effectiveEstimate.confidence < PhysiologicalStateEstimator.confidenceThreshold {
                effectiveEstimate.state = .neutral
            }
        }

        guard isEnabled,
              effectiveEstimate.confidence >= PhysiologicalStateEstimator.confidenceThreshold,
              effectiveEstimate.state != .neutral else {
            return AdaptiveVoiceDecision(
                estimate: effectiveEstimate,
                prosody: .neutral,
                isAdaptive: false
            )
        }

        let target: VoiceProsodyProfile
        switch effectiveEstimate.state {
        case .calm:
            target = profile(0.95, 1.10, -0.15, 0.92, 0.97, 0.92, 0.88, 0.92, 0.98, 1.03, 0.95, 0.94)
        case .focused:
            target = profile(1.04, 0.92, 0.25, 1.08, 1.02, 1.04, 1.07, 1.06, 1.04, 0.98, 1.05, 0.94)
        case .fatigued:
            target = profile(0.91, 1.17, -0.35, 0.84, 0.94, 0.86, 0.82, 0.84, 0.97, 1.06, 0.91, 0.78)
        case .elevated:
            target = profile(0.89, 1.22, -0.50, 0.78, 0.91, 0.80, 0.76, 0.80, 0.95, 1.07, 0.88, 0.70)
        case .recovering:
            target = profile(0.92, 1.18, -0.30, 0.82, 0.93, 0.84, 0.80, 0.84, 0.96, 1.06, 0.90, 0.76)
        case .neutral:
            target = .neutral
        }

        let amount = Float(clamp(
            (effectiveEstimate.confidence - PhysiologicalStateEstimator.confidenceThreshold) / 0.35
        ))
        return AdaptiveVoiceDecision(
            estimate: effectiveEstimate,
            prosody: target.interpolated(amount: amount),
            isAdaptive: amount > 0
        )
    }

    private static func profile(
        _ tempo: Float, _ pause: Float, _ pitch: Float, _ pitchRange: Float,
        _ intensity: Float, _ dynamicRange: Float, _ rhythm: Float, _ emphasis: Float,
        _ articulation: Float, _ vowel: Float, _ consonant: Float, _ utterance: Float
    ) -> VoiceProsodyProfile {
        VoiceProsodyProfile(
            tempoScale: tempo,
            pauseScale: pause,
            pitchSemitones: pitch,
            pitchRangeScale: pitchRange,
            intensityScale: intensity,
            dynamicRangeScale: dynamicRange,
            rhythmVariationScale: rhythm,
            emphasisScale: emphasis,
            articulationScale: articulation,
            vowelDurationScale: vowel,
            consonantAttackScale: consonant,
            utteranceLengthScale: utterance
        )
    }
}

@MainActor
final class AdaptiveVoiceCoordinator: ObservableObject {
    static let shared = AdaptiveVoiceCoordinator()

    @Published private(set) var currentEstimate = PhysiologicalVoiceEstimate.neutral()
    private var smoother = TemporalVoiceStateSmoother()

    private init() {}

    func ingest(_ snapshot: HealthWellnessSnapshot) {
        let context = PhysiologicalContextBuilder.build(from: snapshot)
        currentEstimate = smoother.update(with: PhysiologicalStateEstimator.estimate(context))
    }

    func decision() -> AdaptiveVoiceDecision {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(forKey: HealthVoicePreferences.adaptiveEnabledKey) as? Bool
            ?? HealthVoicePreferences.defaultAdaptiveEnabled
        return VoicePolicy.decision(for: currentEstimate, isEnabled: isEnabled)
    }

    func reset() {
        smoother.reset()
        currentEstimate = smoother.current
    }
}

private func clamp(_ value: Double, lower: Double = 0, upper: Double = 1) -> Double {
    min(max(value, lower), upper)
}
