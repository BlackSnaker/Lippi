import SwiftUI

typealias LippiLang = AppLang

// EnvironmentKey (уникальные имена ключа/значения)
private struct LippiLangKey: EnvironmentKey {
    static let defaultValue: LippiLang = .ru
}

extension EnvironmentValues {
    var lippiLang: LippiLang {
        get { self[LippiLangKey.self] }
        set { self[LippiLangKey.self] = newValue }
    }
}
