import Foundation

enum AdaptiveGoalPaceLevel: String, Codable, Hashable {
    case recovery
    case light
    case balanced
    case momentum
}

enum AdaptiveGoalPaceReason: String, Codable, Hashable {
    case recoverySignals
    case gentleSignals
    case userOverloaded
    case userTired
    case overdueSteps
    case stalledStart
    case steadyProgress
    case strongMomentum
}

struct AdaptiveGoalPace: Codable, Hashable {
    var level: AdaptiveGoalPaceLevel
    var dailyStepLimit: Int
    var focusMinutes: Int
    var spacingDays: Int
    var reasons: [AdaptiveGoalPaceReason]
    var shouldRedistributeOverdueSteps: Bool

    var keepsGoalIntact: Bool { true }
}

enum AdaptiveGoalPaceEngine {
    static func evaluate(
        health: HealthWellnessRecommendation?,
        audit: GoalPlanProgressAudit?,
        userState: GoalUserState
    ) -> AdaptiveGoalPace {
        var reasons: [AdaptiveGoalPaceReason] = []

        if health?.band == .recovery { reasons.append(.recoverySignals) }
        if health?.band == .light { reasons.append(.gentleSignals) }
        if userState == .overloaded { reasons.append(.userOverloaded) }
        if userState == .tired { reasons.append(.userTired) }
        if (audit?.overdueTasks ?? 0) > 0 { reasons.append(.overdueSteps) }
        if audit?.isStalledWithoutFirstWin == true { reasons.append(.stalledStart) }

        let level: AdaptiveGoalPaceLevel
        if health?.band == .recovery || userState == .overloaded {
            level = .recovery
        } else if health?.band == .light
                    || userState == .tired
                    || userState == .uncertain
                    || audit?.isOverloaded == true
                    || (audit?.overdueTasks ?? 0) >= 2 {
            level = .light
        } else if health?.band == .ready, userState == .energetic, audit?.isOverloaded != true {
            level = .momentum
            reasons.append(.strongMomentum)
        } else {
            level = .balanced
            if reasons.isEmpty { reasons.append(.steadyProgress) }
        }

        let parameters: (daily: Int, focus: Int, spacing: Int)
        switch level {
        case .recovery:
            parameters = (1, min(15, health?.suggestedFocusMinutes ?? 15), 3)
        case .light:
            parameters = (1, min(25, health?.suggestedFocusMinutes ?? 25), 2)
        case .balanced:
            parameters = (2, health?.band == .ready ? 50 : 25, 2)
        case .momentum:
            parameters = (3, max(50, health?.suggestedFocusMinutes ?? 50), 1)
        }

        return AdaptiveGoalPace(
            level: level,
            dailyStepLimit: parameters.daily,
            focusMinutes: parameters.focus,
            spacingDays: parameters.spacing,
            reasons: Array(reasons.prefix(3)),
            shouldRedistributeOverdueSteps: (audit?.overdueTasks ?? 0) > 0
        )
    }
}

enum AdaptiveGoalPlanEngine {
    static func applying(
        to roadmap: GoalRoadmap,
        pace: AdaptiveGoalPace,
        lang: AppLang,
        replacing previousRecord: AdaptiveGoalPlanRecord? = nil
    ) -> GoalRoadmap {
        var adjusted = roadmap
        if let previousRecord, previousRecord.roadmapID == roadmap.id {
            adjusted.firstActions.removeAll { $0 == previousRecord.firstAction }
            adjusted.habits.removeAll {
                $0.title == previousRecord.habitTitle
                    && $0.detail == previousRecord.habitDetail
            }
        }
        let firstAction = firstAction(for: pace, lang: lang)
        let habitTitle = habitTitle(lang: lang)
        let habitDetail = habitDetail(for: pace, lang: lang)

        if !adjusted.firstActions.contains(firstAction) {
            adjusted.firstActions.insert(firstAction, at: 0)
        }
        if let index = adjusted.habits.firstIndex(where: { $0.title == habitTitle }) {
            adjusted.habits[index].detail = habitDetail
        } else {
            adjusted.habits.append(GoalHabit(title: habitTitle, detail: habitDetail))
        }
        return adjusted
    }

    static func isApplied(
        to roadmap: GoalRoadmap,
        pace: AdaptiveGoalPace,
        lang: AppLang
    ) -> Bool {
        roadmap.firstActions.contains(firstAction(for: pace, lang: lang))
            && roadmap.habits.contains {
                $0.title == habitTitle(lang: lang)
                    && $0.detail == habitDetail(for: pace, lang: lang)
            }
    }

    static func firstAction(for pace: AdaptiveGoalPace, lang: AppLang) -> String {
        L10n.fmt(
            "adaptive.goal.applied.first_action",
            lang,
            pace.focusMinutes,
            pace.dailyStepLimit
        )
    }

    static func habitTitle(lang: AppLang) -> String {
        L10n.tr("adaptive.goal.applied.habit_title", lang)
    }

    static func habitDetail(for pace: AdaptiveGoalPace, lang: AppLang) -> String {
        L10n.fmt(
            "adaptive.goal.applied.habit_detail",
            lang,
            pace.dailyStepLimit
        )
    }
}

struct AdaptiveGoalPlanRecord: Codable, Hashable {
    var roadmapID: UUID
    var appliedAt: Date
    var pace: AdaptiveGoalPace
    var userState: GoalUserState
    var healthBand: HealthReadinessBand?
    var activeTaskCount: Int
    var completedTaskCount: Int
    var overdueTaskCount: Int
    var redistributedTaskCount: Int
    var firstAction: String
    var habitTitle: String
    var habitDetail: String

