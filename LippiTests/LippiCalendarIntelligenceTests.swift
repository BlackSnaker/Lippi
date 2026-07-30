import Foundation
import Testing
@testable import Lippi

struct LippiCalendarIntelligenceTests {
    @Test("Busy days are redistributed without changing task content")
    func busyDayCreatesGentleMoves() {
        let calendar = Calendar(identifier: .gregorian)
        let now = date(day: 30, hour: 10, calendar: calendar)
        let busyDay = date(day: 31, hour: 18, calendar: calendar)
        let tasks = (1...4).map { index in
            TaskItem(title: "Plan \(index)", dueDate: busyDay, category: .work)
        }

        let result = LippiCalendarIntelligenceEngine.analyze(
            tasks: tasks,
            roadmap: nil,
            healthSnapshot: nil,
            healthRecommendation: nil,
            userState: .calm,
            careSuggestion: nil,
            completedThisWeek: 2,
            focusMinutesToday: 25,
            now: now,
            calendar: calendar
        )

        #expect(result.pace.level == .balanced)
        #expect(result.pace.dailyStepLimit == 2)
        #expect(result.overloadedDays == 1)
        #expect(result.suggestions.count == 2)
        #expect(Set(result.suggestions.map(\.taskTitle)).isSubset(of: Set(tasks.map(\.title))))
        #expect(result.suggestions.allSatisfy { $0.proposedDate > busyDay })
    }

    @Test("Recovery signals protect a one-plan day")
    func recoverySignalsReduceDailyLoad() {
        let calendar = Calendar(identifier: .gregorian)
        let now = date(day: 30, hour: 9, calendar: calendar)
        let due = date(day: 30, hour: 17, calendar: calendar)
        let recommendation = HealthWellnessRecommendation(
            band: .recovery,
            confidence: 0.84,
            signals: [.sleepBelowBaseline, .hrvBelowBaseline],
            suggestedFocusMinutes: 15,
            planLoadScale: 0.65,
            suggestsBreathing: true,
            suggestsEyeBreak: true
        )
        let tasks = (1...3).map { index in
            TaskItem(title: "Recovery plan \(index)", dueDate: due, category: .other)
        }

        let result = LippiCalendarIntelligenceEngine.analyze(
            tasks: tasks,
            roadmap: nil,
            healthSnapshot: HealthWellnessSnapshot(generatedAt: now, recentSleepHours: 5),
            healthRecommendation: recommendation,
            userState: .tired,
            careSuggestion: nil,
            completedThisWeek: 0,
            focusMinutesToday: 0,
            now: now,
            calendar: calendar
        )

        #expect(result.pace.level == .recovery)
        #expect(result.pace.dailyStepLimit == 1)
        #expect(result.pace.focusMinutes <= 15)
        #expect(result.suggestions.count == 2)
        #expect(result.suggestions.allSatisfy { $0.reason == .recoveryPace })
    }

    @Test("Overdue work is offered a future date and never deleted")
    func overduePlanMovesForward() {
        let calendar = Calendar(identifier: .gregorian)
        let now = date(day: 30, hour: 16, calendar: calendar)
        let oldDate = date(day: 27, hour: 12, calendar: calendar)
        let task = TaskItem(title: "Keep this exact plan", dueDate: oldDate, category: .study)

        let result = LippiCalendarIntelligenceEngine.analyze(
            tasks: [task],
            roadmap: nil,
            healthSnapshot: nil,
            healthRecommendation: nil,
            userState: .calm,
            careSuggestion: nil,
            completedThisWeek: 0,
            focusMinutesToday: 0,
            now: now,
            calendar: calendar
        )

        #expect(result.overduePlans == 1)
        #expect(result.suggestions.count == 1)
        #expect(result.suggestions.first?.taskID == task.id)
        #expect(result.suggestions.first?.taskTitle == task.title)
        #expect(result.suggestions.first?.proposedDate ?? .distantPast > now)
    }

    private func date(day: Int, hour: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }
}
