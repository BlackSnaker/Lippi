import Testing
@testable import Lippi

struct GoalRoadmapQualityGateTests {
    @Test("Normalizes a grounded roadmap to the selected horizon")
    func normalizesGroundedRoadmap() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let roadmap = sampleRoadmap()
        let validated = GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .en)

        #expect(validated != nil)
        #expect(validated?.milestones.count == 3)
        #expect(validated?.milestones.first?.timeframe != "custom range")
    }

    @Test("Sanitizes an invented outcome metric")
    func sanitizesInventedOutcomeMetric() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.successCriteria[1] = "Reach 100 downloads in the first month"

        let validated = GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .en)
        #expect(validated != nil)
        #expect(!validated!.successCriteria.joined(separator: " ").localizedCaseInsensitiveContains("100 downloads"))
    }

    @Test("Rejects generic and repeated tasks")
    func rejectsGenericOrRepeatedTasks() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.milestones[0].tasks = ["Work on the project", "Define the first release scope"]
        roadmap.milestones[1].tasks[0] = "Define the first release scope"

        #expect(GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .en) == nil)
    }

    @Test("Rejects roadmap without useful clarifying questions")
    func rejectsMissingClarifyingQuestions() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.clarifyingQuestions = ["What else?"]

        #expect(GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .en) == nil)
    }

    @Test("Rejects roadmap without context-specific insights")
    func rejectsGenericPersonalizedInsights() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.personalizedInsights = ["This is a good route.", "Keep making progress."]

        #expect(GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .en) == nil)
    }

    @Test("Removes invented named examples and unsupported engagement claims")
    func sanitizesGeneratedExamplesAndClaims() throws {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.milestones[0].tasks[0] = "Write a review note after a podcast (for example, 'Made Up Show')."
        roadmap.personalizedInsights?[1] = "This interaction attracts attention and ensures validation."

        let normalized = GoalRoadmapQualityGate.normalizedForDisplay(roadmap, input: input, lang: .en)
        let secondInsight = try #require(normalized.personalizedInsights?[1])

        #expect(!normalized.milestones[0].tasks[0].contains("Made Up Show"))
        #expect(!secondInsight.localizedCaseInsensitiveContains("attracts attention"))
        #expect(secondInsight.localizedCaseInsensitiveContains("decision"))
    }

    @Test("Repairs a weak thermal partial with domain-specific local steps")
    func repairsWeakPartialWithoutDiscardingUsefulModelWork() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS habit tracker MVP",
            context: "Solo Swift developer with 8 hours per week and a $300 budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var partial = sampleRoadmap()
        partial.milestones[0].tasks = ["Work on the project", "Do research"]
        partial.milestones[1].tasks = ["Continue learning", "Improve skills"]
        partial.personalizedInsights = ["Good route", "Keep going"]
        let fallback = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .en)

        let repaired = GoalRoadmapQualityGate.repairedWithLocalFallback(
            partial,
            fallback: fallback,
            input: input,
            lang: .en
        )

        #expect(GoalRoadmapQualityGate.validated(repaired, input: input, lang: .en) != nil)
        #expect(!repaired.milestones.flatMap(\.tasks).contains("Work on the project"))
        #expect(repaired.milestones.allSatisfy { $0.tasks.count == 2 })
        #expect(repaired.personalizedInsights?.count == 2)
    }

    @Test("Rejects abstract milestones that leave the work to the user")
    func rejectsAbstractMilestoneLanguage() {
        let input = GoalPlannerInput(
            goal: "Выучить немецкий на уровне A1",
            context: "Начинаю с нуля",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        var roadmap = sampleRoadmap()
        roadmap.title = input.goal
        roadmap.summary = "Маршрут по немецкому языку на восемь недель."
        roadmap.milestones[0].title = "Уточнение результата"
        roadmap.milestones[0].target = "Сформулировать измеримый результат и убрать лишнее."

        #expect(GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .ru) == nil)
    }

    @Test("Local language fallback starts with a baseline and ends with reassessment")
    func buildsActionableLanguageFallback() throws {
        let input = GoalPlannerInput(
            goal: "Выучить немецкий на уровне A1",
            context: "Немецкий нужен для работы, начинаю с нуля",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let roadmap = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .ru)
        let first = try #require(roadmap.milestones.first)
        let last = try #require(roadmap.milestones.last)

        #expect(first.title.localizedCaseInsensitiveContains("текущая точка"))
        #expect(first.tasks.first?.localizedCaseInsensitiveContains("запись") == true)
        #expect(last.title.localizedCaseInsensitiveContains("повторная проверка"))
        #expect(last.tasks.contains { $0.localizedCaseInsensitiveContains("чтения") })
        #expect(roadmap.firstActions == first.tasks)
        #expect(GoalRoadmapQualityGate.validated(roadmap, input: input, lang: .ru) != nil)
    }

    private func sampleRoadmap() -> GoalRoadmap {
        GoalRoadmap(
            title: "Habit tracker MVP",
            summary: "Build and test a focused first release within the available weekly capacity.",
            source: .bonsai,
            confidence: 0.78,
            successCriteria: [
                "A reviewable MVP build contains the chosen habit loop.",
                "The first release scope and test checklist are documented."
            ],
            firstActions: [
                "Write a one-page first-release scope with excluded features.",
                "Create a SwiftUI project and a habit data model."
            ],
            assumptions: ["The preferred pricing approach still needs confirmation."],
            personalizedInsights: [
                "Because you are a solo Swift developer with eight hours per week, a narrow vertical slice protects both build time and test quality.",
                "Treat the first physical-device test as a scope gate: keep the core habit loop and defer features that do not improve it."
            ],
            clarifyingQuestions: [
                "Which habit loop is most important for the first release?",
                "How many hours per week can you spend on testing the first build?"
            ],
            milestones: [
                GoalMilestone(
                    title: "Define the first release",
                    timeframe: "custom range",
                    target: "A one-page scope and acceptance checklist.",
                    tasks: [
                        "List the one habit flow the MVP must support.",
                        "Write acceptance checks for creating and completing a habit."
                    ],
                    category: .work
                ),
                GoalMilestone(
                    title: "Build the core flow",
                    timeframe: "custom range",
                    target: "A local build that persists and displays habits.",
                    tasks: [
                        "Implement a SwiftData habit record and completion state.",
                        "Build a SwiftUI list and completion interaction."
                    ],
                    category: .work
                ),
                GoalMilestone(
                    title: "Test the release candidate",
                    timeframe: "custom range",
                    target: "A tested build and a short list of next fixes.",
                    tasks: [
                        "Run the acceptance checklist on a physical device.",
                        "Record the highest-impact defects before expanding scope."
                    ],
                    category: .work
                )
            ],
            habits: [GoalHabit(title: "Weekly review", detail: "Review scope and completed work once a week.")],
            risks: [GoalRisk(title: "Scope growth", mitigation: "Move non-core ideas to a later backlog.")]
        )
    }
}
