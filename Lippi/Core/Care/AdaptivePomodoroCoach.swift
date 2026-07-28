import Combine
import Foundation

enum PomodoroTransitionReason: String, Codable, Hashable {
    case timerCompleted
    case skipped
    case stopped
    case replaced
}

struct PomodoroSessionRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var phase: PomodoroPhase
    var plannedSeconds: TimeInterval
    var activeSeconds: TimeInterval
    var transitionReason: PomodoroTransitionReason
    var endedAt: Date = .now

    var completionRatio: Double {
        guard plannedSeconds > 0 else { return 0 }
        return min(max(activeSeconds / plannedSeconds, 0), 1)
    }

    var wasCompleted: Bool {
        transitionReason == .timerCompleted || completionRatio >= 0.9
    }
}

struct PomodoroRhythmHistory: Codable, Hashable {
    private(set) var sessions: [PomodoroSessionRecord] = []

    var recentSessions: [PomodoroSessionRecord] {
        Array(sessions.suffix(24))
    }

    var focusSessions: [PomodoroSessionRecord] {
        recentSessions.filter { $0.phase == .focus }
    }

    var breakSessions: [PomodoroSessionRecord] {
        recentSessions.filter { $0.phase == .shortBreak || $0.phase == .longBreak }
    }

    var focusCompletionRate: Double {
        averageCompletion(in: focusSessions)
    }

    var breakCompletionRate: Double {
        averageCompletion(in: breakSessions)
    }

    mutating func append(_ record: PomodoroSessionRecord) {
        sessions.append(record)
        sessions = Array(sessions.suffix(60))
    }

    private func averageCompletion(in records: [PomodoroSessionRecord]) -> Double {
        guard !records.isEmpty else { return 1 }
        return records.map(\.completionRatio).reduce(0, +) / Double(records.count)
    }
}

enum AdaptivePomodoroRecommendationSource: String, Codable, Hashable {
    case localAnalysis
    case bonsai
}

enum AdaptiveRecoveryKind: String, Codable, Hashable {
    case move
    case water
    case eyes
    case breathe
    case reset

    var systemImage: String {
        switch self {
        case .move: return "figure.walk"
        case .water: return "drop.fill"
        case .eyes: return "eye.fill"
        case .breathe: return "wind"
        case .reset: return "figure.cooldown"
        }
    }
}

struct AdaptivePomodoroRecommendation: Codable, Hashable {
    var generatedAt = Date()
    var source: AdaptivePomodoroRecommendationSource
    var title: String
    var summary: String
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var roundsBeforeLongBreak: Int
    var nextGoalStep: String?
    var recoveryKind: AdaptiveRecoveryKind
    var recoveryAction: String
    var reasons: [String]
    var confidence: Double

    var config: PomodoroConfig {
        PomodoroConfig(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            roundsBeforeLongBreak: roundsBeforeLongBreak
        )
    }
}

struct AdaptivePomodoroContext: Hashable {
    var healthSnapshot: HealthWellnessSnapshot?
    var healthRecommendation: HealthWellnessRecommendation?
    var goalTitle: String?
    var goalAudit: GoalPlanProgressAudit?
    var fallbackGoalStep: String?
    var userState: GoalUserState
    var rhythmHistory: PomodoroRhythmHistory
    var lang: AppLang

    var fingerprint: String {
        let readiness = healthRecommendation?.band.rawValue ?? "unknown"
        let healthConfidence = String(Int((healthRecommendation?.confidence ?? 0) * 10))
        let goal = goalTitle ?? "no-goal"
        let nextStep = fallbackGoalStep ?? "no-step"
        let completed = String(goalAudit?.completedTasks ?? 0)
        let active = String(goalAudit?.activeTasks ?? 0)
        let overdue = String(goalAudit?.overdueTasks ?? 0)
        let sessionCount = String(rhythmHistory.recentSessions.count)
        let focusCompletion = String(Int((rhythmHistory.focusCompletionRate * 100).rounded()))
        let breakCompletion = String(Int((rhythmHistory.breakCompletionRate * 100).rounded()))
        let healthFreshness = healthSnapshot.map { String(Int($0.generatedAt.timeIntervalSince1970 / (15 * 60))) } ?? "no-health"
        return [
            readiness,
            healthConfidence,
            healthFreshness,
            goal,
            nextStep,
            completed,
            active,
            overdue,
            userState.rawValue,
            sessionCount,
            focusCompletion,
            breakCompletion,
            lang.rawValue
        ]
            .joined(separator: "|")
    }
}

