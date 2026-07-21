import Foundation

/// A deterministic, offline Russian-to-English bridge for goal-planning input.
/// It intentionally translates the planning meaning instead of attempting a broad machine translation.
struct RussianGoalTranslation: Equatable {
    let goal: String
    let context: String
}

enum RussianGoalTranslator {
    static func translate(goal: String, context: String) -> RussianGoalTranslation {
        let source = "\(goal) \(context)".goalTranslationNormalized
        let signals = PlanningSignals(source: source)
        let subject = goalSubject(in: source)
        let action = goalAction(in: source, subject: subject)
        let englishGoal = makeGoal(action: action, subject: subject, signals: signals)

        return RussianGoalTranslation(
            goal: englishGoal,
            context: makeContext(source: source, context: context, subject: subject, signals: signals)
        )
    }

    private static func makeGoal(action: String, subject: String, signals: PlanningSignals) -> String {
        var result = "\(action) \(subject)"

        if let level = signals.languageLevel, subject.contains("English") || subject.contains("Spanish") || subject.contains("German") || subject.contains("French") {
            result += " and reach \(level) level"
        }

        if let weight = signals.weightChange, action == "Lose weight" {
            result = "Lose weight by \(weight)"
        }

        if let timeframe = signals.timeframe {
            result += " in \(timeframe)"
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines) + "."
    }

    private static func makeContext(
        source: String,
        context: String,
        subject: String,
        signals: PlanningSignals
    ) -> String {
        var points = [
            "Lippi created this English planning translation locally from the user's Russian input.",
            "Primary goal: \(subject)."
        ]

        if let timeframe = signals.timeframe {
            points.append("Target timeframe: \(timeframe).")
        }
        if let weeklyTime = signals.weeklyTime {
            points.append("Available time: \(weeklyTime).")
        }
        if source.containsAnyGoalToken(["с нуля", "начинающ", "нович", "без опыта"]) {
            points.append("Starting point: beginner level or no prior experience.")
        }
        if let level = signals.languageLevel {
            points.append("Target level: \(level).")
        }
        if source.containsAnyGoalToken(["работ", "занят", "офис", "смен"]) {
            points.append("Constraint: the plan must fit around work commitments.")
        }
        if source.containsAnyGoalToken(["семь", "ребен", "детей", "детьми", "родител"]) {
            points.append("Constraint: the plan must fit around family commitments.")
        }
        if source.containsAnyGoalToken(["бюджет", "деньг", "дешев", "расход"]) {
            points.append("Constraint: keep the plan budget-aware.")
        }
        if subject == "weight" || source.containsAnyGoalToken(["здоров", "травм", "бол", "врач"]) {
            points.append("Safety: keep health-related steps gradual and avoid medical claims.")
        }
        if !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            points.append("The user supplied additional context; use the explicit constraints above and state assumptions for anything else.")
        }

