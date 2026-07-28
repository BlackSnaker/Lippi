import Combine
import Foundation

enum EyeHealthAnalysisSource: String, Codable, Hashable {
    case localAnalysis
    case bonsai
}

enum EyeHealthComfortLevel: String, Codable, Hashable {
    case comfortable
    case gentleRest
    case extendedRest
    case limitedReading
}

struct EyeHealthTrendPoint: Codable, Hashable {
    var fatigueEstimate: Double
    var appearanceEstimate: Double?
    var exerciseCompletion: Double
}

struct EyeHealthAnalysisInput: Hashable {
    var completedTargets: Int
    var missedTargets: Int
    var totalTargets: Int
    var averageTargetTime: Double?
    var detectedBlinks: Int
    var fatigueEstimate: Double
    var appearanceEstimate: Double?
    var lightLevel: Double
    var hasUsableLight: Bool
    var recentSessions: [EyeHealthTrendPoint]
    var lang: AppLang

    var exerciseCompletion: Double {
        guard totalTargets > 0 else { return 0 }
        return min(max(Double(completedTargets) / Double(totalTargets), 0), 1)
    }

    var hasReliableCameraReading: Bool {
        hasUsableLight && appearanceEstimate != nil && totalTargets > 0
    }
}

struct EyeHealthAnalysisReport: Codable, Hashable {
    var generatedAt = Date()
    var source: EyeHealthAnalysisSource
    var level: EyeHealthComfortLevel
    var title: String
    var summary: String
    var observations: [String]
    var action: String
    var restMinutes: Int
    var safetyNote: String
    var confidence: Double
}

enum EyeHealthAnalysisPolicy {
    static func fallback(for input: EyeHealthAnalysisInput) -> EyeHealthAnalysisReport {
        guard input.hasReliableCameraReading else {
            return EyeHealthAnalysisReport(
                source: .localAnalysis,
                level: .limitedReading,
                title: L10n.tr("eye.analysis.limited.title", input.lang),
                summary: L10n.tr("eye.analysis.limited.summary", input.lang),
                observations: [
                    L10n.tr("eye.analysis.observation.light", input.lang),
                    exerciseObservation(for: input)
                ],
                action: L10n.tr("eye.analysis.action.retry", input.lang),
                restMinutes: 5,
                safetyNote: L10n.tr("eye.analysis.safety", input.lang),
                confidence: 0.32
            )
        }

        let appearance = input.appearanceEstimate ?? 0
        let combined = max(input.fatigueEstimate, appearance)
        let level: EyeHealthComfortLevel
        let restMinutes: Int
        if combined >= 0.68 {
            level = .extendedRest
            restMinutes = 20
        } else if combined >= 0.34 {
            level = .gentleRest
            restMinutes = 10
        } else {
            level = .comfortable
            restMinutes = 5
        }

        var observations = [signalObservation(level: level, lang: input.lang)]
        observations.append(trendObservation(for: input))
        if input.exerciseCompletion < 0.7 {
            observations[1] = exerciseObservation(for: input)
        }

        return EyeHealthAnalysisReport(
            source: .localAnalysis,
            level: level,
            title: L10n.tr("eye.analysis.\(level.rawValue).title", input.lang),
            summary: L10n.tr("eye.analysis.\(level.rawValue).summary", input.lang),
            observations: observations,
            action: L10n.fmt("eye.analysis.\(level.rawValue).action", input.lang, restMinutes),
            restMinutes: restMinutes,
            safetyNote: L10n.tr("eye.analysis.safety", input.lang),
            confidence: localConfidence(for: input)
        )
    }

    static func validated(
        _ payload: BonsaiEyeHealthPayload,
        fallback: EyeHealthAnalysisReport
    ) -> EyeHealthAnalysisReport {
        guard fallback.level != .limitedReading else { return fallback }
        return EyeHealthAnalysisReport(
            source: .bonsai,
            level: fallback.level,
            title: safeNarrative(payload.title, limit: 60) ?? fallback.title,
            summary: safeNarrative(payload.summary, limit: 190) ?? fallback.summary,
            observations: fallback.observations,
            action: fallback.action,
            restMinutes: min(max(payload.restMinutes ?? fallback.restMinutes, fallback.restMinutes), 30),
            safetyNote: fallback.safetyNote,
            confidence: min(max(payload.confidence ?? fallback.confidence, 0), fallback.confidence)
        )
    }

    private static func signalObservation(level: EyeHealthComfortLevel, lang: AppLang) -> String {
        L10n.tr("eye.analysis.observation.\(level.rawValue)", lang)
    }

    private static func trendObservation(for input: EyeHealthAnalysisInput) -> String {
        let recent = input.recentSessions.suffix(4)
        guard recent.count >= 2 else {
            return L10n.tr("eye.analysis.observation.no_trend", input.lang)
        }
        let baseline = recent.map { max($0.fatigueEstimate, $0.appearanceEstimate ?? 0) }.reduce(0, +)
            / Double(recent.count)
        let current = max(input.fatigueEstimate, input.appearanceEstimate ?? 0)
        if current >= baseline + 0.18 {
            return L10n.tr("eye.analysis.observation.above_recent", input.lang)
        }
        return L10n.tr("eye.analysis.observation.steady", input.lang)
    }

