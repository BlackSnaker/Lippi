import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetShared {
    static let suiteID  = "group.illumionix.lippi"
    static let titleKey = "nextTaskTitle"
    static let dueKey   = "nextTaskDue"
    static let pomodoroPhaseKey = "pomodoroPhase"
    static let pomodoroStartKey = "pomodoroStart"
    static let pomodoroEndKey   = "pomodoroEnd"
    static let pomodoroRoundKey = "pomodoroRound"
}

enum WidgetBridge {
    static func writeNextTask(title: String?, due: Date?) {
        guard let defaults = UserDefaults(suiteName: WidgetShared.suiteID) else { return }

        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            defaults.set(t, forKey: WidgetShared.titleKey)
        } else {
            defaults.removeObject(forKey: WidgetShared.titleKey)
        }

        if let due {
            defaults.set(due.timeIntervalSince1970, forKey: WidgetShared.dueKey)
        } else {
            defaults.removeObject(forKey: WidgetShared.dueKey)
        }

        defaults.synchronize()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func clearNextTask() {
        guard let defaults = UserDefaults(suiteName: WidgetShared.suiteID) else { return }
        defaults.removeObject(forKey: WidgetShared.titleKey)
        defaults.removeObject(forKey: WidgetShared.dueKey)
        defaults.synchronize()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func writePomodoro(phase: String, start: Date?, end: Date?, round: Int) {
        guard let defaults = UserDefaults(suiteName: WidgetShared.suiteID) else { return }

        defaults.set(phase, forKey: WidgetShared.pomodoroPhaseKey)
        defaults.set(round, forKey: WidgetShared.pomodoroRoundKey)

        if let start {
            defaults.set(start.timeIntervalSince1970, forKey: WidgetShared.pomodoroStartKey)
        } else {
            defaults.removeObject(forKey: WidgetShared.pomodoroStartKey)
        }

        if let end {
            defaults.set(end.timeIntervalSince1970, forKey: WidgetShared.pomodoroEndKey)
        } else {
            defaults.removeObject(forKey: WidgetShared.pomodoroEndKey)
        }

        defaults.synchronize()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static func clearPomodoro() {
        guard let defaults = UserDefaults(suiteName: WidgetShared.suiteID) else { return }
        defaults.set("stopped", forKey: WidgetShared.pomodoroPhaseKey)
        defaults.set(0, forKey: WidgetShared.pomodoroRoundKey)
        defaults.removeObject(forKey: WidgetShared.pomodoroStartKey)
        defaults.removeObject(forKey: WidgetShared.pomodoroEndKey)
        defaults.synchronize()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
