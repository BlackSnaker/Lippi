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
    case addScheduledTask(title: String, category: TaskCategory, dueDate: Date)
    case completeTask(title: String?)
    case reopenTask(title: String?)
    case deleteTask(title: String?)
    case rescheduleTask(title: String?, dueDate: Date)
    case openTab(AppTab)
    case openCalendar
    case startPomodoro(minutes: Int?)
    case pausePomodoro
    case resumePomodoro
    case startShortBreak
    case startLongBreak
    case stopPomodoro
    case openEyeExercise
    case summarizeMetrics(period: AppVoiceMetricsPeriod)
    case openSmartGoals
    case createSmartGoal(description: String?)
    case showSmartGoalProgress
    case showCareRecommendation
    case logCareAction(LippiCareAction)
    case showCapabilities
    case clarifyAction(topic: String)
    case unknown
}

private enum AppVoiceIntentKind: String, Codable, CaseIterable {
    case addTask
    case addScheduledTask
    case completeTask
    case reopenTask
    case deleteTask
    case rescheduleTask
    case openTabToday
    case openTabTasks
    case openTabPomodoro
    case openTabBreak
    case openTabHealth
    case openTabEye
    case openTabSettings
    case openCalendar
    case startPomodoro
    case pausePomodoro
    case resumePomodoro
    case startShortBreak
    case startLongBreak
    case stopPomodoro
    case openEyeExercise
    case summarizeMetricsToday
    case summarizeMetricsWeek
    case openSmartGoals
    case createSmartGoal
    case showSmartGoalProgress
    case showCareRecommendation
    case logMeal
    case logMovement
    case logWater
    case showCapabilities
    case clarifyAction
    case unknown

    init(intent: AppVoiceCommandIntent) {
        switch intent {
        case .addTask:
            self = .addTask
        case .addScheduledTask:
            self = .addScheduledTask
        case .completeTask:
            self = .completeTask
        case .reopenTask:
            self = .reopenTask
        case .deleteTask:
            self = .deleteTask
        case .rescheduleTask:
            self = .rescheduleTask
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
        case .openCalendar:
            self = .openCalendar
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
        case .openSmartGoals:
            self = .openSmartGoals
        case .createSmartGoal:
            self = .createSmartGoal
        case .showSmartGoalProgress:
            self = .showSmartGoalProgress
        case .showCareRecommendation:
            self = .showCareRecommendation
        case .logCareAction(let action):
            switch action {
            case .logMeal: self = .logMeal
            case .logMovement: self = .logMovement
            case .logWater: self = .logWater
            case .openEyes: self = .openEyeExercise
            case .openRecovery: self = .openTabBreak
            case .openGoal: self = .openSmartGoals
            case .none: self = .unknown
            }
        case .showCapabilities:
            self = .showCapabilities
        case .clarifyAction:
            self = .clarifyAction
        case .unknown:
            self = .unknown
        }
    }
}

struct AppVoiceCommandEnvelope: Identifiable, Equatable {
    let id = UUID()
    let transcript: String
    let intents: [AppVoiceCommandIntent]

    var intent: AppVoiceCommandIntent { intents.first ?? .unknown }

    init(transcript: String, intent: AppVoiceCommandIntent) {
        self.transcript = transcript
        self.intents = [intent]
    }

    init(transcript: String, intents: [AppVoiceCommandIntent]) {
        self.transcript = transcript
        self.intents = intents.isEmpty ? [.unknown] : intents
    }
}

enum AppVoiceCommandParser {
    static func parse(
        _ text: String,
        lang: AppLang,
        context: AppVoiceCommandIntent? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AppVoiceCommandIntent {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return .unknown }

        return parseSingle(
            normalized,
            lang: lang,
            contextHistory: context.map { [$0] } ?? [],
            now: now,
            calendar: calendar
        )
    }

