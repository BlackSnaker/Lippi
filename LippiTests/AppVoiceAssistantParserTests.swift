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

    @Test("Falls back to unknown intent")
    func parsesUnknown() {
        let intent = AppVoiceCommandParser.parse("квантовая бабочка", lang: .ru)
        #expect(intent == .unknown)
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
            "assistant.quick.tasks",
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
            "assistant.response.task_completed",
            "assistant.response.task_deleted",
            "assistant.response.task_not_found",
            "assistant.response.tab_opened",
            "assistant.response.pomodoro_started",
            "assistant.response.pomodoro_paused",
            "assistant.response.pomodoro_resumed",
            "assistant.response.short_break_started",
            "assistant.response.long_break_started",
            "assistant.response.pomodoro_stopped",
            "assistant.response.eye_opened"
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
