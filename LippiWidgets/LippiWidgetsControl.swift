import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct LippiWidgetsControl: ControlWidget {
    static let kind: String = "Illumionix.Lippi.LippiWidgets"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Фокус-таймер",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "Работает" : "Остановлен", systemImage: isRunning ? "bolt.fill" : "pause.fill")
            }
        }
        .displayName("Фокус-контроль")
        .description("Быстрый запуск и пауза фокус-сессии.")
    }
}

extension LippiWidgetsControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            LippiWidgetsControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let defaults = UserDefaults(suiteName: WidgetShared.suiteID)
            let phase = defaults?.string(forKey: WidgetShared.pomodoroPhaseKey) ?? "stopped"
            let isRunning = phase == "focus" || phase == "shortBreak" || phase == "longBreak"
            return LippiWidgetsControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Название таймера"

    @Parameter(title: "Название", default: "Фокус")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Переключить фокус"

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

        if value {
            let start = Date()
            defaults.set("focus", forKey: WidgetShared.pomodoroPhaseKey)
            defaults.set(start.timeIntervalSince1970, forKey: WidgetShared.pomodoroStartKey)
            defaults.set(start.addingTimeInterval(25 * 60).timeIntervalSince1970, forKey: WidgetShared.pomodoroEndKey)
        } else {
            defaults.set("paused", forKey: WidgetShared.pomodoroPhaseKey)
            defaults.removeObject(forKey: WidgetShared.pomodoroEndKey)
        }

        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
