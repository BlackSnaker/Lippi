import Foundation

enum GoalRoadmapQualityGate {
    static func validated(
        _ roadmap: GoalRoadmap,
        input: GoalPlannerInput,
        lang: AppLang
    ) -> GoalRoadmap? {
        let sanitized = sanitizingUnsupportedClaims(in: roadmap, input: input, lang: lang)
        guard issues(for: sanitized, input: input).isEmpty else { return nil }

        var normalized = sanitized
        normalized.milestones = sanitized.milestones.enumerated().map { index, milestone in
            var milestone = milestone
            let slot = milestoneSlots(totalWeeks: input.horizon.weeks, count: sanitized.milestones.count)[index]
            milestone.timeframe = localizedTimeframe(start: slot.start, end: slot.end, lang: lang)
            return milestone
        }
        return normalized
    }

    static func feedback(for roadmap: GoalRoadmap?, input: GoalPlannerInput) -> String {
        guard let roadmap else {
            return "The previous answer did not match the required JSON schema. Return every required field with grounded, non-empty values."
        }

        let findings = issues(for: roadmap, input: input)
        guard !findings.isEmpty else {
            return "Keep the plan grounded, specific, and within the selected horizon."
        }
        return findings.joined(separator: " ")
    }

    private static func issues(for roadmap: GoalRoadmap, input: GoalPlannerInput) -> [String] {
        var findings: [String] = []
        let expectedMilestones = input.horizon.weeks == 12 ? 4 : 3

        if roadmap.milestones.count != expectedMilestones {
            findings.append("Use exactly \(expectedMilestones) milestones for this horizon.")
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

        if roadmap.milestones.contains(where: { normalized($0.target).count < 12 }) {
            findings.append("Give every milestone a clear, reviewable outcome instead of a short generic target.")
        }

        let normalizedTasks = allTasks.map(normalized)
        if Set(normalizedTasks).count != normalizedTasks.count {
            findings.append("Do not repeat the same task across milestones.")
        }

        let plannedFields = [
            roadmap.summary,
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
            "работать над проектом",
            "изучить материалы",
            "сделать исследование",
            "продвигаться к цели",
            "подготовить все"
        ]
        return vagueTasks.contains(value)
    }

    private static func hasUnsupportedOutcomeClaim(in text: String, input: GoalPlannerInput) -> Bool {
        let userNumbers = Set(numbers(in: "\(input.goal) \(input.context) \(input.horizon.weeks)"))
        if numbers(in: text).contains(where: { !userNumbers.contains($0) }) { return true }

        let unsupportedPhrases = [
            "paid user", "user acquisition", "acquire users", "will pay", "generate revenue", "be profitable",
            "платящ", "привлечь пользователей", "пользователи будут платить", "принесет выручку", "будет прибыльным"
        ]
        let userBrief = "\(input.goal) \(input.context)".lowercased()
        return unsupportedPhrases.contains { phrase in
            text.localizedCaseInsensitiveContains(phrase) && !userBrief.contains(phrase)
        }
    }

    private static func numbers(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isNumber }).map(String.init)
    }
}
