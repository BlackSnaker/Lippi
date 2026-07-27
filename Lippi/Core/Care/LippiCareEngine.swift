import Foundation
import SwiftUI

enum LippiCareKind: String, Codable, CaseIterable, Hashable {
    case eyeBreak
    case recovery
    case mealCheck
    case movement
    case hydration
    case goalStep
    case steady

    var icon: String {
        switch self {
        case .eyeBreak: return "eye.fill"
        case .recovery: return "heart.fill"
        case .mealCheck: return "fork.knife"
        case .movement: return "figure.walk"
        case .hydration: return "drop.fill"
        case .goalStep: return "scope"
        case .steady: return "sparkles"
        }
    }
}

enum LippiCareAction: String, Codable, CaseIterable, Hashable {
    case openEyes
    case openRecovery
    case logMeal
    case logMovement
    case logWater
    case openGoal
    case none
}

struct LippiCareSuggestion: Codable, Hashable, Identifiable {
    var kind: LippiCareKind
    var title: String
    var body: String
    var actionTitle: String
    var action: LippiCareAction
    var priority: Int
    var deepLink: String
    var evidence: [String]

    var id: String { kind.rawValue }
    var isNotificationWorthy: Bool { kind != .steady }
}

struct LippiCareHistory: Codable, Hashable {
    var actionDates: [String: Date] = [:]

    func lastDate(for action: LippiCareAction) -> Date? {
        actionDates[action.rawValue]
    }

    mutating func record(_ action: LippiCareAction, at date: Date) {
        guard action != .none else { return }
        actionDates[action.rawValue] = date
    }
}

struct LippiCareInput {
    var now: Date
    var healthSnapshot: HealthWellnessSnapshot?
    var healthRecommendation: HealthWellnessRecommendation?
    var goalAudit: GoalPlanProgressAudit?
    var fallbackGoalStep: String?
    var userState: GoalUserState
    var focusElapsed: TimeInterval
    var isFocusRunning: Bool
    var history: LippiCareHistory
    var lang: AppLang
}

