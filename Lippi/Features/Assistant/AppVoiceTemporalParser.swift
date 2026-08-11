import Foundation

struct AppVoiceTemporalResolution: Equatable {
    let dueDate: Date
    let hasExplicitTime: Bool
}

enum AppVoiceTemporalParser {
    static func resolve(
        in source: String,
        lang: AppLang,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> AppVoiceTemporalResolution? {
        let text = normalize(source)
        guard !text.isEmpty else { return nil }

        var calendar = calendar
        calendar.locale = Locale(identifier: lang.localeIdentifier)

        let today = calendar.startOfDay(for: now)
        var selectedDay: Date?

        if containsAny(text, dayAfterTomorrowWords) {
            selectedDay = calendar.date(byAdding: .day, value: 2, to: today)
        } else if containsAny(text, tomorrowWords) {
            selectedDay = calendar.date(byAdding: .day, value: 1, to: today)
        } else if containsAny(text, todayWords) {
            selectedDay = today
        } else if let explicit = explicitDate(in: text, now: now, calendar: calendar) {
            selectedDay = explicit
        } else if let weekday = detectedWeekday(in: text) {
            selectedDay = nextWeekday(weekday, from: now, calendar: calendar)
        }

        let time = detectedTime(in: text)
        if selectedDay == nil, time != nil {
            selectedDay = today
        }
        guard var day = selectedDay else { return nil }

        let fallbackHour = dayPartHour(in: text) ?? 18
        let hour = time?.hour ?? fallbackHour
        let minute = time?.minute ?? 0
        var dueDate = calendar.date(
            bySettingHour: min(max(hour, 0), 23),
            minute: min(max(minute, 0), 59),
            second: 0,
            of: day
        ) ?? day.addingTimeInterval(TimeInterval(fallbackHour * 3_600))

        if dueDate <= now, selectedDay.map({ calendar.isDate($0, inSameDayAs: today) }) == true {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
            dueDate = calendar.date(
                bySettingHour: min(max(hour, 0), 23),
                minute: min(max(minute, 0), 59),
                second: 0,
                of: day
            ) ?? day.addingTimeInterval(TimeInterval(fallbackHour * 3_600))
        }

        return AppVoiceTemporalResolution(
            dueDate: dueDate,
            hasExplicitTime: time != nil || dayPartHour(in: text) != nil
        )
    }

    static func removingTemporalPhrases(from source: String, lang: AppLang) -> String {
        var text = normalize(source)
        let literalPhrases = dayAfterTomorrowWords
            + tomorrowWords
            + todayWords
            + weekdayWords.flatMap(\.words)
            + dayPartWords
            + [
                "на утро", "на вечер", "на день", "утром", "вечером", "днем",
                "in the morning", "in the evening", "this evening",
                "am morgen", "am abend", "morgens", "abends",
                "por la manana", "por la tarde", "por la noche"
            ]

        for phrase in literalPhrases.sorted(by: { $0.count > $1.count }) {
            text = replacingWholePhrase(phrase, in: text, with: " ")
        }

        let patterns = [
            #"\b(?:на|к|в|at|um|a\s+las|a\s+la)?\s*\d{1,2}(?::|\.)\d{2}\b"#,
            #"\b(?:в|к|at|um|a\s+las|a\s+la)\s+\d{1,2}\s+\d{2}\b"#,
            #"\b(?:в|к|at|um|a\s+las|a\s+la)\s+\d{1,2}(?:\s*(?:час(?:а|ов)?|ч|uhr|o'clock))?(?:\s*(?:утра|дня|вечера|ночи|am|pm))?\b"#,
            #"\b\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?\b"#,
            #"\b(?:на|к|в|at|um|a)\s*$"#
        ]
        for pattern in patterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removingReferencePhrases(from source: String) -> String {
        var text = normalize(source)
        let phrases = [
            "туда же", "на это же время", "в тот же день",
            "same time", "same day", "there too",
            "zur gleichen zeit", "am selben tag",
            "a la misma hora", "el mismo dia"
        ]
        for phrase in phrases {
            text = replacingWholePhrase(phrase, in: text, with: " ")
        }
        return text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let todayWords = ["сегодня", "today", "heute", "hoy"]
    private static let tomorrowWords = ["завтра", "tomorrow", "morgen", "manana"]
    private static let dayAfterTomorrowWords = [
        "послезавтра", "day after tomorrow", "ubermorgen", "pasado manana"
    ]
    private static let dayPartWords = [
        "утром", "утра", "днем", "дня", "вечером", "вечера", "ночью", "ночи",
        "morning", "afternoon", "evening", "tonight", "am", "pm",
        "morgens", "nachmittag", "abends", "morgen", "abend",
        "manana", "tarde", "noche"
    ]

    private struct WeekdayWords {
        let weekday: Int
        let words: [String]
    }

    private static let weekdayWords: [WeekdayWords] = [
        .init(weekday: 2, words: ["понедельник", "понедельника", "monday", "montag", "lunes"]),
        .init(weekday: 3, words: ["вторник", "вторника", "tuesday", "dienstag", "martes"]),
        .init(weekday: 4, words: ["среду", "среда", "wednesday", "mittwoch", "miercoles"]),
        .init(weekday: 5, words: ["четверг", "четверга", "thursday", "donnerstag", "jueves"]),
        .init(weekday: 6, words: ["пятницу", "пятница", "friday", "freitag", "viernes"]),
        .init(weekday: 7, words: ["субботу", "суббота", "saturday", "samstag", "sabado"]),
        .init(weekday: 1, words: ["воскресенье", "sunday", "sonntag", "domingo"])
    ]

    private static func explicitDate(in text: String, now: Date, calendar: Calendar) -> Date? {
        guard let groups = captures(
            pattern: #"\b(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?\b"#,
            in: text
        ), groups.count >= 2,
        let day = Int(groups[0]),
        let month = Int(groups[1]) else {
            return nil
        }

        var year = calendar.component(.year, from: now)
        if groups.count >= 3, !groups[2].isEmpty, let parsedYear = Int(groups[2]) {
            year = parsedYear < 100 ? 2_000 + parsedYear : parsedYear
        }
        guard var date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        if groups.count < 3, date < calendar.startOfDay(for: now),
           let nextYear = calendar.date(byAdding: .year, value: 1, to: date) {
            date = nextYear
        }
        return date
    }

    private static func detectedWeekday(in text: String) -> Int? {
        weekdayWords.first(where: { containsAny(text, $0.words) })?.weekday
    }

    private static func nextWeekday(_ weekday: Int, from now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        let current = calendar.component(.weekday, from: today)
        var distance = (weekday - current + 7) % 7
        if distance == 0 { distance = 7 }
        return calendar.date(byAdding: .day, value: distance, to: today)
    }

    private static func detectedTime(in text: String) -> (hour: Int, minute: Int)? {
        if let groups = captures(
            pattern: #"\b(?:в|к|at|um|a\s+las|a\s+la)?\s*(\d{1,2})(?::|\.)(\d{2})\b"#,
            in: text
        ), groups.count >= 2,
        let hour = Int(groups[0]), let minute = Int(groups[1]),
        (0...23).contains(hour), (0...59).contains(minute) {
            return (hour, minute)
        }

        guard let groups = captures(
            pattern: #"\b(?:в|к|at|um|a\s+las|a\s+la)\s+(\d{1,2})(?:\s*(?:час(?:а|ов)?|ч|uhr|o'clock))?(?:\s*(утра|дня|вечера|ночи|am|pm))?\b"#,
            in: text
        ), let rawHour = groups.first.flatMap(Int.init), (0...23).contains(rawHour) else {
            return nil
        }

        let qualifier = groups.count > 1 ? groups[1] : ""
        var hour = rawHour
        if ["вечера", "дня", "pm"].contains(qualifier), hour < 12 { hour += 12 }
        if ["утра", "am"].contains(qualifier), hour == 12 { hour = 0 }
        return (hour, 0)
    }

    private static func dayPartHour(in text: String) -> Int? {
        if containsAny(text, ["утром", "утра", "morning", "morgens", "por la manana"]) { return 9 }
        if containsAny(text, ["днем", "дня", "afternoon", "nachmittag", "por la tarde"]) { return 14 }
        if containsAny(text, ["вечером", "вечера", "evening", "abends", "por la noche"]) { return 19 }
        if containsAny(text, ["ночью", "ночи", "tonight", "noche"]) { return 21 }
        return nil
    }

    private static func captures(pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: fullRange) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return "" }
            return String(text[swiftRange])
        }
    }

    private static func containsAny(_ source: String, _ words: [String]) -> Bool {
        words.contains { source.contains(normalize($0)) }
    }

    private static func replacingWholePhrase(_ phrase: String, in source: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: normalize(phrase))
        return source.replacingOccurrences(
            of: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            with: replacement,
            options: .regularExpression
        )
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "й", with: "\u{F0000}")
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "\u{F0000}", with: "й")
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s:./'-]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