enum AdaptivePomodoroPolicy {
    static func fallback(for context: AdaptivePomodoroContext) -> AdaptivePomodoroRecommendation {
        let pace = AdaptiveGoalPaceEngine.evaluate(
            health: context.healthRecommendation,
            audit: context.goalAudit,
            userState: context.userState
        )
        let recentFocus = context.rhythmHistory.focusSessions
        let recentBreaks = context.rhythmHistory.breakSessions

        var focus = pace.focusMinutes
        var shortBreak: Int
        var longBreak: Int
        var rounds: Int

        switch pace.level {
        case .recovery:
            focus = min(focus, 15)
            shortBreak = 7
            longBreak = 20
            rounds = 2
        case .light:
            focus = min(focus, 25)
            shortBreak = 7
            longBreak = 18
            rounds = 3
        case .balanced:
            shortBreak = 5
            longBreak = 15
            rounds = 4
        case .momentum:
            focus = min(focus, 50)
            shortBreak = 8
            longBreak = 20
            rounds = 4
        }

        if recentFocus.count >= 2, context.rhythmHistory.focusCompletionRate < 0.62 {
            focus = min(focus, max(10, focus - 10))
        }
        if recentBreaks.count >= 2, context.rhythmHistory.breakCompletionRate < 0.55 {
            shortBreak = min(12, shortBreak + 2)
            longBreak = min(25, longBreak + 3)
            rounds = min(rounds, 3)
        }

        focus = min(max(focus, 10), 60)
        shortBreak = min(max(shortBreak, 3), 15)
        longBreak = min(max(longBreak, 10), 30)
        rounds = min(max(rounds, 2), 4)

        let reasons = localizedReasons(
            pace: pace,
            context: context,
            shortenedForHistory: recentFocus.count >= 2 && context.rhythmHistory.focusCompletionRate < 0.62,
            strengthenedBreaks: recentBreaks.count >= 2 && context.rhythmHistory.breakCompletionRate < 0.55
        )

        let recovery = recoveryPlan(for: context)
        return AdaptivePomodoroRecommendation(
            source: .localAnalysis,
            title: L10n.tr("pomodoro.coach.local.title", context.lang),
            summary: summary(pace: pace, hasGoal: context.fallbackGoalStep != nil, lang: context.lang),
            focusMinutes: focus,
            shortBreakMinutes: shortBreak,
            longBreakMinutes: longBreak,
            roundsBeforeLongBreak: rounds,
            nextGoalStep: context.fallbackGoalStep,
            recoveryKind: recovery.kind,
            recoveryAction: recovery.action,
            reasons: Array(reasons.prefix(2)),
            confidence: localConfidence(for: context)
        )
    }

    static func validated(
        _ payload: BonsaiPomodoroPayload,
        fallback: AdaptivePomodoroRecommendation,
        context: AdaptivePomodoroContext
    ) -> AdaptivePomodoroRecommendation {
        let title = clean(payload.title, limit: 60) ?? fallback.title
        let summary = clean(payload.summary, limit: 180) ?? fallback.summary
        let modelRecovery = clean(payload.recoveryAction, limit: 110)
        let modelRecoveryKind = payload.recoveryKind.flatMap(AdaptiveRecoveryKind.init(rawValue:))
        let protectsRecovery = context.healthRecommendation?.band == .recovery
            || context.userState == .overloaded
            || context.userState == .tired

        return AdaptivePomodoroRecommendation(
            source: .bonsai,
            title: title,
            summary: summary,
            focusMinutes: min(max(payload.focusMinutes ?? fallback.focusMinutes, 10), fallback.focusMinutes),
            shortBreakMinutes: min(max(payload.shortBreakMinutes ?? fallback.shortBreakMinutes, fallback.shortBreakMinutes), 15),
            longBreakMinutes: min(max(payload.longBreakMinutes ?? fallback.longBreakMinutes, fallback.longBreakMinutes), 30),
            roundsBeforeLongBreak: min(max(payload.roundsBeforeLongBreak ?? fallback.roundsBeforeLongBreak, 2), fallback.roundsBeforeLongBreak),
            nextGoalStep: fallback.nextGoalStep,
            recoveryKind: protectsRecovery ? fallback.recoveryKind : (modelRecoveryKind ?? fallback.recoveryKind),
            recoveryAction: protectsRecovery ? fallback.recoveryAction : (modelRecovery ?? fallback.recoveryAction),
            reasons: fallback.reasons,
            confidence: min(max(payload.confidence ?? fallback.confidence, 0), 1)
        )
    }

    private static func summary(pace: AdaptiveGoalPace, hasGoal: Bool, lang: AppLang) -> String {
        if hasGoal {
            return L10n.tr("pomodoro.coach.local.summary.goal.\(pace.level.rawValue)", lang)
        }
        return L10n.tr("pomodoro.coach.local.summary.general.\(pace.level.rawValue)", lang)
    }

