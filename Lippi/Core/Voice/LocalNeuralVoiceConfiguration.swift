import Foundation

enum LocalNeuralVoiceProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case f2
    case m3

    static let storageKey = "neural.voice.local.profile"
    static let defaultProfile: LocalNeuralVoiceProfile = .f2

    var id: String { rawValue }

    /// Supertonic stores F1...F5, then M1...M5 in voice.bin.
    var speakerID: Int {
        switch self {
        case .f2: return 1
        case .m3: return 7
        }
    }

    func title(_ lang: AppLang) -> String {
        L10n.tr("settings.neural_voice.profile.\(rawValue)", lang)
    }
}

struct NeuralVoiceConfiguration: Equatable, Sendable {
    static let enabledKey = "neural.voice.provider.enabled"
    private static let localOnlyMigrationKey = "neural.voice.localOnlyMigration.v1"
    private static let legacyEndpointKey = "neural.voice.provider.endpoint"
    private static let legacySelectionPrefix = "app.voice.selection"

    var isEnabled: Bool
    var profile: LocalNeuralVoiceProfile

    static var stored: NeuralVoiceConfiguration {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: localOnlyMigrationKey) {
            defaults.removeObject(forKey: legacyEndpointKey)
            for language in AppLang.allCases {
                defaults.removeObject(
                    forKey: "\(legacySelectionPrefix).\(language.rawValue)"
                )
            }
            defaults.set(true, forKey: localOnlyMigrationKey)
        }
        let enabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        let rawProfile = defaults.string(forKey: LocalNeuralVoiceProfile.storageKey)
        return NeuralVoiceConfiguration(
            isEnabled: enabled,
            profile: rawProfile.flatMap(LocalNeuralVoiceProfile.init(rawValue:))
                ?? .defaultProfile
        )
    }

    var isConfigured: Bool {
        isEnabled && LocalVoiceModelStorage.isVerified
    }

    func supports(_ language: AppLang) -> Bool {
        switch language {
        case .ru, .en, .de, .es:
            return true
        }
    }
}

enum NeuralVoiceProviderError: Error, Equatable {
    case disabled
    case modelUnavailable
    case lowPowerMode
    case cooldown
    case initialization
    case generation
    case cancelled

    var localizationKey: String {
        switch self {
        case .disabled: return "voice.neural.error.disabled"
        case .modelUnavailable: return "voice.neural.error.model_unavailable"
        case .lowPowerMode: return "voice.neural.error.low_power"
        case .cooldown: return "voice.neural.error.cooldown"
        case .initialization: return "voice.neural.error.initialization"
        case .generation: return "voice.neural.error.generation"
        case .cancelled: return "voice.neural.error.cancelled"
        }
    }

    func message(lang: AppLang) -> String {
        L10n.tr(localizationKey, lang)
    }
}

extension HealthVoicePlaybackSpeed {
    var neuralSpeed: Float {
        switch self {
        case .calm: return 0.92
        case .balanced: return 1.0
        case .energetic: return 1.08
        }
    }
}
