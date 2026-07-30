import Foundation
import Testing
@testable import Lippi

struct AppVoiceAssistantParserTests {

    @Test("Parses Russian add task command and infers category")
    func parsesAddTaskRU() {
        let intent = AppVoiceCommandParser.parse("Добавь задачу сделать проект", lang: .ru)

        switch intent {
        case .addTask(let title, let category):
            #expect(title == "сделать проект")
            #expect(category == .work)
        default:
            Issue.record("Expected addTask intent")
        }
    }

    @Test("Parses open tab command")
    func parsesOpenTab() {
        let intent = AppVoiceCommandParser.parse("Открой настройки", lang: .ru)

        switch intent {
        case .openTab(let tab):
            #expect(tab == .settings)
        default:
            Issue.record("Expected openTab intent")
        }
    }

    @Test("Parses pomodoro start with minutes")
    func parsesStartPomodoro() {
        let intent = AppVoiceCommandParser.parse("Запусти помодоро 40 минут", lang: .ru)

        switch intent {
        case .startPomodoro(let minutes):
            #expect(minutes == 40)
        default:
            Issue.record("Expected startPomodoro intent")
        }
    }

    @Test("Parses pomodoro stop command")
    func parsesStopPomodoro() {
        let intent = AppVoiceCommandParser.parse("Stop pomodoro", lang: .en)
        #expect(intent == .stopPomodoro)
    }

    @Test("Parses pomodoro pause command")
    func parsesPausePomodoro() {
        let intent = AppVoiceCommandParser.parse("Поставь помодоро на паузу", lang: .ru)
        #expect(intent == .pausePomodoro)
    }

    @Test("Parses pomodoro resume command")
    func parsesResumePomodoro() {
        let intent = AppVoiceCommandParser.parse("Resume pomodoro", lang: .en)
        #expect(intent == .resumePomodoro)
    }

    @Test("Parses short break command")
    func parsesShortBreak() {
        let intent = AppVoiceCommandParser.parse("Запусти короткий перерыв", lang: .ru)
        #expect(intent == .startShortBreak)
    }

    @Test("Parses complete task command")
    func parsesCompleteTask() {
        let intent = AppVoiceCommandParser.parse("Выполни задачу написать отчет", lang: .ru)
        switch intent {
        case .completeTask(let title):
            #expect(title == "написать отчет")
        default:
            Issue.record("Expected completeTask intent")
        }
    }

    @Test("Parses delete task command")
    func parsesDeleteTask() {
        let intent = AppVoiceCommandParser.parse("Delete task call mom", lang: .en)
        switch intent {
        case .deleteTask(let title):
            #expect(title == "call mom")
        default:
            Issue.record("Expected deleteTask intent")
        }
    }

    @Test("Understands a polite task request with flexible word order")
    func parsesFlexibleTaskRequest() {
        let intent = AppVoiceCommandParser.parse(
            "Добавь, пожалуйста, в задачи позвонить врачу",
            lang: .ru
        )

        switch intent {
        case .addTask(let title, let category):
            #expect(title == "позвонить врачу")
            #expect(category == .other)
        default:
            Issue.record("Expected addTask intent")
        }
    }

    @Test("Does not confuse a task about a goal with Smart Goal creation")
    func keepsGoalRelatedTaskAsTask() {
        let intent = AppVoiceCommandParser.parse(
            "Создай задачу сформулировать цель проекта",
            lang: .ru
        )

        switch intent {
        case .addTask(let title, _):
            #expect(title == "сформулировать цель проекта")
        default:
            Issue.record("Expected addTask intent")
        }
    }

    @Test("Uses task context for an elliptical follow-up")
    func parsesContextualTaskFollowUp() {
        let intent = AppVoiceCommandParser.parse(
            "И ещё купить молоко",
            lang: .ru,
            context: .openTab(.tasks)
        )

        switch intent {
        case .addTask(let title, let category):
            #expect(title == "купить молоко")
            #expect(category == .home)
        default:
            Issue.record("Expected contextual addTask intent")
        }
    }

    @Test("Creates a Smart Goal from a natural roadmap request")
    func parsesSmartGoalRoadmapRequest() {
        let intent = AppVoiceCommandParser.parse(
            "Составь дорожную карту для изучения испанского за полгода",
            lang: .ru
        )

        switch intent {
        case .createSmartGoal(let description):
            #expect(description == "изучения испанского за полгода")
        default:
            Issue.record("Expected createSmartGoal intent")
        }
    }

