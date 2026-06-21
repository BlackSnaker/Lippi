import Testing
@testable import Lippi

struct RussianGoalTranslatorTests {
    @Test("Translates language goal with level, timeframe, and weekly time")
    func translatesLanguageGoal() {
        let translation = RussianGoalTranslator.translate(
            goal: "Выучить английский до уровня A1 за 6 месяцев",
            context: "Могу заниматься 5 часов в неделю после работы"
        )

        #expect(translation.goal == "Learn English and reach A1 level in 6 months.")
        #expect(translation.context.contains("Available time: 5 hours per week."))
        #expect(!translation.goal.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) })
        #expect(!translation.context.unicodeScalars.contains { (0x0400...0x04FF).contains(Int($0.value)) })
    }

    @Test("Translates weight goal without losing the target")
    func translatesWeightGoal() {
        let translation = RussianGoalTranslator.translate(
            goal: "Похудеть на 4 килограмма за 3 месяца",
            context: "Нужен спокойный режим без перегруза"
        )

        #expect(translation.goal == "Lose weight by 4 kg in 3 months.")
        #expect(translation.context.contains("Target timeframe: 3 months."))
        #expect(translation.context.contains("Safety: keep health-related steps gradual"))
    }

    @Test("Translates launch goal from the simulator case")
    func translatesTourLaunchGoal() {
        let translation = RussianGoalTranslator.translate(
            goal: "Запустить тур за 4 месяца",
            context: "Есть работа и ограниченный бюджет"
        )

        #expect(translation.goal == "Launch a travel tour in 4 months.")
        #expect(translation.context.contains("fit around work commitments"))
        #expect(translation.context.contains("budget-aware"))
    }
}