        return points.uniqueGoalTranslationLines.joined(separator: " ")
    }

    private static func goalAction(in source: String, subject: String) -> String {
        if source.containsAnyGoalToken(["похуд", "сброс", "скинуть вес", "убрать вес"]) {
            return "Lose weight"
        }
        if source.containsAnyGoalToken(["запустить", "стартовать", "открыть"]) {
            return "Launch"
        }
        if source.containsAnyGoalToken(["создать", "сделать", "разработ", "собрать", "построить"]) {
            return subject == "a new skill" ? "Learn" : "Build"
        }
        if source.containsAnyGoalToken(["выуч", "изуч", "осво", "науч", "подтян"]) {
            return "Learn"
        }
        if source.containsAnyGoalToken(["сдать", "подготов", "экзам"]) {
            return "Prepare for and pass"
        }
        if source.containsAnyGoalToken(["найти", "устроит", "получить работу"]) {
            return "Find"
        }
        if source.containsAnyGoalToken(["увелич", "поднять", "вырастить"]) {
            return "Increase"
        }
        if source.containsAnyGoalToken(["улучш", "прокач", "развить"]) {
            return "Improve"
        }
        return subject == "a new skill" ? "Learn" : "Achieve"
    }

    private static func goalSubject(in source: String) -> String {
        if source.containsAnyGoalToken(["английск", "english"]) { return "English" }
        if source.containsAnyGoalToken(["испанск", "spanish"]) { return "Spanish" }
        if source.containsAnyGoalToken(["немецк", "german"]) { return "German" }
        if source.containsAnyGoalToken(["француз", "french"]) { return "French" }
        if source.containsAnyGoalToken(["китайск", "chinese"]) { return "Chinese" }
        if source.containsAnyGoalToken(["японск", "japanese"]) { return "Japanese" }
        if source.containsAnyGoalToken(["похуд", "сброс", "скинуть вес", "убрать вес", "килограмм", "кг"]) { return "weight" }
        if source.containsAnyGoalToken(["марафон", "полумарафон"]) { return "a running event" }
        if source.containsAnyGoalToken(["бег", "пробеж", "выносливост"]) { return "running endurance" }
        if source.containsAnyGoalToken(["мышц", "массу", "зал", "тренировк"]) { return "fitness and body composition" }
        if source.containsAnyGoalToken(["тур", "путешеств", "экскурси"]) { return "a travel tour" }
        if source.containsAnyGoalToken(["приложен", "app"]) { return "an app" }
        if source.containsAnyGoalToken(["сайт", "лендинг", "website"]) { return "a website" }
        if source.containsAnyGoalToken(["mvp", "стартап", "проект", "продукт"]) { return "a project MVP" }
        if source.containsAnyGoalToken(["курс", "обучен"]) { return "an online course" }
        if source.containsAnyGoalToken(["бизнес", "магазин", "продаж"]) { return "a business goal" }
        if source.containsAnyGoalToken(["работ", "карьер", "ваканси", "собесед"]) { return "a career goal" }
        if source.containsAnyGoalToken(["экзам", "сертификат", "тест"]) { return "an exam or certification" }
        if source.containsAnyGoalToken(["сон", "стресс", "баланс", "отдых"]) { return "daily wellbeing and balance" }
        if source.containsAnyGoalToken(["ремонт", "дом", "квартир"]) { return "a home project" }
        return "a new skill"
    }
}

private struct PlanningSignals {
    let source: String

    var languageLevel: String? {
        firstMatch("\\b(A1|A2|B1|B2|C1|C2)\\b", options: [.caseInsensitive])?.uppercased()
    }

    var weightChange: String? {
        guard let value = firstMatch("([0-9]+(?:[\\.,][0-9]+)?)\\s*(?:кг|килограмм(?:а|ов)?)") else { return nil }
        return "\(value.replacingOccurrences(of: ",", with: ".")) kg"
    }

    var timeframe: String? {
        guard let match = firstMatchGroups("(?:за|на|через|к|в течение)\\s*([0-9]+)\\s*(день|дня|дней|неделю|недели|недель|месяц|месяца|месяцев|год|года|лет)") else { return nil }
        return englishDuration(value: match[0], russianUnit: match[1])
    }

    var weeklyTime: String? {
        guard let match = firstMatchGroups("([0-9]+(?:[\\.,][0-9]+)?)\\s*(час|часа|часов|минут|минуты)?\\s*(?:в|на)\\s*недел") else { return nil }
        let value = match[0].replacingOccurrences(of: ",", with: ".")
        let unit = match.count > 1 ? match[1] : "часов"
        let englishUnit = unit.hasPrefix("мин") ? "minutes per week" : "hours per week"
        return "\(value) \(englishUnit)"
    }

    private func englishDuration(value: String, russianUnit: String) -> String {
        let unit: String
        if russianUnit.hasPrefix("д") {
            unit = value == "1" ? "day" : "days"
        } else if russianUnit.hasPrefix("н") {
            unit = value == "1" ? "week" : "weeks"
        } else if russianUnit.hasPrefix("м") {
            unit = value == "1" ? "month" : "months"
        } else {
            unit = value == "1" ? "year" : "years"
        }
        return "\(value) \(unit)"
    }

    private func firstMatch(_ pattern: String, options: NSRegularExpression.Options = []) -> String? {
        firstMatchGroups(pattern, options: options)?.first
    }

    private func firstMatchGroups(_ pattern: String, options: NSRegularExpression.Options = []) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, range: range) else { return nil }

        return (1..<match.numberOfRanges).compactMap { index in
            let resultRange = match.range(at: index)
            guard resultRange.location != NSNotFound, let range = Range(resultRange, in: source) else { return nil }
            return String(source[range])
        }
    }
}

private extension String {
    var goalTranslationNormalized: String {
        lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    func containsAnyGoalToken(_ tokens: [String]) -> Bool {
        tokens.contains { contains($0) }
    }
}

private extension Array where Element == String {
    var uniqueGoalTranslationLines: [String] {
        reduce(into: []) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }
    }
}