    @Test("Understands an idea transformed into a Smart Goal")
    func parsesSmartGoalTransformation() {
        let intent = AppVoiceCommandParser.parse(
            "Хочу превратить запуск приложения в умную цель",
            lang: .ru
        )

        switch intent {
        case .createSmartGoal(let description):
            #expect(description == "запуск приложения")
        default:
            Issue.record("Expected createSmartGoal intent")
        }
    }

    @Test("Opens Smart Goals using roadmap terminology")
    func parsesOpenSmartGoals() {
        let intent = AppVoiceCommandParser.parse(
            "Покажи мою дорожную карту",
            lang: .ru
        )
        #expect(intent == .openSmartGoals)
    }

    @Test("Fuzzy local interpretation tolerates a speech recognition typo")
    func parsesFuzzySmartGoalsRequest() {
        let intent = AppVoiceCommandParser.parse(
            "Открой умную цэль",
            lang: .ru
        )
        #expect(intent == .openSmartGoals)
    }

    @Test("Recognizes a Smart Goal progress question")
    func parsesSmartGoalProgress() {
        let intent = AppVoiceCommandParser.parse(
            "Как продвигается моя цель?",
            lang: .ru
        )
        #expect(intent == .showSmartGoalProgress)
    }

    @Test("Uses Smart Goal context for a short progress follow-up")
    func parsesContextualSmartGoalProgress() {
        let intent = AppVoiceCommandParser.parse(
            "А что там с прогрессом?",
            lang: .ru,
            context: .openSmartGoals
        )
        #expect(intent == .showSmartGoalProgress)
    }

    @Test("Uses Smart Goal context for a natural goal description")
    func parsesContextualSmartGoalDescription() {
        let intent = AppVoiceCommandParser.parse(
            "Хочу выучить японский за год",
            lang: .ru,
            context: .openSmartGoals
        )

        switch intent {
        case .createSmartGoal(let description):
            #expect(description == "японский за год")
        default:
            Issue.record("Expected contextual createSmartGoal intent")
        }
    }

    @Test("Understands an English achievement request as a Smart Goal")
    func parsesEnglishSmartGoalRequest() {
        let intent = AppVoiceCommandParser.parse(
            "Help me achieve a half marathon in six months",
            lang: .en
        )

        switch intent {
        case .createSmartGoal(let description):
            #expect(description == "a half marathon in six months")
        default:
            Issue.record("Expected createSmartGoal intent")
        }
    }

    @Test("Keeps an unsupported topic and asks for the desired action")
    func preservesUnknownTopicForClarification() {
        let intent = AppVoiceCommandParser.parse("квантовая бабочка", lang: .ru)
        #expect(intent == .clarifyAction(topic: "квантовая бабочка"))
    }