    private static func exerciseObservation(for input: EyeHealthAnalysisInput) -> String {
        if input.exerciseCompletion >= 0.7 {
            return L10n.tr("eye.analysis.observation.exercise_clear", input.lang)
        }
        return L10n.tr("eye.analysis.observation.exercise_retry", input.lang)
    }

    private static func localConfidence(for input: EyeHealthAnalysisInput) -> Double {
        var confidence = 0.55
        if input.hasUsableLight { confidence += 0.12 }
        if input.appearanceEstimate != nil { confidence += 0.10 }
        if input.exerciseCompletion >= 0.7 { confidence += 0.08 }
        if input.recentSessions.count >= 2 { confidence += 0.07 }
        return min(confidence, 0.88)
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(limit))
    }

    private static func safeNarrative(_ value: String?, limit: Int) -> String? {
        guard let cleaned = clean(value, limit: limit) else { return nil }
        let normalized = cleaned.lowercased()
        let medicalClaimMarkers = [
            "diagnos", "disease", "infection", "conjunct", "glaucoma", "cataract",
            "диагноз", "болезн", "инфекц", "конъюнктив", "глауком", "катаракт",
            "erkrank", "infektion", "enfermedad", "infección", "conjuntivitis"
        ]
        guard !medicalClaimMarkers.contains(where: { normalized.contains($0) }) else { return nil }
        return cleaned
    }
}

struct BonsaiEyeHealthPayload: Decodable, Hashable {
    var title: String?
    var summary: String?
    var action: String?
    var restMinutes: Int?
    var confidence: Double?
}

enum EyeHealthBonsaiPrompt {
    static func make(input: EyeHealthAnalysisInput, safety: EyeHealthAnalysisReport) -> String {
        let trend = input.recentSessions.suffix(4)
            .map { "fatigue=\(band($0.fatigueEstimate)), appearance=\(band($0.appearanceEstimate)), completion=\(percentage($0.exerciseCompletion))" }
            .joined(separator: "; ")

        return """
        Output language: \(input.lang.rawValue)
        Exercise completion: \(input.completedTargets)/\(input.totalTargets); missed: \(input.missedTargets)
        Average target time: \(input.averageTargetTime.map { String(format: "%.1f", $0) } ?? "unknown") seconds
        Guided blinks completed: \(input.detectedBlinks)
        Relative eyelid fatigue signal: \(band(input.fatigueEstimate))
        Camera appearance signal around the eyes: \(band(input.appearanceEstimate))
        Lighting quality: \(input.hasUsableLight ? "usable" : "limited")
        Recent aggregate sessions: \(trend.isEmpty ? "none" : trend)

        Authoritative local result: \(safety.level.rawValue), at least \(safety.restMinutes) minutes away from the screen.
        Explain only these aggregate observations. Do not diagnose, name a disease, infer a cause, or claim that redness or fatigue is medically confirmed.
        Exercise speed and missed targets describe interaction quality, not eye health. Images and video are not available to you.
        The rest recommendation may become longer, never shorter. Keep the safety note implicit; the app displays it separately.
        """
    }

    private static func band(_ value: Double?) -> String {
        guard let value else { return "unknown" }
        if value < 0.34 { return "low" }
        if value < 0.68 { return "moderate" }
        return "high"
    }

    private static func percentage(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }
}

enum BonsaiEyeHealthCoachState: Equatable {
    case idle
    case analyzing
    case ready
    case localFallback(String)
}

@MainActor
final class BonsaiEyeHealthCoach: ObservableObject {
    @Published private(set) var report: EyeHealthAnalysisReport?
    @Published private(set) var state: BonsaiEyeHealthCoachState = .idle

    private let provider: BonsaiGoalProvider

    init(provider: BonsaiGoalProvider = BonsaiGoalProvider()) {
        self.provider = provider
    }

    func analyze(_ input: EyeHealthAnalysisInput) async -> EyeHealthAnalysisReport {
        let fallback = EyeHealthAnalysisPolicy.fallback(for: input)
        report = fallback

        guard input.hasReliableCameraReading,
              BonsaiConfiguration.stored.isEnabled,
              BonsaiModelStorage.isInstalled else {
            state = .ready
            return fallback
        }

        state = .analyzing
        do {
            let raw = try await provider.generateEyeHealthAnalysis(
                prompt: EyeHealthBonsaiPrompt.make(input: input, safety: fallback),
                configuration: .stored
            )
            try Task.checkCancellation()
            guard let json = GoalJSONRecovery.rootObject(in: raw),
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(BonsaiEyeHealthPayload.self, from: data) else {
                throw BonsaiProviderError.malformedResponse
            }
            let result = EyeHealthAnalysisPolicy.validated(payload, fallback: fallback)
            report = result
            state = .ready
            return result
        } catch is CancellationError {
            report = fallback
            state = .ready
            return fallback
        } catch let error as BonsaiProviderError {
            report = fallback
            state = .localFallback(error.message(lang: input.lang))
            return fallback
        } catch {
            report = fallback
            state = .localFallback(BonsaiProviderError.generationFailed.message(lang: input.lang))
            return fallback
        }
    }
}
