import Testing
@testable import Lippi

struct GoalRequestBriefTests {
    @Test("Detects Russian request language independently from app language")
    func detectsRussianRequestLanguage() {
        let input = GoalPlannerInput(
            goal: "Выучить английский до A2 за 6 месяцев",
            context: "Могу заниматься 5 часов в неделю, нужен спокойный режим",
            horizon: .twelveWeeks,
            intensity: .balanced
        )

        let brief = GoalRequestBrief.make(input: input, fallbackLang: .en)

        #expect(brief.responseLanguage == .ru)
        #expect(brief.quantitiesAndDates.contains("A2"))
        #expect(brief.constraints.contains { $0.localizedCaseInsensitiveContains("5 часов") })
        #expect(brief.promptSection().contains("response language: Russian"))
    }

    @Test("Keeps English output for English user requests in Russian UI")
    func keepsEnglishForEnglishRequest() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS MVP in 8 weeks",
            context: "Solo developer, evenings only, small budget",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let brief = GoalRequestBrief.make(input: input, fallbackLang: .ru)
        let draft = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .ru)

        #expect(brief.responseLanguage == .en)
        #expect(draft.summary.localizedCaseInsensitiveContains("roadmap"))
        #expect(!draft.summary.localizedCaseInsensitiveContains("маршрут"))
    }

    @Test("Keeps Russian output for Russian fallback drafts")
    func keepsRussianForRussianDraft() {
        let input = GoalPlannerInput(
            goal: "Запустить MVP за 8 недель",
            context: "Есть 6 часов в неделю и небольшой бюджет",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let draft = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .en)

        #expect(draft.summary.localizedCaseInsensitiveContains("Маршрут"))
        #expect(!draft.summary.localizedCaseInsensitiveContains("roadmap"))
    }

    @Test("Builds guiding questions in the request language")
    func buildsGuidingQuestionsInRequestLanguage() {
        let input = GoalPlannerInput(
            goal: "Запустить MVP",
            context: "",
            horizon: .eightWeeks,
            intensity: .balanced
        )
        let brief = GoalRequestBrief.make(input: input, fallbackLang: .en)

        let questions = GoalGuidanceQuestionBuilder.questions(for: input, brief: brief, lang: brief.responseLanguage)

        #expect(questions.count == 3)
        #expect(questions.allSatisfy(containsCyrillic))
        #expect(questions.contains { $0.localizedCaseInsensitiveContains("что уже сделано") })
    }

    @Test("Draft roadmap keeps clarifying questions")
    func draftRoadmapKeepsClarifyingQuestions() {
        let input = GoalPlannerInput(
            goal: "Launch an MVP",
            context: "",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let roadmap = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .ru)

        #expect(roadmap.clarifyingQuestions?.count == 3)
        #expect(roadmap.clarifyingQuestions?.first?.localizedCaseInsensitiveContains("already done") == true)
    }

    @Test("Separates preferences, starting point, and explicit non-goals")
    func extractsPersonalizationSignals() {
        let input = GoalPlannerInput(
            goal: "Подготовить портфолио для новой работы",
            context: "Уже 3 года работаю дизайнером. Мне важно сохранить спокойный темп и показать мобильные проекты. Не хочу вести ежедневные соцсети.",
            horizon: .eightWeeks,
            intensity: .balanced
        )

        let brief = GoalRequestBrief.make(input: input, fallbackLang: .en)
        let section = brief.promptSection()

        #expect(brief.startingPoint.contains { $0.localizedCaseInsensitiveContains("3 года") })
        #expect(brief.preferences.contains { $0.localizedCaseInsensitiveContains("мобильные проекты") })
        #expect(brief.avoidances.contains { $0.localizedCaseInsensitiveContains("соцсети") })
        #expect(section.contains("desired experience and priorities"))
        #expect(section.contains("explicit avoidances and non-goals"))
    }

    @Test("Product fallback stays domain-specific and uses the selected horizon")
    func productFallbackIsDomainSpecific() {
        let input = GoalPlannerInput(
            goal: "Launch an iOS speaking practice app",
            context: "Solo Swift developer with four hours weekly. I want calm practice without streak pressure.",
            horizon: .eightWeeks,
            intensity: .light
        )

        let roadmap = GoalRoadmapEngine().buildDraftRoadmap(input: input, lang: .en)
        let tasks = roadmap.milestones.flatMap(\.tasks).joined(separator: " ")

        #expect(roadmap.milestones.count == 3)
        #expect(roadmap.milestones.allSatisfy { $0.tasks.count == 2 })
        #expect(roadmap.firstActions.count == 2)
        #expect(tasks.localizedCaseInsensitiveContains("prototype"))
        #expect(tasks.localizedCaseInsensitiveContains("acceptance checklist"))
        #expect(roadmap.personalizedInsights?.first?.localizedCaseInsensitiveContains("calm practice") == true)
    }

    private func containsCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(Int(scalar.value))
        }
    }
}
