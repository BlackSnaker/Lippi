import Foundation

enum BonsaiProviderError: Error, Equatable {
    case disabled
    case modelMissing
    case runtimeUnavailable
    case modelLoadFailed
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

    func generate(prompt: String, configuration: BonsaiConfiguration) async throws -> String {
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
            maximumOutputTokens: 1_700
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
            maximumOutputTokens: 1_000
        )
    }

    func check(configuration: BonsaiConfiguration) async throws {
        try ensureReady(configuration: configuration)
        let response = try await run(
            systemPrompt: "You are a local readiness check. Return JSON only.",
            userPrompt: "Return exactly {\"ready\":true} and nothing else.",
            maximumOutputTokens: 32
        )
        guard response.contains("\"ready\":true") || response.contains("\"ready\": true") else {
            throw BonsaiProviderError.malformedResponse
        }
    }

    private func run(
        systemPrompt: String,
        userPrompt: String,
        maximumOutputTokens: Int32
    ) async throws -> String {
        do {
            return try await engine.generate(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                options: BonsaiGenerationOptions(maximumOutputTokens: maximumOutputTokens)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BonsaiRuntimeError {
            switch error {
            case .runtimeUnavailable:
                throw BonsaiProviderError.runtimeUnavailable
            case .modelMissing:
                throw BonsaiProviderError.modelMissing
            case .modelLoadFailed, .contextCreationFailed:
                throw BonsaiProviderError.modelLoadFailed
            case .promptTooLong:
                throw BonsaiProviderError.promptTooLong
            case .emptyResponse, .tokenizationFailed, .evaluationFailed:
                throw BonsaiProviderError.generationFailed
            }
        } catch {
            throw BonsaiProviderError.generationFailed
        }
    }
}

private enum BonsaiSystemPrompt {
    static let roadmap = """
    You are Lippi's private on-device goal-roadmap planner. Turn the user's stated goal and constraints into a practical route, never a promise of success.
    Treat only the user brief and supplied excerpts as facts. Put unknown details into assumptions or concrete clarifying questions.
    Match the real domain work: discovery, learning, building, validation, recovery, review, or habit formation.
    Use excerpts only within their evidence boundary. Prefer official or specialist material when references conflict.
    Write every human-readable JSON value in the user's request language. Preserve names, brands, acronyms, quantities, dates, and explicit constraints.
    If task facts show delay or overload, preserve the goal, reduce the nearest workload, split skipped steps, and avoid blame or invented explanations.
    Never invent users, demand, feedback, revenue, health outcomes, legal outcomes, resources, deadlines, or personal circumstances.
    Return valid JSON matching the requested contract and nothing else.
    """

    static let progressSummary = """
    You are Lippi's private on-device progress analyst. Summarize only the visible app facts and the user's self-report, then offer a kind conditional forecast.
    Never infer hidden health, sleep, motivation, finances, demand, or reasons for delay. A forecast is not a guarantee.
    If the user reports fatigue or overload, reduce pressure and make the next action smaller. Start with wins, then risks, then a gentle next step.
    Write every human-readable JSON value in the requested language. Return valid JSON matching the requested contract and nothing else.
    """
}

private enum BonsaiResponseContract {
    static let roadmap = """
    {
      "title": "string",
      "summary": "string",
      "confidence": 0.0,
      "successCriteria": ["exactly 2 strings"],
      "firstActions": ["exactly 2 strings"],
      "assumptions": ["0 to 3 strings"],
      "clarifyingQuestions": ["2 to 3 strings"],
      "milestones": [
        {
          "title": "string",
          "timeframe": "string",
          "target": "string",
          "tasks": ["2 to 3 strings"],
          "category": "work|study|health|rest|home|other"
        }
      ],
      "habits": [{"title": "string", "detail": "string"}],
      "risks": [{"title": "string", "mitigation": "string"}]
    }
    milestones must contain 3 or 4 objects; habits 1 or 2; risks 1 or 2; confidence is between 0 and 1.
    """

    static let progressSummary = """
    {
      "title": "string",
      "summary": "string",
      "progressScore": 0.0,
      "forecastLabel": "string",
      "forecast": "string",
      "wins": ["2 to 4 strings"],
      "supportiveSignals": ["2 to 4 strings"],
      "risks": ["1 to 3 strings"],
      "nextSteps": ["2 to 3 strings"],
      "stateCare": ["1 to 3 strings"],
      "checkInQuestion": "string",
      "confidence": 0.0
    }
    progressScore and confidence are between 0 and 1.
    """
}
