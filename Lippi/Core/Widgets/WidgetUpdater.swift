//
//  WidgetUpdater.swift
//  App target (НЕ в виджете)
//

import Foundation
import WidgetKit

enum WidgetUpdater {
    private static let suiteName = WidgetShared.suiteID
    private static let defaults  = UserDefaults(suiteName: suiteName)

    /// Записываем ближайшую задачу (или nil) и просим виджет перерисоваться
    static func update(nextTitle: String?, due: Date?) {
        if let title = nextTitle, !title.isEmpty {
            defaults?.set(title, forKey: WidgetShared.titleKey)
            if let due {
                defaults?.set(due.timeIntervalSince1970, forKey: WidgetShared.dueKey)
            } else {
                defaults?.removeObject(forKey: WidgetShared.dueKey)
            }
        } else {
            defaults?.removeObject(forKey: WidgetShared.titleKey)
            defaults?.removeObject(forKey: WidgetShared.dueKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func updatePomodoro(phase: PomodoroPhase, start: Date?, end: Date?, round: Int) {
        defaults?.set(phase.rawValue, forKey: WidgetShared.pomodoroPhaseKey)
        defaults?.set(round, forKey: WidgetShared.pomodoroRoundKey)

        if let start {
            defaults?.set(start.timeIntervalSince1970, forKey: WidgetShared.pomodoroStartKey)
        } else {
            defaults?.removeObject(forKey: WidgetShared.pomodoroStartKey)
        }

        if let end {
            defaults?.set(end.timeIntervalSince1970, forKey: WidgetShared.pomodoroEndKey)
        } else {
            defaults?.removeObject(forKey: WidgetShared.pomodoroEndKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clearPomodoro() {
        defaults?.set(PomodoroPhase.stopped.rawValue, forKey: WidgetShared.pomodoroPhaseKey)
        defaults?.set(0, forKey: WidgetShared.pomodoroRoundKey)
        defaults?.removeObject(forKey: WidgetShared.pomodoroStartKey)
        defaults?.removeObject(forKey: WidgetShared.pomodoroEndKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Удобный тест: записать демо-значения вручную
    static func seedDemo() {
        update(nextTitle: "Демо задача из App Group",
               due: Date().addingTimeInterval(3600))
    }
}