    func isPresent(in roadmap: GoalRoadmap) -> Bool {
        roadmapID == roadmap.id
            && roadmap.firstActions.contains(firstAction)
            && roadmap.habits.contains {
                $0.title == habitTitle && $0.detail == habitDetail
            }
    }

    func matchesCurrentContext(
        healthBand: HealthReadinessBand?,
        userState: GoalUserState,
        audit: GoalPlanProgressAudit?
    ) -> Bool {
        self.healthBand == healthBand
            && self.userState == userState
            && activeTaskCount == (audit?.activeTasks ?? 0)
            && completedTaskCount == (audit?.completedTasks ?? 0)
            && overdueTaskCount == (audit?.overdueTasks ?? 0)
    }
}

enum AdaptiveGoalPlanRecordStore {
    static let storageKey = "health.plan.lastAdaptation"

    static func decode(_ rawValue: String) -> AdaptiveGoalPlanRecord? {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AdaptiveGoalPlanRecord.self, from: data)
    }

    static func encode(_ record: AdaptiveGoalPlanRecord) -> String? {
        guard let data = try? JSONEncoder().encode(record) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ record: AdaptiveGoalPlanRecord, defaults: UserDefaults = .standard) {
        guard let value = encode(record) else { return }
        defaults.set(value, forKey: storageKey)
    }
}

enum GoalCareNotificationScheduler {
    static let enabledKey = "goal.care.notifications.enabled"
    static let notificationID = "goal-care-next-suggestion"

    private static let lastFingerprintKey = "goal.care.notifications.lastFingerprint"
    private static let lastScheduledAtKey = "goal.care.notifications.lastScheduledAt"
    private static let weekStartKey = "goal.care.notifications.weekStart"
    private static let weekCountKey = "goal.care.notifications.weekCount"
    private static let minimumInterval: TimeInterval = 36 * 60 * 60
    private static let weeklyLimit = 2

    static func refresh(
        roadmap: GoalRoadmap?,
        tasks: [TaskItem],
        health: HealthWellnessRecommendation?,
        userState: GoalUserState,
        lang: AppLang,
        now: Date = .now
    ) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }

        guard defaults.bool(forKey: enabledKey), let roadmap else {
            NotificationManager.shared.cancel(ids: [notificationID])
            return
        }

        let audit = GoalPlanProgressAudit.make(roadmap: roadmap, tasks: tasks, now: now)
        guard let advice = advice(health: health, audit: audit, userState: userState, lang: lang) else {
            NotificationManager.shared.cancel(ids: [notificationID])
            return
        }

        let fingerprint = "\(roadmap.id.uuidString)|\(advice.kind)"
        if let last = defaults.object(forKey: lastScheduledAtKey) as? Date {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < minimumInterval { return }
            if defaults.string(forKey: lastFingerprintKey) == fingerprint,
               elapsed < 7 * 24 * 60 * 60 {
                return
            }
        }

        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)
        let storedWeekStart = defaults.object(forKey: weekStartKey) as? Date
        var count = defaults.integer(forKey: weekCountKey)
        if storedWeekStart == nil || !calendar.isDate(storedWeekStart!, inSameDayAs: currentWeekStart) {
            count = 0
            defaults.set(currentWeekStart, forKey: weekStartKey)
            defaults.set(0, forKey: weekCountKey)
        }
        guard count < weeklyLimit else { return }

        NotificationManager.shared.scheduleGentle(
            id: notificationID,
            title: advice.title,
            body: advice.body,
            at: nextGentleTime(after: now),
            userInfo: ["url": "lippi://goals?mode=progress"]
        )
        defaults.set(fingerprint, forKey: lastFingerprintKey)
        defaults.set(now, forKey: lastScheduledAtKey)
        defaults.set(count + 1, forKey: weekCountKey)
    }

    static func cancel() {
        NotificationManager.shared.cancel(ids: [notificationID])
    }

    private static func advice(
        health: HealthWellnessRecommendation?,
        audit: GoalPlanProgressAudit?,
        userState: GoalUserState,
        lang: AppLang
    ) -> GoalCareAdvice? {
        if userState == .overloaded || audit?.isOverloaded == true {
            return GoalCareAdvice(
                kind: "overload",
                title: L10n.tr("goalcare.notification.overload.title", lang),
                body: L10n.tr("goalcare.notification.overload.body", lang)
            )
        }
        if (audit?.overdueTasks ?? 0) > 0 {
            return GoalCareAdvice(
                kind: "overdue",
                title: L10n.tr("goalcare.notification.overdue.title", lang),
                body: L10n.tr("goalcare.notification.overdue.body", lang)
            )
        }
        if health?.band == .recovery || userState == .tired {
            return GoalCareAdvice(
                kind: "recovery",
                title: L10n.tr("goalcare.notification.recovery.title", lang),
                body: L10n.tr("goalcare.notification.recovery.body", lang)
            )
        }
        if audit?.isStalledWithoutFirstWin == true {
            return GoalCareAdvice(
                kind: "restart",
                title: L10n.tr("goalcare.notification.restart.title", lang),
                body: L10n.tr("goalcare.notification.restart.body", lang)
            )
        }
        return nil
    }

    private static func nextGentleTime(after date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        if hour < 9 {
            return calendar.date(bySettingHour: 10, minute: 30, second: 0, of: date)
                ?? date.addingTimeInterval(2 * 60 * 60)
        }
        if hour < 17 {
            let candidate = date.addingTimeInterval(3 * 60 * 60)
            if calendar.component(.hour, from: candidate) < 20 { return candidate }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)
            ?? tomorrow
    }
}

private struct GoalCareAdvice {
    let kind: String
    let title: String
    let body: String
}
