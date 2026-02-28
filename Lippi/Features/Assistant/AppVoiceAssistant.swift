import SwiftUI
import Speech
import AVFoundation
import NaturalLanguage
#if os(iOS)
import AudioToolbox
import UIKit
#endif

enum AppVoiceAssistantState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case error(String)
}

enum AppVoiceMetricsPeriod: Equatable {
    case today
    case week
}

enum AppVoiceCommandIntent: Equatable {
    case addTask(title: String, category: TaskCategory)
    case completeTask(title: String?)
    case deleteTask(title: String?)
    case openTab(AppTab)
    case startPomodoro(minutes: Int?)
    case pausePomodoro
    case resumePomodoro
    case startShortBreak
    case startLongBreak
    case stopPomodoro
    case openEyeExercise
    case summarizeMetrics(period: AppVoiceMetricsPeriod)
    case unknown
}

private enum AppVoiceIntentKind: String, Codable, CaseIterable {
    case addTask
    case completeTask
    case deleteTask
    case openTabToday
    case openTabTasks
    case openTabPomodoro
    case openTabBreak
    case openTabHealth
    case openTabEye
    case openTabSettings
    case startPomodoro
    case pausePomodoro
    case resumePomodoro
    case startShortBreak
    case startLongBreak
    case stopPomodoro
    case openEyeExercise
    case summarizeMetricsToday
    case summarizeMetricsWeek
    case unknown

    init(intent: AppVoiceCommandIntent) {
        switch intent {
        case .addTask:
            self = .addTask
        case .completeTask:
            self = .completeTask
        case .deleteTask:
            self = .deleteTask
        case .openTab(let tab):
            switch tab {
            case .today: self = .openTabToday
            case .tasks: self = .openTabTasks
            case .pomodoro: self = .openTabPomodoro
            case .break: self = .openTabBreak
            case .health: self = .openTabHealth
            case .eye: self = .openTabEye
            case .settings: self = .openTabSettings
            }
        case .startPomodoro:
            self = .startPomodoro
        case .pausePomodoro:
            self = .pausePomodoro
        case .resumePomodoro:
            self = .resumePomodoro
        case .startShortBreak:
            self = .startShortBreak
        case .startLongBreak:
            self = .startLongBreak
        case .stopPomodoro:
            self = .stopPomodoro
        case .openEyeExercise:
            self = .openEyeExercise
        case .summarizeMetrics(let period):
            switch period {
            case .today: self = .summarizeMetricsToday
            case .week: self = .summarizeMetricsWeek
            }
        case .unknown:
            self = .unknown
        }
    }
}

struct AppVoiceCommandEnvelope: Identifiable, Equatable {
    let id = UUID()
    let transcript: String
    let intent: AppVoiceCommandIntent
}

enum AppVoiceCommandParser {
    static func parse(_ text: String, lang: AppLang, context: AppVoiceCommandIntent? = nil) -> AppVoiceCommandIntent {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return .unknown }

        if let contextualIntent = resolveContextualIntent(in: normalized, context: context) {
            return contextualIntent
        }

        if isPausePomodoro(normalized) {
            return .pausePomodoro
        }

        if isResumePomodoro(normalized) {
            return .resumePomodoro
        }

        if isStopPomodoro(normalized) {
            return .stopPomodoro
        }

        if let period = detectMetricsSummaryPeriod(in: normalized) {
            return .summarizeMetrics(period: period)
        }

        if let taskTitle = extractSuffix(in: normalized, prefixes: addTaskPrefixes) {
            let category = detectCategory(in: normalized, lang: lang)
            return .addTask(title: taskTitle, category: category)
        }

        if isCompleteTask(normalized) {
            return .completeTask(title: extractSuffix(in: normalized, prefixes: completeTaskPrefixes))
        }

        if isDeleteTask(normalized) {
            return .deleteTask(title: extractSuffix(in: normalized, prefixes: deleteTaskPrefixes))
        }

        if isStartLongBreak(normalized) {
            return .startLongBreak
        }

        if isStartShortBreak(normalized) {
            return .startShortBreak
        }

        if isStartPomodoro(normalized) {
            return .startPomodoro(minutes: extractMinutes(from: normalized))
        }

        if isOpenEyeExercise(normalized) {
            return .openEyeExercise
        }

        if let tab = detectTab(in: normalized) {
            return .openTab(tab)
        }

        if let aiIntent = AppEmbeddedAIInterpreter.shared.interpret(normalizedText: normalized, lang: lang, context: context) {
            return aiIntent
        }