enum LippiCareEngine {
    static func evaluate(_ input: LippiCareInput) -> [LippiCareSuggestion] {
        let now = input.now
        let hour = Calendar.current.component(.hour, from: now)
        let health = input.healthSnapshot
        let recentHealth = health.map { abs(now.timeIntervalSince($0.generatedAt)) < 3 * 60 * 60 } == true
        let lastMovement = health?.lastMovementAt
        let recentSteps = health?.stepsLast90Minutes
        let inactiveFor: TimeInterval? = lastMovement.map { now.timeIntervalSince($0) }
        let hasLowRecentMovement = recentHealth
            && recentSteps.map { $0 < 90 } == true
            && (inactiveFor.map { $0 >= 75 * 60 } ?? true)
        let prolongedSitting = hasLowRecentMovement || (input.isFocusRunning && input.focusElapsed >= 60 * 60)
        var suggestions: [LippiCareSuggestion] = []

        if input.isFocusRunning,
           input.focusElapsed >= 40 * 60,
           isReady(.openEyes, after: 75 * 60, input: input) {
            suggestions.append(make(
                .eyeBreak,
                title: "care.suggestion.eyes.title",
                body: "care.suggestion.eyes.body",
                action: .openEyes,
                priority: 100,
                deepLink: "lippi://eye",
                evidence: ["focus:\(Int(input.focusElapsed / 60))"],
                lang: input.lang
            ))
        }

        if (input.healthRecommendation?.band == .recovery
            || input.userState == .overloaded
            || input.userState == .tired),
           isReady(.openRecovery, after: 90 * 60, input: input) {
            suggestions.append(make(
                .recovery,
                title: "care.suggestion.recovery.title",
                body: "care.suggestion.recovery.body",
                action: .openRecovery,
                priority: 92,
                deepLink: "lippi://break",
                evidence: ["state:\(input.userState.rawValue)"],
                lang: input.lang
            ))
        }

        let mealWindow = (11...14).contains(hour) || (17...20).contains(hour)
        let lastMeal = latest(
            input.history.lastDate(for: .logMeal),
            health?.lastNutritionAt
        )
        let mealDue = lastMeal.map { now.timeIntervalSince($0) >= 4 * 60 * 60 } ?? true
        if mealWindow,
           prolongedSitting,
           mealDue,
           isReady(.logMeal, after: 4 * 60 * 60, input: input) {
            suggestions.append(make(
                .mealCheck,
                title: "care.suggestion.meal.title",
                body: "care.suggestion.meal.body",
                action: .logMeal,
                priority: 86,
                deepLink: "lippi://health",
                evidence: ["movement:low", "meal:check"],
                lang: input.lang
            ))
        }

        if prolongedSitting,
           isReady(.logMovement, after: 90 * 60, input: input) {
            suggestions.append(make(
                .movement,
                title: "care.suggestion.move.title",
                body: "care.suggestion.move.body",
                action: .logMovement,
                priority: 80,
                deepLink: "lippi://health",
                evidence: ["movement:low"],
                lang: input.lang
            ))
        }

        let lastWater = latest(
            input.history.lastDate(for: .logWater),
            health?.lastHydrationAt
        )
        let hydrationDue = lastWater.map { now.timeIntervalSince($0) >= 2 * 60 * 60 } ?? true
        if (9...20).contains(hour),
           hydrationDue,
           (prolongedSitting || input.focusElapsed >= 25 * 60),
           isReady(.logWater, after: 2 * 60 * 60, input: input) {
            suggestions.append(make(
                .hydration,
                title: "care.suggestion.water.title",
                body: "care.suggestion.water.body",
                action: .logWater,
                priority: 70,
                deepLink: "lippi://health",
                evidence: ["hydration:check"],
                lang: input.lang
            ))
        }

        let nextStep = input.goalAudit?.nextActiveTask ?? input.fallbackGoalStep
        if let nextStep,
           !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           input.userState != .overloaded,
           input.healthRecommendation?.band != .recovery,
           isReady(.openGoal, after: 6 * 60 * 60, input: input) {
            suggestions.append(LippiCareSuggestion(
                kind: .goalStep,
                title: L10n.tr("care.suggestion.goal.title", input.lang),
                body: L10n.fmt("care.suggestion.goal.body", input.lang, nextStep),
                actionTitle: L10n.tr("care.action.open_goal", input.lang),
                action: .openGoal,
                priority: 60,
                deepLink: "lippi://goals?mode=progress",
                evidence: ["goal:next-step"]
            ))
        }

        if suggestions.isEmpty {
            suggestions.append(LippiCareSuggestion(
                kind: .steady,
                title: L10n.tr("care.suggestion.steady.title", input.lang),
                body: L10n.tr("care.suggestion.steady.body", input.lang),
                actionTitle: L10n.tr("care.action.none", input.lang),
                action: .none,
                priority: 10,
                deepLink: "lippi://health",
                evidence: []
            ))
        }

        return suggestions.sorted { lhs, rhs in
            if lhs.priority == rhs.priority { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.priority > rhs.priority
        }
    }

    private static func make(
        _ kind: LippiCareKind,
        title: String,
        body: String,
        action: LippiCareAction,
        priority: Int,
        deepLink: String,
        evidence: [String],
        lang: AppLang
    ) -> LippiCareSuggestion {
        LippiCareSuggestion(
            kind: kind,
            title: L10n.tr(title, lang),
            body: L10n.tr(body, lang),
            actionTitle: L10n.tr("care.action.\(action.rawValue)", lang),
            action: action,
            priority: priority,
            deepLink: deepLink,
            evidence: evidence
        )
    }

    private static func isReady(
        _ action: LippiCareAction,
        after interval: TimeInterval,
        input: LippiCareInput
    ) -> Bool {
        guard let date = input.history.lastDate(for: action) else { return true }
        return input.now.timeIntervalSince(date) >= interval
    }

    private static func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?): return max(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}

@MainActor
final class LippiCareCenter: ObservableObject {
    static let shared = LippiCareCenter()
    static let historyStorageKey = "lippi.care.history.v1"

    @Published private(set) var suggestions: [LippiCareSuggestion] = []
    @Published private(set) var history: LippiCareHistory
    @Published private(set) var lastUpdated: Date?

    private var latestInput: LippiCareInput?

    var primarySuggestion: LippiCareSuggestion? { suggestions.first }

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.historyStorageKey),
           let value = try? JSONDecoder().decode(LippiCareHistory.self, from: data) {
            history = value
        } else {
            history = LippiCareHistory()
        }
    }

    func refresh(
        now: Date = .now,
        healthSnapshot: HealthWellnessSnapshot?,
        healthRecommendation: HealthWellnessRecommendation?,
        roadmap: GoalRoadmap?,
        tasks: [TaskItem],
        userState: GoalUserState,
        focusElapsed: TimeInterval,
        isFocusRunning: Bool,
        lang: AppLang
    ) {
        let audit = roadmap.flatMap { GoalPlanProgressAudit.make(roadmap: $0, tasks: tasks, now: now) }
        let input = LippiCareInput(
            now: now,
            healthSnapshot: healthSnapshot,
            healthRecommendation: healthRecommendation,
            goalAudit: audit,
            fallbackGoalStep: roadmap?.firstActions.first,
            userState: userState,
            focusElapsed: focusElapsed,
            isFocusRunning: isFocusRunning,
            history: history,
            lang: lang
        )
        latestInput = input
        suggestions = LippiCareEngine.evaluate(input)
        lastUpdated = now
        LippiCareNotificationScheduler.refresh(suggestion: primarySuggestion, now: now)
    }

    func record(_ action: LippiCareAction, at date: Date = .now) {
        guard action != .none else { return }
        history.record(action, at: date)
        persist()
        if var input = latestInput {
            input.now = date
            input.history = history
            latestInput = input
            suggestions = LippiCareEngine.evaluate(input)
            lastUpdated = date
            LippiCareNotificationScheduler.refresh(suggestion: primarySuggestion, now: date)
        }
        NotificationCenter.default.post(name: .lippiCareDidChange, object: nil)
    }

    private func persist(defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.historyStorageKey)
    }
}