    @Test("Schedules a task from natural relative date and time")
    func parsesScheduledTask() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 10))!

        let intent = AppVoiceCommandParser.parse(
            "Добавь задачу позвонить врачу завтра в 15:30",
            lang: .ru,
            now: now,
            calendar: calendar
        )

        switch intent {
        case .addScheduledTask(let title, let category, let dueDate):
            #expect(title == "позвонить врачу")
            #expect(category == .other)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            #expect(components == DateComponents(year: 2026, month: 7, day: 31, hour: 15, minute: 30))
        default:
            Issue.record("Expected addScheduledTask intent")
        }
    }

    @Test("Resolves a task pronoun from conversation context")
    func resolvesTaskPronoun() {
        let intent = AppVoiceCommandParser.parse(
            "Отметь её выполненной",
            lang: .ru,
            context: .addTask(title: "позвонить врачу", category: .other)
        )
        #expect(intent == .completeTask(title: "позвонить врачу"))
    }

    @Test("Reschedules the referenced task with a natural date")
    func reschedulesReferencedTask() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 10))!

        let intent = AppVoiceCommandParser.parse(
            "Перенеси её на послезавтра утром",
            lang: .ru,
            context: .addTask(title: "встреча с командой", category: .work),
            now: now,
            calendar: calendar
        )

        switch intent {
        case .rescheduleTask(let title, let dueDate):
            #expect(title == "встреча с командой")
            let components = calendar.dateComponents([.day, .hour, .minute], from: dueDate)
            #expect(components == DateComponents(day: 1, hour: 9, minute: 0))
        default:
            Issue.record("Expected rescheduleTask intent")
        }
    }

    @Test("Understands several actions in one request")
    func parsesCompoundRequest() {
        let intents = AppVoiceCommandParser.parseAll(
            "Добавь задачу купить воду, а потом запусти помодоро на 30 минут",
            lang: .ru
        )

        #expect(intents.count == 2)
        if case .addTask(let title, _) = intents[0] {
            #expect(title == "купить воду")
        } else {
            Issue.record("Expected addTask as the first command")
        }
        #expect(intents[1] == .startPomodoro(minutes: 30))
    }

    @Test("Opens the new calendar from a natural plan question")
    func opensCalendarFromPlanQuestion() {
        let intent = AppVoiceCommandParser.parse("Покажи, что у меня сегодня по плану", lang: .ru)
        #expect(intent == .openCalendar)
    }

    @Test("Logs care actions without confusing them with reminders")
    func logsWater() {
        let intent = AppVoiceCommandParser.parse("Отметь, что я выпил воды", lang: .ru)
        #expect(intent == .logCareAction(.logWater))
    }

    @Test("A water reminder remains a task")
    func waterReminderIsTask() {
        let intent = AppVoiceCommandParser.parse("Запиши задачу купить воду", lang: .ru)

        if case .addTask(let title, _) = intent {
            #expect(title == "купить воду")
        } else {
            Issue.record("Expected addTask intent")
        }
    }

    @Test("Reschedules a naturally named task without requiring the word task")
    func reschedulesNamedTaskNaturally() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30, hour: 10))!

        let intent = AppVoiceCommandParser.parse(
            "Перенеси встречу с командой на завтра",
            lang: .ru,
            now: now,
            calendar: calendar
        )

        switch intent {
        case .rescheduleTask(let title, let dueDate):
            #expect(title == "встречу с командой")
            let components = calendar.dateComponents([.day, .hour, .minute], from: dueDate)
            #expect(components == DateComponents(day: 31, hour: 18, minute: 0))
        default:
            Issue.record("Expected rescheduleTask intent")
        }
    }

    @Test("A clarification can become a task on the next turn")
    func resolvesClarificationFollowUp() {
        let intent = AppVoiceCommandParser.parse(
            "Оформи как задачу",
            lang: .ru,
            context: .clarifyAction(topic: "подготовить идеи для презентации")
        )
        #expect(intent == .addTask(title: "подготовить идеи для презентации", category: .work))
    }

    @Test("Assistant localization keys resolve for all languages")
    func assistantLocalizationKeysResolve() {
        let keys = [
            "assistant.title",
            "assistant.subtitle",
            "assistant.description",
            "assistant.state.ready",
            "assistant.state.listening",
            "assistant.state.processing",
            "assistant.state.speaking",
            "assistant.state.error",
            "assistant.transcript.title",
            "assistant.transcript.empty",
            "assistant.response.title",
            "assistant.response.unknown",
            "assistant.quick.title",
            "assistant.quick.add",
            "assistant.quick.smart_goal",
            "assistant.quick.goal_progress",
            "assistant.quick.tasks",
            "assistant.quick.calendar",
            "assistant.quick.care",
            "assistant.quick.pomodoro",
            "assistant.quick.pause",
            "assistant.quick.resume",
            "assistant.quick.break",
            "assistant.quick.eye",
            "assistant.hint.tap_hold",
            "assistant.button.start",
            "assistant.button.stop",
            "assistant.button.close",
            "assistant.permission.speech",
            "assistant.permission.mic",
            "assistant.permission.unavailable",
            "assistant.response.task_added",
            "assistant.response.task_scheduled",
            "assistant.response.task_completed",
            "assistant.response.task_reopened",
            "assistant.response.task_deleted",
            "assistant.response.task_rescheduled",
            "assistant.response.task_not_found",
            "assistant.response.tab_opened",
            "assistant.response.calendar_opened",
            "assistant.response.pomodoro_started",
            "assistant.response.pomodoro_paused",
            "assistant.response.pomodoro_resumed",
            "assistant.response.short_break_started",
            "assistant.response.long_break_started",
            "assistant.response.pomodoro_stopped",
            "assistant.response.eye_opened",
            "assistant.response.smart_goals_opened",
            "assistant.response.smart_goal_ready",
            "assistant.response.smart_goal_prepared",
            "assistant.response.goal_progress_opened",
            "assistant.response.goal_progress_missing",
            "assistant.response.care_balanced",
            "assistant.response.water_logged",
            "assistant.response.meal_logged",
            "assistant.response.movement_logged",
            "assistant.response.capabilities",
            "assistant.response.clarify_action"
        ]

        for lang in AppLang.allCases {
            for key in keys {
                let value = L10n.tr(key, lang).trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(!value.isEmpty)
                #expect(value != key)
            }
        }
    }
}
