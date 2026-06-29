import Foundation
import Testing
@testable import Lippi

struct GoalPlanProgressAuditTests {
    @Test("Detects overdue tasks linked to a roadmap")
    func detectsOverdueLinkedTasks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let roadmap = sampleRoadmap(createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60))

        let tasks = [
            TaskItem(
                title: "Write MVP scope",
                notes: roadmap.title,
                dueDate: now.addingTimeInterval(-24 * 60 * 60),
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60),
                category: .work
            ),
            TaskItem(
                title: "Create SwiftData model",
                notes: roadmap.title,
                dueDate: now.addingTimeInterval(24 * 60 * 60),
                isCompleted: true,
                createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                category: .work
            ),
            TaskItem(
                title: "Unrelated overdue task",
                notes: "Another goal",
                dueDate: now.addingTimeInterval(-24 * 60 * 60),
                isCompleted: false,
                createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60),
                category: .other
            )
        ]

        let audit = GoalPlanProgressAudit.make(roadmap: roadmap, tasks: tasks, now: now)

        #expect(audit?.trackedTasks == 2)
        #expect(audit?.completedTasks == 1)
        #expect(audit?.activeTasks == 1)
        #expect(audit?.overdueTasks == 1)
        #expect(audit?.shouldSuggestAdjustment == true)
        #expect(audit?.overdueExamples == ["Write MVP scope"])
    }

    @Test("Ignores unrelated tasks")
    func ignoresUnrelatedTasks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let roadmap = sampleRoadmap(createdAt: now)
        let tasks = [
            TaskItem(
                title: "Write a grocery list",
                notes: "Home",
                dueDate: now.addingTimeInterval(-24 * 60 * 60),
                isCompleted: false,
                createdAt: now.addingTimeInterval(-24 * 60 * 60),
                category: .home
            )
        ]

        #expect(GoalPlanProgressAudit.make(roadmap: roadmap, tasks: tasks, now: now) == nil)
    }

    @Test("Builds an adaptive draft when progress is stalled")
    func buildsAdaptiveDraft() {
        let audit = GoalPlanProgressAudit(
            trackedTasks: 4,
            completedTasks: 0,
            activeTasks: 4,
            overdueTasks: 2,
            daysSinceRoadmapCreated: 3,
            oldestActiveTaskAgeDays: 3,
            overdueExamples: ["Write MVP scope"],
            nextActiveTask: "Write MVP scope"
        )
        let input = GoalPlannerInput(
            goal: "Launch an iOS MVP",
            context: "Solo developer, evenings only",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let roadmap = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .en, progressAudit: audit)

        #expect(roadmap.summary.localizedCaseInsensitiveContains("Adjusted route"))
        #expect(roadmap.milestones.first?.title == "Gentle plan restart")
        #expect(roadmap.firstActions.first?.localizedCaseInsensitiveContains("48 hours") == true)
        #expect(roadmap.assumptions.contains("Lippi used only facts from created tasks: overdue items, active items, and completed steps."))
    }

    private func sampleRoadmap(createdAt: Date) -> GoalRoadmap {
        GoalRoadmap(
            title: "MVP roadmap",
            summary: "Build a scoped first version.",
            source: .ollama,
            confidence: 0.82,
            createdAt: createdAt,
            successCriteria: [
                "A reviewable MVP scope is ready.",
                "The first build path is documented."
            ],
            firstActions: [
                "Write MVP scope",
                "Create SwiftData model"
            ],
            assumptions: [],
            milestones: [
                GoalMilestone(
                    title: "Scope",
                    timeframe: "Weeks 1-2",
                    target: "One-page MVP scope.",
                    tasks: ["Write MVP scope", "Create SwiftData model"],
                    category: .work
                ),
                GoalMilestone(
                    title: "Build",
                    timeframe: "Weeks 3-5",
                    target: "A local build with core persistence.",
                    tasks: ["Implement task storage", "Review build checklist"],
                    category: .work
                ),
                GoalMilestone(
                    title: "Review",
                    timeframe: "Weeks 6-8",
                    target: "A tested build and release notes.",
                    tasks: ["Run acceptance checks", "Write release notes"],
                    category: .work
                )
            ],
            habits: [GoalHabit(title: "Weekly review", detail: "Review progress weekly.")],
            risks: [GoalRisk(title: "Scope", mitigation: "Keep the first release small.")]
        )
    }
}