    private static func localizedReasons(
        pace: AdaptiveGoalPace,
        context: AdaptivePomodoroContext,
        shortenedForHistory: Bool,
        strengthenedBreaks: Bool
    ) -> [String] {
        var result: [String] = []
        if shortenedForHistory {
            result.append(L10n.tr("pomodoro.coach.reason.focus_history", context.lang))
        }
        if strengthenedBreaks {
            result.append(L10n.tr("pomodoro.coach.reason.break_history", context.lang))
        }
        if context.healthRecommendation?.band == .recovery || context.healthRecommendation?.band == .light {
            result.append(L10n.tr("pomodoro.coach.reason.recovery_signals", context.lang))
        }
        if (context.goalAudit?.overdueTasks ?? 0) > 0 || context.goalAudit?.isOverloaded == true {
            result.append(L10n.tr("pomodoro.coach.reason.goal_load", context.lang))
        }
        if context.fallbackGoalStep != nil {
            result.append(L10n.tr("pomodoro.coach.reason.goal_step", context.lang))
        }
        if result.isEmpty || result.count == 1 {
            result.append(L10n.tr("pomodoro.coach.reason.\(pace.level.rawValue)", context.lang))
        }
        return result
    }

    private static func recoveryPlan(for context: AdaptivePomodoroContext) -> (kind: AdaptiveRecoveryKind, action: String) {
        let now = Date.now
        if let movement = context.healthSnapshot?.lastMovementAt,
           now.timeIntervalSince(movement) >= 75 * 60 {
            return (.move, L10n.tr("pomodoro.coach.recovery.move", context.lang))
        }
        if let hydration = context.healthSnapshot?.lastHydrationAt,
           now.timeIntervalSince(hydration) >= 2 * 60 * 60 {
            return (.water, L10n.tr("pomodoro.coach.recovery.water", context.lang))
        }
        if context.healthRecommendation?.suggestsEyeBreak == true
            || context.rhythmHistory.focusSessions.last?.plannedSeconds ?? 0 >= 40 * 60 {
            return (.eyes, L10n.tr("pomodoro.coach.recovery.eyes", context.lang))
        }
        if context.healthRecommendation?.suggestsBreathing == true {
            return (.breathe, L10n.tr("pomodoro.coach.recovery.breathe", context.lang))
        }
        return (.reset, L10n.tr("pomodoro.coach.recovery.reset", context.lang))
    }

    private static func localConfidence(for context: AdaptivePomodoroContext) -> Double {
        var confidence = 0.42
        if context.healthRecommendation != nil { confidence += 0.18 }
        if context.goalAudit != nil { confidence += 0.14 }
        if context.rhythmHistory.focusSessions.count >= 2 { confidence += 0.14 }
        return min(confidence, 0.84)
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(limit))
    }
}

struct BonsaiPomodoroPayload: Decodable, Hashable {
    var title: String?
    var summary: String?
    var focusMinutes: Int?
    var shortBreakMinutes: Int?
    var longBreakMinutes: Int?
    var roundsBeforeLongBreak: Int?
    var recoveryKind: String?
    var recoveryAction: String?
    var confidence: Double?
}

enum AdaptivePomodoroPrompt {
    static func make(context: AdaptivePomodoroContext, safety: AdaptivePomodoroRecommendation) -> String {
        let health = context.healthRecommendation
        let audit = context.goalAudit
        let history = context.rhythmHistory
        let nextStep = context.fallbackGoalStep ?? "none"
        let title = context.goalTitle ?? "none"

        return """
        Output language: \(context.lang.rawValue)
        User state: \(context.userState.promptLabel)
        Readiness band: \(health?.band.rawValue ?? "unknown")
        Readiness confidence: \(rounded(health?.confidence))
        Health signals: \(health?.signals.map(\.rawValue).joined(separator: ",") ?? "limitedData")
        Movement in last 90 minutes: \(rounded(context.healthSnapshot?.stepsLast90Minutes)) steps
        Hydration logged today: \(context.healthSnapshot?.dietaryWaterTodayMilliliters == nil ? "unknown" : "yes")
        Goal title: \(title)
        Exact next goal step: \(nextStep)
        Goal progress: \(audit?.completedTasks ?? 0) completed, \(audit?.activeTasks ?? 0) active, \(audit?.overdueTasks ?? 0) overdue
        Recent focus completion: \(Int((history.focusCompletionRate * 100).rounded())) percent across \(history.focusSessions.count) sessions
        Recent break completion: \(Int((history.breakCompletionRate * 100).rounded())) percent across \(history.breakSessions.count) breaks

        Safety ceiling from local analysis:
        focus <= \(safety.focusMinutes) minutes; short break >= \(safety.shortBreakMinutes); long break >= \(safety.longBreakMinutes); long break every <= \(safety.roundsBeforeLongBreak) rounds.
        Personalize the explanation and recovery action using only these facts. You may reduce focus or increase rest, never do the opposite.
        Use the exact next goal step; do not invent or rewrite it. Do not diagnose health or infer a cause.
        """
    }

