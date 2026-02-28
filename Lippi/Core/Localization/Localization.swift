import SwiftUI

// Compatibility shim for legacy calls.
typealias AppLanguage = AppLang

enum TKey: String {
    case settings_language

    case tab_today
    case tab_tasks
    case tab_pomodoro
    case tab_break
    case tab_health
    case tab_eye
    case tab_settings
}

final class T {
    static let storageKey = L10n.storageKey

    private static let map: [TKey: L10nKey] = [
        .settings_language: .settings_language_title,
        .tab_today: .tab_today,
        .tab_tasks: .tab_tasks,
        .tab_pomodoro: .tab_pomodoro,
        .tab_break: .tab_break,
        .tab_health: .tab_health,
        .tab_eye: .tab_eye,
        .tab_settings: .tab_settings
    ]

    static func str(_ key: TKey, lang: AppLanguage) -> String {
        guard let l10nKey = map[key] else { return key.rawValue }
        return L10n.tr(l10nKey, lang)
    }
}

@inline(__always)
func tr(_ key: TKey, _ lang: AppLanguage) -> String {
    T.str(key, lang: lang)
}
