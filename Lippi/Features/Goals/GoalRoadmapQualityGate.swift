import Foundation

enum GoalRoadmapQualityGate {
    static func validated(
        _ roadmap: GoalRoadmap,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource] = []
    ) -> GoalRoadmap? {
        let normalized = normalizedForDisplay(roadmap, input: input, lang: lang)
        guard issues(for: normalized, input: input, evidence: evidence).isEmpty else { return nil }
        return normalized
    }

    static func normalizedForDisplay(
        _ roadmap: GoalRoadmap,
        input: GoalPlannerInput,
        lang: AppLang
    ) -> GoalRoadmap {
        let sanitized = sanitizingUnsupportedClaims(in: roadmap, input: input, lang: lang)
        var normalized = sanitized
        normalized.milestones = sanitized.milestones.enumerated().map { index, milestone in
            var milestone = milestone
            let slot = milestoneSlots(totalWeeks: input.horizon.weeks, count: sanitized.milestones.count)[index]
            milestone.timeframe = localizedTimeframe(start: slot.start, end: slot.end, lang: lang)
            return milestone
        }
        return normalized
    }

    static func feedback(for roadmap: GoalRoadmap?, input: GoalPlannerInput, evidence: [GoalEvidenceSource] = []) -> String {
        guard let roadmap else {
            return "The previous answer did not match the required JSON schema. Return every required field with grounded, non-empty values."
        }

        let findings = issues(for: roadmap, input: input, evidence: evidence)
        guard !findings.isEmpty else {
            return "Keep the plan grounded, specific, and within the selected horizon."
        }
        return findings.joined(separator: " ")
    }

    private static func issues(for roadmap: GoalRoadmap, input: GoalPlannerInput, evidence: [GoalEvidenceSource]) -> [String] {
        var findings: [String] = []
        let expectedMilestones = input.horizon.weeks == 12 ? 4 : 3

        if roadmap.milestones.count != expectedMilestones {
            findings.append("Use exactly \(expectedMilestones) milestones for this horizon.")
        }

        if roadmap.successCriteria.count != 2 {
            findings.append("Return exactly two success criteria.")
        }

        if roadmap.firstActions.count != 2 {
            findings.append("Return exactly two first actions that can start within 24-48 hours.")
        }

        let insights = roadmap.personalizedInsights ?? []
        if insights.count != 2 {
            findings.append("Return exactly two personalized insights: one route-fit explanation and one useful tradeoff, decision, or checkpoint.")
        } else {
            let normalizedInsights = insights.map(normalized)
            if Set(normalizedInsights).count != normalizedInsights.count || insights.contains(where: { normalized($0).count < 18 }) {
                findings.append("Make both personalized insights distinct and specific rather than short generic restatements.")
            }

            let contextTerms = meaningfulTerms(in: input.context)
            if !contextTerms.isEmpty {
                let insightTerms = normalized(insights.joined(separator: " ")).split(separator: " ").map(String.init)
                let reflectsContext = contextTerms.contains { anchor in
                    insightTerms.contains { looselyMatches(anchor, $0) }
                }
                if !reflectsContext {
                    findings.append("Make the route-fit insight explicitly reflect a stated preference, starting resource, constraint, or non-goal from the user's context.")
                }
            }
        }

        let normalizedTitles = roadmap.milestones.map { normalized($0.title) }
        if Set(normalizedTitles).count != normalizedTitles.count {
            findings.append("Give every milestone a distinct purpose and title.")
        }

        let allTasks = roadmap.milestones.flatMap(\.tasks)
        if roadmap.milestones.contains(where: { $0.tasks.count < 2 }) {
            findings.append("Each milestone needs two or three concrete next actions.")
        }

        if allTasks.contains(where: isVagueTask) || roadmap.firstActions.contains(where: isVagueTask) {
            findings.append("Replace vague tasks such as generic research or working on the project with an action and a concrete artifact or decision.")
        }

        if (allTasks + roadmap.firstActions).contains(where: lacksConcreteOutput) {
            findings.append("Every task and first action must name a concrete output, check, artifact, decision, or deliverable.")
        }

        if roadmap.milestones.contains(where: { normalized($0.target).count < 12 }) {
            findings.append("Give every milestone a clear, reviewable outcome instead of a short generic target.")
        }

        if roadmap.successCriteria.contains(where: lacksConcreteOutput) {
            findings.append("Success criteria must be observable: name a deliverable, metric supplied by the user, checklist, review, or test.")
        }

        let questions = roadmap.clarifyingQuestions ?? []
        if questions.count < 2 {
            findings.append("Return two or three concrete clarifying questions for refining the roadmap and future support.")
        }
        if questions.contains(where: isVagueQuestion) {
            findings.append("Replace generic clarifying questions with specific questions about context, constraints, timing, blockers, or support cadence.")
        }

        let normalizedTasks = allTasks.map(normalized)
        if Set(normalizedTasks).count != normalizedTasks.count {
            findings.append("Do not repeat the same task across milestones.")
        }

        let plannedFields = [
            roadmap.summary,
            (roadmap.personalizedInsights ?? []).joined(separator: " "),
            roadmap.successCriteria.joined(separator: " "),
            roadmap.firstActions.joined(separator: " "),
            roadmap.milestones.map(\.target).joined(separator: " "),
            roadmap.milestones.flatMap(\.tasks).joined(separator: " "),
            roadmap.habits.map(\.detail).joined(separator: " "),
            roadmap.risks.map(\.mitigation).joined(separator: " ")
        ]
        if plannedFields.contains(where: { hasUnsupportedOutcomeClaim(in: $0, input: input) }) {
            findings.append("Remove invented performance numbers, downloads, users, revenue, demand, conversion, or health outcomes unless the user explicitly supplied them.")
        }

        let anchorTerms = meaningfulTerms(in: "\(input.goal) \(input.context)")
        let plannedTerms = normalized(plannedFields.joined(separator: " "))
            .split(separator: " ")
            .map(String.init)
        if anchorTerms.count >= 2 {
            let hits = anchorTerms.filter { anchor in
                plannedTerms.contains { looselyMatches(anchor, $0) }
            }.count
            if hits < min(2, anchorTerms.count) {
                findings.append("Tie the roadmap back to the user's actual goal words, domain, and context instead of giving a generic plan.")
            }
        }

        return findings
    }

    private static func milestoneSlots(totalWeeks: Int, count: Int) -> [(start: Int, end: Int)] {
        let base = totalWeeks / max(count, 1)
        var slots: [(Int, Int)] = []

        for index in 0..<count {
            let start = index * base + 1
            let end = index == count - 1 ? totalWeeks : min(totalWeeks, (index + 1) * base)
            slots.append((start, end))
        }
        return slots
    }

    private static func localizedTimeframe(start: Int, end: Int, lang: AppLang) -> String {
        if start == end {
            return L10n.fmt("goals.local.week", lang, start)
        }
        return L10n.fmt("goals.local.weeks", lang, start, end)
    }

    private static func sanitizingUnsupportedClaims(
        in roadmap: GoalRoadmap,
        input: GoalPlannerInput,
        lang: AppLang
    ) -> GoalRoadmap {
        var sanitized = roadmap
        let goal = String(input.goal.prefix(90))

        func cleanExamples(_ text: String) -> String {
            removingGeneratedExamples(from: text)
        }

        sanitized.title = cleanExamples(sanitized.title)
        sanitized.summary = cleanExamples(sanitized.summary)
        sanitized.successCriteria = sanitized.successCriteria.map(cleanExamples)
        sanitized.firstActions = sanitized.firstActions.map(cleanExamples)
        sanitized.assumptions = sanitized.assumptions.map(cleanExamples)
        sanitized.personalizedInsights = sanitized.personalizedInsights?.map(cleanExamples)
        sanitized.clarifyingQuestions = sanitized.clarifyingQuestions?.map(cleanExamples)
        sanitized.milestones = sanitized.milestones.map { milestone in
            var milestone = milestone
            milestone.title = cleanExamples(milestone.title)
            milestone.target = cleanExamples(milestone.target)
            milestone.tasks = milestone.tasks.map(cleanExamples)
            return milestone
        }
        sanitized.habits = sanitized.habits.map {
            GoalHabit(title: cleanExamples($0.title), detail: cleanExamples($0.detail))
        }
        sanitized.risks = sanitized.risks.map {
            GoalRisk(title: cleanExamples($0.title), mitigation: cleanExamples($0.mitigation))
        }

        if hasUnsupportedOutcomeClaim(in: sanitized.summary, input: input) {
            sanitized.summary = L10n.fmt("goals.quality.safe_summary", lang, goal, input.horizon.weeks)
        }

        sanitized.successCriteria = sanitized.successCriteria.enumerated().map { index, item in
            guard hasUnsupportedOutcomeClaim(in: item, input: input) else { return item }
            return index == 0
                ? L10n.fmt("goals.quality.safe_criterion_goal", lang, goal)
                : L10n.tr("goals.quality.safe_criterion_review", lang)
        }

        sanitized.firstActions = sanitized.firstActions.enumerated().map { index, item in
            guard hasUnsupportedOutcomeClaim(in: item, input: input) else { return item }
            return index == 0
                ? L10n.tr("goals.quality.safe_action_question", lang)
                : L10n.tr("goals.quality.safe_action_checklist", lang)
        }

        sanitized.assumptions = sanitized.assumptions.map { item in
            hasUnsupportedOutcomeClaim(in: item, input: input)
                ? L10n.tr("goals.quality.safe_assumption", lang)
                : item
        }

        sanitized.personalizedInsights = sanitized.personalizedInsights?.enumerated().map { index, item in
            guard hasUnsupportedOutcomeClaim(in: item, input: input) else { return item }
            return index == 0
                ? L10n.fmt("goals.insights.local_fit", lang, String(input.goal.prefix(140)))
                : L10n.tr("goals.insights.local_decision", lang)
        }

        sanitized.milestones = sanitized.milestones.enumerated().map { index, milestone in
            var milestone = milestone
            if hasUnsupportedOutcomeClaim(in: milestone.target, input: input) {
                milestone.target = L10n.tr("goals.quality.safe_target", lang)
            }
            milestone.tasks = milestone.tasks.enumerated().map { taskIndex, task in
                guard hasUnsupportedOutcomeClaim(in: task, input: input) else { return task }
                let safeTask = taskIndex.isMultiple(of: 2)
                    ? L10n.tr("goals.quality.safe_action_question", lang)
                    : L10n.tr("goals.quality.safe_action_checklist", lang)
                return "\(safeTask): \(milestone.target)"
            }
            return milestone
        }

        sanitized.habits = sanitized.habits.map { habit in
            guard hasUnsupportedOutcomeClaim(in: habit.detail, input: input) else { return habit }
            return GoalHabit(title: habit.title, detail: L10n.tr("goals.quality.safe_habit", lang))
        }

        sanitized.risks = sanitized.risks.map { risk in
            guard hasUnsupportedOutcomeClaim(in: risk.mitigation, input: input) else { return risk }
            return GoalRisk(title: risk.title, mitigation: L10n.tr("goals.quality.safe_risk", lang))
        }

        return sanitized
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isVagueTask(_ task: String) -> Bool {
        let value = normalized(task)
        if value.count < 9 { return true }

        let vagueTasks: Set<String> = [
            "make progress",
            "work on the project",
            "do research",
            "learn more",
            "prepare everything",
            "continue learning",
            "study the topic",
            "practice more",
            "improve skills",
            "работать над проектом",
            "изучить материалы",
            "сделать исследование",
            "продвигаться к цели",
            "подготовить все",
            "заниматься больше",
            "улучшить навыки",
            "изучить тему"
        ]
        return vagueTasks.contains(value)
    }

    private static func lacksConcreteOutput(_ text: String) -> Bool {
        let value = normalized(text)
        if value.count < 14 { return true }

        let concreteSignals = [
            "checklist", "artifact", "draft", "prototype", "test", "decision", "metric", "review", "report",
            "summary", "plan", "schedule", "experiment", "interview", "feedback", "lesson", "practice",
            "release", "implementation", "document", "note", "map", "brief", "baseline",
            "чек лист", "артефакт", "черновик", "прототип", "тест", "провер", "решение", "метрик",
            "обзор", "отчет", "сводк", "план", "распис", "эксперимент", "интервью", "обратн",
            "урок", "практик", "релиз", "документ", "заметк", "карта", "бриф", "база"
        ]
        if concreteSignals.contains(where: { value.contains($0) }) { return false }

        let weakOpeners = [
            "learn", "study", "explore", "understand", "work", "continue",
            "изуч", "разобрат", "понять", "работ", "продолж"
        ]
        return weakOpeners.contains { value.hasPrefix($0) }
    }

    private static func isVagueQuestion(_ question: String) -> Bool {
        let value = normalized(question)
        if value.count < 12 { return true }

        let vagueQuestions: Set<String> = [
            "what else",
            "anything else",
            "any constraints",
            "что еще",
            "есть ли еще что то",
            "какие ограничения"
        ]
        return vagueQuestions.contains(value)
    }

    private static func hasUnsupportedOutcomeClaim(in text: String, input: GoalPlannerInput) -> Bool {
        let unsupportedPhrases = [
            "paid user", "user acquisition", "acquire users", "will pay", "generate revenue", "be profitable",
            "attract attention", "ensures validation", "guarantees validation", "will motivate", "will engage",
            "платящ", "привлечь пользователей", "пользователи будут платить", "принесет выручку", "будет прибыльным",
            "привлекает внимание", "обеспечивает быструю валидацию", "гарантирует валидацию", "будет мотивировать", "вовлечет"
        ]
        let userBrief = "\(input.goal) \(input.context)".lowercased()
        if unsupportedPhrases.contains(where: { phrase in
            text.localizedCaseInsensitiveContains(phrase) && !userBrief.contains(phrase)
        }) {
            return true
        }

        let userNumbers = Set(numbers(in: "\(input.goal) \(input.context) \(input.horizon.weeks)"))
        let metricPattern = #"(?i)(?:[%$€₽]\s*\d+(?:[.,]\d+)?|\d+(?:[.,]\d+)?\s*(?:%|percent|percentage|users?|downloads?|installs?|customers?|subscribers?|sales|revenue|profit|kg|kilograms?|lbs?|pounds?|процент(?:а|ов)?|пользовател\p{L}*|скачиван\p{L}*|установ\p{L}*|клиент\p{L}*|подписчик\p{L}*|продаж\p{L}*|выручк\p{L}*|прибы(?:ль|ли)|руб(?:лей|ля)?|доллар\p{L}*|евро|кг|килограмм\p{L}*))"#
        guard let expression = try? NSRegularExpression(pattern: metricPattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).contains { match in
            guard let matchRange = Range(match.range, in: text) else { return false }
            return numbers(in: String(text[matchRange])).contains { !userNumbers.contains($0) }
        }
    }

    private static func numbers(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isNumber }).map(String.init)
    }

    private static func removingGeneratedExamples(from text: String) -> String {
        let pattern = #"(?iu)\s*\((?:например|for\s+example|e\.g\.|zum\s+beispiel|por\s+ejemplo)[^)]*\)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func meaningfulTerms(in text: String) -> [String] {
        let stopwords: Set<String> = [
            "goal", "plan", "week", "weeks", "month", "months", "task", "tasks", "want", "need",
            "цель", "план", "недел", "месяц", "задач", "хочу", "нужно", "надо", "сделать", "достичь",
            "для", "with", "from", "that", "this", "будет", "есть", "как"
        ]
        var seen = Set<String>()
        let terms = normalized(text)
            .split(separator: " ")
            .map(String.init)
            .filter { term in
                term.count >= 4 && !stopwords.contains(where: { stopword in
                    term == stopword || (stopword.count >= 4 && term.hasPrefix(stopword))
                })
            }
            .filter { seen.insert($0).inserted }
        return Array(terms.prefix(8))
    }

    private static func looselyMatches(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard lhs.count >= 5, rhs.count >= 5 else { return false }
        let prefixLength = min(6, min(lhs.count, rhs.count) - 1)
        return lhs.prefix(prefixLength) == rhs.prefix(prefixLength)
    }
}
