import Foundation

enum LippiCalendarMoveReason: String, Hashable {
    case overdue
    case overloadedDay
    case recoveryPace
}

struct LippiCalendarMove: Identifiable, Hashable {
    let taskID: UUID
    let taskTitle: String
    let originalDate: Date
    let proposedDate: Date
    let reason: LippiCalendarMoveReason

    var id: UUID { taskID }
}

struct LippiCalendarSignal: Identifiable, Hashable {
    let icon: String
    let titleKey: String

    var id: String { "\(icon)|\(titleKey)" }
}

struct LippiCalendarIntelligence: Hashable {
    let pace: AdaptiveGoalPace
    let plansToday: Int
    let overduePlans: Int
    let overloadedDays: Int
    let completedThisWeek: Int
    let focusMinutesToday: Int
    let nextGoalStep: String?
    let suggestions: [LippiCalendarMove]
    let signals: [LippiCalendarSignal]

    var shouldOfferAdaptation: Bool { !suggestions.isEmpty }
}

enum LippiCalendarIntelligenceEngine {
    static func analyze(
        tasks: [TaskItem],
        roadmap: GoalRoadmap?,
        healthSnapshot: HealthWellnessSnapshot?,
        healthRecommendation: HealthWellnessRecommendation?,
        userState: GoalUserState,
        careSuggestion: LippiCareSuggestion?,
        completedThisWeek: Int,
        focusMinutesToday: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> LippiCalendarIntelligence {
        let activeTasks = tasks.filter { !$0.isCompleted }
        let audit = roadmap.flatMap {
            GoalPlanProgressAudit.make(roadmap: $0, tasks: tasks, now: now)
        }
        let pace = AdaptiveGoalPaceEngine.evaluate(
            health: healthRecommendation,
            audit: audit,
            userState: userState
        )
        let today = calendar.startOfDay(for: now)

        let datedTasks = activeTasks.compactMap { task -> (TaskItem, Date)? in
            guard let dueDate = task.dueDate else { return nil }
            return (task, dueDate)
        }
        let plansToday = datedTasks.reduce(into: 0) { result, item in
            if calendar.isDate(item.1, inSameDayAs: today) { result += 1 }
        }
        let overduePlans = datedTasks.reduce(into: 0) { result, item in
            if item.1 < now && !calendar.isDate(item.1, inSameDayAs: today) { result += 1 }
        }

        var tasksByDay: [Date: [TaskItem]] = [:]
        for (task, dueDate) in datedTasks {
            tasksByDay[calendar.startOfDay(for: dueDate), default: []].append(task)
        }
        let overloadedDays = tasksByDay.values.reduce(into: 0) { result, items in
            if items.count > pace.dailyStepLimit { result += 1 }
        }

        let suggestions = scheduleSuggestions(
            activeTasks: activeTasks,
            roadmap: roadmap,
            pace: pace,
            now: now,
            calendar: calendar
        )

        return LippiCalendarIntelligence(
            pace: pace,
            plansToday: plansToday,
            overduePlans: overduePlans,
            overloadedDays: overloadedDays,
            completedThisWeek: completedThisWeek,
            focusMinutesToday: focusMinutesToday,
            nextGoalStep: audit?.nextActiveTask ?? roadmap?.firstActions.first,
            suggestions: suggestions,
            signals: signals(
                healthSnapshot: healthSnapshot,
                healthRecommendation: healthRecommendation,
                userState: userState,
                careSuggestion: careSuggestion,
                hasRoadmap: roadmap != nil,
                focusMinutesToday: focusMinutesToday
            )
        )
    }

    private static func scheduleSuggestions(
        activeTasks: [TaskItem],
        roadmap: GoalRoadmap?,
        pace: AdaptiveGoalPace,
        now: Date,
        calendar: Calendar
    ) -> [LippiCalendarMove] {
        let today = calendar.startOfDay(for: now)
        let capacity = max(1, pace.dailyStepLimit)
        let dated = activeTasks.compactMap { task -> (TaskItem, Date, Date)? in
            guard let dueDate = task.dueDate else { return nil }
            return (task, dueDate, calendar.startOfDay(for: dueDate))
        }

        var projectedLoad: [Date: Int] = [:]
        for (_, _, day) in dated where day >= today {
            projectedLoad[day, default: 0] += 1
        }

        let linkedIDs: Set<UUID>
        if let roadmap {
            linkedIDs = Set(activeTasks.filter { GoalPlanProgressAudit.isLinked($0, to: roadmap) }.map(\.id))
        } else {
            linkedIDs = []
        }

        var candidates: [(TaskItem, Date, LippiCalendarMoveReason)] = []
        var candidateIDs = Set<UUID>()

        for (task, dueDate, day) in dated where dueDate < now && day < today {
            candidates.append((task, dueDate, .overdue))
            candidateIDs.insert(task.id)
        }

        let grouped = Dictionary(grouping: dated.filter { $0.2 >= today }, by: { $0.2 })
        for (_, items) in grouped where items.count > capacity {
            let ordered = items.sorted { lhs, rhs in
                let lhsLinked = linkedIDs.contains(lhs.0.id)
                let rhsLinked = linkedIDs.contains(rhs.0.id)
                if lhsLinked != rhsLinked { return lhsLinked && !rhsLinked }
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.createdAt < rhs.0.createdAt
            }
            for (task, dueDate, _) in ordered.dropFirst(capacity) where !candidateIDs.contains(task.id) {
                let reason: LippiCalendarMoveReason = pace.level == .recovery
                    ? .recoveryPace
                    : .overloadedDay
                candidates.append((task, dueDate, reason))
                candidateIDs.insert(task.id)
                let sourceDay = calendar.startOfDay(for: dueDate)
                projectedLoad[sourceDay] = max(0, (projectedLoad[sourceDay] ?? 1) - 1)
            }
        }

        candidates.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            let lhsLinked = linkedIDs.contains(lhs.0.id)
            let rhsLinked = linkedIDs.contains(rhs.0.id)
            if lhsLinked != rhsLinked { return lhsLinked && !rhsLinked }
            return lhs.0.createdAt < rhs.0.createdAt
        }

        var moves: [LippiCalendarMove] = []
        moves.reserveCapacity(min(candidates.count, 6))

        for (task, originalDate, reason) in candidates.prefix(6) {
            let preferredStart: Date
            if reason == .overdue {
                preferredStart = today
            } else {
                let originalDay = calendar.startOfDay(for: originalDate)
                preferredStart = calendar.date(byAdding: .day, value: 1, to: originalDay) ?? today
            }

            let destinationDay = nextAvailableDay(
                from: max(preferredStart, today),
                capacity: capacity,
                spacingDays: max(1, pace.spacingDays),
                projectedLoad: &projectedLoad,
                calendar: calendar
            )
            let proposedDate = preservingUsefulTime(
                from: originalDate,
                on: destinationDay,
                now: now,
                calendar: calendar
            )
            moves.append(
                LippiCalendarMove(
                    taskID: task.id,
                    taskTitle: task.title,
                    originalDate: originalDate,
                    proposedDate: proposedDate,
                    reason: reason
                )
            )
        }

        return moves
    }