extension Notification.Name {
    static let lippiCareDidChange = Notification.Name("lippiCareDidChange")
}

enum LippiCareNotificationScheduler {
    static let notificationID = "lippi-care-next-suggestion"
    private static let oldNotificationID = GoalCareNotificationScheduler.notificationID
    private static let lastScheduledAtKey = "lippi.care.notification.lastScheduledAt"
    private static let lastKindKey = "lippi.care.notification.lastKind"
    private static let dayKey = "lippi.care.notification.day"
    private static let dayCountKey = "lippi.care.notification.dayCount"
    private static let minimumInterval: TimeInterval = 90 * 60
    private static let dailyLimit = 3

    static func refresh(
        suggestion: LippiCareSuggestion?,
        now: Date = .now,
        defaults: UserDefaults = .standard
    ) {
        NotificationManager.shared.cancel(ids: [oldNotificationID])
        guard defaults.object(forKey: GoalCareNotificationScheduler.enabledKey) == nil
                || defaults.bool(forKey: GoalCareNotificationScheduler.enabledKey),
              let suggestion,
              suggestion.isNotificationWorthy else {
            cancel()
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let storedDay = defaults.object(forKey: dayKey) as? Date
        var count = defaults.integer(forKey: dayCountKey)
        if storedDay == nil || !calendar.isDate(storedDay!, inSameDayAs: today) {
            count = 0
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: dayCountKey)
        }
        guard count < dailyLimit else { return }

        if let last = defaults.object(forKey: lastScheduledAtKey) as? Date {
            let elapsed = now.timeIntervalSince(last)
            guard elapsed >= minimumInterval else { return }
            if defaults.string(forKey: lastKindKey) == suggestion.kind.rawValue,
               elapsed < sameKindCooldown(suggestion.kind) {
                return
            }
        }

        NotificationManager.shared.scheduleGentle(
            id: notificationID,
            title: suggestion.title,
            body: suggestion.body,
            at: nextGentleTime(after: now),
            userInfo: ["url": suggestion.deepLink]
        )
        defaults.set(now, forKey: lastScheduledAtKey)
        defaults.set(suggestion.kind.rawValue, forKey: lastKindKey)
        defaults.set(count + 1, forKey: dayCountKey)
    }

    static func cancel() {
        NotificationManager.shared.cancel(ids: [notificationID, oldNotificationID])
    }

    private static func sameKindCooldown(_ kind: LippiCareKind) -> TimeInterval {
        switch kind {
        case .eyeBreak: return 2 * 60 * 60
        case .movement, .hydration: return 3 * 60 * 60
        case .mealCheck: return 6 * 60 * 60
        case .goalStep, .recovery: return 8 * 60 * 60
        case .steady: return 24 * 60 * 60
        }
    }

    private static func nextGentleTime(after date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour < 8 {
            return calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date)
                ?? date.addingTimeInterval(60 * 60)
        }
        if hour < 20 {
            return date.addingTimeInterval(30 * 60)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

struct LippiCareLifecycleModifier: ViewModifier {
    @ObservedObject var healthKit: HealthKitManager
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var watch: AppleWatchDiscovery
    let userStateRaw: String
    let refresh: () -> Void
    let handleWatchAction: (LippiCareWatchActionEvent) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: healthKit.snapshot) { _, _ in refresh() }
            .onChange(of: taskStore.tasks) { _, _ in refresh() }
            .onChange(of: userStateRaw) { _, _ in refresh() }
            .onChange(of: pomodoro.phase) { _, _ in refresh() }
            .onChange(of: watch.latestCareAction) { _, event in
                if let event { handleWatchAction(event) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .lippiCareDidChange)) { _ in
                refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusWorkLogged)) { _ in
                refresh()
            }
            .task(id: pomodoro.startDate) {
                guard pomodoro.phase == .focus else { return }
                while !Task.isCancelled, pomodoro.phase == .focus {
                    try? await Task.sleep(nanoseconds: 300_000_000_000)
                    guard !Task.isCancelled, pomodoro.phase == .focus else { break }
                    refresh()
                }
            }
    }
}
