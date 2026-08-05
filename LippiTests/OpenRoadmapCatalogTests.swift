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

        #expect(Set(identifiers) == Set(["roadmap-frontend", "mdn-learn-web"]))
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

    @Test("Uses a career route for portfolio and job goals")
    func selectsCareerProfile() {
        let input = GoalPlannerInput(
            goal: "Подготовить портфолио для новой работы",
            context: "Хочу удалённую продуктовую роль и не хочу вести ежедневные соцсети",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let profile = OpenRoadmapCatalog.profile(for: input)

        #expect(profile.domain == .career)
        #expect(profile.routeLogic.contains("proof-of-skill artifact"))
        #expect(profile.personalizationFocus.contains("conditions they do not want"))
    }

    @Test("Keeps a language goal in the language domain even when work is the motivation")
    func languageGoalOutranksCareerContext() {
        let input = GoalPlannerInput(
            goal: "Выучить немецкий на уровне A1",
            context: "Немецкий нужен для новой работы, начинаю с нуля",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let profile = OpenRoadmapCatalog.profile(for: input)

        #expect(profile.domain == .language)
        #expect(profile.routeLogic.contains("observable reassessment"))
    }

    @Test("Uses a creative route for a distinctive writing project")
    func selectsCreativeProfile() {
        let input = GoalPlannerInput(
            goal: "Написать короткий научно-фантастический рассказ",
            context: "Люблю тихую атмосферу и не хочу копировать структуру популярных сериалов",
            horizon: .fourWeeks,
            intensity: .light
        )

        let profile = OpenRoadmapCatalog.profile(for: input)

        #expect(profile.domain == .creative)
        #expect(profile.routeLogic.contains("complete rough version"))
        #expect(profile.usefulAngles.contains("protects the user's voice"))
    }
}
