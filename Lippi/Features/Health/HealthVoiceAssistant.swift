import Foundation
import AVFoundation

enum HealthVoicePreferences {
    static let isEnabledKey = "health.voice.enabled"
    static let autoSpeakKey = "health.voice.auto"
    static let defaultEnabled = true
    static let defaultAutoSpeak = false
}

enum AppVoicePreferences {
    static let selectionPrefix = "app.voice.selection"
    static let autoIdentifier = "auto"

    static func storageKey(for lang: AppLang) -> String {
        "\(selectionPrefix).\(lang.rawValue)"
    }
}

enum AppVoiceSelector {
    static func storedIdentifier(for lang: AppLang) -> String {
        let raw = UserDefaults.standard.string(forKey: AppVoicePreferences.storageKey(for: lang))
        return raw ?? AppVoicePreferences.autoIdentifier
    }

    static func storeIdentifier(_ identifier: String?, for lang: AppLang) {
        let key = AppVoicePreferences.storageKey(for: lang)
        let value = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty, value != AppVoicePreferences.autoIdentifier {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func availableVoices(for lang: AppLang) -> [AVSpeechSynthesisVoice] {
        let langCode = lang.rawValue.lowercased()
        let preferredCode = lang.speechLanguageCode.lowercased()

        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            let code = voice.language.lowercased()
            return code.hasPrefix(langCode) || code.hasPrefix(preferredCode.prefix(2))
        }

        return voices.sorted { lhs, rhs in
            let l = voiceScore(lhs, preferredCode: preferredCode)
            let r = voiceScore(rhs, preferredCode: preferredCode)
            if l == r {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return l > r
        }
    }

    static func voice(withIdentifier identifier: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(identifier: identifier)
            ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == identifier })
    }

    static func preferredVoice(for lang: AppLang) -> AVSpeechSynthesisVoice? {
        let selected = storedIdentifier(for: lang)
        if selected != AppVoicePreferences.autoIdentifier,
           let voice = voice(withIdentifier: selected) {
            return voice
        }

        return availableVoices(for: lang).first
            ?? AVSpeechSynthesisVoice(language: lang.speechLanguageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        "\(voice.name) (\(voice.language))"
    }

    private static func voiceScore(_ voice: AVSpeechSynthesisVoice, preferredCode: String) -> Int {
        var score = 0
        switch voice.quality {
        case .premium: score += 300
        case .enhanced: score += 200
        case .default: score += 100
        @unknown default: score += 80
        }

        let code = voice.language.lowercased()
        if code == preferredCode {
            score += 45
        } else if code.hasPrefix(preferredCode.prefix(2)) {
            score += 30
        }

        let name = voice.name.lowercased()
        if name.contains("siri") { score += 12 }
        if name.contains("neural") { score += 10 }
        return score
    }
}

enum HealthVoicePlaybackSpeed: String, CaseIterable, Identifiable, Codable {
    case calm
    case balanced
    case energetic

    static let storageKey = "health.voice.speed"
    static let defaultSpeed: HealthVoicePlaybackSpeed = .balanced

    var id: String { rawValue }

    var speechRate: Float {
        switch self {
        case .calm: return 0.44
        case .balanced: return 0.50
        case .energetic: return 0.56
        }
    }

    func title(_ lang: AppLang) -> String {
        L10n.tr("health.voice.speed.\(rawValue)", lang)
    }
}

extension AppLang {
    var speechLanguageCode: String {
        switch self {
        case .ru: return "ru-RU"
        case .en: return "en-US"
        case .de: return "de-DE"
        case .es: return "es-ES"
        }
    }
}

@MainActor
final class HealthVoiceAssistant: NSObject, ObservableObject {
    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        _ text: String,
        language: AppLang,
        speed: HealthVoicePlaybackSpeed
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AppVoiceSelector.preferredVoice(for: language)
        utterance.rate = speed.speechRate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.08
        utterance.prefersAssistiveTechnologySettings = true

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        guard synthesizer.isSpeaking else {
            isSpeaking = false
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension HealthVoiceAssistant: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