        return .unknown
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\s:]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ source: String, keywords: [String]) -> Bool {
        keywords.contains { source.contains(normalize($0)) }
    }

    private static let addTaskPrefixes = [
        "добавь задачу",
        "добавить задачу",
        "создай задачу",
        "создать задачу",
        "новая задача",
        "add task",
        "create task",
        "new task",
        "aufgabe hinzufugen",
        "aufgabe erstellen",
        "neue aufgabe",
        "agregar tarea",
        "crear tarea",
        "nueva tarea"
    ]

    private static let completeTaskPrefixes = [
        "заверши задачу",
        "выполни задачу",
        "отметь задачу",
        "complete task",
        "finish task",
        "mark task",
        "aufgabe abschliessen",
        "aufgabe erledigen",
        "completar tarea",
        "terminar tarea",
        "marcar tarea"
    ]

    private static let deleteTaskPrefixes = [
        "удали задачу",
        "удалить задачу",
        "delete task",
        "remove task",
        "aufgabe loschen",
        "aufgabe entfernen",
        "eliminar tarea",
        "borrar tarea",
        "quitar tarea"
    ]

    private static func extractSuffix(in text: String, prefixes: [String]) -> String? {
        for rawPrefix in prefixes {
            let prefix = normalize(rawPrefix)
            guard let range = text.range(of: prefix) else { continue }
            let suffix = text[range.upperBound...]
            let cleaned = suffix
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    private static func isStartPomodoro(_ text: String) -> Bool {
        let pomodoroWords = ["помодоро", "pomodoro", "focus timer", "фокус"]
        let startWords = ["запусти", "начни", "старт", "start", "run", "starte", "iniciar"]

        if text.hasPrefix("помодоро") || text.hasPrefix("pomodoro") {
            return true
        }

        return containsAny(text, keywords: pomodoroWords) && containsAny(text, keywords: startWords)
    }

    private static func isStopPomodoro(_ text: String) -> Bool {
        let pomodoroWords = ["помодоро", "pomodoro", "focus"]
        let stopWords = ["стоп", "останов", "прекрати", "stop", "cancel", "stopp", "detener", "parar"]
        return containsAny(text, keywords: pomodoroWords) && containsAny(text, keywords: stopWords)
    }

    private static func isPausePomodoro(_ text: String) -> Bool {
        let pomodoroWords = ["помодоро", "pomodoro", "focus", "фокус"]
        let pauseWords = ["пауза", "поставь на паузу", "pause", "pausa", "anhalten", "unterbrechen"]
        return containsAny(text, keywords: pomodoroWords) && containsAny(text, keywords: pauseWords)
    }

    private static func isResumePomodoro(_ text: String) -> Bool {
        let pomodoroWords = ["помодоро", "pomodoro", "focus", "фокус", "таймер"]
        let resumeWords = ["продолж", "возобнов", "resume", "continue", "fortsetzen", "reanudar", "continuar"]
        return containsAny(text, keywords: pomodoroWords) && containsAny(text, keywords: resumeWords)
    }

    private static func isStartShortBreak(_ text: String) -> Bool {
        let shortBreakWords = ["короткий перерыв", "short break", "kleine pause", "descanso corto", "перерыв"]
        let startWords = ["запусти", "начни", "старт", "start", "run", "starte", "iniciar"]
        return containsAny(text, keywords: shortBreakWords) && containsAny(text, keywords: startWords)
    }

    private static func isStartLongBreak(_ text: String) -> Bool {
        let longBreakWords = ["длинный перерыв", "большой перерыв", "long break", "lange pause", "descanso largo"]
        let startWords = ["запусти", "начни", "старт", "start", "run", "starte", "iniciar"]
        return containsAny(text, keywords: longBreakWords) && containsAny(text, keywords: startWords)
    }

    private static func isCompleteTask(_ text: String) -> Bool {
        let taskWords = ["задач", "task", "aufgabe", "tarea"]
        let completeWords = ["заверши", "выполни", "отметь", "complete", "finish", "done", "erledige", "completar", "terminar"]
        return containsAny(text, keywords: taskWords) && containsAny(text, keywords: completeWords)
    }

    private static func isDeleteTask(_ text: String) -> Bool {
        let taskWords = ["задач", "task", "aufgabe", "tarea"]
        let deleteWords = ["удали", "delete", "remove", "losch", "entfern", "elimina", "borrar", "quitar"]
        return containsAny(text, keywords: taskWords) && containsAny(text, keywords: deleteWords)
    }

    private static func isOpenEyeExercise(_ text: String) -> Bool {
        let eyeWords = [
            "тренировк глаз",
            "упражнен для глаз",
            "eye exercise",
            "eye workout",
            "ejercicio de ojos",
            "augen training"
        ]
        let openWords = ["открой", "запусти", "open", "start", "abre", "offne", "iniciar"]
        return containsAny(text, keywords: eyeWords) && containsAny(text, keywords: openWords)
    }

    private static func detectMetricsSummaryPeriod(in text: String) -> AppVoiceMetricsPeriod? {
        guard isMetricsSummaryRequest(text) else { return nil }

        if containsAny(text, keywords: ["сегодня", "за сегодня", "today", "heute", "hoy"]) {
            return .today
        }

        if containsAny(text, keywords: ["недел", "за неделю", "7 дней", "week", "weekly", "woche", "semana"]) {
            return .week
        }

        return .week
    }

    private static func isMetricsSummaryRequest(_ text: String) -> Bool {
        let summaryWords = [
            "сводк",
            "итог",
            "показател",
            "статистик",
            "прогресс",
            "summary",
            "stats",
            "statistics",
            "metrics",
            "report",
            "zusammenfassung",
            "statistik",
            "kennzahlen",
            "resumen",
            "estadistica",
            "metricas"
        ]
        return containsAny(text, keywords: summaryWords)
    }

    private static func resolveContextualIntent(in text: String, context: AppVoiceCommandIntent?) -> AppVoiceCommandIntent? {
        guard let context else { return nil }

        switch context {
        case .startPomodoro, .pausePomodoro, .resumePomodoro, .stopPomodoro, .startShortBreak, .startLongBreak:
            if containsAny(text, keywords: ["пауза", "pause", "pausa", "anhalten", "unterbrechen"]) {
                return .pausePomodoro
            }
            if containsAny(text, keywords: ["продолж", "возобнов", "resume", "continue", "fortsetzen", "reanudar"]) {
                return .resumePomodoro
            }
            if containsAny(text, keywords: ["стоп", "останов", "stop", "cancel", "stopp", "detener", "parar"]) {
                return .stopPomodoro
            }
            if containsAny(text, keywords: ["коротк", "short", "klein", "corto"]), containsAny(text, keywords: ["перерыв", "break", "pause", "descanso"]) {
                return .startShortBreak
            }
            if containsAny(text, keywords: ["длин", "больш", "long", "lange", "largo"]), containsAny(text, keywords: ["перерыв", "break", "pause", "descanso"]) {
                return .startLongBreak
            }
            if let minutes = extractMinutes(from: text), containsAny(text, keywords: ["мин", "minute", "min", "minut"]) {
                return .startPomodoro(minutes: minutes)
            }
            return nil

        case .summarizeMetrics:
            if containsAny(text, keywords: ["сегодня", "today", "heute", "hoy"]) {
                return .summarizeMetrics(period: .today)
            }
            if containsAny(text, keywords: ["недел", "7 дн", "week", "woche", "semana"]) {
                return .summarizeMetrics(period: .week)
            }
            return nil

        case .addTask, .completeTask, .deleteTask, .openTab, .openEyeExercise, .unknown:
            return nil
        }
    }

    private static func extractMinutes(from text: String) -> Int? {
        guard let match = text.range(of: "\\b\\d{1,3}\\b", options: .regularExpression),
              let number = Int(text[match]) else {
            return nil
        }
        return max(5, min(120, number))
    }

    private static func detectTab(in text: String) -> AppTab? {
        if containsAny(text, keywords: ["задач", "tasks", "aufgabe", "tarea"]) { return .tasks }
        if containsAny(text, keywords: ["помодоро", "focus", "pomodoro"]) { return .pomodoro }
        if containsAny(text, keywords: ["перерыв", "break", "game", "pause"]) { return .break }
        if containsAny(text, keywords: ["здоров", "health", "gesund", "salud"]) { return .health }
        if containsAny(text, keywords: ["глаз", "eyes", "eye", "augen", "ojos"]) { return .eye }
        if containsAny(text, keywords: ["настро", "settings", "einstellungen", "ajustes"]) { return .settings }
        if containsAny(text, keywords: ["сегодн", "главн", "today", "home", "inicio"]) { return .today }
        return nil
    }

    private static func detectCategory(in text: String, lang: AppLang) -> TaskCategory {
        let rules: [(TaskCategory, [String])] = [
            (.work, ["работ", "проект", "клиент", "work", "job", "arbeit", "trabajo"]),
            (.study, ["учеб", "урок", "экзам", "study", "learn", "lernen", "estudio"]),
            (.health, ["здоров", "спорт", "трен", "дыхан", "health", "workout", "gesund", "salud"]),
            (.rest, ["отдых", "перерыв", "сон", "rest", "break", "ruhe", "descanso"]),
            (.home, ["дом", "уборк", "покупк", "home", "house", "haus", "hogar"])
        ]

        var bestMatch: (TaskCategory, Int) = (.other, 0)
        for (category, words) in rules {
            let score = words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
            if score > bestMatch.1 {
                bestMatch = (category, score)
            }
        }

        if bestMatch.1 > 0 {
            return bestMatch.0
        }

        if lang == .en && text.contains("task") {
            return .work
        }
        return .other
    }
}

private final class AppVoiceBehaviorModel {
    static let shared = AppVoiceBehaviorModel()

    private struct LanguageStats: Codable {
        var totalObservations: Int = 0
        var intentCounts: [String: Int] = [:]
        var transitionCounts: [String: [String: Int]] = [:]
        var tokenCounts: [String: [String: Int]] = [:]
        var intentTokenTotals: [String: Int] = [:]
    }

    private let storageKey = "assistant.behavior.model.v1"
    private let saveQueue = DispatchQueue(label: "assistant.behavior.save", qos: .utility)
    private let lock = NSLock()
    private var statsByLanguage: [String: LanguageStats] = [:]
    private var pendingSave: DispatchWorkItem?

    private init() {
        load()
    }

    func observe(
        transcript: String,
        intent: AppVoiceCommandIntent,
        context: AppVoiceCommandIntent?,
        lang: AppLang
    ) {
        let intentKind = AppVoiceIntentKind(intent: intent)
        guard intentKind != .unknown else { return }

        let tokens = behaviorTokens(from: transcript)

        lock.lock()
        var language = statsByLanguage[lang.rawValue] ?? LanguageStats()
        language.totalObservations += 1
        increment(&language.intentCounts, key: intentKind.rawValue)

        if let context {
            let contextKind = AppVoiceIntentKind(intent: context)
            if contextKind != .unknown {
                incrementNested(&language.transitionCounts, parent: contextKind.rawValue, key: intentKind.rawValue)
            }
        }

        if !tokens.isEmpty {
            for token in tokens {
                incrementNested(&language.tokenCounts, parent: intentKind.rawValue, key: token)
                increment(&language.intentTokenTotals, key: intentKind.rawValue)
            }
        }

        if language.totalObservations % 80 == 0 {
            applyDecay(&language, factor: 0.96)
        }

        statsByLanguage[lang.rawValue] = language
        lock.unlock()

        scheduleSave()
    }

    func probabilisticBoost(
        for intent: AppVoiceCommandIntent,
        tokens: Set<String>,
        context: AppVoiceCommandIntent?,
        lang: AppLang
    ) -> Double {
        let intentKind = AppVoiceIntentKind(intent: intent)
        guard intentKind != .unknown else { return 0 }

        lock.lock()
        let language = statsByLanguage[lang.rawValue]
        lock.unlock()

        guard let language, language.totalObservations >= 10 else { return 0 }

        let classCount = max(1, AppVoiceIntentKind.allCases.count - 1)
        let intentKey = intentKind.rawValue
        let prior = smoothingProbability(
            count: language.intentCounts[intentKey] ?? 0,
            total: language.totalObservations,
            classes: classCount
        )

        let transition: Double
        if let context {
            let contextKind = AppVoiceIntentKind(intent: context)
            if contextKind != .unknown {
                let row = language.transitionCounts[contextKind.rawValue] ?? [:]
                let rowTotal = row.values.reduce(0, +)
                transition = smoothingProbability(
                    count: row[intentKey] ?? 0,
                    total: rowTotal,
                    classes: classCount
                )
            } else {
                transition = prior
            }
        } else {
            transition = prior
        }

        let lexical = lexicalProbability(
            language: language,
            intentKey: intentKey,
            tokens: behaviorTokens(from: tokens)
        )

        let combined = (0.46 * prior) + (0.30 * transition) + (0.24 * lexical)
        let baseline = 1.0 / Double(classCount)
        let advantage = max(0, combined - baseline)
        return min(0.16, advantage * 0.9)
    }

    func suggestedQuickCommandKeys(
        lang: AppLang,
        context: AppVoiceCommandIntent?,
        limit: Int
    ) -> [String] {
        let rankedIntents = rankedIntentKinds(lang: lang, context: context, limit: max(limit * 3, 10))
        guard !rankedIntents.isEmpty else { return [] }

        var result: [String] = []
        result.reserveCapacity(limit)

        for intentKind in rankedIntents {
            guard let quickKey = quickCommandKey(for: intentKind) else { continue }
            if result.contains(quickKey) { continue }
            result.append(quickKey)
            if result.count >= limit { break }
        }

        return result
    }

    private func lexicalProbability(
        language: LanguageStats,
        intentKey: String,
        tokens: [String]
    ) -> Double {
        guard !tokens.isEmpty else { return 0.5 }

        let intentTokenMap = language.tokenCounts[intentKey] ?? [:]
        let intentTokenTotal = language.intentTokenTotals[intentKey] ?? 0
        let globalTokenMap = language.tokenCounts.values.reduce(into: [String: Int]()) { partial, item in
            for (token, value) in item {
                partial[token, default: 0] += value
            }
        }
        let globalTotal = globalTokenMap.values.reduce(0, +)
        let vocabulary = max(32, globalTokenMap.count)

        let scores = tokens.map { token -> Double in
            let local = smoothingProbability(
                count: intentTokenMap[token] ?? 0,
                total: intentTokenTotal,
                classes: vocabulary
            )
            let global = smoothingProbability(
                count: globalTokenMap[token] ?? 0,
                total: globalTotal,
                classes: vocabulary
            )
            let ratio = local / max(global, 0.00001)
            let normalized = (ratio - 0.8) / 2.4
            return min(1, max(0, normalized))
        }

        return scores.reduce(0, +) / Double(scores.count)
    }

    private func smoothingProbability(count: Int, total: Int, classes: Int) -> Double {
        let numerator = Double(count + 1)
        let denominator = Double(max(0, total) + max(1, classes))
        return numerator / max(denominator, 1.0)
    }

    private func rankedIntentKinds(
        lang: AppLang,
        context: AppVoiceCommandIntent?,
        limit: Int
    ) -> [AppVoiceIntentKind] {
        lock.lock()
        let language = statsByLanguage[lang.rawValue]
        lock.unlock()

        guard let language, language.totalObservations >= 6 else { return [] }

        let classCount = max(1, AppVoiceIntentKind.allCases.count - 1)
        let contextRow: [String: Int]
        if let context {
            let contextKind = AppVoiceIntentKind(intent: context)
            contextRow = language.transitionCounts[contextKind.rawValue] ?? [:]
        } else {
            contextRow = [:]
        }
        let contextRowTotal = contextRow.values.reduce(0, +)
        let hasContextHistory = contextRowTotal > 0

        let scored: [(kind: AppVoiceIntentKind, score: Double, count: Int)] = AppVoiceIntentKind.allCases.compactMap { kind in
            guard kind != .unknown else { return nil }

            let key = kind.rawValue
            let observedCount = language.intentCounts[key] ?? 0
            guard observedCount > 0 else { return nil }

            let prior = smoothingProbability(
                count: observedCount,
                total: language.totalObservations,
                classes: classCount
            )

            let score: Double
            if hasContextHistory {
                let transition = smoothingProbability(
                    count: contextRow[key] ?? 0,
                    total: contextRowTotal,
                    classes: classCount
                )
                score = (0.62 * prior) + (0.38 * transition)
            } else {
                score = prior
            }

            return (kind: kind, score: score, count: observedCount)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            .prefix(limit)
            .map { $0.kind }
    }

    private func quickCommandKey(for kind: AppVoiceIntentKind) -> String? {
        switch kind {
        case .addTask:
            return "assistant.quick.add"
        case .openTabToday, .openTabTasks:
            return "assistant.quick.tasks"
        case .summarizeMetricsToday, .summarizeMetricsWeek:
            return "assistant.quick.summary"
        case .startPomodoro:
            return "assistant.quick.pomodoro"
        case .pausePomodoro:
            return "assistant.quick.pause"
        case .resumePomodoro:
            return "assistant.quick.resume"
        case .startShortBreak, .startLongBreak, .openTabBreak:
            return "assistant.quick.break"
        case .openEyeExercise, .openTabEye:
            return "assistant.quick.eye"
        case .deleteTask, .completeTask, .openTabPomodoro, .openTabHealth, .openTabSettings, .stopPomodoro, .unknown:
            return nil
        }
    }

    private func behaviorTokens(from source: String) -> [String] {
        behaviorTokens(from: Set(source.split(separator: " ").map(String.init)))
    }

    private func behaviorTokens(from tokenSet: Set<String>) -> [String] {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "that", "this",
            "das", "und", "der", "die", "mit", "fur",
            "de", "la", "el", "los", "las", "con", "por",
            "и", "на", "по", "это", "как", "для", "что"
        ]

        return tokenSet
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && !stopWords.contains($0) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs < rhs }
                return lhs.count > rhs.count
            }
            .prefix(14)
            .map { $0 }
    }

    private func increment(_ dict: inout [String: Int], key: String) {
        dict[key, default: 0] += 1
    }

    private func incrementNested(_ dict: inout [String: [String: Int]], parent: String, key: String) {
        var nested = dict[parent] ?? [:]
        nested[key, default: 0] += 1
        dict[parent] = nested
    }

    private func applyDecay(_ language: inout LanguageStats, factor: Double) {
        func decay(_ value: Int) -> Int {
            Int((Double(value) * factor).rounded(.toNearestOrAwayFromZero))
        }

        language.totalObservations = max(0, decay(language.totalObservations))
        language.intentCounts = language.intentCounts.reduce(into: [:]) { partial, pair in
            let updated = decay(pair.value)
            if updated > 0 { partial[pair.key] = updated }
        }
        language.transitionCounts = language.transitionCounts.reduce(into: [String: [String: Int]]()) { partial, pair in
            let nested = pair.value.reduce(into: [String: Int]()) { nestedPartial, nestedPair in
                let updated = decay(nestedPair.value)
                if updated > 0 { nestedPartial[nestedPair.key] = updated }
            }
            if !nested.isEmpty { partial[pair.key] = nested }
        }
        language.tokenCounts = language.tokenCounts.reduce(into: [String: [String: Int]]()) { partial, pair in
            let nested = pair.value.reduce(into: [String: Int]()) { nestedPartial, nestedPair in
                let updated = decay(nestedPair.value)
                if updated > 0 { nestedPartial[nestedPair.key] = updated }
            }
            if !nested.isEmpty { partial[pair.key] = nested }
        }
        language.intentTokenTotals = language.intentTokenTotals.reduce(into: [:]) { partial, pair in
            let updated = decay(pair.value)
            if updated > 0 { partial[pair.key] = updated }
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: LanguageStats].self, from: data) else {
            statsByLanguage = [:]
            return
        }
        statsByLanguage = decoded
    }

    private func scheduleSave() {
        lock.lock()
        pendingSave?.cancel()
        let snapshot = statsByLanguage
        let work = DispatchWorkItem { [storageKey] in
            guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        pendingSave = work
        lock.unlock()
        saveQueue.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}

private final class AppEmbeddedAIInterpreter {
    static let shared = AppEmbeddedAIInterpreter()

    private let behaviorModel = AppVoiceBehaviorModel.shared

    private init() {}

    func interpret(normalizedText: String, lang: AppLang, context: AppVoiceCommandIntent? = nil) -> AppVoiceCommandIntent? {
        let prepared = Self.normalize(normalizedText)
        guard !prepared.isEmpty else { return nil }

        let features = FeatureSet(text: prepared, language: lang.nlLanguage)
        let candidates = scoreCandidates(features: features, lang: lang, context: context)
            .sorted(by: { $0.score > $1.score })
        guard let best = candidates.first else { return nil }
        guard best.score >= 0.62 else { return nil }
        if candidates.count > 1 {
            let second = candidates[1]
            if (best.score - second.score) < 0.05, best.score < 0.80 {
                return nil
            }
        }
        return best.intent
    }

    func observeSuccessfulCommand(
        transcript: String,
        intent: AppVoiceCommandIntent,
        context: AppVoiceCommandIntent?,
        lang: AppLang
    ) {
        let prepared = Self.normalize(transcript)
        guard !prepared.isEmpty else { return }
        behaviorModel.observe(
            transcript: prepared,
            intent: intent,
            context: context,
            lang: lang
        )
    }

    private struct Candidate {
        let intent: AppVoiceCommandIntent
        let score: Double
    }

    private struct FeatureSet {
        let text: String
        let tokens: Set<String>

        init(text: String, language: NLLanguage) {
            self.text = text
            var set = Set(text.split(separator: " ").map(String.init))

            let tagger = NLTagger(tagSchemes: [.lemma])
            tagger.string = text
            let range = text.startIndex..<text.endIndex
            tagger.setLanguage(language, range: range)
            tagger.enumerateTags(
                in: range,
                unit: .word,
                scheme: .lemma,
                options: [.omitWhitespace, .omitPunctuation, .joinNames]
            ) { tag, tokenRange in
                let token = String(text[tokenRange])
                let normalizedToken = AppEmbeddedAIInterpreter.normalize(token)
                if !normalizedToken.isEmpty {
                    set.insert(normalizedToken)
                }
                if let lemma = tag?.rawValue {
                    let normalizedLemma = AppEmbeddedAIInterpreter.normalize(lemma)
                    if !normalizedLemma.isEmpty {
                        set.insert(normalizedLemma)
                    }
                }
                return true
            }

            self.tokens = set
        }

        func containsAny(stems: [String]) -> Bool {
            stems.contains { stem in
                stemScore(stem) >= 0.65
            }
        }

        func score(stems: [String]) -> Double {
            let total = stems.reduce(0.0) { partial, stem in
                partial + stemScore(stem)
            }
            guard !stems.isEmpty else { return 0 }
            return total / Double(stems.count)
        }

        private func stemScore(_ stem: String) -> Double {
            let normalizedStem = AppEmbeddedAIInterpreter.normalize(stem)
            guard !normalizedStem.isEmpty else { return 0 }

            if text.contains(normalizedStem) {
                return 1.0
            }

            var best: Double = 0
            for token in tokens {
                if token.hasPrefix(normalizedStem) || normalizedStem.hasPrefix(token) {
                    best = max(best, 1.0)
                    continue
                }

                if AppEmbeddedAIInterpreter.fuzzyMatch(token: token, stem: normalizedStem) {
                    best = max(best, 0.72)
                }
            }
            return best
        }
    }

    private func scoreCandidates(features: FeatureSet, lang: AppLang, context: AppVoiceCommandIntent?) -> [Candidate] {
        var candidates: [Candidate] = []

        let taskWords = ["задач", "task", "aufgabe", "tarea"]
        let addWords = ["добав", "созда", "нов", "add", "create", "new", "hinzuf", "agregar"]
        let completeWords = ["заверш", "выполн", "отмет", "complete", "finish", "done", "erledig", "completar"]
        let deleteWords = ["удал", "delete", "remove", "losch", "entfern", "eliminar", "borrar"]
        let openWords = ["откро", "перейд", "покаж", "open", "show", "go", "offne", "abre"]
        let pomodoroWords = ["помодоро", "pomodoro", "focus", "фокус"]
        let startWords = ["запуст", "начн", "старт", "start", "run", "iniciar", "starte"]
        let pauseWords = ["пауза", "pause", "pausa", "anhalten"]
        let resumeWords = ["продолж", "возобнов", "resume", "continue", "fortsetzen", "reanudar"]
        let stopWords = ["стоп", "останов", "stop", "cancel", "stopp", "detener", "parar"]
        let shortBreakWords = ["коротк", "short", "klein", "corto"]
        let longBreakWords = ["длин", "больш", "long", "lange", "largo"]
        let breakWords = ["перерыв", "break", "pause", "descanso"]
        let eyeWords = ["глаз", "eyes", "eye", "augen", "ojos"]
        let summaryWords = [
            "сводк",
            "итог",
            "показател",
            "статистик",
            "прогресс",
            "summary",
            "metrics",
            "stats",
            "report",
            "zusammenfassung",
            "kennzahlen",
            "resumen"
        ]

        if features.containsAny(stems: summaryWords) {
            let period: AppVoiceMetricsPeriod
            if features.containsAny(stems: ["сегодня", "today", "heute", "hoy"]) {
                period = .today
            } else if features.containsAny(stems: ["недел", "week", "woche", "semana", "7 дн"]) {
                period = .week
            } else {
                period = .week
            }

            let score = 0.55 + (0.30 * features.score(stems: summaryWords))
            candidates.append(.init(intent: .summarizeMetrics(period: period), score: score))
        }

        if features.containsAny(stems: addWords), features.containsAny(stems: taskWords) {
            if let title = extractTaskTitle(from: features.text, mode: .add), !title.isEmpty {
                let category = detectCategory(in: features.text, lang: lang)
                let score = 0.62 + (0.18 * features.score(stems: addWords))
                candidates.append(.init(intent: .addTask(title: title, category: category), score: score))
            }
        }

        if features.containsAny(stems: completeWords), features.containsAny(stems: taskWords) {
            let title = extractTaskTitle(from: features.text, mode: .complete)
            let score = 0.62 + (0.18 * features.score(stems: completeWords))
            candidates.append(.init(intent: .completeTask(title: title), score: score))
        }

        if features.containsAny(stems: deleteWords), features.containsAny(stems: taskWords) {
            let title = extractTaskTitle(from: features.text, mode: .delete)
            let score = 0.62 + (0.18 * features.score(stems: deleteWords))
            candidates.append(.init(intent: .deleteTask(title: title), score: score))
        }

        if features.containsAny(stems: pauseWords), features.containsAny(stems: pomodoroWords) {
            let score = 0.68 + (0.16 * features.score(stems: pauseWords))
            candidates.append(.init(intent: .pausePomodoro, score: score))
        }

        if features.containsAny(stems: resumeWords), features.containsAny(stems: pomodoroWords) {
            let score = 0.68 + (0.16 * features.score(stems: resumeWords))
            candidates.append(.init(intent: .resumePomodoro, score: score))
        }

        if features.containsAny(stems: stopWords), features.containsAny(stems: pomodoroWords) {
            let score = 0.66 + (0.16 * features.score(stems: stopWords))
            candidates.append(.init(intent: .stopPomodoro, score: score))
        }

        if features.containsAny(stems: startWords), features.containsAny(stems: pomodoroWords) {
            let minutes = extractMinutes(from: features.text)
            let score = 0.66 + (0.16 * features.score(stems: startWords))
            candidates.append(.init(intent: .startPomodoro(minutes: minutes), score: score))
        }

        if features.containsAny(stems: startWords), features.containsAny(stems: breakWords) {
            if features.containsAny(stems: longBreakWords) {
                candidates.append(.init(intent: .startLongBreak, score: 0.74))
            } else if features.containsAny(stems: shortBreakWords) {
                candidates.append(.init(intent: .startShortBreak, score: 0.74))
            } else {
                candidates.append(.init(intent: .startShortBreak, score: 0.66))
            }
        }

        if features.containsAny(stems: eyeWords) && (features.containsAny(stems: openWords) || features.containsAny(stems: startWords)) {
            let score = 0.70 + (0.14 * features.score(stems: eyeWords))
            candidates.append(.init(intent: .openEyeExercise, score: score))
        }

        if features.containsAny(stems: openWords) {
            if let tab = detectTab(features: features) {
                let score = 0.64 + (0.20 * features.score(stems: openWords))
                candidates.append(.init(intent: .openTab(tab), score: score))
            }
        }

        return candidates.map { candidate in
            var boosted = candidate.score
            if let context {
                boosted += contextBoost(for: candidate.intent, context: context)
            }
            boosted += behaviorModel.probabilisticBoost(
                for: candidate.intent,
                tokens: features.tokens,
                context: context,
                lang: lang
            )
            return Candidate(intent: candidate.intent, score: min(1.0, max(0.0, boosted)))
        }
    }

    private enum TaskActionMode {
        case add
        case complete
        case delete
    }

    private func extractTaskTitle(from text: String, mode: TaskActionMode) -> String? {
        let prefixes: [String]
        switch mode {
        case .add:
            prefixes = [
                "добавь задачу",
                "добавить задачу",
                "создай задачу",
                "создать задачу",
                "новая задача",
                "add task",
                "create task",
                "new task",
                "aufgabe erstellen",
                "aufgabe hinzufugen",
                "agregar tarea",
                "crear tarea"
            ]
        case .complete:
            prefixes = [
                "заверши задачу",
                "выполни задачу",
                "отметь задачу",
                "complete task",
                "finish task",
                "mark task",
                "aufgabe erledigen",
                "completar tarea"
            ]
        case .delete:
            prefixes = [
                "удали задачу",
                "удалить задачу",
                "delete task",
                "remove task",
                "aufgabe loschen",
                "eliminar tarea",
                "borrar tarea"
            ]
        }

        let normalizedText = Self.normalize(text)
        for prefix in prefixes.sorted(by: { $0.count > $1.count }) {
            let normalizedPrefix = Self.normalize(prefix)
            guard let range = normalizedText.range(of: normalizedPrefix) else { continue }
            let suffix = String(normalizedText[range.upperBound...])
            let cleaned = sanitizeTaskTitle(suffix)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return nil
    }

    private func sanitizeTaskTitle(_ source: String) -> String {
        var cleaned = Self.normalize(source)
        let trims = [
            "пожалуйста ",
            "please ",
            "bitte ",
            "por favor ",
            "задачу ",
            "task ",
            "aufgabe ",
            "tarea "
        ]
        for trim in trims where cleaned.hasPrefix(trim) {
            cleaned.removeFirst(trim.count)
            break
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if cleaned.count > 120 {
            cleaned = String(cleaned.prefix(120)).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        return cleaned
    }

    private func detectTab(features: FeatureSet) -> AppTab? {
        let mapping: [(AppTab, [String])] = [
            (.tasks, ["задач", "tasks", "aufgabe", "tarea"]),
            (.pomodoro, ["помодоро", "pomodoro", "focus"]),
            (.break, ["перерыв", "break", "pause", "descanso"]),
            (.health, ["здоров", "health", "gesund", "salud"]),
            (.eye, ["глаз", "eyes", "augen", "ojos"]),
            (.settings, ["настро", "settings", "einstellungen", "ajustes"]),
            (.today, ["сегодн", "today", "heute", "hoy", "home", "inicio"])
        ]

        var best: (tab: AppTab, score: Double)?
        for (tab, keywords) in mapping {
            let score = features.score(stems: keywords)
            guard score > 0 else { continue }
            if best == nil || score > best!.score {
                best = (tab, score)
            }
        }
        return best?.tab
    }

    private func detectCategory(in text: String, lang: AppLang) -> TaskCategory {
        let rules: [(TaskCategory, [String])] = [
            (.work, ["работ", "проект", "клиент", "work", "job", "arbeit", "trabajo"]),
            (.study, ["учеб", "урок", "экзам", "study", "learn", "lernen", "estudio"]),
            (.health, ["здоров", "спорт", "трен", "дыхан", "health", "workout", "gesund", "salud"]),
            (.rest, ["отдых", "перерыв", "сон", "rest", "break", "ruhe", "descanso"]),
            (.home, ["дом", "уборк", "покупк", "home", "house", "haus", "hogar"])
        ]

        var bestMatch: (TaskCategory, Int) = (.other, 0)
        for (category, words) in rules {
            let score = words.reduce(0) { partial, word in
                partial + (text.contains(Self.normalize(word)) ? 1 : 0)
            }
            if score > bestMatch.1 {
                bestMatch = (category, score)
            }
        }

        if bestMatch.1 > 0 {
            return bestMatch.0
        }
        if lang == .en && text.contains("task") {
            return .work
        }
        return .other
    }

    private func extractMinutes(from text: String) -> Int? {
        guard let range = text.range(of: "\\b\\d{1,3}\\b", options: .regularExpression),
              let number = Int(text[range]) else {
            return nil
        }
        return max(5, min(120, number))
    }

    private func contextBoost(for intent: AppVoiceCommandIntent, context: AppVoiceCommandIntent) -> Double {
        switch (intent, context) {
        case (.pausePomodoro, .startPomodoro),
             (.pausePomodoro, .resumePomodoro),
             (.resumePomodoro, .pausePomodoro),
             (.resumePomodoro, .startPomodoro),
             (.stopPomodoro, .startPomodoro),
             (.stopPomodoro, .pausePomodoro),
             (.startPomodoro, .pausePomodoro),
             (.startPomodoro, .resumePomodoro),
             (.startShortBreak, .startPomodoro),
             (.startLongBreak, .startPomodoro):
            return 0.08

        case (.summarizeMetrics, .summarizeMetrics),
             (.openTab, .openTab):
            return 0.06

        default:
            return 0
        }
    }

    private static func fuzzyMatch(token: String, stem: String) -> Bool {
        guard token.count >= 3, stem.count >= 3 else { return false }
        let maxLen = max(token.count, stem.count)
        let distanceLimit: Int
        if maxLen <= 4 {
            distanceLimit = 1
        } else if maxLen <= 8 {
            distanceLimit = 2
        } else {
            distanceLimit = 3
        }
        return editDistanceWithin(token, stem, limit: distanceLimit)
    }

    private static func editDistanceWithin(_ lhs: String, _ rhs: String, limit: Int) -> Bool {
        let a = Array(lhs)
        let b = Array(rhs)
        if abs(a.count - b.count) > limit { return false }

        var previous = Array(0...b.count)
        for (i, ac) in a.enumerated() {
            var current = Array(repeating: 0, count: b.count + 1)
            current[0] = i + 1
            var rowMin = current[0]

            for (j, bc) in b.enumerated() {
                let cost = (ac == bc) ? 0 : 1
                let deletion = previous[j + 1] + 1
                let insertion = current[j] + 1
                let substitution = previous[j] + cost
                let value = min(deletion, min(insertion, substitution))
                current[j + 1] = value
                rowMin = min(rowMin, value)
            }

            if rowMin > limit { return false }
            previous = current
        }

        return previous[b.count] <= limit
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\s:]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension AppLang {
    var nlLanguage: NLLanguage {
        switch self {
        case .ru: return .russian
        case .en: return .english
        case .de: return .german
        case .es: return .spanish
        }
    }
}

@MainActor
final class AppVoiceAssistantCenter: NSObject, ObservableObject {
    @Published private(set) var state: AppVoiceAssistantState = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var lastResponse: String = ""
    @Published private(set) var pendingCommand: AppVoiceCommandEnvelope?
    @Published private(set) var quickCommandKeys: [String] = []
    @Published private(set) var hasPersonalizedSuggestions: Bool = false

    private var recognizer: SFSpeechRecognizer?
    private var recognizerCache: [String: SFSpeechRecognizer] = [:]
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isTapInstalled = false
    private var isStoppingManually = false
    private var isBootstrappingRecognition = false
    private var audioSessionDeactivateTask: Task<Void, Never>?
    private var silenceCommitTask: Task<Void, Never>?
    private var lastPartialTranscript = ""
    private var lastResolvedIntent: AppVoiceCommandIntent?

    private let silenceCommitDelay: UInt64 = 1_150_000_000

    private let synthesizer = AVSpeechSynthesizer()
    private let behaviorModel = AppVoiceBehaviorModel.shared
    private static let defaultQuickCommandKeys = [
        "assistant.quick.add",
        "assistant.quick.tasks",
        "assistant.quick.summary",
        "assistant.quick.pomodoro",
        "assistant.quick.pause",
        "assistant.quick.resume",
        "assistant.quick.break",
        "assistant.quick.eye"
    ]

    var isListening: Bool {
        if case .listening = state { return true }
        return false
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        quickCommandKeys = Self.defaultQuickCommandKeys
    }

    deinit {
        audioSessionDeactivateTask?.cancel()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    func startListening(lang: AppLang) {
        guard !isListening, !isBootstrappingRecognition else { return }
        isBootstrappingRecognition = true
        AppVoiceAssistantFeedback.startListeningCue()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        state = .processing
        transcript = ""
        lastPartialTranscript = ""
        silenceCommitTask?.cancel()
        silenceCommitTask = nil

        Task {
            defer { isBootstrappingRecognition = false }
            let canProceed = await ensurePermissions(lang: lang)
            guard canProceed else { return }

            do {
                try beginRecognition(lang: lang)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func stopListeningAndCommit(lang: AppLang) {
        guard isListening else { return }
        let text = transcript
        silenceCommitTask?.cancel()
        silenceCommitTask = nil
        teardownRecognition()
        handleRecognizedText(text, lang: lang)
    }

    func cancelListening() {
        silenceCommitTask?.cancel()
        silenceCommitTask = nil
        teardownRecognition()
        if case .speaking = state {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if case .processing = state {
            state = .idle
        }
        if case .listening = state {
            state = .idle
        }
    }

    func runTextCommand(_ text: String, lang: AppLang) {
        transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        handleRecognizedText(transcript, lang: lang)
    }

    func refreshSuggestions(lang: AppLang) {
        let learnedKeys = behaviorModel.suggestedQuickCommandKeys(
            lang: lang,
            context: lastResolvedIntent,
            limit: 4
        )

        var merged: [String] = learnedKeys
        for key in Self.defaultQuickCommandKeys where !merged.contains(key) {
            merged.append(key)
        }

        quickCommandKeys = merged
        hasPersonalizedSuggestions = !learnedKeys.isEmpty
    }

    func completePendingCommand(response: String, lang: AppLang) {
        pendingCommand = nil
        lastResponse = response
        speak(response, lang: lang)
    }

    func recordCommandOutcome(
        intent: AppVoiceCommandIntent,
        transcript: String,
        wasSuccessful: Bool,
        lang: AppLang
    ) {
        guard wasSuccessful else { return }
        guard intent != .unknown else { return }

        let prepared = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prepared.isEmpty else { return }

        AppEmbeddedAIInterpreter.shared.observeSuccessfulCommand(
            transcript: prepared,
            intent: intent,
            context: lastResolvedIntent,
            lang: lang
        )
        lastResolvedIntent = intent
        refreshSuggestions(lang: lang)
    }

    private func handleRecognizedText(_ text: String, lang: AppLang) {
        let prepared = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prepared.isEmpty else {
            let unknown = L10n.tr("assistant.response.unknown", lang)
            lastResponse = unknown
            state = .idle
            return
        }

        state = .processing
        let intent = AppVoiceCommandParser.parse(prepared, lang: lang, context: lastResolvedIntent)
        pendingCommand = AppVoiceCommandEnvelope(
            transcript: prepared,
            intent: intent
        )
    }

    private func ensurePermissions(lang: AppLang) async -> Bool {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechStatus = .authorized
        default:
            speechStatus = await requestSpeechAuthorization()
        }

        guard speechStatus == .authorized else {
            state = .error(L10n.tr("assistant.permission.speech", lang))
            return false
        }

        let micAllowed: Bool
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                micAllowed = true
            case .denied:
                micAllowed = false
            case .undetermined:
                micAllowed = await requestMicrophonePermission()
            @unknown default:
                micAllowed = await requestMicrophonePermission()
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                micAllowed = true
            case .denied:
                micAllowed = false
            case .undetermined:
                micAllowed = await requestMicrophonePermission()
            @unknown default:
                micAllowed = await requestMicrophonePermission()
            }
        }
        guard micAllowed else {
            state = .error(L10n.tr("assistant.permission.mic", lang))
            return false
        }

        return true
    }

    private func recognizer(for lang: AppLang) -> SFSpeechRecognizer? {
        let localeIdentifier = lang.localeIdentifier
        if let cached = recognizerCache[localeIdentifier] {
            return cached
        }

        guard let created = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            return nil
        }
        recognizerCache[localeIdentifier] = created
        return created
    }

    private func beginRecognition(lang: AppLang) throws {
        teardownRecognition()
        silenceCommitTask?.cancel()
        silenceCommitTask = nil
        lastPartialTranscript = ""
        audioSessionDeactivateTask?.cancel()
        audioSessionDeactivateTask = nil

        guard let recognizer = recognizer(for: lang) else {
            state = .error(L10n.tr("assistant.permission.unavailable", lang))
            return
        }

        guard recognizer.isAvailable else {
            state = .error(L10n.tr("assistant.permission.unavailable", lang))
            return
        }

        self.recognizer = recognizer

        try configureAudioSessionForRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        isTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()

        isStoppingManually = false
        state = .listening

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let recognized = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.handleRecognitionProgress(recognized, isFinal: result.isFinal, lang: lang)
                }
                return
            }

            if let error, !self.isStoppingManually {
                Task { @MainActor in
                    self.silenceCommitTask?.cancel()
                    self.silenceCommitTask = nil
                    self.teardownRecognition()
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    private func handleRecognitionProgress(_ recognized: String, isFinal: Bool, lang: AppLang) {
        transcript = recognized

        if isFinal {
            silenceCommitTask?.cancel()
            silenceCommitTask = nil
            teardownRecognition()
            handleRecognizedText(recognized, lang: lang)
            return
        }

        let prepared = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prepared.isEmpty else { return }

        lastPartialTranscript = prepared
        armSilenceCommit(lang: lang)
    }

    private func armSilenceCommit(lang: AppLang) {
        silenceCommitTask?.cancel()
        let snapshot = lastPartialTranscript

        silenceCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: silenceCommitDelay)
            guard !Task.isCancelled, isListening else { return }

            let current = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !current.isEmpty, current == snapshot else { return }

            teardownRecognition()
            handleRecognizedText(current, lang: lang)
        }
    }

    private func teardownRecognition() {
        isStoppingManually = true

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        silenceCommitTask?.cancel()
        silenceCommitTask = nil

        scheduleAudioSessionDeactivation()
    }

    private func scheduleAudioSessionDeactivation() {
        audioSessionDeactivateTask?.cancel()
        audioSessionDeactivateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            guard !audioEngine.isRunning, recognitionTask == nil else { return }
            guard !synthesizer.isSpeaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func speak(_ text: String, lang: AppLang) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            state = .idle
            return
        }

        configureAudioSessionForSpeechPlayback()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AppVoiceSelector.preferredVoice(for: lang)
            ?? AVSpeechSynthesisVoice(language: lang.speechLanguageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.06
        utterance.prefersAssistiveTechnologySettings = true

        synthesizer.speak(utterance)
        state = .speaking
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func configureAudioSessionForRecognition() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSessionForSpeechPlayback() {
        audioSessionDeactivateTask?.cancel()
        audioSessionDeactivateTask = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

private enum AppVoiceAssistantFeedback {
    static func startListeningCue() {
        #if os(iOS)
        let haptic = UIImpactFeedbackGenerator(style: .soft)
        haptic.prepare()
        haptic.impactOccurred(intensity: 0.55)
        AudioServicesPlaySystemSound(1104)
        #endif
    }
}

extension AppVoiceAssistantCenter: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if case .speaking = self.state {
                self.state = .idle
            }
            self.scheduleAudioSessionDeactivation()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if case .speaking = self.state {
                self.state = .idle
            }
            self.scheduleAudioSessionDeactivation()
        }
    }
}

struct AppVoiceAssistantSheet: View {
    @ObservedObject var assistant: AppVoiceAssistantCenter
    let lang: AppLang
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private struct QuickCommandItem: Identifiable {
        let key: String
        let icon: String
        let tone: Color

        var id: String { key }
    }

    private var commandCatalog: [String: QuickCommandItem] {
        Dictionary(uniqueKeysWithValues: allQuickCommands.map { ($0.key, $0) })
    }

    private var statusText: String {
        switch assistant.state {
        case .idle:
            return s("assistant.state.ready")
        case .listening:
            return s("assistant.state.listening")
        case .processing:
            return s("assistant.state.processing")
        case .speaking:
            return s("assistant.state.speaking")
        case .error(let message):
            return L10n.fmt("assistant.state.error", lang, message)
        }
    }

    private var allQuickCommands: [QuickCommandItem] {
        [
            .init(key: "assistant.quick.add", icon: "plus.circle.fill", tone: Color(hex: 0x34C7FF)),
            .init(key: "assistant.quick.tasks", icon: "checklist", tone: Color(hex: 0x64D2FF)),
            .init(key: "assistant.quick.summary", icon: "chart.bar.xaxis", tone: Color(hex: 0x5AC8FA)),
            .init(key: "assistant.quick.pomodoro", icon: "timer", tone: Color(hex: 0x30B0FF)),
            .init(key: "assistant.quick.pause", icon: "pause.circle.fill", tone: Color(hex: 0xFF9F0A)),
            .init(key: "assistant.quick.resume", icon: "play.circle.fill", tone: Color(hex: 0x30D158)),
            .init(key: "assistant.quick.break", icon: "cup.and.saucer.fill", tone: Color(hex: 0x5AC8FA)),
            .init(key: "assistant.quick.eye", icon: "eye.fill", tone: Color(hex: 0x64D2FF))
        ]
    }

    private var quickCommands: [QuickCommandItem] {
        let sourceKeys = assistant.quickCommandKeys.isEmpty
            ? allQuickCommands.map(\.key)
            : assistant.quickCommandKeys
        var result: [QuickCommandItem] = []
        result.reserveCapacity(allQuickCommands.count)

        for key in sourceKeys {
            guard let item = commandCatalog[key] else { continue }
            if result.contains(where: { $0.key == key }) { continue }
            result.append(item)
        }

        for fallback in allQuickCommands where !result.contains(where: { $0.key == fallback.key }) {
            result.append(fallback)
        }
        return result
    }

    private var suggestedCommands: [QuickCommandItem] {
        Array(quickCommands.prefix(4))
    }

    private var quickCommandColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)
                liquidAmbient

                ScrollView {
                    LazyVStack(spacing: 12) {
                        heroCard
                        suggestionsCard
                        controlsCard
                        quickCommandsCard
                        conversationCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(s("assistant.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(s("assistant.button.close")) {
                        dismiss()
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
        .onAppear {
            assistant.refreshSuggestions(lang: lang)
        }
        .onDisappear {
            assistant.cancelListening()
        }
    }

    private var liquidAmbient: some View {
        let tones = assistant.state.liquidTones
        return ZStack {
            Circle()
                .fill(tones[0].opacity(reduceTransparency ? 0.10 : 0.22))
                .frame(width: 260, height: 260)
                .blur(radius: reduceTransparency ? 0 : 56)
                .offset(x: -138, y: -305)

            Circle()
                .fill(tones[1].opacity(reduceTransparency ? 0.08 : 0.20))
                .frame(width: 230, height: 230)
                .blur(radius: reduceTransparency ? 0 : 50)
                .offset(x: 155, y: -185)
        }
        .allowsHitTesting(false)
    }

    private var heroCard: some View {
        GlassCard(padding: 16, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    LiquidAssistantCore(
                        state: assistant.state,
                        reduceMotion: reduceMotion,
                        reduceTransparency: reduceTransparency
                    )
                    .frame(width: 92, height: 92)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(s("assistant.title"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(DS.text(0.96))
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Label(statusText, systemImage: assistant.state.liquidIcon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.text(0.90))
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(DS.glassFill(0.10))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            assistant.state.liquidTones[0].opacity(0.18),
                                                            assistant.state.liquidTones[1].opacity(0.08)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(DS.glassStroke(0.16), lineWidth: 1)
                                        )
                                )
                        }

                        Text(s("assistant.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(DS.text(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(s("assistant.description"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    LiquidMetaPill(
                        title: assistant.isListening ? s("assistant.button.stop") : s("assistant.button.start"),
                        icon: assistant.isListening ? "stop.circle.fill" : "mic.circle.fill",
                        tone: assistant.state.liquidTones[0]
                    )

                    LiquidMetaPill(
                        title: s("assistant.quick.title"),
                        icon: "sparkles",
                        tone: assistant.state.liquidTones[1]
                    )
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var conversationCard: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .lightweight) {
            VStack(spacing: 10) {
                LiquidAssistantBubble(
                    title: s("assistant.transcript.title"),
                    text: assistant.transcript.isEmpty ? s("assistant.transcript.empty") : assistant.transcript,
                    icon: "waveform",
                    tone: assistant.state.liquidTones[0],
                    isPlaceholder: assistant.transcript.isEmpty,
                    isOutgoing: false
                )

                LiquidAssistantBubble(
                    title: s("assistant.response.title"),
                    text: assistant.lastResponse.isEmpty ? s("assistant.response.unknown") : assistant.lastResponse,
                    icon: "sparkles",
                    tone: assistant.state.liquidTones[1],
                    isPlaceholder: assistant.lastResponse.isEmpty,
                    isOutgoing: true
                )
            }
        }
    }

    private var quickCommandsCard: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                Text(s("assistant.quick.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.66))

                LazyVGrid(columns: quickCommandColumns, spacing: 10) {
                    ForEach(quickCommands) { command in
                        LiquidCommandTile(
                            title: s(command.key),
                            icon: command.icon,
                            tone: command.tone
                        ) {
                            assistant.runTextCommand(s(command.key), lang: lang)
                        }
                    }
                }
            }
        }
    }

    private var suggestionsCard: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                Text(s("assistant.suggested.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.66))

                Text(
                    assistant.hasPersonalizedSuggestions
                    ? s("assistant.suggested.personalized")
                    : s("assistant.suggested.learning")
                )
                .font(.caption2)
                .foregroundStyle(DS.text(0.58))
                .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: quickCommandColumns, spacing: 10) {
                    ForEach(suggestedCommands) { command in
                        LiquidCommandTile(
                            title: s(command.key),
                            icon: command.icon,
                            tone: command.tone
                        ) {
                            assistant.runTextCommand(s(command.key), lang: lang)
                        }
                    }
                }
            }
        }
    }

    private var controlsCard: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .full) {
            VStack(spacing: 12) {
                LiquidPrimaryVoiceButton(
                    title: assistant.isListening ? s("assistant.button.stop") : s("assistant.button.start"),
                    subtitle: statusText,
                    icon: assistant.isListening ? "stop.fill" : "mic.fill",
                    tones: assistant.state.liquidTones,
                    isActive: assistant.state.isActive,
                    reduceMotion: reduceMotion
                ) {
                    if assistant.isListening {
                        assistant.stopListeningAndCommit(lang: lang)
                    } else {
                        assistant.startListening(lang: lang)
                    }
                }

                Text(s("assistant.hint.tap_hold"))
                    .font(.caption)
                    .foregroundStyle(DS.text(0.62))
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    dismiss()
                } label: {
                    Label(s("assistant.button.close"), systemImage: "xmark")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }
}

struct VoiceAssistantLauncherButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var pulse = false
    @State private var isPressed = false
    @State private var pressStart: Date?
    @State private var didTriggerLongPress = false
    @State private var didTriggerTouchDownTap = false

    let title: String
    let state: AppVoiceAssistantState
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let holdThreshold: TimeInterval = 0.42

    private var launcherScale: CGFloat {
        if isPressed { return DS.pressScale }
        return state.isActive ? 1.02 : 1.0
    }

    var body: some View {
        ZStack {
            if state.isActive && !reduceMotion {
                Circle()
                    .stroke(state.liquidTones[0].opacity(0.40), lineWidth: 1.2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulse ? 1.24 : 0.92)
                    .opacity(pulse ? 0.0 : 0.55)
            }

            Circle()
                .fill(state.liquidGradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .fill(DS.liquidSheen)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )

            Image(systemName: state.isActive ? "waveform.and.mic" : "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .contentShape(Circle())
        .shadow(color: state.liquidTones[0].opacity(reduceTransparency ? 0.18 : 0.42), radius: state.isActive ? 14 : 8, x: 0, y: 6)
        .scaleEffect(launcherScale)
        .animation(reduceMotion ? nil : DS.motionQuick, value: state.isActive)
        .animation(reduceMotion ? nil : DS.motionQuick, value: isPressed)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressStart == nil {
                        pressStart = Date()
                        isPressed = true
                        didTriggerLongPress = false
                        didTriggerTouchDownTap = false

                        if !state.isActive {
                            didTriggerTouchDownTap = true
                            DS.hapticSoft()
                            onTap()
                        }
                    }
                    guard let pressStart, !didTriggerLongPress else { return }
                    if Date().timeIntervalSince(pressStart) >= holdThreshold {
                        didTriggerLongPress = true
                        isPressed = false
                        DS.hapticSoft()
                        onLongPress()
                    }
                }
                .onEnded { _ in
                    let isLong = didTriggerLongPress
                    pressStart = nil
                    didTriggerLongPress = false
                    isPressed = false
                    let didTapOnTouchDown = didTriggerTouchDownTap
                    didTriggerTouchDownTap = false
                    guard !isLong, !didTapOnTouchDown else { return }
                    DS.hapticSoft()
                    onTap()
                }
        )
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .animation(
            reduceMotion
            ? nil
            : .easeOut(duration: 1.25).repeatForever(autoreverses: false),
            value: pulse
        )
    }
}

private extension AppVoiceAssistantState {
    var isActive: Bool {
        switch self {
        case .listening, .processing, .speaking:
            return true
        case .idle, .error:
            return false
        }
    }

    var liquidIcon: String {
        switch self {
        case .idle: return "waveform.and.mic"
        case .listening: return "mic.fill"
        case .processing: return "sparkles"
        case .speaking: return "waveform"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var liquidTones: [Color] {
        switch self {
        case .idle:
            return [Color(hex: 0x5AC8FA), Color(hex: 0x0A84FF), Color(hex: 0x77E6FF)]
        case .listening:
            return [Color(hex: 0x0A84FF), Color(hex: 0x30B0FF), Color(hex: 0x78D9FF)]
        case .processing:
            return [Color(hex: 0x64D2FF), Color(hex: 0x30D6C2), Color(hex: 0x34C7FF)]
        case .speaking:
            return [Color(hex: 0x34C7FF), Color(hex: 0x0A84FF), Color(hex: 0x4D9EFF)]
        case .error:
            return [Color(hex: 0xFF6B6B), Color(hex: 0xFF453A), Color(hex: 0xFF9F8C)]
        }
    }

    var liquidGradient: LinearGradient {
        LinearGradient(
            colors: [liquidTones[0], liquidTones[1], liquidTones[2]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct LiquidAssistantCore: View {
    let state: AppVoiceAssistantState
    let reduceMotion: Bool
    let reduceTransparency: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if state.isActive && !reduceMotion {
                Circle()
                    .stroke(state.liquidTones[0].opacity(0.36), lineWidth: 1.3)
                    .scaleEffect(pulse ? 1.35 : 0.95)
                    .opacity(pulse ? 0.0 : 0.65)
            }

            Circle()
                .fill(state.liquidGradient)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.32), .clear],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 54
                            )
                        )
                )
                .overlay(
                    Circle()
                        .fill(DS.liquidSheen)
                        .opacity(reduceTransparency ? 0.40 : 0.68)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.30), lineWidth: 1)
                )
                .shadow(
                    color: state.liquidTones[0].opacity(reduceTransparency ? 0.14 : 0.34),
                    radius: 12,
                    x: 0,
                    y: 7
                )

            Image(systemName: state.liquidIcon)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .animation(
            reduceMotion
            ? nil
            : .easeOut(duration: 1.45).repeatForever(autoreverses: false),
            value: pulse
        )
    }
}

private struct LiquidAssistantBubble: View {
    let title: String
    let text: String
    let icon: String
    let tone: Color
    let isPlaceholder: Bool
    let isOutgoing: Bool

    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tone.opacity(0.20))
                        .overlay(
                            Circle()
                                .stroke(DS.glassStroke(0.18), lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.text(0.90))
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.68))
                        .singleLine()

                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(isPlaceholder ? DS.text(0.60) : DS.text(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.glassFill(isOutgoing ? 0.11 : 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tone.opacity(0.18), Color.clear],
                                    startPoint: isOutgoing ? .trailing : .leading,
                                    endPoint: isOutgoing ? .leading : .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}

private struct LiquidMetaPill: View {
    let title: String
    let icon: String
    let tone: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.text(0.90))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.88))
                .singleLine()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(DS.glassFill(0.10))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tone.opacity(0.18), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DS.glassStroke(0.15), lineWidth: 1)
                )
        )
    }
}

private struct LiquidCommandTile: View {
    let title: String
    let icon: String
    let tone: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tone.opacity(0.22))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.text(0.95))
                }
                .frame(width: 24, height: 24)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.90))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tone.opacity(0.18), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DS.glassStroke(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct LiquidPrimaryVoiceButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tones: [Color]
    let isActive: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tones[0], tones[1]],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.30), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.96))
                        .singleLine()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.text(0.68))
                        .singleLine()
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.78))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tones[0].opacity(0.20), tones[1].opacity(0.10), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DS.glassStroke(0.17), lineWidth: 1)
                    )
            )
            .scaleEffect(isActive ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : DS.motionQuick, value: isActive)
    }
}