    private static func rounded(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        return String(format: "%.1f", value)
    }
}

enum AdaptivePomodoroCoachState: Equatable {
    case idle
    case analyzing
    case ready
    case unavailable(String)
}

@MainActor
final class AdaptivePomodoroCoach: ObservableObject {
    static let recommendationStorageKey = "pomodoro.coach.lastRecommendation.v1"
    static let recommendationFingerprintKey = "pomodoro.coach.lastFingerprint.v1"
    static let lastAttemptStorageKey = "pomodoro.coach.lastAttempt.v1"

    @Published private(set) var recommendation: AdaptivePomodoroRecommendation?
    @Published private(set) var state: AdaptivePomodoroCoachState = .idle

    private let provider: BonsaiGoalProvider
    private let defaults: UserDefaults
    private var lastAttemptAt: Date?
    private var lastGeneratedFingerprint: String?

    init(
        provider: BonsaiGoalProvider = BonsaiGoalProvider(),
        defaults: UserDefaults = .standard
    ) {
        self.provider = provider
        self.defaults = defaults
        lastAttemptAt = defaults.object(forKey: Self.lastAttemptStorageKey) as? Date
        lastGeneratedFingerprint = defaults.string(forKey: Self.recommendationFingerprintKey)
        if let data = defaults.data(forKey: Self.recommendationStorageKey),
           let saved = try? JSONDecoder().decode(AdaptivePomodoroRecommendation.self, from: data) {
            recommendation = saved
            state = .ready
        }
    }

    func refreshLocal(for context: AdaptivePomodoroContext) {
        guard state != .analyzing else { return }
        if recommendation?.source == .bonsai,
           lastGeneratedFingerprint == context.fingerprint,
           let generatedAt = recommendation?.generatedAt,
           Date.now.timeIntervalSince(generatedAt) < 36 * 60 * 60 {
            state = .ready
            return
        }
        recommendation = AdaptivePomodoroPolicy.fallback(for: context)
        state = .ready
    }

    func personalizeIfNeeded(for context: AdaptivePomodoroContext, now: Date = .now) async {
        guard BonsaiConfiguration.stored.isEnabled, BonsaiModelStorage.isInstalled else { return }
        guard lastGeneratedFingerprint != context.fingerprint else { return }
        if let lastAttemptAt, now.timeIntervalSince(lastAttemptAt) < 6 * 60 * 60 { return }
        await personalize(for: context, now: now)
    }

    func personalize(for context: AdaptivePomodoroContext, now: Date = .now) async {
        let fallback = AdaptivePomodoroPolicy.fallback(for: context)
        recommendation = fallback
        state = .analyzing
        lastAttemptAt = now
        defaults.set(now, forKey: Self.lastAttemptStorageKey)

        do {
            let raw = try await provider.generatePersonalRecommendation(
                prompt: AdaptivePomodoroPrompt.make(context: context, safety: fallback),
                configuration: .stored
            )
            try Task.checkCancellation()
            guard let json = GoalJSONRecovery.rootObject(in: raw),
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(BonsaiPomodoroPayload.self, from: data) else {
                throw BonsaiProviderError.malformedResponse
            }
            recommendation = AdaptivePomodoroPolicy.validated(payload, fallback: fallback, context: context)
            lastGeneratedFingerprint = context.fingerprint
            persistRecommendation()
            state = .ready
        } catch is CancellationError {
            recommendation = fallback
            state = .ready
        } catch let error as BonsaiProviderError {
            recommendation = fallback
            state = .unavailable(error.message(lang: context.lang))
        } catch {
            recommendation = fallback
            state = .unavailable(BonsaiProviderError.generationFailed.message(lang: context.lang))
        }
    }

    private func persistRecommendation() {
        guard let recommendation,
              let data = try? JSONEncoder().encode(recommendation),
              let lastGeneratedFingerprint else { return }
        defaults.set(data, forKey: Self.recommendationStorageKey)
        defaults.set(lastGeneratedFingerprint, forKey: Self.recommendationFingerprintKey)
    }
}
