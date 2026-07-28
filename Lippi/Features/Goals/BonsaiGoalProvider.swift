import Foundation

enum BonsaiProviderError: Error, Equatable {
    case disabled
    case modelMissing
    case runtimeUnavailable
    case modelLoadFailed
    case lowPowerMode
    case thermalLimitReached
    case timeLimitReached
    case promptTooLong
    case generationFailed
    case malformedResponse
    case incompleteRoadmap

    func message(lang: AppLang) -> String {
        let key: String
        switch self {
        case .disabled: key = "bonsai.error.disabled"
        case .modelMissing: key = "bonsai.error.model_missing"
        case .runtimeUnavailable: key = "bonsai.error.runtime"
        case .modelLoadFailed: key = "bonsai.error.load"
        case .lowPowerMode: key = "bonsai.error.low_power"
        case .thermalLimitReached: key = "bonsai.error.thermal"
        case .timeLimitReached: key = "bonsai.error.time_limit"
        case .promptTooLong: key = "bonsai.error.context"
        case .generationFailed: key = "bonsai.error.generation"
        case .malformedResponse: key = "bonsai.error.malformed"
        case .incompleteRoadmap: key = "bonsai.error.incomplete_plan"
        }
        return L10n.tr(key, lang)
    }
}

struct BonsaiGoalProvider {
    private let engine: BonsaiInferenceEngine

    init(engine: BonsaiInferenceEngine = .shared) {
        self.engine = engine
    }

    func ensureReady(configuration: BonsaiConfiguration) throws {
        guard configuration.isEnabled else { throw BonsaiProviderError.disabled }
        guard BonsaiModelStorage.isInstalled else { throw BonsaiProviderError.modelMissing }
        #if !canImport(llama)
        throw BonsaiProviderError.runtimeUnavailable
        #endif
    }