    static func parseAll(
        _ text: String,
        lang: AppLang,
        contextHistory: [AppVoiceCommandIntent] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [AppVoiceCommandIntent] {
        let parts = splitCompoundRequest(text)
        guard !parts.isEmpty else { return [.unknown] }

        var rollingContext = contextHistory
        var intents: [AppVoiceCommandIntent] = []
        for part in parts {
            let normalized = normalize(part)
            guard !normalized.isEmpty else { continue }
            let intent = parseSingle(
                normalized,
                lang: lang,
                contextHistory: rollingContext,
                now: now,
                calendar: calendar
            )
            intents.append(intent)
            if intent != .unknown {
                rollingContext.append(intent)
                if rollingContext.count > 8 {
                    rollingContext.removeFirst(rollingContext.count - 8)
                }
            }
        }
        return intents.isEmpty ? [.unknown] : intents
    }

    private static func parseSingle(
        _ normalized: String,
        lang: AppLang,
        contextHistory: [AppVoiceCommandIntent],
        now: Date,
        calendar: Calendar
    ) -> AppVoiceCommandIntent {
        let context = contextHistory.last

        if let referenceIntent = resolveConversationReference(
            in: normalized,
            lang: lang,
            contextHistory: contextHistory,
            now: now,
            calendar: calendar
        ) {
            return referenceIntent
        }

        if let contextualIntent = resolveContextualIntent(
            in: normalized,
            lang: lang,
            context: context
        ) {
            return contextualIntent
        }

        if isCapabilitiesRequest(normalized) {
            return .showCapabilities
        }

        if let careAction = detectCareLogAction(in: normalized) {
            return .logCareAction(careAction)
        }

        if isCareRecommendationRequest(normalized) {
            return .showCareRecommendation
        }

        if isOpenCalendarRequest(normalized) {
            return .openCalendar
        }

        if isRescheduleTask(normalized),
           let temporal = AppVoiceTemporalParser.resolve(
                in: normalized,
                lang: lang,
                now: now,
                calendar: calendar
            ) {
            return .rescheduleTask(
                title: extractRescheduledTaskTitle(from: normalized, lang: lang),
                dueDate: temporal.dueDate
            )
        }

        if isReopenTask(normalized) {
            return .reopenTask(
                title: extractFlexibleTaskTitle(
                    from: normalized,
                    actionStems: reopenTaskActionStems
                )
            )
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

        if isSmartGoalProgressRequest(normalized) {
            return .showSmartGoalProgress
        }

        if isSmartGoalCreationRequest(normalized) {
            return .createSmartGoal(
                description: extractSmartGoalDescription(from: normalized)
            )
        }

        if isOpenSmartGoalsRequest(normalized) {
            return .openSmartGoals
        }

        if let period = detectMetricsSummaryPeriod(in: normalized) {
            return .summarizeMetrics(period: period)
        }

        if let taskTitle = extractSuffix(in: normalized, prefixes: addTaskPrefixes) {
            return taskCreationIntent(
                title: taskTitle,
                sourceText: normalized,
                lang: lang,
                now: now,
                calendar: calendar
            )
        }

        if let taskTitle = extractFlexibleTaskTitle(
            from: normalized,
            actionStems: addTaskActionStems
        ) {
            return taskCreationIntent(
                title: taskTitle,
                sourceText: normalized,
                lang: lang,
                now: now,
                calendar: calendar
            )
        }

        if isCompleteTask(normalized) {
            return .completeTask(
                title: extractSuffix(in: normalized, prefixes: completeTaskPrefixes)
                    ?? extractFlexibleTaskTitle(
                        from: normalized,
                        actionStems: completeTaskActionStems
                    )
            )
        }

        if isDeleteTask(normalized) {
            return .deleteTask(
                title: extractSuffix(in: normalized, prefixes: deleteTaskPrefixes)
                    ?? extractFlexibleTaskTitle(
                        from: normalized,
                        actionStems: deleteTaskActionStems
                    )
            )
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

        if let goal = implicitSmartGoalDescription(from: normalized) {
            return .createSmartGoal(description: goal)
        }

        let topic = cleanActionPayload(normalized)
        return topic.split(separator: " ").count >= 2
            ? .clarifyAction(topic: topic)
            : .unknown
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

    private static func splitCompoundRequest(_ text: String) -> [String] {
        var prepared = text
        let marker = " __lippi_next_command__ "
        let boundaryPatterns = [
            #"\s*;\s*"#,
            #"\s+а\s+потом\s+"#,
            #"\s+и\s+потом\s+"#,
            #"\s+после\s+этого\s+"#,
            #"\s+затем\s+"#,
            #"\s+and\s+then\s+"#,
            #"\s+after\s+that\s+"#,
            #"\s+then\s+"#,
            #"\s+und\s+dann\s+"#,
            #"\s+danach\s+"#,
            #"\s+anschliessend\s+"#,
            #"\s+y\s+luego\s+"#,
            #"\s+despues\s+"#
        ]
        for pattern in boundaryPatterns {
            prepared = prepared.replacingOccurrences(
                of: pattern,
                with: marker,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let actionBoundary = #"\s+(?:и|а|and|und|y)\s+(?=(?:добав|созд|запиш|откро|покаж|запуст|начн|постав|продолж|останов|удал|заверш|выполн|перенес|перен|отмет|add|create|open|show|start|pause|resume|stop|delete|complete|move|reschedule|offne|zeig|starte|losch|abre|muestra|inicia|elimina))"#
        prepared = prepared.replacingOccurrences(
            of: actionBoundary,
            with: marker,
            options: [.regularExpression, .caseInsensitive]
        )

        return prepared
            .components(separatedBy: marker)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func taskCreationIntent(
        title: String,
        sourceText: String,
        lang: AppLang,
        now: Date,
        calendar: Calendar
    ) -> AppVoiceCommandIntent {
        let temporal = AppVoiceTemporalParser.resolve(
            in: sourceText,
            lang: lang,
            now: now,
            calendar: calendar
        )
        let preparedTitle = temporal.map { _ in
            AppVoiceTemporalParser.removingTemporalPhrases(from: title, lang: lang)
        } ?? title
        let cleanedTitle = cleanActionPayload(preparedTitle)
        let category = detectCategory(in: cleanedTitle, lang: lang)

        guard let temporal else {
            return .addTask(title: cleanedTitle, category: category)
        }
        return .addScheduledTask(
            title: cleanedTitle,
            category: category,
            dueDate: temporal.dueDate
        )
    }

    private static func isCapabilitiesRequest(_ text: String) -> Bool {
        containsAny(
            text,
            keywords: [
                "что ты умеешь", "чем ты можешь помочь", "какие команды", "твои возможности",
                "what can you do", "how can you help", "commands", "capabilities",
                "was kannst du", "welche befehle", "funktionen",
                "que puedes hacer", "como puedes ayudar", "comandos"
            ]
        )
    }

    private static func detectCareLogAction(in text: String) -> LippiCareAction? {
        let logWords = [
            "отмет", "запиш", "зафикс", "я выпил", "я попил", "я поел", "я перекусил",
            "я прошелся", "я прогулялся", "я размялся", "готово",
            "log", "record", "i drank", "i had water", "i ate", "i walked", "done",
            "eintragen", "getrunken", "gegessen", "gegangen",
            "registr", "bebi", "comi", "camine", "hecho"
        ]
        guard containsAny(text, keywords: logWords) else { return nil }

        // «Запиши задачу купить воду» — это задача, а не отметка о выпитом стакане.
        // Действие заботы считаем выполненным только без явной сущности задачи либо
        // когда пользователь прямо сообщает о совершённом действии.
        let explicitSelfReport = containsAny(text, keywords: [
            "я выпил", "я попил", "я поел", "я перекусил", "я прошелся", "я прогулялся", "я размялся",
            "i drank", "i had water", "i ate", "i walked",
            "ich habe getrunken", "ich habe gegessen", "ich bin gegangen",
            "he bebido", "he comido", "he caminado"
        ])
        guard !containsAny(text, keywords: taskEntityStems) || explicitSelfReport else { return nil }

        if containsAny(text, keywords: [
            "вод", "пить", "стакан", "water", "drink", "wasser", "trink", "agua", "bebi"
        ]) {
            return .logWater
        }
        if containsAny(text, keywords: [
            "поел", "еда", "прием пищи", "завтрак", "обед", "ужин", "перекус",
            "ate", "meal", "breakfast", "lunch", "dinner",
            "gegessen", "mahlzeit", "comi", "comida"
        ]) {
            return .logMeal
        }
        if containsAny(text, keywords: [
            "прошелся", "прогуля", "размял", "движен", "шаг",
            "walk", "movement", "stretch", "gegangen", "beweg", "camine", "movimiento"
        ]) {
            return .logMovement
        }
        return nil
    }

    private static func isCareRecommendationRequest(_ text: String) -> Bool {
        let question = containsAny(
            text,
            keywords: [
                "что мне сейчас", "что лучше сделать", "что посоветуешь", "как мое состояние",
                "как я себя чувствую", "нужен ли отдых", "мне нужен отдых", "я устал",
                "what should i do", "what do you recommend", "how am i doing", "i am tired",
                "was soll ich", "was empfiehlst du", "ich bin mude",
                "que debo hacer", "que recomiendas", "estoy cansado", "estoy cansada"
            ]
        )
        let excludesGoal = containsAny(text, keywords: strongSmartGoalEntityWords)
        return question && !excludesGoal
    }

    private static func isOpenCalendarRequest(_ text: String) -> Bool {
        let calendarWords = [
            "календар", "расписан", "планы на", "мой день", "что у меня сегодня",
            "calendar", "schedule", "plans for", "my day",
            "kalender", "zeitplan", "mein tag",
            "calendario", "agenda", "mi dia"
        ]
        let openWords = [
            "откро", "покаж", "что у меня", "посмотр", "open", "show", "what is",
            "offne", "zeig", "abre", "muestra"
        ]
        let clearlyAboutGoal = containsAny(text, keywords: [
            "достижен", "дорожн", "умн цель", "goal roadmap", "smart goal",
            "zielplan", "objetivo inteligente"
        ])
        return !clearlyAboutGoal
            && containsAny(text, keywords: calendarWords)
            && (containsAny(text, keywords: openWords) || text.split(separator: " ").count <= 3)
    }

    private static let rescheduleTaskActionStems = [
        "перенес", "перенеси", "перен", "сдвин", "передвин", "назнач",
        "reschedule", "move", "postpone",
        "verschieb", "verleg",
        "reprogram", "mueve", "pospon"
    ]

    private static func isRescheduleTask(_ text: String) -> Bool {
        containsAny(text, keywords: rescheduleTaskActionStems)
            && (containsAny(text, keywords: taskEntityStems)
                || containsAny(text, keywords: ["ее", "её", "его", "эту", "ту", "it", "this one", "sie", "es", "la", "lo"])
                || text.split(separator: " ").count >= 3)
    }

    private static func extractRescheduledTaskTitle(
        from text: String,
        lang: AppLang
    ) -> String? {
        var payload = AppVoiceTemporalParser.removingTemporalPhrases(from: text, lang: lang)
        payload = removingFirstKeyword(from: payload, keywords: rescheduleTaskActionStems)
        payload = removingFirstKeyword(from: payload, keywords: taskEntityStems)
        let cleaned = cleanActionPayload(payload)
        let references = ["ее", "её", "его", "эту", "ту", "it", "this one", "sie", "es", "la", "lo"]
        if cleaned.isEmpty || references.contains(cleaned) { return nil }
        return cleaned
    }

    private static let reopenTaskActionStems = [
        "верни", "вернуть", "возобнови", "снова актив", "отмени выполнение",
        "reopen", "restore", "mark incomplete", "undo completion",
        "wieder offnen", "wiederherstell", "reaktivier",
        "reabrir", "restaur", "marcar pendiente"
    ]

    private static func isReopenTask(_ text: String) -> Bool {
        containsAny(text, keywords: reopenTaskActionStems)
            && containsAny(text, keywords: taskEntityStems + ["ее", "её", "it", "sie", "la"])
    }

    private static let addTaskPrefixes = [
        "добавь задачу",
        "добавить задачу",
        "создай задачу",
        "создать задачу",
        "запиши задачу",
        "запиши мне задачу",
        "поставь задачу",
        "добавь в задачи",
        "напомни мне",
        "не забудь",
        "новая задача",
        "add task",
        "create task",
        "put on my task list",
        "remind me to",
        "remember to",
        "new task",
        "aufgabe hinzufugen",
        "aufgabe erstellen",
        "erinnere mich",
        "neue aufgabe",
        "agregar tarea",
        "crear tarea",
        "recuerdame",
        "nueva tarea"
    ]

    private static let taskEntityStems = [
        "задач", "дело", "список",
        "task", "todo", "list",
        "aufgabe", "liste",
        "tarea", "lista"
    ]

    private static let addTaskActionStems = [
        "добав", "созда", "запиш", "постав", "напом", "не забуд",
        "add", "create", "remember", "remind", "put",
        "hinzuf", "erstell", "erinner",
        "agreg", "crea", "recuerd"
    ]

    private static let completeTaskActionStems = [
        "заверш", "выполн", "отмет", "готов",
        "complete", "finish", "done", "mark",
        "erledig", "abschliess",
        "complet", "termin", "marc"
    ]

    private static let deleteTaskActionStems = [
        "удал", "убер",
        "delete", "remove",
        "losch", "entfern",
        "elimin", "borr", "quit"
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
        for rawPrefix in prefixes.sorted(by: { $0.count > $1.count }) {
            let prefix = normalize(rawPrefix)
            guard let range = text.range(of: prefix) else { continue }
            let suffix = text[range.upperBound...]
            let cleaned = cleanActionPayload(String(suffix))
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    private static func extractFlexibleTaskTitle(
        from text: String,
        actionStems: [String]
    ) -> String? {
        let hasAction = containsAny(text, keywords: actionStems)
        let hasTaskEntity = containsAny(text, keywords: taskEntityStems)
        let isImplicitReminder = containsAny(
            text,
            keywords: [
                "напомни", "не забуд", "мне нужно",
                "remind me", "remember to", "i need to",
                "erinnere mich", "ich muss",
                "recuerdame", "necesito"
            ]
        )
        guard (hasAction && hasTaskEntity) || isImplicitReminder else { return nil }

        var payload = text
        payload = removingFirstKeyword(from: payload, keywords: actionStems)
        payload = removingFirstKeyword(from: payload, keywords: taskEntityStems)
        let cleaned = cleanActionPayload(payload)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func removingFirstKeyword(
        from text: String,
        keywords: [String]
    ) -> String {
        let sourceTokens = text.split(separator: " ").map(String.init)
        for keyword in keywords.sorted(by: { $0.count > $1.count }) {
            let keywordTokens = normalize(keyword).split(separator: " ").map(String.init)
            guard !keywordTokens.isEmpty, keywordTokens.count <= sourceTokens.count else {
                continue
            }

            for start in 0...(sourceTokens.count - keywordTokens.count) {
                let matches = keywordTokens.indices.allSatisfy { offset in
                    let source = sourceTokens[start + offset]
                    let target = keywordTokens[offset]
                    return source == target
                        || source.hasPrefix(target)
                        || target.hasPrefix(source)
                }
                guard matches else { continue }

                var resultTokens = sourceTokens
                resultTokens.removeSubrange(
                    start..<(start + keywordTokens.count)
                )
                return resultTokens.joined(separator: " ")
            }
        }
        return text
    }

    private static func cleanActionPayload(_ source: String) -> String {
        var cleaned = source
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let leadingFillers = [
            "пожалуйста", "мне нужно", "мне надо", "нужно", "надо", "мне", "для меня", "еще", "ещё", "и еще", "и ещё",
            "что", "чтобы", "по", "для", "в", "идею",
            "добавь", "добавить", "создай", "создать", "запиши", "задачу",
            "please", "i need to", "i should", "for me", "also", "and another", "to", "that",
            "add", "create", "task",
            "bitte", "fur mich", "noch", "zu", "dass",
            "hinzufugen", "erstellen", "aufgabe",
            "por favor", "para mi", "tambien", "que",
            "agregar", "crear", "tarea"
        ]
        var didTrim = true
        while didTrim {
            didTrim = false
            for filler in leadingFillers.sorted(by: { $0.count > $1.count }) {
                let normalizedFiller = normalize(filler)
                if cleaned == normalizedFiller {
                    return ""
                }
                if cleaned.hasPrefix(normalizedFiller + " ") {
                    cleaned.removeFirst(normalizedFiller.count)
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    didTrim = true
                    break
                }
            }
        }

        if cleaned.count > 240 {
            cleaned = String(cleaned.prefix(240))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private static let smartGoalEntityWords = [
        "умн цел", "мою цель", "моя цель", "цели", "цель",
        "дорожн карт", "дорожн", "план достижения",
        "smart goal", "my goal", "roadmap",
        "smartes ziel", "mein ziel", "roadmap",
        "meta inteligente", "mi meta", "hoja de ruta"
    ]

    private static let strongSmartGoalEntityWords = [
        "умн", "дорожн", "smart goal", "roadmap",
        "smartes ziel", "fahrplan",
        "meta inteligente", "hoja de ruta"
    ]

    private static let smartGoalCreationWords = [
        "созд", "сдел", "добав", "состав", "постро", "спланир", "преврат",
        "create", "make", "build", "plan", "turn",
        "erstell", "plan", "mach",
        "crea", "haz", "planifica", "convierte"
    ]

    private static let smartGoalOpenWords = [
        "откро", "покаж", "перейд", "верн", "продолж",
        "open", "show", "go to", "continue",
        "offne", "zeig", "weiter",
        "abre", "muestra", "continua"
    ]

    private static let smartGoalProgressWords = [
        "прогресс", "как продвига", "как дела", "результат", "статус цели",
        "goal progress", "how is my goal", "goal status", "progress",
        "zielfortschritt", "wie lauft mein ziel", "fortschritt",
        "progreso de mi meta", "como va mi meta", "estado de mi meta"
    ]

    private static let smartGoalCreationPrefixes = [
        "создай умную цель", "создать умную цель", "сделай умную цель",
        "добавь умную цель", "создай цель", "создать цель",
        "составь дорожную карту для", "построй дорожную карту для",
        "составь план для", "помоги мне построить план чтобы",
        "помоги построить план чтобы", "помоги мне достичь", "помоги достичь",
        "хочу достичь", "хочу добиться", "хочу научиться",
        "хочу освоить", "хочу выучить", "моя цель",
        "create a smart goal to", "create smart goal to", "make a smart goal to",
        "build a roadmap to", "make a plan to", "help me achieve",
        "i want to achieve", "i want to learn", "my goal is to",
        "erstelle ein smartes ziel", "erstelle ein ziel", "plane einen weg zu",
        "hilf mir", "ich mochte lernen", "mein ziel ist",
        "crea una meta inteligente", "crea una meta", "haz una hoja de ruta para",
        "ayudame a lograr", "quiero lograr", "quiero aprender", "mi meta es"
    ]

    private static func isSmartGoalProgressRequest(_ text: String) -> Bool {
        let hasProgress = containsAny(text, keywords: smartGoalProgressWords)
        let hasGoal = containsAny(text, keywords: smartGoalEntityWords)
        return hasProgress && hasGoal
    }

    private static func isSmartGoalCreationRequest(_ text: String) -> Bool {
        let hasGoal = containsAny(text, keywords: smartGoalEntityWords)
        let hasCreateAction = containsAny(text, keywords: smartGoalCreationWords)
        let mentionsTask = containsAny(text, keywords: taskEntityStems)
        let hasStrongGoalEntity = containsAny(
            text,
            keywords: strongSmartGoalEntityWords
        )
        if mentionsTask && !hasStrongGoalEntity {
            return false
        }
        if hasGoal && hasCreateAction {
            return true
        }

        return smartGoalCreationPrefixes.contains { prefix in
            text.contains(normalize(prefix))
        }
    }

    private static func isOpenSmartGoalsRequest(_ text: String) -> Bool {
        let hasGoal = containsAny(text, keywords: smartGoalEntityWords)
        guard hasGoal else { return false }
        if containsAny(text, keywords: smartGoalOpenWords) {
            return true
        }
        return text == "умные цели"
            || text == "smart goals"
            || text == "smarte ziele"
            || text == "metas inteligentes"
    }

    fileprivate static func extractSmartGoalDescription(from text: String) -> String? {
        if let suffix = extractSuffix(in: text, prefixes: smartGoalCreationPrefixes) {
            return suffix
        }

        let destinationPhrases = [
            " в умную цель", " как умную цель",
            " into a smart goal", " as a smart goal",
            " in ein smartes ziel", " als smartes ziel",
            " en una meta inteligente", " como meta inteligente"
        ]
        for phrase in destinationPhrases {
            guard let range = text.range(of: normalize(phrase)) else { continue }
            var prefix = String(text[..<range.lowerBound])
            prefix = removingFirstKeyword(
                from: prefix,
                keywords: [
                    "хочу превратить", "преврати", "сделай",
                    "turn", "make",
                    "verwandle", "mach",
                    "convierte", "haz"
                ]
            )
            let cleaned = cleanActionPayload(prefix)
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
        let pauseWords = ["пауз", "поставь на паузу", "pause", "pausa", "anhalten", "unterbrechen"]
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

    private static func resolveConversationReference(
        in text: String,
        lang: AppLang,
        contextHistory: [AppVoiceCommandIntent],
        now: Date,
        calendar: Calendar
    ) -> AppVoiceCommandIntent? {
        guard !contextHistory.isEmpty else { return nil }

        if let clarification = contextHistory.reversed().compactMap({ intent -> String? in
            if case .clarifyAction(let topic) = intent { return topic }
            return nil
        }).first {
            if containsAny(text, keywords: [
                "как задачу", "в задачи", "сделай задачей", "task", "as a task",
                "als aufgabe", "como tarea"
            ]) {
                return taskCreationIntent(
                    title: clarification,
                    sourceText: text,
                    lang: lang,
                    now: now,
                    calendar: calendar
                )
            }
            if containsAny(text, keywords: [
                "как цель", "в умную цель", "дорожную карту", "smart goal", "roadmap",
                "als ziel", "fahrplan", "como meta", "hoja de ruta"
            ]) {
                return .createSmartGoal(description: clarification)
            }
        }

        let lastTaskContext = contextHistory.reversed().compactMap { intent -> (title: String?, dueDate: Date?)? in
            switch intent {
            case .addTask(let title, _):
                return (title, nil)
            case .addScheduledTask(let title, _, let dueDate):
                return (title, dueDate)
            case .completeTask(let title), .reopenTask(let title):
                return (title, nil)
            case .rescheduleTask(let title, let dueDate):
                return (title, dueDate)
            default:
                return nil
            }
        }.first

        let hasReference = containsAny(
            text,
            keywords: [
                "ее", "её", "его", "эту", "ту задачу", "предыдущую", "последнюю",
                "it", "that task", "the previous one", "last one",
                "sie", "diese aufgabe", "letzte aufgabe",
                "la", "esa tarea", "la anterior", "ultima tarea"
            ]
        )

        if let lastTaskContext, hasReference {
            if containsAny(text, keywords: completeTaskActionStems) {
                return .completeTask(title: lastTaskContext.title)
            }
            if containsAny(text, keywords: reopenTaskActionStems) {
                return .reopenTask(title: lastTaskContext.title)
            }
            if containsAny(text, keywords: deleteTaskActionStems) {
                return .deleteTask(title: lastTaskContext.title)
            }
            if containsAny(text, keywords: rescheduleTaskActionStems),
               let temporal = AppVoiceTemporalParser.resolve(
                    in: text,
                    lang: lang,
                    now: now,
                    calendar: calendar
               ) {
                return .rescheduleTask(title: lastTaskContext.title, dueDate: temporal.dueDate)
            }
        }

        if let lastTaskContext,
           let inheritedDate = lastTaskContext.dueDate,
           containsAny(text, keywords: [
                "туда же", "на это же время", "в тот же день",
                "same time", "same day", "there too",
                "zur gleichen zeit", "am selben tag",
                "a la misma hora", "el mismo dia"
           ]),
           let title = contextualTaskTitle(from: text, actionStems: addTaskActionStems) {
            return .addScheduledTask(
                title: AppVoiceTemporalParser.removingReferencePhrases(from: title),
                category: detectCategory(in: title, lang: lang),
                dueDate: inheritedDate
            )
        }

        return nil
    }

    private static func resolveContextualIntent(
        in text: String,
        lang: AppLang,
        context: AppVoiceCommandIntent?
    ) -> AppVoiceCommandIntent? {
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

        case .openSmartGoals, .createSmartGoal, .showSmartGoalProgress:
            if containsAny(text, keywords: smartGoalProgressWords) {
                return .showSmartGoalProgress
            }
            if isSmartGoalCreationRequest(text) {
                return .createSmartGoal(
                    description: extractSmartGoalDescription(from: text)
                )
            }
            if isOpenSmartGoalsRequest(text)
                || containsAny(
                    text,
                    keywords: [
                        "продолжим", "вернись к ней", "открой ее",
                        "continue with it", "open it",
                        "weiter damit", "offne es",
                        "continuemos", "abrela"
                    ]
                ) {
                return .openSmartGoals
            }
            if let description = contextualSmartGoalDescription(from: text) {
                return .createSmartGoal(description: description)
            }
            return nil

        case .addTask, .addScheduledTask, .openTab(.tasks):
            if containsAny(text, keywords: completeTaskActionStems) {
                return .completeTask(
                    title: contextualTaskTitle(
                        from: text,
                        actionStems: completeTaskActionStems
                    )
                )
            }
            if containsAny(text, keywords: deleteTaskActionStems) {
                return .deleteTask(
                    title: contextualTaskTitle(
                        from: text,
                        actionStems: deleteTaskActionStems
                    )
                )
            }
            if let title = contextualTaskTitle(
                from: text,
                actionStems: addTaskActionStems
            ) {
                return .addTask(
                    title: title,
                    category: detectCategory(in: title, lang: lang)
                )
            }
            return nil

        case .completeTask, .reopenTask, .deleteTask,
             .rescheduleTask, .openTab, .openCalendar, .openEyeExercise,
             .showCareRecommendation, .logCareAction, .showCapabilities,
             .clarifyAction, .unknown:
            return nil
        }
    }

    private static func contextualTaskTitle(
        from text: String,
        actionStems: [String]
    ) -> String? {
        let continuationWords = [
            "и еще", "и ещё", "еще", "ещё", "также",
            "and another", "also",
            "und noch", "noch",
            "y tambien", "tambien"
        ]
        let hasAction = containsAny(text, keywords: actionStems)
        let hasContinuation = containsAny(text, keywords: continuationWords)
        guard hasAction || hasContinuation else { return nil }

        var payload = text
        if hasAction {
            payload = removingFirstKeyword(from: payload, keywords: actionStems)
        }
        payload = removingFirstKeyword(from: payload, keywords: taskEntityStems)
        let cleaned = cleanActionPayload(payload)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func contextualSmartGoalDescription(from text: String) -> String? {
        let goalVerbStems = [
            "хочу", "выуч", "осво", "науч", "запуст", "созд", "подготов",
            "похуд", "накоп", "достич", "добит",
            "i want", "learn", "launch", "build", "prepare", "achieve", "save",
            "ich mochte", "lernen", "starten", "erreichen", "sparen",
            "quiero", "aprender", "lanzar", "lograr", "ahorrar"
        ]
        let unrelatedCommandWords = [
            "помодоро", "таймер", "задач", "настро", "здоров", "перерыв",
            "pomodoro", "timer", "task", "settings", "health", "break",
            "aufgabe", "einstellungen", "pause",
            "tarea", "ajustes", "descanso"
        ]
        guard containsAny(text, keywords: goalVerbStems),
              !containsAny(text, keywords: unrelatedCommandWords) else {
            return nil
        }
        let cleaned = cleanActionPayload(text)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func implicitSmartGoalDescription(from text: String) -> String? {
        let prefixes = [
            "помоги мне спланировать", "помоги спланировать", "как мне добиться",
            "как мне достичь", "разбей на шаги", "построй маршрут к",
            "help me plan", "how can i achieve", "break down", "map out",
            "hilf mir planen", "wie erreiche ich", "teile in schritte",
            "ayudame a planificar", "como puedo lograr", "divide en pasos"
        ]
        guard containsAny(text, keywords: prefixes) else { return nil }
        if let extracted = extractSuffix(in: text, prefixes: prefixes) {
            return extracted
        }
        let cleaned = cleanActionPayload(
            removingFirstKeyword(from: text, keywords: prefixes)
        )
        return cleaned.isEmpty ? nil : cleaned
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
            (.work, ["работ", "проект", "клиент", "презентац", "work", "job", "presentation", "arbeit", "prasentation", "trabajo", "presentacion"]),
            (.study, ["учеб", "урок", "экзам", "study", "learn", "lernen", "estudio"]),
            (.health, ["здоров", "спорт", "трен", "дыхан", "health", "workout", "gesund", "salud"]),
            (.rest, ["отдых", "перерыв", "сон", "rest", "break", "ruhe", "descanso"]),
            (.home, [
                "дом", "уборк", "покупк", "куп", "магаз",
                "home", "house", "buy", "shop", "grocery",
                "haus", "kauf", "einkauf",
                "hogar", "compr", "tienda"
            ])
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
        case .addTask, .addScheduledTask:
            return "assistant.quick.add"
        case .openTabToday, .openTabTasks, .completeTask, .reopenTask,
             .deleteTask, .rescheduleTask:
            return "assistant.quick.tasks"
        case .openCalendar:
            return "assistant.quick.calendar"
        case .summarizeMetricsToday, .summarizeMetricsWeek:
            return "assistant.quick.summary"
        case .openSmartGoals, .createSmartGoal:
            return "assistant.quick.smart_goal"
        case .showSmartGoalProgress:
            return "assistant.quick.goal_progress"
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
        case .showCareRecommendation, .logMeal, .logMovement, .logWater:
            return "assistant.quick.care"
        case .openTabPomodoro, .openTabHealth, .openTabSettings,
             .stopPomodoro, .showCapabilities, .clarifyAction, .unknown:
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
        let pauseWords = ["пауз", "pause", "pausa", "anhalten"]
        let resumeWords = ["продолж", "возобнов", "resume", "continue", "fortsetzen", "reanudar"]
        let stopWords = ["стоп", "останов", "stop", "cancel", "stopp", "detener", "parar"]
        let shortBreakWords = ["коротк", "short", "klein", "corto"]
        let longBreakWords = ["длин", "больш", "long", "lange", "largo"]
        let breakWords = ["перерыв", "break", "pause", "descanso"]
        let eyeWords = ["глаз", "eyes", "eye", "augen", "ojos"]
        let calendarWords = [
            "календар", "расписан", "планы", "calendar", "schedule",
            "kalender", "zeitplan", "calendario", "agenda"
        ]
        let careWords = [
            "состояни", "самочувств", "отдых", "совет", "рекоменд", "устал",
            "wellbeing", "recovery", "recommend", "tired",
            "erholung", "empfehl", "mude", "descanso", "recomiend", "cansad"
        ]
        let capabilityWords = [
            "умеешь", "возможност", "команд", "capabilities", "commands", "help",
            "funktionen", "befehle", "comandos", "ayuda"
        ]
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
        let smartGoalWords = [
            "цел", "цель", "дорожн", "карт", "план",
            "goal", "roadmap",
            "ziel", "fahrplan",
            "meta", "ruta"
        ]
        let smartGoalCreateWords = [
            "созд", "состав", "постро", "спланир", "достич", "хочу",
            "create", "build", "plan", "achieve", "want",
            "erstell", "plan", "erreich", "mochte",
            "crea", "planifica", "logra", "quiero"
        ]
        let smartGoalProgressWords = [
            "прогресс", "продвига", "статус", "результат",
            "progress", "status",
            "fortschritt", "status",
            "progreso", "estado"
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

        if features.containsAny(stems: calendarWords),
           features.containsAny(stems: openWords + ["сегодня", "today", "heute", "hoy"]) {
            let score = 0.66
                + (0.14 * features.score(stems: calendarWords))
                + (0.08 * features.score(stems: openWords))
            candidates.append(.init(intent: .openCalendar, score: score))
        }

        if features.containsAny(stems: careWords) {
            let score = 0.63 + (0.18 * features.score(stems: careWords))
            candidates.append(.init(intent: .showCareRecommendation, score: score))
        }

        if features.containsAny(stems: capabilityWords) {
            let score = 0.64 + (0.18 * features.score(stems: capabilityWords))
            candidates.append(.init(intent: .showCapabilities, score: score))
        }

        if features.containsAny(stems: smartGoalWords),
           features.containsAny(stems: smartGoalProgressWords) {
            let score = 0.69
                + (0.10 * features.score(stems: smartGoalWords))
                + (0.10 * features.score(stems: smartGoalProgressWords))
            candidates.append(.init(intent: .showSmartGoalProgress, score: score))
        }

        if features.containsAny(stems: smartGoalWords),
           features.containsAny(stems: smartGoalCreateWords) {
            let description = AppVoiceCommandParser.extractSmartGoalDescription(
                from: features.text
            )
            let score = 0.66
                + (0.10 * features.score(stems: smartGoalWords))
                + (0.10 * features.score(stems: smartGoalCreateWords))
            candidates.append(
                .init(
                    intent: .createSmartGoal(description: description),
                    score: score
                )
            )
        }

        if features.containsAny(stems: smartGoalWords),
           features.containsAny(stems: openWords) {
            let score = 0.65
                + (0.11 * features.score(stems: smartGoalWords))
                + (0.09 * features.score(stems: openWords))
            candidates.append(.init(intent: .openSmartGoals, score: score))
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
            (.work, ["работ", "проект", "клиент", "презентац", "work", "job", "presentation", "arbeit", "prasentation", "trabajo", "presentacion"]),
            (.study, ["учеб", "урок", "экзам", "study", "learn", "lernen", "estudio"]),
            (.health, ["здоров", "спорт", "трен", "дыхан", "health", "workout", "gesund", "salud"]),
            (.rest, ["отдых", "перерыв", "сон", "rest", "break", "ruhe", "descanso"]),
            (.home, [
                "дом", "уборк", "покупк", "куп", "магаз",
                "home", "house", "buy", "shop", "grocery",
                "haus", "kauf", "einkauf",
                "hogar", "compr", "tienda"
            ])
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
             (.openTab, .openTab),
             (.showSmartGoalProgress, .openSmartGoals),
             (.showSmartGoalProgress, .createSmartGoal),
             (.openSmartGoals, .showSmartGoalProgress),
             (.createSmartGoal, .openSmartGoals):
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
    private struct ConversationTurn {
        let intent: AppVoiceCommandIntent
        let resolvedAt: Date
    }
    private var conversationHistory: [ConversationTurn] = []

    private let silenceCommitDelay: UInt64 = 1_150_000_000
    private let conversationContextLifetime: TimeInterval = 12 * 60

    private var neuralVoicePlayer: AVAudioPlayer?
    private var neuralSpeechTask: Task<Void, Never>?
    private var speechRequestID = UUID()
    private let behaviorModel = AppVoiceBehaviorModel.shared
    private static let defaultQuickCommandKeys = [
        "assistant.quick.add",
        "assistant.quick.smart_goal",
        "assistant.quick.goal_progress",
        "assistant.quick.tasks",
        "assistant.quick.calendar",
        "assistant.quick.care",
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
        quickCommandKeys = Self.defaultQuickCommandKeys
    }

    deinit {
        audioSessionDeactivateTask?.cancel()
        neuralSpeechTask?.cancel()
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    func startListening(lang: AppLang) {
        guard !isListening, !isBootstrappingRecognition else { return }
        isBootstrappingRecognition = true
        AppVoiceAssistantFeedback.startListeningCue()
        stopSpeechPlayback()
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
            stopSpeechPlayback()
            state = .idle
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
            context: activeConversationContext,
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

        let previousContext = activeConversationContext
        AppEmbeddedAIInterpreter.shared.observeSuccessfulCommand(
            transcript: prepared,
            intent: intent,
            context: previousContext,
            lang: lang
        )
        conversationHistory.append(.init(intent: intent, resolvedAt: .now))
        if conversationHistory.count > 8 {
            conversationHistory.removeFirst(conversationHistory.count - 8)
        }
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
        let intents = AppVoiceCommandParser.parseAll(
            prepared,
            lang: lang,
            contextHistory: activeConversationHistory
        )
        pendingCommand = AppVoiceCommandEnvelope(
            transcript: prepared,
            intents: intents
        )
    }

    private var activeConversationContext: AppVoiceCommandIntent? {
        activeConversationHistory.last
    }

    private var activeConversationHistory: [AppVoiceCommandIntent] {
        let cutoff = Date().addingTimeInterval(-conversationContextLifetime)
        return conversationHistory
            .filter { $0.resolvedAt >= cutoff }
            .map(\.intent)
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
            guard neuralVoicePlayer?.isPlaying != true else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func speak(_ text: String, lang: AppLang) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            state = .idle
            return
        }

        stopSpeechPlayback()
        let requestID = UUID()
        speechRequestID = requestID
        state = .speaking

        let configuration = NeuralVoiceConfiguration.stored
        guard configuration.isEnabled, configuration.supports(lang) else {
            state = .error(NeuralVoiceProviderError.disabled.message(lang: lang))
            scheduleAudioSessionDeactivation()
            return
        }
        guard configuration.isConfigured else {
            LocalVoiceModelStore.shared.ensureDownloadStarted()
            state = .error(NeuralVoiceProviderError.modelUnavailable.message(lang: lang))
            scheduleAudioSessionDeactivation()
            return
        }

        neuralSpeechTask = Task { [weak self] in
            do {
                let audio = try await LocalNeuralVoiceProvider.shared.synthesize(
                    message,
                    language: lang,
                    speed: HealthVoicePlaybackSpeed.balanced.neuralSpeed,
                    profile: configuration.profile
                )
                guard !Task.isCancelled, let self, self.speechRequestID == requestID else { return }
                self.playNeuralSpeech(audio, lang: lang)
            } catch let error as NeuralVoiceProviderError {
                guard !Task.isCancelled, let self, self.speechRequestID == requestID else { return }
                self.state = .error(error.message(lang: lang))
                self.scheduleAudioSessionDeactivation()
            } catch {
                guard !Task.isCancelled, let self, self.speechRequestID == requestID else { return }
                self.state = .error(NeuralVoiceProviderError.generation.message(lang: lang))
                self.scheduleAudioSessionDeactivation()
            }
        }
    }

    private func playNeuralSpeech(_ audio: Data, lang: AppLang) {
        do {
            configureAudioSessionForSpeechPlayback()
            let player = try AVAudioPlayer(data: audio)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { throw NSError(domain: "Lippi.NeuralVoice", code: 1) }
            neuralVoicePlayer = player
        } catch {
            state = .error(NeuralVoiceProviderError.generation.message(lang: lang))
            scheduleAudioSessionDeactivation()
        }
    }

    private func stopSpeechPlayback() {
        speechRequestID = UUID()
        neuralSpeechTask?.cancel()
        neuralSpeechTask = nil
        neuralVoicePlayer?.stop()
        neuralVoicePlayer = nil
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

extension AppVoiceAssistantCenter: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.neuralVoicePlayer === player else { return }
            self.neuralVoicePlayer = nil
            if case .speaking = self.state {
                self.state = .idle
            }
            self.scheduleAudioSessionDeactivation()
        }
    }
}

private enum VoiceAssistantPanel: String, Identifiable {
    case quickCommands
    case keyboard

    var id: String { rawValue }
}

/// Keeps the assistant on Apple's native Liquid Glass when the system supports it,
/// while retaining a calm, readable material on earlier releases and when
/// transparency is reduced. Unlike the generic fallback, this modifier does not
/// stack an extra blur beneath the system glass.
private struct VoiceAssistantSystemGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DS.contentSurface, in: shape)
                .overlay(shape.stroke(DS.glassStroke(0.16), lineWidth: 1))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: shape
            )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(DS.glassStroke(0.10), lineWidth: 1))
        }
    }
}

private extension View {
    func voiceAssistantSystemGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(
            VoiceAssistantSystemGlassModifier(
                shape: shape,
                tint: tint,
                interactive: interactive
            )
        )
    }

    @ViewBuilder
    func voiceAssistantGlassMaterialize() -> some View {
        if #available(iOS 26.0, *) {
            glassEffectTransition(.materialize)
        } else {
            self
        }
    }
}

private struct VoiceAssistantTextRevealRenderer: TextRenderer {
    var progress: Double
    let tint: Color
    let stagger: Double
    let travel: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var displayPadding: EdgeInsets {
        EdgeInsets(top: 9, leading: 6, bottom: 9, trailing: 6)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let glyphCount = max(
            1,
            layout.reduce(0) { lineCount, line in
                lineCount + line.reduce(0) { $0 + $1.count }
            }
        )
        var glyphIndex = 0

        for line in layout {
            for run in line {
                for glyph in run {
                    let position = Double(glyphIndex) / Double(max(glyphCount - 1, 1))
                    let delay = position * stagger
                    let localProgress = min(
                        max((progress - delay) / max(1 - delay, 0.001), 0),
                        1
                    )
                    let eased = 1 - pow(1 - localProgress, 3)
                    let lift = (1 - eased) * travel
                    let glowAmount = sin(localProgress * .pi) * 0.42

                    if glowAmount > 0.001 {
                        var glowContext = context
                        glowContext.opacity = glowAmount
                        glowContext.translateBy(x: 0, y: lift * 0.45)
                        glowContext.addFilter(.colorMultiply(tint))
                        glowContext.addFilter(.blur(radius: 3.2))
                        glowContext.draw(glyph)
                    }

                    var glyphContext = context
                    glyphContext.opacity = eased
                    glyphContext.translateBy(x: 0, y: lift)
                    if localProgress < 0.999 {
                        glyphContext.addFilter(.blur(radius: (1 - eased) * 5.5))
                    }
                    glyphContext.draw(glyph)
                    glyphIndex += 1
                }
            }
        }
    }
}

private struct VoiceAssistantAnimatedText: View {
    let text: String
    let font: Font
    let color: Color
    let tint: Color
    let alignment: TextAlignment
    let lineLimit: Int?
    let duration: Double
    let delay: Double
    let stagger: Double
    let travel: CGFloat
    let animated: Bool
    let reduceMotion: Bool

    @State private var revealProgress = 0.0

    var body: some View {
        if reduceMotion || !animated {
            label
        } else {
            label
                .textRenderer(
                    VoiceAssistantTextRevealRenderer(
                        progress: revealProgress,
                        tint: tint,
                        stagger: stagger,
                        travel: travel
                    )
                )
                .id(text)
                .transition(.blurReplace(.upUp))
                .task(id: text) {
                    var resetTransaction = Transaction()
                    resetTransaction.disablesAnimations = true
                    withTransaction(resetTransaction) {
                        revealProgress = 0
                    }

                    if delay > 0 {
                        try? await Task.sleep(
                            nanoseconds: UInt64(delay * 1_000_000_000)
                        )
                    } else {
                        await Task.yield()
                    }
                    guard !Task.isCancelled else { return }

                    withAnimation(.easeOut(duration: duration)) {
                        revealProgress = 1
                    }
                }
        }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

struct AppVoiceAssistantSheet: View {
    @ObservedObject var assistant: AppVoiceAssistantCenter
    let lang: AppLang

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @State private var activePanel: VoiceAssistantPanel?
    @State private var typedCommand = ""
    @FocusState private var commandFieldFocused: Bool

    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private struct QuickCommandItem: Identifiable {
        let key: String
        let icon: String
        let tone: Color

        var id: String { key }
        var titleKey: String {
            key.replacingOccurrences(of: "assistant.quick.", with: "assistant.command.") + ".title"
        }
        var subtitleKey: String {
            key
        }
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
        case .error:
            return s("assistant.hero.error.title")
        }
    }

    private var heroTitle: String {
        switch assistant.state {
        case .idle:
            return s("assistant.hero.ready.title")
        case .listening:
            return s("assistant.hero.listening.title")
        case .processing:
            return s("assistant.hero.processing.title")
        case .speaking:
            return s("assistant.hero.speaking.title")
        case .error:
            return s("assistant.hero.error.title")
        }
    }

    private var heroSubtitle: String {
        switch assistant.state {
        case .idle:
            return s("assistant.hero.ready.subtitle")
        case .listening:
            return s("assistant.hero.listening.subtitle")
        case .processing:
            return s("assistant.hero.processing.subtitle")
        case .speaking:
            return s("assistant.hero.speaking.subtitle")
        case .error(let message):
            return message
        }
    }

    private var conversationText: String {
        switch assistant.state {
        case .listening, .processing:
            return assistant.transcript
        case .speaking:
            return assistant.lastResponse
        case .idle, .error:
            return assistant.lastResponse.isEmpty ? assistant.transcript : assistant.lastResponse
        }
    }

    private var conversationIcon: String {
        switch assistant.state {
        case .listening, .processing:
            return "quote.bubble.fill"
        case .idle, .speaking, .error:
            return "sparkles"
        }
    }

    private var animatesConversationReveal: Bool {
        switch assistant.state {
        case .idle, .speaking, .error:
            return true
        case .listening, .processing:
            return false
        }
    }

    private var allQuickCommands: [QuickCommandItem] {
        [
            .init(key: "assistant.quick.add", icon: "plus", tone: Color(hex: 0x34C7FF)),
            .init(key: "assistant.quick.smart_goal", icon: "target", tone: Color(hex: 0x30D158)),
            .init(key: "assistant.quick.goal_progress", icon: "chart.line.uptrend.xyaxis", tone: Color(hex: 0xBF5AF2)),
            .init(key: "assistant.quick.tasks", icon: "checklist", tone: Color(hex: 0x64D2FF)),
            .init(key: "assistant.quick.calendar", icon: "calendar", tone: Color(hex: 0x0A84FF)),
            .init(key: "assistant.quick.care", icon: "heart.fill", tone: Color(hex: 0xFF6482)),
            .init(key: "assistant.quick.summary", icon: "chart.bar.xaxis", tone: Color(hex: 0x5AC8FA)),
            .init(key: "assistant.quick.pomodoro", icon: "timer", tone: Color(hex: 0x30B0FF)),
            .init(key: "assistant.quick.pause", icon: "pause.fill", tone: Color(hex: 0xFF9F0A)),
            .init(key: "assistant.quick.resume", icon: "play.fill", tone: Color(hex: 0x30D158)),
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
        GeometryReader { proxy in
            ZStack {
                VoiceAssistantBackdrop(
                    tones: assistant.state.liquidTones,
                    dark: colorScheme == .dark,
                    simplified: reduceTransparency || DS.runtimeConstrained
                )

                ScrollView {
                    VStack(spacing: 0) {
                        topBar

                        Spacer(minLength: 18)

                        assistantStage(availableWidth: proxy.size.width)

                        Spacer(minLength: 18)

                        if proxy.size.height > 690 {
                            suggestionStrip
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        controlDock
                            .padding(.top, proxy.size.height > 690 ? 16 : 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(item: $activePanel) { panel in
            panelContent(panel)
        }
        .onAppear {
            assistant.refreshSuggestions(lang: lang)
        }
        .onDisappear {
            assistant.cancelListening()
        }
    }

    private var topBar: some View {
        LippiGlassEffectGroup(spacing: 12) {
            HStack(spacing: 10) {
                LippiIntelligenceCapsule(
                    state: assistant.state,
                    status: statusText,
                    reduceMotion: reduceMotion || DS.runtimeConstrained,
                    reduceTransparency: reduceTransparency
                )

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.text(0.78))
                        .frame(width: 42, height: 42)
                        .voiceAssistantSystemGlass(
                            in: Circle(),
                            tint: assistant.state.liquidTones[0].opacity(0.08),
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s("assistant.button.close"))
            }
        }
        .padding(.top, 8)
    }

    private func assistantStage(availableWidth: CGFloat) -> some View {
        let orbSize = min(max(availableWidth * 0.46, 156), 208)

        return VStack(spacing: 0) {
            LiquidAssistantCore(
                state: assistant.state,
                reduceMotion: reduceMotion || DS.runtimeConstrained,
                reduceTransparency: reduceTransparency
            )
            .frame(width: orbSize, height: orbSize)
            .accessibilityHidden(true)

            LippiGlassEffectGroup(spacing: 12) {
                VStack(spacing: 0) {
                    VStack(spacing: 7) {
                        VoiceAssistantAnimatedText(
                            text: heroTitle,
                            font: .system(size: 25, weight: .semibold, design: .rounded),
                            color: DS.text(0.98),
                            tint: assistant.state.intelligencePalette[1],
                            alignment: .center,
                            lineLimit: 2,
                            duration: 0.76,
                            delay: 0,
                            stagger: 0.42,
                            travel: 8,
                            animated: true,
                            reduceMotion: reduceMotion
                        )

                        VoiceAssistantAnimatedText(
                            text: heroSubtitle,
                            font: .subheadline,
                            color: DS.text(0.62),
                            tint: assistant.state.intelligencePalette[2],
                            alignment: .center,
                            lineLimit: 3,
                            duration: 0.68,
                            delay: 0.10,
                            stagger: 0.34,
                            travel: 6,
                            animated: true,
                            reduceMotion: reduceMotion
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .voiceAssistantSystemGlass(
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                        tint: assistant.state.liquidTones[0].opacity(0.045)
                    )
                    .voiceAssistantGlassMaterialize()
                    .id(assistant.state.orbAnimationKey)
                    .padding(.top, 22)

                    if !conversationText.isEmpty {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: conversationIcon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(assistant.state.liquidTones[0])
                                .padding(.top, 2)

                            VoiceAssistantAnimatedText(
                                text: conversationText,
                                font: .footnote,
                                color: DS.text(0.82),
                                tint: assistant.state.intelligencePalette[3],
                                alignment: .leading,
                                lineLimit: nil,
                                duration: 0.86,
                                delay: 0.04,
                                stagger: 0.56,
                                travel: 6,
                                animated: animatesConversationReveal,
                                reduceMotion: reduceMotion
                            )
                            .layoutPriority(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: 360, alignment: .leading)
                        .voiceAssistantSystemGlass(
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            tint: assistant.state.liquidTones[0].opacity(0.09)
                        )
                        .voiceAssistantGlassMaterialize()
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(assistantStageAccessibilityLabel)
        .animation(reduceMotion ? nil : DS.motionState, value: assistant.state.orbAnimationKey)
        .animation(reduceMotion ? nil : DS.motionState, value: conversationText)
    }

    private var assistantStageAccessibilityLabel: String {
        [heroTitle, heroSubtitle, conversationText]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
    }

    private var suggestionStrip: some View {
        LippiGlassEffectGroup(spacing: 10) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label(
                        s("assistant.suggested.title"),
                        systemImage: assistant.hasPersonalizedSuggestions ? "sparkles" : "wand.and.stars"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.64))

                    Spacer()

                    Button(s("assistant.commands.all")) {
                        activePanel = .quickCommands
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(assistant.state.liquidTones[0])
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(suggestedCommands.prefix(3)) { command in
                            Button {
                                run(command)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: command.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(command.tone)

                                    Text(s(command.titleKey))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DS.text(0.84))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 13)
                                .frame(height: 40)
                                .voiceAssistantSystemGlass(
                                    in: Capsule(),
                                    tint: command.tone.opacity(0.09),
                                    interactive: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(12)
            .voiceAssistantSystemGlass(
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                tint: assistant.state.liquidTones[0].opacity(0.045)
            )
        }
    }

    private var controlDock: some View {
        LippiGlassEffectGroup(spacing: 14) {
            HStack(spacing: 22) {
                assistantControlButton(
                    icon: "keyboard",
                    title: s("assistant.button.keyboard"),
                    tone: assistant.state.liquidTones[0]
                ) {
                    activePanel = .keyboard
                }

                Button {
                    toggleListening()
                } label: {
                    ZStack {
                        if assistant.state.isActive && !reduceMotion {
                            LiquidPulseRing(
                                color: assistant.state.liquidTones[0].opacity(0.26),
                                lineWidth: 1,
                                fromScale: 0.94,
                                toScale: 1.24,
                                initialOpacity: 0.54,
                                duration: 1.25
                            )
                            .frame(width: 76, height: 76)
                        }

                        Circle()
                            .fill(assistant.state.liquidGradient)
                            .frame(width: 68, height: 68)
                            .shadow(
                                color: assistant.state.liquidTones[0].opacity(reduceTransparency ? 0.12 : 0.26),
                                radius: 16,
                                x: 0,
                                y: 9
                            )
                            .voiceAssistantSystemGlass(
                                in: Circle(),
                                tint: assistant.state.liquidTones[1].opacity(0.20),
                                interactive: true
                            )

                        Image(systemName: assistant.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: 78, height: 78)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    assistant.isListening
                    ? s("assistant.button.stop")
                    : s("assistant.button.start")
                )

                assistantControlButton(
                    icon: "sparkles",
                    title: s("assistant.button.commands"),
                    tone: assistant.state.liquidTones[1],
                    showsBadge: assistant.hasPersonalizedSuggestions
                ) {
                    activePanel = .quickCommands
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .voiceAssistantSystemGlass(
                in: Capsule(),
                tint: assistant.state.liquidTones[0].opacity(0.08)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func assistantControlButton(
        icon: String,
        title: String,
        tone: Color,
        showsBadge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tone)
                    .frame(width: 46, height: 46)
                    .voiceAssistantSystemGlass(
                        in: Circle(),
                        tint: tone.opacity(0.09),
                        interactive: true
                    )

                if showsBadge {
                    Circle()
                        .fill(Color(hex: 0x30D158))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1.5))
                        .offset(x: -1, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func panelContent(_ panel: VoiceAssistantPanel) -> some View {
        switch panel {
        case .quickCommands:
            quickCommandsPanel
                .presentationDetents([.height(390), .large])
                .presentationDragIndicator(.visible)
        case .keyboard:
            keyboardPanel
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
        }
    }

    private var quickCommandsPanel: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(
                            assistant.hasPersonalizedSuggestions
                            ? s("assistant.suggested.personalized")
                            : s("assistant.suggested.learning")
                        )
                        .font(.footnote)
                        .foregroundStyle(DS.text(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    LippiGlassEffectGroup(spacing: 10) {
                        LazyVGrid(columns: quickCommandColumns, spacing: 10) {
                            ForEach(suggestedCommands) { command in
                                commandTile(command)
                            }
                        }
                    }

                    NavigationLink {
                        commandCatalogView
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(assistant.state.liquidTones[0])
                                .frame(width: 32, height: 32)
                                .background(assistant.state.liquidTones[0].opacity(0.11), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s("assistant.commands.all"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DS.text(0.92))
                                Text(s("assistant.commands.all.subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(DS.text(0.58))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.text(0.44))
                        }
                        .padding(12)
                        .voiceAssistantSystemGlass(
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            tint: assistant.state.liquidTones[0].opacity(0.07),
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(s("assistant.quick.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activePanel = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(s("assistant.button.close"))
                }
            }
        }
    }

    private var commandCatalogView: some View {
        ScrollView {
            LippiGlassEffectGroup(spacing: 9) {
                LazyVStack(spacing: 9) {
                    ForEach(allQuickCommands) { command in
                        Button {
                            run(command)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(command.tone)
                                    .frame(width: 38, height: 38)
                                    .background(command.tone.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s(command.titleKey))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(DS.text(0.92))
                                    Text(s(command.subtitleKey))
                                        .font(.caption)
                                        .foregroundStyle(DS.text(0.58))
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.up.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.text(0.42))
                            }
                            .padding(12)
                            .voiceAssistantSystemGlass(
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                tint: command.tone.opacity(0.055),
                                interactive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(s("assistant.commands.all"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func commandTile(_ command: QuickCommandItem) -> some View {
        Button {
            run(command)
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: command.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(command.tone)
                    .frame(width: 34, height: 34)
                    .background(command.tone.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(s(command.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.90))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
            .voiceAssistantSystemGlass(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                tint: command.tone.opacity(0.07),
                interactive: true
            )
        }
        .buttonStyle(.plain)
    }

    private var keyboardPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(s("assistant.keyboard.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(DS.text(0.96))

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    s("assistant.keyboard.placeholder"),
                    text: $typedCommand,
                    axis: .vertical
                )
                .focused($commandFieldFocused)
                .font(.body)
                .lineLimit(2...4)
                .submitLabel(.send)
                .onSubmit {
                    submitTypedCommand()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .voiceAssistantSystemGlass(
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                    tint: assistant.state.liquidTones[0].opacity(0.055),
                    interactive: true
                )

                Button {
                    submitTypedCommand()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(assistant.state.liquidGradient, in: Circle())
                        .voiceAssistantSystemGlass(
                            in: Circle(),
                            tint: assistant.state.liquidTones[1].opacity(0.18),
                            interactive: true
                        )
                }
                .buttonStyle(.plain)
                .disabled(typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel(s("assistant.keyboard.send"))
            }

            Text(s("assistant.keyboard.hint"))
                .font(.caption)
                .foregroundStyle(DS.text(0.56))
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            commandFieldFocused = true
        }
    }

    private func toggleListening() {
        DS.hapticSoft()
        if assistant.isListening {
            assistant.stopListeningAndCommit(lang: lang)
        } else {
            assistant.startListening(lang: lang)
        }
    }

    private func run(_ command: QuickCommandItem) {
        activePanel = nil
        DS.hapticSoft()
        assistant.runTextCommand(s(command.key), lang: lang)
    }

    private func submitTypedCommand() {
        let command = typedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        activePanel = nil
        typedCommand = ""
        DS.hapticSoft()
        assistant.runTextCommand(command, lang: lang)
    }
}

struct VoiceAssistantLauncherButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling
    @State private var isPressed = false
    @State private var didTriggerLongPress = false
    @State private var movedBeyondTap = false
    @State private var longPressTask: Task<Void, Never>?

    @Binding var isCollapsed: Bool

    let title: String
    let actionTitle: String
    let openTitle: String
    let hideTitle: String
    let showTitle: String
    let collapsedHint: String
    let state: AppVoiceAssistantState
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let holdThreshold: TimeInterval = 0.42
    private let movementTolerance: CGFloat = 18
    private let swipeThreshold: CGFloat = 26

    private var allowsContinuousMotion: Bool {
        !reduceMotion && !isScrolling && !DS.runtimeConstrained
    }

    private var launcherScale: CGFloat {
        if isPressed { return DS.pressScale }
        return state.isActive ? 1.015 : 1.0
    }

    var body: some View {
        HStack(spacing: 4) {
            if !isCollapsed {
                collapseButton
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .move(edge: .trailing).combined(with: .opacity)
                    )
            }

            launcherButton
        }
        .animation(reduceMotion ? nil : DS.motionState, value: isCollapsed)
        .onDisappear {
            longPressTask?.cancel()
        }
    }

    private var collapseButton: some View {
        Button {
            DS.hapticSoft()
            isCollapsed = true
        } label: {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 30, height: 30)
                    .lippiSystemGlass(
                        in: Circle(),
                        tint: state.liquidTones[0].opacity(0.08),
                        interactive: true,
                        enabled: !reduceTransparency
                    )
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.20), lineWidth: 0.8)
                    }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.text(0.66))
            }
            .frame(width: 44, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(hideTitle))
    }

    private var launcherButton: some View {
        ZStack {
            if state.isActive && allowsContinuousMotion {
                LiquidPulseRing(
                    color: state.liquidTones[0].opacity(0.32),
                    lineWidth: 1,
                    fromScale: 0.94,
                    toScale: 1.18,
                    initialOpacity: 0.46,
                    duration: 1.35
                )
                .frame(width: isCollapsed ? 52 : 58, height: 58)
            }

            Capsule()
                .fill(state.liquidGradient)
                .frame(width: isCollapsed ? 44 : 48, height: 48)
                .lippiSystemGlass(
                    in: Capsule(),
                    tint: state.liquidTones[0].opacity(0.14),
                    interactive: true,
                    enabled: !reduceTransparency
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(state.isActive ? 0.30 : 0.18), lineWidth: 0.8)
                )

            if isCollapsed {
                HStack(spacing: 5) {
                    Capsule()
                        .fill(.white.opacity(0.58))
                        .frame(width: 2, height: 14)

                    Image(systemName: state.liquidIcon)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .transition(.opacity)
            } else {
                Image(systemName: state.liquidIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .frame(width: isCollapsed ? 44 : 48, height: 48)
        .contentShape(Capsule())
        .shadow(
            color: state.liquidTones[0].opacity(reduceTransparency ? 0.14 : 0.28),
            radius: state.isActive ? 10 : 6,
            x: 0,
            y: 4
        )
        .scaleEffect(launcherScale)
        .lippiFloating(active: state.isActive, amplitude: 1.2, duration: 4.2)
        .animation(reduceMotion ? nil : DS.motionState, value: state.isActive)
        .animation(reduceMotion ? nil : DS.motionPress, value: isPressed)
        .animation(reduceMotion ? nil : DS.motionState, value: isCollapsed)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(isCollapsed ? collapsedHint : actionTitle))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onTap()
        }
        .accessibilityAction(named: Text(openTitle)) {
            onLongPress()
        }
        .accessibilityAction(named: Text(isCollapsed ? showTitle : hideTitle)) {
            DS.hapticSoft()
            isCollapsed.toggle()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    beginPressIfNeeded()

                    let moved = max(abs(value.translation.width), abs(value.translation.height))
                    if moved > movementTolerance {
                        movedBeyondTap = true
                        isPressed = false
                        longPressTask?.cancel()
                    }
                }
                .onEnded { value in
                    let isLong = didTriggerLongPress
                    let didMove = movedBeyondTap
                    let horizontalSwipe = abs(value.translation.width) > swipeThreshold
                        && abs(value.translation.width) > abs(value.translation.height)

                    longPressTask?.cancel()
                    longPressTask = nil
                    didTriggerLongPress = false
                    movedBeyondTap = false
                    isPressed = false

                    guard !isLong else { return }

                    if horizontalSwipe {
                        if isCollapsed, value.translation.width < 0 {
                            DS.hapticSoft()
                            isCollapsed = false
                        } else if !isCollapsed, value.translation.width > 0 {
                            DS.hapticSoft()
                            isCollapsed = true
                        }
                        return
                    }

                    guard !didMove else { return }
                    DS.hapticSoft()
                    onTap()
                }
        )
    }

    private func beginPressIfNeeded() {
        guard !isPressed, longPressTask == nil else { return }

        isPressed = true
        didTriggerLongPress = false
        movedBeyondTap = false
        longPressTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(holdThreshold * 1_000_000_000))
            guard !Task.isCancelled, isPressed, !movedBeyondTap else { return }

            didTriggerLongPress = true
            isPressed = false
            DS.hapticSoft()
            onLongPress()
        }
    }
}

private struct VoiceAssistantBackdrop: View {
    let tones: [Color]
    let dark: Bool
    let simplified: Bool

    var body: some View {
        ZStack {
            DS.bgBase

            RadialGradient(
                colors: [
                    tones[0].opacity(dark ? 0.20 : 0.13),
                    tones[0].opacity(0)
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 410
            )

            RadialGradient(
                colors: [
                    tones[1].opacity(dark ? 0.18 : 0.11),
                    tones[1].opacity(0)
                ],
                center: .bottomTrailing,
                startRadius: 18,
                endRadius: 460
            )

            if !simplified {
                Circle()
                    .fill(tones[0].opacity(dark ? 0.11 : 0.08))
                    .frame(width: 310, height: 310)
                    .blur(radius: 76)
                    .offset(x: -170, y: -300)

                Circle()
                    .fill(tones[1].opacity(dark ? 0.10 : 0.07))
                    .frame(width: 270, height: 270)
                    .blur(radius: 68)
                    .offset(x: 170, y: 260)
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(dark ? 0.015 : 0.18),
                    Color.clear,
                    tones[2].opacity(dark ? 0.025 : 0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.45), value: tones.description)
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
            return [Color(hex: 0x5A8CFF), Color(hex: 0x8C70FF), Color(hex: 0x5BE6D0)]
        case .listening:
            return [Color(hex: 0x2F8CFF), Color(hex: 0x54D8FF), Color(hex: 0x8C72FF)]
        case .processing:
            return [Color(hex: 0x8C6CFF), Color(hex: 0xE276FF), Color(hex: 0x4BCFD2)]
        case .speaking:
            return [Color(hex: 0x4F9CFF), Color(hex: 0xA96FFF), Color(hex: 0xFF78B8)]
        case .error:
            return [Color(hex: 0xFF786D), Color(hex: 0xFF4D82), Color(hex: 0xFFB46A)]
        }
    }

    var intelligencePalette: [Color] {
        switch self {
        case .idle:
            return [
                Color(hex: 0x407BFF),
                Color(hex: 0x9B6DFF),
                Color(hex: 0x54E3D2),
                Color(hex: 0xFF78B5),
                Color(hex: 0xFFC15B)
            ]
        case .listening:
            return [
                Color(hex: 0x188DFF),
                Color(hex: 0x49D6FF),
                Color(hex: 0x9A74FF),
                Color(hex: 0xF178C4),
                Color(hex: 0x55E0BD)
            ]
        case .processing:
            return [
                Color(hex: 0x805DFF),
                Color(hex: 0xE16EFF),
                Color(hex: 0x4BCFD2),
                Color(hex: 0x3E8CFF),
                Color(hex: 0xFFB25E)
            ]
        case .speaking:
            return [
                Color(hex: 0x378EFF),
                Color(hex: 0xAC6DFF),
                Color(hex: 0xFF6FB0),
                Color(hex: 0xFFD067),
                Color(hex: 0x50DFCE)
            ]
        case .error:
            return [
                Color(hex: 0xFF5F6D),
                Color(hex: 0xFF4B91),
                Color(hex: 0xFF9860),
                Color(hex: 0xA960FF),
                Color(hex: 0xFFCF78)
            ]
        }
    }

    var liquidGradient: LinearGradient {
        LinearGradient(
            colors: [liquidTones[0], liquidTones[1], liquidTones[2]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var orbAmplitude: CGFloat {
        switch self {
        case .idle: return 5
        case .listening: return 12
        case .processing: return 8
        case .speaking: return 10
        case .error: return 4
        }
    }

    var orbSpeed: Double {
        switch self {
        case .idle: return 5.8
        case .listening: return 1.65
        case .processing: return 2.15
        case .speaking: return 1.9
        case .error: return 4.8
        }
    }

    var orbAnimationKey: Int {
        switch self {
        case .idle: return 0
        case .listening: return 1
        case .processing: return 2
        case .speaking: return 3
        case .error: return 4
        }
    }

    var intelligenceMotion: CGFloat {
        switch self {
        case .idle: return 0.34
        case .listening: return 0.92
        case .processing: return 0.70
        case .speaking: return 0.82
        case .error: return 0.24
        }
    }

    var intelligencePulseRate: Double {
        switch self {
        case .idle: return 0.72
        case .listening: return 2.45
        case .processing: return 1.35
        case .speaking: return 2.05
        case .error: return 0.54
        }
    }
}

private struct LiquidAssistantCore: View {
    let state: AppVoiceAssistantState
    let reduceMotion: Bool
    let reduceTransparency: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate

            intelligenceOrb(time: time)
        }
        .animation(reduceMotion ? nil : DS.motionState, value: state.orbAnimationKey)
    }

    private func intelligenceOrb(time: TimeInterval) -> some View {
        let palette = state.intelligencePalette
        let pulse = CGFloat(sin(time * state.intelligencePulseRate))
        let slowPulse = CGFloat(sin(time * 0.62))
        let rotation = time * (state == .processing ? 24 : 15)
        let phase = CGFloat(time * (.pi * 2 / max(state.orbSpeed, 0.8)))
        let scale = reduceMotion ? 1 : 1 + pulse * 0.008 + slowPulse * 0.006

        return ZStack {
            ambientHalo(time: time, pulse: slowPulse)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0x263759).opacity(reduceTransparency ? 0.94 : 0.84),
                            Color(hex: 0x111B31).opacity(0.97),
                            Color(hex: 0x050812)
                        ],
                        center: UnitPoint(x: 0.42, y: 0.34),
                        startRadius: 1,
                        endRadius: 150
                    )
                )
                .overlay(
                    LippiIntelligenceField(
                        state: state,
                        time: time,
                        reduceTransparency: reduceTransparency
                    )
                    .clipShape(Circle())
                )
                .overlay(
                    voiceRibbons(phase: phase, pulse: pulse)
                        .padding(10)
                        .clipShape(Circle())
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(reduceTransparency ? 0.12 : 0.30),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.33, y: 0.22),
                                startRadius: 1,
                                endRadius: 105
                            )
                        )
                )
                .overlay(
                    Circle()
                        .trim(from: 0.08, to: 0.92)
                        .stroke(
                            AngularGradient(
                                colors: palette + [palette[0]],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 1.55, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: rotation))
                        .opacity(reduceTransparency ? 0.40 : 0.72)
                        .padding(2)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(reduceTransparency ? 0.35 : 0.62),
                                    Color.white.opacity(0.06),
                                    palette[2].opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: palette[0].opacity(reduceTransparency ? 0.14 : 0.30),
                    radius: 30,
                    x: 0,
                    y: 14
                )
        }
        .scaleEffect(scale)
    }

    private func ambientHalo(time: TimeInterval, pulse: CGFloat) -> some View {
        let palette = state.intelligencePalette
        let clockwise = Angle(degrees: time * 9)
        let counterClockwise = Angle(degrees: -time * 6.5)
        let pulseScale = reduceMotion ? 1 : 1 + pulse * 0.025

        return ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            palette[0].opacity(0.05),
                            palette[1].opacity(0.42),
                            palette[3].opacity(0.15),
                            palette[2].opacity(0.36),
                            palette[0].opacity(0.05)
                        ],
                        center: .center
                    ),
                    lineWidth: reduceTransparency ? 1 : 7
                )
                .blur(radius: reduceTransparency ? 0 : 8)
                .rotationEffect(clockwise)
                .scaleEffect(1.10 * pulseScale)

            Circle()
                .trim(from: 0.04, to: 0.64)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            palette[4].opacity(0.28),
                            palette[0].opacity(0.42),
                            Color.clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.05, lineCap: .round)
                )
                .rotationEffect(counterClockwise)
                .scaleEffect(1.20)

            Circle()
                .stroke(palette[2].opacity(reduceTransparency ? 0.08 : 0.14), lineWidth: 0.8)
                .scaleEffect(1.31 + (reduceMotion ? 0 : pulse * 0.015))
        }
    }

    private func voiceRibbons(phase: CGFloat, pulse: CGFloat) -> some View {
        let palette = state.intelligencePalette
        let liveAmplitude = state.orbAmplitude * (1 + abs(pulse) * state.intelligenceMotion * 0.22)

        return ZStack {
            LiquidVoiceWave(
                phase: phase,
                amplitude: liveAmplitude,
                verticalOffset: -2
            )
            .fill(
                LinearGradient(
                    colors: [
                        palette[0].opacity(0.10),
                        palette[0].opacity(0.88),
                        palette[1].opacity(0.82),
                        palette[3].opacity(0.68),
                        palette[4].opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: reduceTransparency ? 0 : 0.7)
            .blendMode(.plusLighter)

            LiquidVoiceWave(
                phase: -phase * 0.76 + 1.7,
                amplitude: liveAmplitude * 0.60,
                verticalOffset: 4
            )
            .fill(
                LinearGradient(
                    colors: [
                        palette[2].opacity(0.08),
                        palette[2].opacity(0.76),
                        Color.white.opacity(0.80),
                        palette[0].opacity(0.56),
                        palette[1].opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(reduceTransparency ? 0.72 : 0.94)
            .blendMode(.plusLighter)

            LiquidVoiceWave(
                phase: phase * 0.48 - 0.8,
                amplitude: liveAmplitude * 0.32,
                verticalOffset: -7
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.78),
                        palette[4].opacity(0.58),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round)
            )
            .blendMode(.plusLighter)
        }
        .rotationEffect(.degrees(state == .processing ? -5 : 0))
    }
}

private struct LippiIntelligenceField: View {
    let state: AppVoiceAssistantState
    let time: TimeInterval
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            let palette = state.intelligencePalette
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            let speed = Double(state.intelligenceMotion)

            ZStack {
                ForEach(palette.indices, id: \.self) { index in
                    let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
                    let orbit = time * speed * direction + Double(index) * 1.31
                    let distance = shortestSide * CGFloat(0.15 + Double(index % 3) * 0.025)
                    let width = shortestSide * CGFloat(index.isMultiple(of: 2) ? 0.70 : 0.58)
                    let height = shortestSide * CGFloat(index.isMultiple(of: 3) ? 0.48 : 0.62)
                    let x = center.x + cos(orbit) * distance
                    let y = center.y + sin(orbit * 1.17) * distance

                    LippiIntelligenceLobe(
                        color: palette[index],
                        reduceTransparency: reduceTransparency
                    )
                    .frame(width: width, height: height)
                    .position(x: x, y: y)
                }

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(reduceTransparency ? 0.07 : 0.18),
                                Color.white.opacity(0.025),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: shortestSide * 0.31
                        )
                    )
                    .frame(width: shortestSide * 0.56, height: shortestSide * 0.50)
                    .position(x: center.x, y: center.y)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct LippiIntelligenceLobe: View {
    let color: Color
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(reduceTransparency ? 0.08 : 0.16),
                            color.opacity(reduceTransparency ? 0.58 : 0.86),
                            color.opacity(reduceTransparency ? 0.16 : 0.30),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.58
                    )
                )
                .opacity(reduceTransparency ? 0.90 : 1)
        }
    }
}

private struct LippiIntelligenceCapsule: View {
    let state: AppVoiceAssistantState
    let status: String
    let reduceMotion: Bool
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 9) {
            MiniIntelligenceOrb(
                state: state,
                reduceMotion: reduceMotion,
                reduceTransparency: reduceTransparency
            )
            .frame(width: 29, height: 29)

            VStack(alignment: .leading, spacing: 1) {
                Text("Lippi")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.96))

                Text(status)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.text(0.60))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 13)
        .padding(.vertical, 6)
        .voiceAssistantSystemGlass(
            in: Capsule(),
            tint: state.intelligencePalette[0].opacity(0.11)
        )
        .shadow(
            color: state.intelligencePalette[0].opacity(reduceTransparency ? 0.06 : 0.13),
            radius: 12,
            y: 6
        )
        .accessibilityElement(children: .combine)
    }
}

private struct MiniIntelligenceOrb: View {
    let state: AppVoiceAssistantState
    let reduceMotion: Bool
    let reduceTransparency: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let palette = state.intelligencePalette

            ZStack {
                Circle()
                    .fill(Color(hex: 0x0A1020))

                LippiIntelligenceField(
                    state: state,
                    time: time,
                    reduceTransparency: reduceTransparency
                )
                .clipShape(Circle())

                Image(systemName: state.liquidIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: palette + [palette[0]],
                            center: .center
                        ),
                        lineWidth: 0.7
                    )
                    .rotationEffect(Angle(degrees: time * 18))
            }
        }
    }
}

private struct LiquidVoiceWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var verticalOffset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerY = rect.midY + verticalOffset
        let thickness = max(9, rect.height * 0.075)
        let steps = max(Int(rect.width / 3), 28)

        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let x = rect.minX + progress * rect.width
            let envelope = sin(progress * .pi)
            let wave = sin(progress * .pi * 2.25 + phase) * amplitude * envelope
            let secondary = sin(progress * .pi * 4.5 - phase * 0.58) * amplitude * 0.18
            let y = centerY + wave + secondary - thickness * 0.5

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        for index in stride(from: steps, through: 0, by: -1) {
            let progress = CGFloat(index) / CGFloat(steps)
            let x = rect.minX + progress * rect.width
            let envelope = sin(progress * .pi)
            let wave = sin(progress * .pi * 2.25 + phase + 0.24) * amplitude * envelope
            let secondary = sin(progress * .pi * 4.5 - phase * 0.58) * amplitude * 0.18
            let y = centerY + wave + secondary + thickness * 0.5
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

private struct LiquidPulseRing: View {
    let color: Color
    let lineWidth: CGFloat
    let fromScale: CGFloat
    let toScale: CGFloat
    let initialOpacity: Double
    let duration: Double

    @State private var isExpanded = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: lineWidth)
            .scaleEffect(isExpanded ? toScale : fromScale)
            .opacity(isExpanded ? 0 : initialOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    isExpanded = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
