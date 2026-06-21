import Testing
@testable import Lippi

struct OpenRoadmapCatalogTests {
    @Test("Selects only web-development references for a frontend goal")
    func selectsFrontendReferences() {
        let input = GoalPlannerInput(
            goal: "Освоить frontend и React за 12 недель",
            context: "Есть 6 часов в неделю на HTML, CSS и JavaScript",
            horizon: .twelveWeeks,
            intensity: .balanced
        )

        let identifiers = OpenRoadmapCatalog.candidates(for: input).map(\.id)

        #expect(identifiers == ["roadmap-frontend", "mdn-learn-web"])
    }

    @Test("Selects health references for a gradual weight goal")
    func selectsHealthReferences() {
        let input = GoalPlannerInput(
            goal: "Похудеть на 4 килограмма за 3 месяца",
            context: "Нужен спокойный режим без перегруза",
            horizon: .twelveWeeks,
            intensity: .light
        )

        let identifiers = OpenRoadmapCatalog.candidates(for: input).map(\.id)

        #expect(identifiers.contains("cdc-healthy-weight"))
        #expect(identifiers.contains("who-physical-activity"))
    }

    @Test("Leaves unrelated goals without a pretend external roadmap")
    func leavesUnmatchedGoalWithoutSources() {
        let input = GoalPlannerInput(
            goal: "Навести порядок в заметках",
            context: "Хочу убрать дубли и быстро находить важное",
            horizon: .fourWeeks,
            intensity: .balanced
        )

        #expect(OpenRoadmapCatalog.candidates(for: input).isEmpty)
    }
}