    private static func nextAvailableDay(
        from start: Date,
        capacity: Int,
        spacingDays: Int,
        projectedLoad: inout [Date: Int],
        calendar: Calendar
    ) -> Date {
        var candidate = calendar.startOfDay(for: start)
        for _ in 0..<45 {
            if (projectedLoad[candidate] ?? 0) < capacity {
                projectedLoad[candidate, default: 0] += 1
                return candidate
            }
            candidate = calendar.date(byAdding: .day, value: spacingDays, to: candidate)
                ?? candidate.addingTimeInterval(86_400 * Double(spacingDays))
        }
        projectedLoad[candidate, default: 0] += 1
        return candidate
    }

    private static func preservingUsefulTime(
        from originalDate: Date,
        on day: Date,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let original = calendar.dateComponents([.hour, .minute], from: originalDate)
        let hour = original.hour ?? 18
        let minute = original.minute ?? 0
        var result = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            ?? day.addingTimeInterval(18 * 60 * 60)

        if result <= now {
            result = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
                ?? day.addingTimeInterval(18 * 60 * 60)
            if result <= now {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
                result = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)
                    ?? tomorrow.addingTimeInterval(18 * 60 * 60)
            }
        }
        return result
    }

    private static func signals(
        healthSnapshot: HealthWellnessSnapshot?,
        healthRecommendation: HealthWellnessRecommendation?,
        userState: GoalUserState,
        careSuggestion: LippiCareSuggestion?,
        hasRoadmap: Bool,
        focusMinutesToday: Int
    ) -> [LippiCalendarSignal] {
        var result: [LippiCalendarSignal] = []

        if healthSnapshot?.hasAppleWatchData == true {
            result.append(.init(icon: "applewatch", titleKey: "calendar.signal.watch"))
        } else if healthSnapshot?.hasRecentData == true {
            result.append(.init(icon: "heart.text.square.fill", titleKey: "calendar.signal.health"))
        }

        switch healthRecommendation?.band {
        case .recovery:
            result.append(.init(icon: "heart.fill", titleKey: "calendar.signal.recovery"))
        case .light:
            result.append(.init(icon: "leaf.fill", titleKey: "calendar.signal.light"))
        case .ready:
            result.append(.init(icon: "bolt.fill", titleKey: "calendar.signal.ready"))
        case .balanced:
            result.append(.init(icon: "equal.circle.fill", titleKey: "calendar.signal.balanced"))
        case .unknown, .none:
            break
        }

        if userState == .tired || userState == .overloaded {
            result.append(.init(icon: "person.fill", titleKey: "calendar.signal.checkin"))
        }
        if focusMinutesToday > 0 {
            result.append(.init(icon: "timer", titleKey: "calendar.signal.focus"))
        }
        if hasRoadmap {
            result.append(.init(icon: "point.topleft.down.curvedto.point.bottomright.up", titleKey: "calendar.signal.roadmap"))
        }
        if let careSuggestion, careSuggestion.kind != .steady {
            result.append(.init(icon: careSuggestion.kind.icon, titleKey: "calendar.signal.care"))
        }

        if result.isEmpty {
            result.append(.init(icon: "sparkles", titleKey: "calendar.signal.local"))
        }
        return Array(result.prefix(4))
    }
}
