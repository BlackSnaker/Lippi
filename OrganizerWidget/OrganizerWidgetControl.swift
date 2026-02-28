import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct OrganizerWidgetControl: ControlWidget {
    static let kind: String = "Illumionix.Lippi.OrganizerWidget"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Режим фокуса",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "Активен" : "Неактивен", systemImage: isRunning ? "checkmark.circle.fill" : "circle")
            }
        }
        .displayName("Фокус-переключатель")
        .description("Быстрое переключение режима фокусировки для задач.")
    }
}

extension OrganizerWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            OrganizerWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let defaults = UserDefaults(suiteName: WidgetShared.suiteID)
            let phase = defaults?.string(forKey: WidgetShared.pomodoroPhaseKey) ?? "stopped"
            let isRunning = phase == "focus" || phase == "shortBreak" || phase == "longBreak"
            return OrganizerWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Название режима"

    @Parameter(title: "Название", default: "Фокус")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Переключить режим"

    @Parameter(title: "Название")
    var name: String

    @Parameter(title: "Состояние")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: WidgetShared.suiteID) else { return .result() }

        defaults.set(value ? "focus" : "paused", forKey: WidgetShared.pomodoroPhaseKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