    func prepare(configuration: BonsaiConfiguration) async throws {
        try ensureReady(configuration: configuration)
        do {
            try await engine.prepare()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BonsaiRuntimeError {
            throw providerError(for: error)
        } catch {
            throw BonsaiProviderError.generationFailed
        }
    }

    func generate(
        prompt: String,
        configuration: BonsaiConfiguration,
        maximumOutputTokens: Int32 = 640
    ) async throws -> String {
        try ensureReady(configuration: configuration)
        let request = """
        \(prompt)

        Required JSON contract:
        \(BonsaiResponseContract.roadmap)
        Return one JSON object only. Do not wrap it in Markdown.
        """
        return try await run(
            systemPrompt: BonsaiSystemPrompt.roadmap,
            userPrompt: request,
            maximumOutputTokens: maximumOutputTokens,
            maximumDuration: BonsaiGenerationSafetyPolicy.roadmapMaximumDuration
        )
    }

    func generateProgressSummary(prompt: String, configuration: BonsaiConfiguration) async throws -> String {
        try ensureReady(configuration: configuration)
        let request = """
        \(prompt)

        Required JSON contract:
        \(BonsaiResponseContract.progressSummary)
        Return one JSON object only. Do not wrap it in Markdown.
        """
        return try await run(
            systemPrompt: BonsaiSystemPrompt.progressSummary,
            userPrompt: request,
            maximumOutputTokens: 480,
            maximumDuration: BonsaiGenerationSafetyPolicy.progressMaximumDuration
        )
    }

    func generatePersonalRecommendation(prompt: String, configuration: BonsaiConfiguration) async throws -> String {
        try ensureReady(configuration: configuration)
        let request = """
        \(prompt)

        Required JSON contract:
        \(BonsaiResponseContract.personalRecommendation)
        Return one JSON object only. Do not wrap it in Markdown.
        """
        return try await run(
            systemPrompt: BonsaiSystemPrompt.personalRecommendation,
            userPrompt: request,
            maximumOutputTokens: 240,
            maximumDuration: BonsaiGenerationSafetyPolicy.personalRecommendationMaximumDuration
        )
    }

    func generateEyeHealthAnalysis(prompt: String, configuration: BonsaiConfiguration) async throws -> String {
        try ensureReady(configuration: configuration)
        let request = """
        \(prompt)

        Required JSON contract:
        \(BonsaiResponseContract.eyeHealthAnalysis)
        Return one JSON object only. Do not wrap it in Markdown.
        """
        return try await run(
            systemPrompt: BonsaiSystemPrompt.eyeHealthAnalysis,
            userPrompt: request,
            maximumOutputTokens: 210,
            maximumDuration: BonsaiGenerationSafetyPolicy.eyeHealthMaximumDuration
        )
    }

    func check(configuration: BonsaiConfiguration) async throws {
        try ensureReady(configuration: configuration)
        let response = try await run(
            systemPrompt: "You are a local readiness check. Return JSON only.",
            userPrompt: "Return exactly {\"ready\":true} and nothing else.",
            maximumOutputTokens: 32,
            maximumDuration: 15
        )
        guard response.contains("\"ready\":true") || response.contains("\"ready\": true") else {
            throw BonsaiProviderError.malformedResponse
        }
    }

    private func run(
        systemPrompt: String,
        userPrompt: String,
        maximumOutputTokens: Int32,
        maximumDuration: TimeInterval
    ) async throws -> String {
        do {
            return try await engine.generate(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                options: BonsaiGenerationOptions(
                    maximumOutputTokens: maximumOutputTokens,
                    maximumDuration: maximumDuration
                )
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BonsaiRuntimeError {
            throw providerError(for: error)
        } catch {
            throw BonsaiProviderError.generationFailed
        }
    }

    private func providerError(for error: BonsaiRuntimeError) -> BonsaiProviderError {
        switch error {
        case .runtimeUnavailable:
            return .runtimeUnavailable
        case .modelMissing:
            return .modelMissing
        case .modelLoadFailed, .contextCreationFailed:
            return .modelLoadFailed
        case .lowPowerMode:
            return .lowPowerMode
        case .thermalLimitReached:
            return .thermalLimitReached
        case .timeLimitReached:
            return .timeLimitReached
        case .promptTooLong:
            return .promptTooLong
        case .emptyResponse, .tokenizationFailed, .evaluationFailed:
            return .generationFailed
        }
    }
}

private enum BonsaiSystemPrompt {
    static let roadmap = """
    You are Lippi's private on-device roadmap planner and a coach in the goal's real domain.
    Preserve stated facts, language, quantities, dates, preferences, resources, constraints, and non-goals. Unknowns stay conditional.
    Recommend a clear sequence of domain-specific artifacts, checks, decisions, or practice outputs. Each milestone must unlock the next.
    Explain why the route fits this user and surface one useful tradeoff or checkpoint.
    Never invent named resources, people, feedback, demand, money, health or legal outcomes, circumstances, or guarantees. Treat product choices as tests, not promises.
    Use excerpts only within their stated boundary. If progress shows overload, reduce the nearest work without blame.
    Return one compact JSON object only.
    """

    static let progressSummary = """
    You are Lippi's private on-device progress analyst. Summarize only the visible app facts and the user's self-report, then offer a kind conditional forecast.
    Never infer hidden health, sleep, motivation, finances, demand, or reasons for delay. A forecast is not a guarantee.
    If the user reports fatigue or overload, reduce pressure and make the next action smaller. Start with wins, then risks, then a gentle next step.
    Write every human-readable JSON value in the requested language. Return valid JSON matching the requested contract and nothing else.
    """

    static let personalRecommendation = """
    You are Lippi's private on-device focus and recovery coach. Use only the supplied aggregate signals, session history, user state, and exact goal step.
    Never diagnose health, infer hidden causes, invent measurements, rewrite the goal step, or promise an outcome.
    The local safety ceiling is authoritative: focus may only become shorter, breaks may only become longer, and long breaks may only become more frequent.
    Make the recommendation specific, kind, practical, and concise. Write every human-readable value in the requested language.
    Return valid JSON matching the requested contract and nothing else.
    """

    static let eyeHealthAnalysis = """
    You are Lippi's private on-device eye comfort coach. You receive only coarse aggregate signals from a short guided exercise, never images or video.
    Describe observable signals carefully. Never diagnose, name a condition, confirm redness or fatigue medically, infer a cause, or use exercise speed as evidence of eye health.
    Preserve the authoritative local comfort level and never shorten its screen-rest recommendation. Prefer simple low-risk actions: a screen pause, relaxed blinking, distance viewing, and comfortable lighting.
    Write every human-readable value in the requested language. Return valid JSON matching the requested contract and nothing else.
    """
}

private enum BonsaiResponseContract {
    static let roadmap = """
    {
      "title": "string",
      "summary": "one concise sentence",
      "confidence": 0.0,
      "personalizedInsights": ["exactly 2 strings"],
      "milestones": [
        {
          "title": "string",
          "timeframe": "string",
          "target": "string",
          "tasks": ["exactly 2 strings"],
          "category": "work|study|health|rest|home|other"
        }
      ]
    }
    personalizedInsights must explain (1) why this route fits stated preferences, resources, constraints, or non-goals and (2) a useful non-obvious tradeoff, decision, or checkpoint. Do not merely restate the goal.
    milestones must contain 3 or 4 objects. Keep every string under 16 words. confidence is between 0 and 1.
    """

    static let progressSummary = """
    {
      "title": "string",
      "summary": "string",
      "progressScore": 0.0,
      "forecastLabel": "string",
      "forecast": "string",
      "wins": ["exactly 2 short strings"],
      "supportiveSignals": ["exactly 1 short string"],
      "risks": ["exactly 1 short string"],
      "nextSteps": ["exactly 2 short strings"],
      "stateCare": ["exactly 1 short string"],
      "checkInQuestion": "string",
      "confidence": 0.0
    }
    progressScore and confidence are between 0 and 1. Keep every string under 16 words.
    """

    static let personalRecommendation = """
    {
      "title": "string",
      "summary": "one concise sentence",
      "focusMinutes": 25,
      "shortBreakMinutes": 5,
      "longBreakMinutes": 15,
      "roundsBeforeLongBreak": 4,
      "recoveryKind": "move|water|eyes|breathe|reset",
      "recoveryAction": "one concrete safe action",
      "confidence": 0.0
    }
    Keep title under 7 words and summary and recoveryAction under 18 words. confidence is between 0 and 1.
    """

    static let eyeHealthAnalysis = """
    {
      "title": "string",
      "summary": "one careful sentence about observed signals",
      "action": "one concrete low-risk comfort action",
      "restMinutes": 10,
      "confidence": 0.0
    }
    Keep title under 7 words and summary and action under 20 words. restMinutes is between the supplied minimum and 30. confidence is between 0 and 1.
    """
}
