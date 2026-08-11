import Foundation

/// Converts display-oriented text into a form that a compact local TTS model
/// can pronounce reliably. The visible response is left unchanged; only the
/// private copy passed to Supertonic is normalized.
enum LocalVoiceTextNormalizer {
    static func normalize(_ source: String, language: AppLang) -> String {
        var text = source
            .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: ". ")

        text = replacingTypography(in: text)
        text = replacingAliases(in: text, language: language)
        if language == .ru {
            text = replacingRussianPronunciationHints(in: text)
        }
        text = replacingDates(in: text, language: language)
        text = replacingPhoneNumbers(in: text, language: language)
        text = replacingTimes(in: text, language: language)
        text = replacingFractions(in: text, language: language)
        if language == .ru {
            text = replacingRussianPartitiveCounts(in: text)
            text = replacingRussianCountedRanges(in: text)
        }
        text = replacingRanges(in: text, language: language)
        text = replacingTemperatures(in: text, language: language)
        text = replacingPercentages(in: text, language: language)
        if language == .ru {
            text = replacingRussianAdjectiveCounters(in: text)
            text = replacingRussianCounters(in: text)
        }
        text = replacingMeasurements(in: text, language: language)
        text = replacingOrdinals(in: text, language: language)
        text = replacingIdentifiers(in: text, language: language)
        text = replacingInitialisms(in: text, language: language)
        text = replacingDecimals(in: text, language: language)
        text = replacingIntegers(in: text, language: language)
        text = replacingSymbols(in: text, language: language)
        text = removingUnsupportedSpeechCharacters(in: text)
        if language == .ru {
            text = applyingRussianProsody(to: text)
        }

        let normalized = text
            .replacingOccurrences(of: #"\.{2,}"#, with: ".", options: .regularExpression)
            .replacingOccurrences(of: #",\s*([,.!?;:])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([,.!?;:])(?=[\p{L}\p{N}])"#, with: "$1 ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // A terminal boundary gives the acoustic model enough context to
        // finish the final syllable instead of clipping a quiet ending.
        guard let last = normalized.last,
              !".!?…".contains(last) else {
            return normalized
        }
        return normalized + "."
    }

    // MARK: - Speech-safe typography

    private static func replacingTypography(in source: String) -> String {
        var text = source
        let pauses = ["•", "·", "▪", "◦", "→", "⇒"]
        for marker in pauses {
            text = text.replacingOccurrences(of: marker, with: ". ")
        }

        let removable = ["«", "»", "“", "”", "„", "\"", "`", "*", "_"]
        for marker in removable {
            text = text.replacingOccurrences(of: marker, with: "")
        }

        text = text
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "(", with: ", ")
            .replacingOccurrences(of: ")", with: ", ")
            .replacingOccurrences(of: "[", with: ", ")
            .replacingOccurrences(of: "]", with: ", ")

        return text
    }

    private static func removingUnsupportedSpeechCharacters(in source: String) -> String {
        source
            .replacingOccurrences(
                of: #"\s*[—–]\s*"#,
                with: ". ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"[^\p{L}\p{M}\p{N}\s,.!?;:…'\-]"#,
                with: " ",
                options: .regularExpression
            )
    }

    // MARK: - Structured values

    private static func replacingDates(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(\d{1,2})[./-](\d{1,2})[./-](\d{4})(?!\d)"#
        ) { groups in
            guard groups.count == 3,
                  let day = Int(groups[0]),
                  let month = Int(groups[1]),
                  let year = Int(groups[2]),
                  (1...31).contains(day),
                  (1...12).contains(month) else {
                return groups.joined(separator: " ")
            }
            let monthName = monthNames(language)[month - 1]
            switch language {
            case .ru:
                return "\(russianOrdinal(day, suffix: "е")) \(monthName) \(russianOrdinal(year, suffix: "го")) года"
            case .en:
                return "\(monthName) \(englishOrdinal(day)), \(integerWords(year, language: language))"
            case .de:
                return "\(integerWords(day, language: language)) \(monthName) \(integerWords(year, language: language))"
            case .es:
                return "\(integerWords(day, language: language)) de \(monthName) de \(integerWords(year, language: language))"
            }
        }
    }

    private static func replacingPhoneNumbers(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(\+?\d(?:[\s()‑–—-]*\d){6,})(?!\d)"#
        ) { groups in
            guard let raw = groups.first else { return "" }
            let digits = raw.compactMap(\.wholeNumberValue)
            guard digits.count >= 7 else { return raw }
            let prefix: String
            if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") {
                prefix = word(.plus, language: language) + ", "
            } else {
                prefix = ""
            }
            return prefix + digits
                .map { digitWord($0, language: language) }
                .joined(separator: ", ")
        }
    }

    private static func replacingTimes(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)([01]?\d|2[0-3])[:.]([0-5]\d)(?!\d)"#
        ) { groups in
            guard groups.count == 2,
                  let hour = Int(groups[0]),
                  let minute = Int(groups[1]) else { return groups.joined(separator: " ") }

            let hourWords = integerWords(hour, language: language)
            let minuteWords = language == .ru
                ? russianInteger(minute, gender: .feminine)
                : integerWords(minute, language: language)
            switch language {
            case .ru:
                if minute == 0 { return "\(hourWords) \(russianForm(hour, one: "час", few: "часа", many: "часов")) ровно" }
                return "\(hourWords) \(russianForm(hour, one: "час", few: "часа", many: "часов")) \(minuteWords) \(russianForm(minute, one: "минута", few: "минуты", many: "минут"))"
            case .en:
                if minute == 0 { return "\(hourWords) o'clock" }
                let spokenMinute = minute < 10 ? "oh \(minuteWords)" : minuteWords
                return "\(hourWords) \(spokenMinute)"
            case .de:
                if minute == 0 { return "\(hourWords) Uhr" }
                return "\(hourWords) Uhr \(minuteWords)"
            case .es:
                if minute == 0 { return "las \(hourWords) en punto" }
                return "las \(hourWords) y \(minuteWords)"
            }
        }
    }

    private static func replacingFractions(in source: String, language: AppLang) -> String {
        replacingMatches(in: source, pattern: #"(?<!\d)(\d+)\s*/\s*(\d+)(?!\d)"#) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            switch language {
            case .ru:
                return "\(spokenNumber(groups[0], language: language)) из \(russianGenitiveNumber(groups[1]))"
            case .en:
                return "\(spokenNumber(groups[0], language: language)) out of \(spokenNumber(groups[1], language: language))"
            case .de:
                return "\(spokenNumber(groups[0], language: language)) von \(spokenNumber(groups[1], language: language))"
            case .es:
                return "\(spokenNumber(groups[0], language: language)) de \(spokenNumber(groups[1], language: language))"
            }
        }
    }

    private static func replacingRanges(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(-?\d+(?:[.,]\d+)?)\s*[‑–—-]\s*(-?\d+(?:[.,]\d+)?)(?!\d)"#
        ) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            switch language {
            case .ru:
                return "от \(russianGenitiveNumber(groups[0])) до \(russianGenitiveNumber(groups[1]))"
            case .en:
                return "from \(spokenNumber(groups[0], language: language)) to \(spokenNumber(groups[1], language: language))"
            case .de:
                return "von \(spokenNumber(groups[0], language: language)) bis \(spokenNumber(groups[1], language: language))"
            case .es:
                return "de \(spokenNumber(groups[0], language: language)) a \(spokenNumber(groups[1], language: language))"
            }
        }
    }

    private static func replacingTemperatures(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(-?\d+(?:[.,]\d+)?)\s*°\s*([CFcf])(?![\p{L}\p{N}])"#
        ) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            let amount = spokenNumber(groups[0], language: language)
            let scale = groups[1].lowercased() == "f" ? "Fahrenheit" : "Celsius"
            switch language {
            case .ru: return "\(amount) градусов \(scale == "Celsius" ? "Цельсия" : "Фаренгейта")"
            case .en: return "\(amount) degrees \(scale)"
            case .de: return "\(amount) Grad \(scale == "Celsius" ? "Celsius" : "Fahrenheit")"
            case .es: return "\(amount) grados \(scale == "Celsius" ? "Celsius" : "Fahrenheit")"
            }
        }
    }

    private static func replacingPercentages(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(-?\d+(?:[.,]\d+)?)\s*%(?![\p{L}\p{N}])"#
        ) { groups in
            guard let raw = groups.first else { return "" }
            let amount = spokenNumber(raw, language: language)
            switch language {
            case .ru:
                if raw.contains(".") || raw.contains(",") { return "\(amount) процента" }
                return "\(amount) \(russianForm(Int(raw) ?? 0, one: "процент", few: "процента", many: "процентов"))"
            case .en: return "\(amount) percent"
            case .de: return "\(amount) Prozent"
            case .es: return "\(amount) por ciento"
            }
        }
    }

    // MARK: - Russian agreement

    private enum RussianNumeralGender {
        case masculine
        case feminine
        case neuter
    }

    private struct RussianCounter {
        let pattern: String
        let one: String
        let few: String
        let many: String
        let genitiveOne: String
        let gender: RussianNumeralGender
        let accusativeOne: String?
    }

    private struct RussianAdjectiveCounter {
        let pattern: String
        let one: String
        let few: String
        let many: String
        let gender: RussianNumeralGender
    }

    private static let russianCounters: [RussianCounter] = [
        .init(pattern: #"задач(?:а|и|у|е|ей|ами|ах)?"#, one: "задача", few: "задачи", many: "задач", genitiveOne: "задачи", gender: .feminine, accusativeOne: "задачу"),
        .init(pattern: #"цел(?:ь|и|ью|ей|ям|ями|ях)"#, one: "цель", few: "цели", many: "целей", genitiveOne: "цели", gender: .feminine, accusativeOne: "цель"),
        .init(pattern: #"сесси(?:я|и|ю|ей|ям|ями|ях)"#, one: "сессия", few: "сессии", many: "сессий", genitiveOne: "сессии", gender: .feminine, accusativeOne: "сессию"),
        .init(pattern: #"(?:минут(?:а|ы|у|е|ой|ами|ах)?|мин\.?)"#, one: "минута", few: "минуты", many: "минут", genitiveOne: "минуты", gender: .feminine, accusativeOne: "минуту"),
        .init(pattern: #"(?:секунд(?:а|ы|у|е|ой|ами|ах)?|сек\.?)"#, one: "секунда", few: "секунды", many: "секунд", genitiveOne: "секунды", gender: .feminine, accusativeOne: "секунду"),
        .init(pattern: #"недел(?:я|и|ю|е|ей|ями|ях)"#, one: "неделя", few: "недели", many: "недель", genitiveOne: "недели", gender: .feminine, accusativeOne: "неделю"),
        .init(pattern: #"трениров(?:ка|ки|ку|ке|ок|кой|ками|ках)"#, one: "тренировка", few: "тренировки", many: "тренировок", genitiveOne: "тренировки", gender: .feminine, accusativeOne: "тренировку"),
        .init(pattern: #"рекомендаци(?:я|и|ю|ей|ям|ями|ях)"#, one: "рекомендация", few: "рекомендации", many: "рекомендаций", genitiveOne: "рекомендации", gender: .feminine, accusativeOne: "рекомендацию"),
        .init(pattern: #"(?:килокалори(?:я|и|ю|ей|ям|ями|ях)|ккал)"#, one: "килокалория", few: "килокалории", many: "килокалорий", genitiveOne: "килокалории", gender: .feminine, accusativeOne: "килокалорию"),
        .init(pattern: #"попыт(?:ка|ки|ку|ке|ок|кой|ками|ках)"#, one: "попытка", few: "попытки", many: "попыток", genitiveOne: "попытки", gender: .feminine, accusativeOne: "попытку"),
        .init(pattern: #"встреч(?:а|и|у|е|ей|ами|ах)"#, one: "встреча", few: "встречи", many: "встреч", genitiveOne: "встречи", gender: .feminine, accusativeOne: "встречу"),
        .init(pattern: #"привыч(?:ка|ки|ку|ке|ек|кой|ками|ках)"#, one: "привычка", few: "привычки", many: "привычек", genitiveOne: "привычки", gender: .feminine, accusativeOne: "привычку"),
        .init(pattern: #"(?:день|дня|дней|дню|днём|днями|днях|дн\.?)"#, one: "день", few: "дня", many: "дней", genitiveOne: "дня", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"шаг(?:а|ов|у|ом|ами|ах)?"#, one: "шаг", few: "шага", many: "шагов", genitiveOne: "шага", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"цикл(?:а|ов|у|ом|ами|ах)?"#, one: "цикл", few: "цикла", many: "циклов", genitiveOne: "цикла", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"раунд(?:а|ов|у|ом|ами|ах)?"#, one: "раунд", few: "раунда", many: "раундов", genitiveOne: "раунда", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"план(?:а|ов|у|ом|ами|ах)?"#, one: "план", few: "плана", many: "планов", genitiveOne: "плана", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"пункт(?:а|ов|у|ом|ами|ах)?"#, one: "пункт", few: "пункта", many: "пунктов", genitiveOne: "пункта", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"блок(?:а|ов|у|ом|ами|ах)?"#, one: "блок", few: "блока", many: "блоков", genitiveOne: "блока", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"час(?:а|ов|у|ом|ами|ах)?"#, one: "час", few: "часа", many: "часов", genitiveOne: "часа", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"удар(?:а|ов|у|ом|ами|ах)?"#, one: "удар", few: "удара", many: "ударов", genitiveOne: "удара", gender: .masculine, accusativeOne: nil),
        .init(pattern: #"действи(?:е|я|ю|ем|й|ям|ями|ях)"#, one: "действие", few: "действия", many: "действий", genitiveOne: "действия", gender: .neuter, accusativeOne: nil),
        .init(pattern: #"изменени(?:е|я|ю|ем|й|ям|ями|ях)"#, one: "изменение", few: "изменения", many: "изменений", genitiveOne: "изменения", gender: .neuter, accusativeOne: nil),
        .init(pattern: #"упражнени(?:е|я|ю|ем|й|ям|ями|ях)"#, one: "упражнение", few: "упражнения", many: "упражнений", genitiveOne: "упражнения", gender: .neuter, accusativeOne: nil),
        .init(pattern: #"напоминани(?:е|я|ю|ем|й|ям|ями|ях)"#, one: "напоминание", few: "напоминания", many: "напоминаний", genitiveOne: "напоминания", gender: .neuter, accusativeOne: nil)
    ]

    private static let russianAdjectiveCounters: [RussianAdjectiveCounter] = [
        .init(pattern: #"выполненн(?:ая|ые|ых)\s+задач(?:а|и|у|ей)?"#, one: "выполненная задача", few: "выполненные задачи", many: "выполненных задач", gender: .feminine),
        .init(pattern: #"активн(?:ая|ые|ых)\s+задач(?:а|и|у|ей)?"#, one: "активная задача", few: "активные задачи", many: "активных задач", gender: .feminine),
        .init(pattern: #"просроченн(?:ая|ые|ых)\s+задач(?:а|и|у|ей)?"#, one: "просроченная задача", few: "просроченные задачи", many: "просроченных задач", gender: .feminine),
        .init(pattern: #"ключев(?:ой|ых|ые)\s+шаг(?:а|ов)?"#, one: "ключевой шаг", few: "ключевых шага", many: "ключевых шагов", gender: .masculine),
        .init(pattern: #"продуктивн(?:ый|ых|ые)\s+д(?:ень|ня|ней)"#, one: "продуктивный день", few: "продуктивных дня", many: "продуктивных дней", gender: .masculine),
        .init(pattern: #"коротк(?:ая|ие|их)\s+сесси(?:я|и|й)"#, one: "короткая сессия", few: "короткие сессии", many: "коротких сессий", gender: .feminine),
        .init(pattern: #"спокойн(?:ый|ые|ых)\s+цикл(?:а|ов)?"#, one: "спокойный цикл", few: "спокойных цикла", many: "спокойных циклов", gender: .masculine)
    ]

    private static func replacingRussianCountedRanges(in source: String) -> String {
        var text = source
        let separator = #"\s*[‑–—-]\s*"#

        for counter in russianAdjectiveCounters {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])(по\\s+)?(-?\\d+)\(separator)(-?\\d+)\\s+(?:\(counter.pattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 3,
                      let lower = Int(groups[1]),
                      let upper = Int(groups[2]) else {
                    return groups.joined(separator: " ")
                }
                let range = "от \(russianIntegerGenitive(lower, gender: counter.gender)) до \(russianIntegerGenitive(upper, gender: counter.gender)) \(counter.many)"
                return groups[0].isEmpty ? range : "продолжительностью \(range)"
            }
        }

        for counter in russianCounters {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])(по\\s+)?(-?\\d+)\(separator)(-?\\d+)\\s*(?:\(counter.pattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 3,
                      let lower = Int(groups[1]),
                      let upper = Int(groups[2]) else {
                    return groups.joined(separator: " ")
                }
                let range = "от \(russianIntegerGenitive(lower, gender: counter.gender)) до \(russianIntegerGenitive(upper, gender: counter.gender)) \(counter.many)"
                return groups[0].isEmpty ? range : "продолжительностью \(range)"
            }
        }
        return text
    }

    private static func replacingRussianPartitiveCounts(
        in source: String
    ) -> String {
        var text = source
        for counter in russianCounters {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])((?:в|на)\\s+)?(-?\\d+)\\s+из\\s+(-?\\d+)\\s*(?:\(counter.pattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 3,
                      let completed = Int(groups[1]),
                      let total = Int(groups[2]) else {
                    return groups.joined(separator: " ")
                }

                let prefix = groups[0]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let first: String
                if prefix.isEmpty {
                    first = russianInteger(completed, gender: counter.gender)
                } else {
                    first = russianIntegerPrepositional(
                        completed,
                        gender: counter.gender
                    )
                }
                let totalWords = russianIntegerGenitive(
                    total,
                    gender: counter.gender
                )
                let phrase = "\(first) из \(totalWords) \(counter.many)"
                return prefix.isEmpty ? phrase : "\(prefix) \(phrase)"
            }
        }
        return text
    }

    private static func russianGenitiveNumber(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard !normalized.contains("."), let value = Int(normalized) else {
            return spokenNumber(raw, language: .ru)
        }
        return russianIntegerGenitive(value, gender: .masculine)
    }

    private static func replacingRussianAdjectiveCounters(in source: String) -> String {
        var text = source
        for counter in russianAdjectiveCounters {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}.,])(-?\\d+)\\s+(?:\(counter.pattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard let raw = groups.first, let value = Int(raw) else { return groups.joined(separator: " ") }
                let phrase = russianForm(value, one: counter.one, few: counter.few, many: counter.many)
                return "\(russianInteger(value, gender: counter.gender)) \(phrase)"
            }
        }
        return text
    }

    private static func replacingRussianCounters(in source: String) -> String {
        var text = source
        let prefixPattern = #"(?:из|до|после|без|для|около|от|за|через|на)\s+"#
        let genitivePrefixes: Set<String> = ["из", "до", "после", "без", "для", "около", "от"]
        let accusativePrefixes: Set<String> = ["за", "через", "на"]

        for counter in russianCounters {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}.,])(?:(\(prefixPattern)))?(-?\\d+)\\s*(\(counter.pattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 3, let value = Int(groups[1]) else {
                    return groups.joined(separator: " ")
                }

                let prefixWithSpace = groups[0]
                let prefix = prefixWithSpace.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let rawNoun = groups[2].lowercased()
                let absolute = abs(value)

                if genitivePrefixes.contains(prefix) {
                    let noun = russianForm(
                        value,
                        one: counter.genitiveOne,
                        few: counter.many,
                        many: counter.many
                    )
                    return "\(prefix) \(russianIntegerGenitive(value, gender: counter.gender)) \(noun)"
                }

                let usesAccusative = counter.accusativeOne != nil
                    && (
                        (
                            counter.accusativeOne != counter.one
                            && counter.accusativeOne == rawNoun
                        )
                        || accusativePrefixes.contains(prefix)
                    )
                    && !(rawNoun.hasSuffix("е") || rawNoun.hasSuffix("и"))
                let singular = russianForm(value, one: true, few: false, many: false)
                let noun: String
                if singular, usesAccusative, let accusativeOne = counter.accusativeOne {
                    noun = accusativeOne
                } else {
                    noun = russianForm(value, one: counter.one, few: counter.few, many: counter.many)
                }

                let numeral = russianInteger(
                    value,
                    gender: counter.gender,
                    accusativeFeminine: usesAccusative && absolute % 10 == 1 && absolute % 100 != 11
                )
                return prefix.isEmpty ? "\(numeral) \(noun)" : "\(prefix) \(numeral) \(noun)"
            }
        }
        return text
    }

    private enum MeasurementKind: String, CaseIterable {
        case calories, kilometers, meters, kilograms, grams, milliliters, liters
        case minutes, seconds, hours, days, weeks, steps

        var patterns: [String] {
            switch self {
            case .calories: return ["ккал", "kcal"]
            case .kilometers: return ["км", "km"]
            case .meters: return ["метр(?:а|ов)?", "meters?", "metres?", "m"]
            case .kilograms: return ["кг", "kg"]
            case .grams: return ["грамм(?:а|ов)?", "grams?", "g"]
            case .milliliters: return ["мл", "ml"]
            case .liters: return ["литр(?:а|ов)?", "liters?", "litres?", "l"]
            case .minutes: return ["мин(?:ут(?:а|ы)?)?", "minutes?", "min"]
            case .seconds: return ["сек(?:унд(?:а|ы)?)?", "seconds?", "secs?", "s"]
            case .hours: return ["час(?:а|ов)?", "hours?", "hrs?", "h"]
            case .days: return ["дн(?:я|ей)?", "days?", "tage?", "días?"]
            case .weeks: return ["недел(?:я|и|ь)", "weeks?", "wochen?", "semanas?"]
            case .steps: return ["шаг(?:а|ов)?", "steps?", "schritte?", "pasos?"]
            }
        }
    }

    private static func replacingMeasurements(in source: String, language: AppLang) -> String {
        var text = source
        for kind in MeasurementKind.allCases {
            let unitPattern = kind.patterns.joined(separator: "|")
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])(-?\\d+(?:[.,]\\d+)?)\\s*(?:\(unitPattern))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard let raw = groups.first else { return "" }
                let normalized = raw.replacingOccurrences(of: ",", with: ".")
                let amount: String
                if language == .ru, let integer = Int(normalized) {
                    amount = russianInteger(
                        integer,
                        gender: russianMeasurementGender(kind)
                    )
                } else {
                    amount = spokenNumber(raw, language: language)
                }
                return "\(amount) \(measurementName(kind, rawAmount: raw, language: language))"
            }
        }
        return text
    }

    private static func russianMeasurementGender(
        _ kind: MeasurementKind
    ) -> RussianNumeralGender {
        switch kind {
        case .calories, .minutes, .seconds, .weeks:
            return .feminine
        case .kilometers, .meters, .kilograms, .grams, .milliliters,
             .liters, .hours, .days, .steps:
            return .masculine
        }
    }

    private static func measurementName(
        _ kind: MeasurementKind,
        rawAmount: String,
        language: AppLang
    ) -> String {
        let normalized = rawAmount.replacingOccurrences(of: ",", with: ".")
        let integer = Int(normalized)
        switch language {
        case .ru:
            let forms: (String, String, String)
            switch kind {
            case .calories: forms = ("килокалория", "килокалории", "килокалорий")
            case .kilometers: forms = ("километр", "километра", "километров")
            case .meters: forms = ("метр", "метра", "метров")
            case .kilograms: forms = ("килограмм", "килограмма", "килограммов")
            case .grams: forms = ("грамм", "грамма", "граммов")
            case .milliliters: forms = ("миллилитр", "миллилитра", "миллилитров")
            case .liters: forms = ("литр", "литра", "литров")
            case .minutes: forms = ("минута", "минуты", "минут")
            case .seconds: forms = ("секунда", "секунды", "секунд")
            case .hours: forms = ("час", "часа", "часов")
            case .days: forms = ("день", "дня", "дней")
            case .weeks: forms = ("неделя", "недели", "недель")
            case .steps: forms = ("шаг", "шага", "шагов")
            }
            guard let integer else { return forms.1 }
            return russianForm(integer, one: forms.0, few: forms.1, many: forms.2)
        case .en:
            let forms: (String, String)
            switch kind {
            case .calories: forms = ("kilocalorie", "kilocalories")
            case .kilometers: forms = ("kilometer", "kilometers")
            case .meters: forms = ("meter", "meters")
            case .kilograms: forms = ("kilogram", "kilograms")
            case .grams: forms = ("gram", "grams")
            case .milliliters: forms = ("milliliter", "milliliters")
            case .liters: forms = ("liter", "liters")
            case .minutes: forms = ("minute", "minutes")
            case .seconds: forms = ("second", "seconds")
            case .hours: forms = ("hour", "hours")
            case .days: forms = ("day", "days")
            case .weeks: forms = ("week", "weeks")
            case .steps: forms = ("step", "steps")
            }
            return normalized == "1" ? forms.0 : forms.1
        case .de:
            switch kind {
            case .calories: return "Kilokalorien"
            case .kilometers: return "Kilometer"
            case .meters: return "Meter"
            case .kilograms: return "Kilogramm"
            case .grams: return "Gramm"
            case .milliliters: return "Milliliter"
            case .liters: return "Liter"
            case .minutes: return normalized == "1" ? "Minute" : "Minuten"
            case .seconds: return normalized == "1" ? "Sekunde" : "Sekunden"
            case .hours: return normalized == "1" ? "Stunde" : "Stunden"
            case .days: return normalized == "1" ? "Tag" : "Tage"
            case .weeks: return normalized == "1" ? "Woche" : "Wochen"
            case .steps: return normalized == "1" ? "Schritt" : "Schritte"
            }
        case .es:
            let forms: (String, String)
            switch kind {
            case .calories: forms = ("kilocaloría", "kilocalorías")
            case .kilometers: forms = ("kilómetro", "kilómetros")
            case .meters: forms = ("metro", "metros")
            case .kilograms: forms = ("kilogramo", "kilogramos")
            case .grams: forms = ("gramo", "gramos")
            case .milliliters: forms = ("mililitro", "mililitros")
            case .liters: forms = ("litro", "litros")
            case .minutes: forms = ("minuto", "minutos")
            case .seconds: forms = ("segundo", "segundos")
            case .hours: forms = ("hora", "horas")
            case .days: forms = ("día", "días")
            case .weeks: forms = ("semana", "semanas")
            case .steps: forms = ("paso", "pasos")
            }
            return normalized == "1" ? forms.0 : forms.1
        }
    }

    // MARK: - Identifiers and standalone numbers

    private static func replacingOrdinals(in source: String, language: AppLang) -> String {
        switch language {
        case .ru:
            return replacingMatches(
                in: source,
                pattern: #"(?<!\d)(\d+)[-‑]?(й|я|е|го|му|ом|ую)(?![\p{L}\p{N}])"#,
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 2, let value = Int(groups[0]) else { return groups.joined() }
                return russianOrdinal(value, suffix: groups[1].lowercased())
            }
        case .en:
            return replacingMatches(
                in: source,
                pattern: #"(?<!\d)(\d+)(?:st|nd|rd|th)(?![\p{L}\p{N}])"#,
                options: [.caseInsensitive]
            ) { groups in
                guard let raw = groups.first, let value = Int(raw) else { return groups.joined() }
                return englishOrdinal(value)
            }
        case .de, .es:
            return source
        }
    }

    private static func replacingIdentifiers(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<![\p{L}\p{N}])([A-ZА-ЯЁ]{1,5})(\d{1,4})(?![\p{L}\p{N}])"#
        ) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            return "\(spellLetters(groups[0], language: language)) \(spokenNumber(groups[1], language: language))"
        }
    }

    private static func replacingInitialisms(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<![\p{L}\p{N}])([A-ZА-ЯЁ]{2,6})(?![\p{L}\p{N}])"#
        ) { groups in
            guard let token = groups.first else { return "" }
            return spellLetters(token, language: language)
        }
    }

    private static func replacingDecimals(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<![\p{L}\p{N}])(-?\d+[.,]\d+)(?![\p{L}\p{N}])"#
        ) { groups in
            groups.first.map { spokenNumber($0, language: language) } ?? ""
        }
    }

    private static func replacingIntegers(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<![\p{L}\p{N}])(-?\d+)(?![\p{L}\p{N}])"#
        ) { groups in
            groups.first.map { spokenNumber($0, language: language) } ?? ""
        }
    }

    // MARK: - Language helpers

    private enum SymbolWord { case plus, minus, number, and }

    private static func replacingSymbols(in source: String, language: AppLang) -> String {
        var text = source
        let replacements: [(String, String)] = [
            ("№", word(.number, language: language)),
            ("+", word(.plus, language: language)),
            ("−", word(.minus, language: language)),
            ("&", word(.and, language: language))
        ]
        for (symbol, spoken) in replacements {
            text = text.replacingOccurrences(of: symbol, with: " \(spoken) ")
        }
        return text
    }

    private static func replacingAliases(in source: String, language: AppLang) -> String {
        let aliases: [(String, String)]
        switch language {
        case .ru:
            aliases = [
                ("Apple Watch", "Эпл Вотч"), ("HealthKit", "Хелс Кит"),
                ("Apple Health", "Эпл Здоровье"), ("WidgetKit", "Виджет Кит"),
                ("Live Activity", "Лайв Активити"), ("Liquid Glass", "Ликвид Гласс"),
                ("iPhone", "айфон"), ("iOS", "ай о эс"),
                ("watchOS", "вотч о эс"), ("macOS", "мак о эс"),
                ("Lippi", "Липпи"), ("Bonsai", "Бонсай"),
                ("Supertonic", "Супертоник"), ("TrueDepth", "Тру Дэпт"),
                ("Vision", "Вижен"), ("Foundation Models", "Фаундейшн Моделс"),
                ("Swift", "Свифт"),
                ("Pomodoro", "Помодоро"), ("AI", "искусственный интеллект"),
                ("ИИ", "искусственный интеллект"), ("HRV", "вариабельность сердечного ритма"),
                ("SpO2", "сатурация кислорода"), ("VO2 max", "максимальное потребление кислорода"),
                ("ECG", "электрокардиограмма"), ("BPM", "ударов в минуту"),
                ("уд/мин", "ударов в минуту")
            ]
        case .en:
            aliases = [
                ("iOS", "eye oh ess"), ("AI", "artificial intelligence"),
                ("HRV", "heart rate variability"), ("SpO2", "blood oxygen saturation"),
                ("VO2 max", "maximum oxygen uptake"), ("ECG", "electrocardiogram")
            ]
        case .de:
            aliases = [
                ("iOS", "i o es"), ("AI", "künstliche Intelligenz"), ("KI", "künstliche Intelligenz"),
                ("HRV", "Herzfrequenzvariabilität"), ("SpO2", "Sauerstoffsättigung"),
                ("VO2 max", "maximale Sauerstoffaufnahme"), ("ECG", "Elektrokardiogramm")
            ]
        case .es:
            aliases = [
                ("iOS", "i o ese"), ("AI", "inteligencia artificial"), ("IA", "inteligencia artificial"),
                ("HRV", "variabilidad de la frecuencia cardíaca"), ("SpO2", "saturación de oxígeno"),
                ("VO2 max", "consumo máximo de oxígeno"), ("ECG", "electrocardiograma")
            ]
        }

        return aliases.sorted(by: { $0.0.count > $1.0.count }).reduce(source) { result, alias in
            let escaped = NSRegularExpression.escapedPattern(for: alias.0)
            return replacingMatches(
                in: result,
                pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { _ in alias.1 }
        }
    }

    private static func replacingRussianPronunciationHints(
        in source: String
    ) -> String {
        let phrases: [(String, String)] = [
            (#"\bи\s+т\.\s*д\."#, "и так далее"),
            (#"\bи\s+т\.\s*п\."#, "и тому подобное"),
            (#"\bт\.\s*е\."#, "то есть")
        ]
        var text = replacingRussianLetterSequences(in: source)
        for (pattern, replacement) in phrases {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let words: [(String, String)] = [
            ("ее", "её"),
            ("еще", "ещё"),
            ("мое", "моё"),
            ("твое", "твоё"),
            ("свое", "своё"),
            ("идет", "идёт"),
            ("идем", "идём"),
            ("идешь", "идёшь"),
            ("пойдет", "пойдёт"),
            ("пойдем", "пойдём"),
            ("пойдешь", "пойдёшь"),
            ("начнем", "начнём"),
            ("перейдем", "перейдём"),
            ("найдем", "найдём"),
            ("учтем", "учтём"),
            ("ждет", "ждёт"),
            ("дает", "даёт"),
            ("ведет", "ведёт"),
            ("создает", "создаёт"),
            ("создаем", "создаём"),
            ("перенес", "перенёс"),
            ("перенесет", "перенесёт"),
            ("сохранен", "сохранён"),
            ("сохраненный", "сохранённый"),
            ("сохраненная", "сохранённая"),
            ("сохраненное", "сохранённое"),
            ("сохраненной", "сохранённой"),
            ("включен", "включён"),
            ("отключен", "отключён"),
            ("завершен", "завершён"),
            ("определен", "определён"),
            ("обновлен", "обновлён"),
            ("учет", "учёт"),
            ("прием", "приём"),
            ("объем", "объём"),
            ("теплый", "тёплый"),
            ("теплая", "тёплая"),
            ("теплое", "тёплое"),
            ("легкий", "лёгкий"),
            ("легкая", "лёгкая"),
            ("легкое", "лёгкое"),
            ("надежный", "надёжный"),
            ("надежная", "надёжная"),
            ("надежное", "надёжное"),
            ("четкий", "чёткий"),
            ("четкая", "чёткая"),
            ("четкое", "чёткое"),
            ("серьезный", "серьёзный"),
            ("серьезная", "серьёзная"),
            ("серьезное", "серьёзное")
        ]

        for (sourceWord, spokenWord) in words {
            let escaped = NSRegularExpression.escapedPattern(for: sourceWord)
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])(\(escaped))(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard let original = groups.first else { return spokenWord }
                return matchingCase(of: spokenWord, to: original)
            }
        }

        let participleStems: [(String, String)] = [
            ("сохраненн", "сохранённ"),
            ("включенн", "включённ"),
            ("отключенн", "отключённ"),
            ("завершенн", "завершённ"),
            ("определенн", "определённ"),
            ("обновленн", "обновлённ")
        ]
        for (sourceStem, spokenStem) in participleStems {
            text = replacingMatches(
                in: text,
                pattern: "(?<![\\p{L}\\p{N}])(\(sourceStem))([а-яё]*)(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) { groups in
                guard groups.count == 2 else { return groups.joined() }
                return matchingCase(of: spokenStem, to: groups[0]) + groups[1]
            }
        }
        return text
    }

    /// Makes letter names explicit only when the text clearly refers to
    /// letters. Normal words containing `е`, `ё`, `и`, or `й` are untouched.
    private static func replacingRussianLetterSequences(in source: String) -> String {
        var text = replacingMatches(
            in: source,
            pattern: #"(?<![\p{L}\p{N}])((?:букв(?:а|ы|у|е|ой|ами|ах)|символ(?:а|ы|ов|у|ом|ами|ах)))\s+((?:[еёий](?:\s*(?:[,;/]|\bи\b)\s*[еёий]){0,7}))(?![\p{L}\p{N}])"#,
            options: [.caseInsensitive]
        ) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            let noun = groups[0]
            let rawLetters = groups[1]
            let separated = rawLetters.replacingOccurrences(
                of: #"\s+и\s+(?=[еёий](?:\s|$))"#,
                with: ",",
                options: [.regularExpression, .caseInsensitive]
            )
            let letters = separated
                .components(separatedBy: CharacterSet(charactersIn: ",;/"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return noun + ": " + letters.map(russianLetterName).joined(separator: ", ")
        }

        // `й` and `ё` are never standalone Russian words, while a lone `е`
        // is overwhelmingly a requested letter. A lone `и` is deliberately
        // not replaced because it is also the everyday conjunction.
        text = replacingMatches(
            in: text,
            pattern: #"(?<!буква )(?<![\p{L}\p{N}])([еёй])(?![\p{L}\p{N}])"#,
            options: [.caseInsensitive]
        ) { groups in
            groups.first.map(russianLetterName) ?? ""
        }
        return text
    }

    private static func russianLetterName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "ё": return "буква ё"
        case "й": return "буква и краткое"
        case "и": return "буква и"
        default: return "буква е"
        }
    }

    private static func matchingCase(of replacement: String, to original: String) -> String {
        guard original.first?.isUppercase == true,
              let first = replacement.first else {
            return replacement
        }
        return first.uppercased() + String(replacement.dropFirst())
    }

    private static func applyingRussianProsody(to source: String) -> String {
        var text = source

        // Supertonic reacts more naturally to explicit medium pauses than to
        // semicolons, which compact multilingual voices often ignore.
        text = text.replacingOccurrences(of: ";", with: ". ")

        let cues = [
            "хорошо", "отлично", "итак", "конечно", "понимаю",
            "пожалуйста", "например", "главное"
        ].joined(separator: "|")
        text = replacingMatches(
            in: text,
            pattern: "(^|[.!?…]\\s+)(\(cues))(?=\\s+)(?!\\s*[,!.?:;])",
            options: [.caseInsensitive]
        ) { groups in
            guard groups.count == 2 else { return groups.joined() }
            return groups[0] + groups[1] + ","
        }
        return text
    }

    private static func spokenNumber(_ raw: String, language: AppLang) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        if normalized.contains("."),
           let separator = normalized.firstIndex(of: ".") {
            let integerPart = String(normalized[..<separator])
            let fractionPart = String(normalized[normalized.index(after: separator)...])
            if language == .ru {
                return russianDecimal(
                    integerPart: integerPart,
                    fractionPart: fractionPart
                )
            }
            let connector: String
            switch language {
            case .ru: connector = "целых"
            case .en: connector = "point"
            case .de: connector = "Komma"
            case .es: connector = "coma"
            }
            let fraction = fractionPart.compactMap(\.wholeNumberValue)
                .map { digitWord($0, language: language) }
                .joined(separator: " ")
            return "\(spokenInteger(integerPart, language: language)) \(connector) \(fraction)"
        }
        return spokenInteger(normalized, language: language)
    }

    private static func russianDecimal(
        integerPart: String,
        fractionPart: String
    ) -> String {
        let negative = integerPart.hasPrefix("-")
        let rawInteger = integerPart.replacingOccurrences(of: "-", with: "")
        guard let integer = Int(rawInteger),
              let fraction = Int(fractionPart) else {
            let fallback = fractionPart.compactMap(\.wholeNumberValue)
                .map { digitWord($0, language: .ru) }
                .joined(separator: " ")
            return "\(spokenInteger(integerPart, language: .ru)) целых \(fallback)"
        }

        let signedInteger = negative ? -integer : integer
        let unsignedIntegerWords = russianInteger(integer, gender: .feminine)
        let integerWords = negative ? "минус \(unsignedIntegerWords)" : unsignedIntegerWords
        let wholeForm = russianForm(
            signedInteger,
            one: "целая",
            few: "целых",
            many: "целых"
        )

        let denominator: String
        switch fractionPart.count {
        case 1:
            denominator = russianForm(fraction, one: "десятая", few: "десятых", many: "десятых")
        case 2:
            denominator = russianForm(fraction, one: "сотая", few: "сотых", many: "сотых")
        case 3:
            denominator = russianForm(fraction, one: "тысячная", few: "тысячных", many: "тысячных")
        default:
            let digits = fractionPart.compactMap(\.wholeNumberValue)
                .map { digitWord($0, language: .ru) }
                .joined(separator: " ")
            return "\(integerWords) \(wholeForm) \(digits)"
        }

        return "\(integerWords) \(wholeForm) \(russianInteger(fraction, gender: .feminine)) \(denominator)"
    }

    private static func spokenInteger(_ raw: String, language: AppLang) -> String {
        guard let value = Int(raw) else {
            return raw.compactMap(\.wholeNumberValue)
                .map { digitWord($0, language: language) }
                .joined(separator: " ")
        }
        return integerWords(value, language: language)
    }

    private static func integerWords(_ value: Int, language: AppLang) -> String {
        switch language {
        case .ru: return russianInteger(value)
        case .en: return englishInteger(value)
        case .de: return germanInteger(value)
        case .es: return spanishInteger(value)
        }
    }

    private static func digitWord(_ digit: Int, language: AppLang) -> String {
        let values: [[String]] = [
            ["ноль", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"],
            ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"],
            ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun"],
            ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
        ]
        let index: Int
        switch language { case .ru: index = 0; case .en: index = 1; case .de: index = 2; case .es: index = 3 }
        return values[index][min(max(digit, 0), 9)]
    }

    private static func spellLetters(_ token: String, language: AppLang) -> String {
        token.map { character in
            let key = String(character).uppercased()
            return letterNames(language)[key] ?? String(character)
        }.joined(separator: ", ")
    }

    private static func letterNames(_ language: AppLang) -> [String: String] {
        switch language {
        case .ru:
            return [
                "A":"эй", "B":"би", "C":"си", "D":"ди", "E":"и", "F":"эф", "G":"джи", "H":"эйч", "I":"ай", "J":"джей", "K":"кей", "L":"эл", "M":"эм", "N":"эн", "O":"оу", "P":"пи", "Q":"кью", "R":"ар", "S":"эс", "T":"ти", "U":"ю", "V":"ви", "W":"дабл ю", "X":"икс", "Y":"уай", "Z":"зед",
                "А":"а", "Б":"бэ", "В":"вэ", "Г":"гэ", "Д":"дэ", "Е":"е", "Ё":"ё", "Ж":"жэ", "З":"зэ", "И":"и", "Й":"и краткое", "К":"ка", "Л":"эл", "М":"эм", "Н":"эн", "О":"о", "П":"пэ", "Р":"эр", "С":"эс", "Т":"тэ", "У":"у", "Ф":"эф", "Х":"ха", "Ц":"цэ", "Ч":"чэ", "Ш":"ша", "Щ":"ща", "Ъ":"твёрдый знак", "Ы":"ы", "Ь":"мягкий знак", "Э":"э", "Ю":"ю", "Я":"я"
            ]
        case .en:
            return Dictionary(uniqueKeysWithValues: zip(
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init),
                ["ay","bee","cee","dee","ee","ef","gee","aitch","eye","jay","kay","el","em","en","oh","pee","cue","ar","ess","tee","you","vee","double you","ex","why","zed"]
            ))
        case .de:
            return Dictionary(uniqueKeysWithValues: zip(
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init),
                ["a","be","tse","de","e","ef","ge","ha","i","jot","ka","el","em","en","o","pe","ku","er","es","te","u","fau","we","iks","ypsilon","tset"]
            ))
        case .es:
            return Dictionary(uniqueKeysWithValues: zip(
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init),
                ["a","be","ce","de","e","efe","ge","hache","i","jota","ka","ele","eme","ene","o","pe","cu","erre","ese","te","u","uve","doble uve","equis","ye","zeta"]
            ))
        }
    }

    private static func word(_ symbol: SymbolWord, language: AppLang) -> String {
        switch (symbol, language) {
        case (.plus, .ru): return "плюс"
        case (.minus, .ru): return "минус"
        case (.number, .ru): return "номер"
        case (.and, .ru): return "и"
        case (.plus, .en): return "plus"
        case (.minus, .en): return "minus"
        case (.number, .en): return "number"
        case (.and, .en): return "and"
        case (.plus, .de): return "plus"
        case (.minus, .de): return "minus"
        case (.number, .de): return "Nummer"
        case (.and, .de): return "und"
        case (.plus, .es): return "más"
        case (.minus, .es): return "menos"
        case (.number, .es): return "número"
        case (.and, .es): return "y"
        }
    }

    private static func monthNames(_ language: AppLang) -> [String] {
        switch language {
        case .ru: return ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        case .en: return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        case .de: return ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
        case .es: return ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        }
    }

    // MARK: - Number names

    private static func russianInteger(
        _ value: Int,
        gender: RussianNumeralGender = .masculine,
        accusativeFeminine: Bool = false
    ) -> String {
        if value == 0 { return "ноль" }
        if value < 0 {
            return "минус " + russianInteger(
                abs(value),
                gender: gender,
                accusativeFeminine: accusativeFeminine
            )
        }
        guard value <= 999_999_999 else { return String(value).compactMap(\.wholeNumberValue).map { digitWord($0, language: .ru) }.joined(separator: " ") }

        let scales = [
            (1_000_000, "миллион", "миллиона", "миллионов", false),
            (1_000, "тысяча", "тысячи", "тысяч", true)
        ]
        var remainder = value
        var parts: [String] = []
        for (scale, one, few, many, feminine) in scales where remainder >= scale {
            let amount = remainder / scale
            parts.append(
                russianChunk(
                    amount,
                    gender: feminine ? .feminine : .masculine
                )
            )
            parts.append(russianForm(amount, one: one, few: few, many: many))
            remainder %= scale
        }
        if remainder > 0 {
            parts.append(
                russianChunk(
                    remainder,
                    gender: gender,
                    accusativeFeminine: accusativeFeminine
                )
            )
        }
        return parts.joined(separator: " ")
    }

    private static func russianChunk(
        _ value: Int,
        gender: RussianNumeralGender,
        accusativeFeminine: Bool = false
    ) -> String {
        let hundreds = ["", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот"]
        let teens = ["десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
        let tens = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"]
        let ones: [String]
        switch gender {
        case .masculine:
            ones = ["", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
        case .feminine:
            ones = [
                "",
                accusativeFeminine ? "одну" : "одна",
                "две",
                "три",
                "четыре",
                "пять",
                "шесть",
                "семь",
                "восемь",
                "девять"
            ]
        case .neuter:
            ones = ["", "одно", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
        }
        var parts: [String] = []
        let h = value / 100
        if h > 0 { parts.append(hundreds[h]) }
        let rest = value % 100
        if (10...19).contains(rest) {
            parts.append(teens[rest - 10])
        } else {
            if rest / 10 > 0 { parts.append(tens[rest / 10]) }
            if rest % 10 > 0 { parts.append(ones[rest % 10]) }
        }
        return parts.joined(separator: " ")
    }

    private static func russianIntegerGenitive(
        _ value: Int,
        gender: RussianNumeralGender
    ) -> String {
        if value == 0 { return "нуля" }
        if value < 0 {
            return "минус " + russianIntegerGenitive(abs(value), gender: gender)
        }
        guard value <= 999_999_999 else {
            return russianInteger(value, gender: gender)
        }

        let scales = [
            (1_000_000, "миллиона", "миллионов", RussianNumeralGender.masculine),
            (1_000, "тысячи", "тысяч", RussianNumeralGender.feminine)
        ]
        var remainder = value
        var parts: [String] = []

        for (scale, one, many, scaleGender) in scales where remainder >= scale {
            let amount = remainder / scale
            parts.append(russianGenitiveChunk(amount, gender: scaleGender))
            parts.append(abs(amount) % 10 == 1 && abs(amount) % 100 != 11 ? one : many)
            remainder %= scale
        }

        if remainder > 0 {
            parts.append(russianGenitiveChunk(remainder, gender: gender))
        }
        return parts.joined(separator: " ")
    }

    private static func russianGenitiveChunk(
        _ value: Int,
        gender: RussianNumeralGender
    ) -> String {
        let hundreds = [
            "", "ста", "двухсот", "трёхсот", "четырёхсот",
            "пятисот", "шестисот", "семисот", "восьмисот", "девятисот"
        ]
        let underTwenty = [
            "", "", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти",
            "десяти", "одиннадцати", "двенадцати", "тринадцати", "четырнадцати",
            "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати"
        ]
        let tens = [
            "", "", "двадцати", "тридцати", "сорока",
            "пятидесяти", "шестидесяти", "семидесяти", "восьмидесяти", "девяноста"
        ]

        var parts: [String] = []
        let hundredsIndex = value / 100
        if hundredsIndex > 0 {
            parts.append(hundreds[hundredsIndex])
        }

        let rest = value % 100
        if rest == 1 {
            parts.append(gender == .feminine ? "одной" : "одного")
        } else if (2...19).contains(rest) {
            parts.append(underTwenty[rest])
        } else if rest >= 20 {
            parts.append(tens[rest / 10])
            let unit = rest % 10
            if unit == 1 {
                parts.append(gender == .feminine ? "одной" : "одного")
            } else if unit > 1 {
                parts.append(underTwenty[unit])
            }
        }

        return parts.joined(separator: " ")
    }

    private static func russianIntegerPrepositional(
        _ value: Int,
        gender: RussianNumeralGender
    ) -> String {
        if value == 0 { return "нуле" }
        if value < 0 {
            return "минус " + russianIntegerPrepositional(
                abs(value),
                gender: gender
            )
        }
        guard value < 1_000 else {
            return russianIntegerGenitive(value, gender: gender)
        }

        let hundreds = [
            "", "ста", "двухстах", "трёхстах", "четырёхстах",
            "пятистах", "шестистах", "семистах", "восьмистах", "девятистах"
        ]
        let underTwenty = [
            "", "", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти",
            "десяти", "одиннадцати", "двенадцати", "тринадцати", "четырнадцати",
            "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати"
        ]
        let tens = [
            "", "", "двадцати", "тридцати", "сорока",
            "пятидесяти", "шестидесяти", "семидесяти", "восьмидесяти", "девяноста"
        ]

        var parts: [String] = []
        let hundredsIndex = value / 100
        if hundredsIndex > 0 {
            parts.append(hundreds[hundredsIndex])
        }

        let rest = value % 100
        if rest == 1 {
            parts.append(gender == .feminine ? "одной" : "одном")
        } else if (2...19).contains(rest) {
            parts.append(underTwenty[rest])
        } else if rest >= 20 {
            parts.append(tens[rest / 10])
            let unit = rest % 10
            if unit == 1 {
                parts.append(gender == .feminine ? "одной" : "одном")
            } else if unit > 1 {
                parts.append(underTwenty[unit])
            }
        }
        return parts.joined(separator: " ")
    }

    private static func russianForm<T>(_ value: Int, one: T, few: T, many: T) -> T {
        let absolute = abs(value) % 100
        if (11...14).contains(absolute) { return many }
        switch absolute % 10 {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }

    private static func englishInteger(_ value: Int) -> String {
        if value == 0 { return "zero" }
        if value < 0 { return "minus " + englishInteger(abs(value)) }
        guard value <= 999_999_999 else { return String(value).compactMap(\.wholeNumberValue).map { digitWord($0, language: .en) }.joined(separator: " ") }
        let scales = [(1_000_000, "million"), (1_000, "thousand")]
        var remainder = value
        var parts: [String] = []
        for (scale, name) in scales where remainder >= scale {
            parts.append(englishUnderThousand(remainder / scale))
            parts.append(name)
            remainder %= scale
        }
        if remainder > 0 { parts.append(englishUnderThousand(remainder)) }
        return parts.joined(separator: " ")
    }

    private static func englishUnderThousand(_ value: Int) -> String {
        let ones = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        var remainder = value
        var parts: [String] = []
        if remainder >= 100 {
            parts.append(ones[remainder / 100] + " hundred")
            remainder %= 100
        }
        if remainder >= 20 {
            parts.append(tens[remainder / 10] + (remainder % 10 > 0 ? " " + ones[remainder % 10] : ""))
        } else if remainder > 0 {
            parts.append(ones[remainder])
        }
        return parts.joined(separator: " ")
    }

    private static func germanInteger(_ value: Int) -> String {
        if value == 0 { return "null" }
        if value < 0 { return "minus " + germanInteger(abs(value)) }
        guard value <= 999_999_999 else { return String(value).compactMap(\.wholeNumberValue).map { digitWord($0, language: .de) }.joined(separator: " ") }
        if value >= 1_000_000 {
            let millions = value / 1_000_000
            let prefix = millions == 1 ? "eine Million" : "\(germanInteger(millions)) Millionen"
            let rest = value % 1_000_000
            return rest == 0 ? prefix : "\(prefix) \(germanInteger(rest))"
        }
        if value >= 1_000 {
            let thousands = value / 1_000
            let prefix = thousands == 1 ? "eintausend" : germanUnderThousand(thousands) + "tausend"
            let rest = value % 1_000
            return rest == 0 ? prefix : prefix + germanUnderThousand(rest)
        }
        return germanUnderThousand(value)
    }

    private static func germanUnderThousand(_ value: Int) -> String {
        let basic = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn"]
        let tens = ["", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig"]
        if value < 20 { return basic[value] }
        if value < 100 {
            let unit = value % 10
            return unit == 0 ? tens[value / 10] : "\(unit == 1 ? "ein" : basic[unit])und\(tens[value / 10])"
        }
        let rest = value % 100
        let prefix = "\(value / 100 == 1 ? "ein" : basic[value / 100])hundert"
        return rest == 0 ? prefix : prefix + germanUnderThousand(rest)
    }

    private static func spanishInteger(_ value: Int) -> String {
        if value == 0 { return "cero" }
        if value < 0 { return "menos " + spanishInteger(abs(value)) }
        guard value <= 999_999_999 else { return String(value).compactMap(\.wholeNumberValue).map { digitWord($0, language: .es) }.joined(separator: " ") }
        if value >= 1_000_000 {
            let millions = value / 1_000_000
            let prefix = millions == 1 ? "un millón" : "\(spanishInteger(millions)) millones"
            let rest = value % 1_000_000
            return rest == 0 ? prefix : "\(prefix) \(spanishInteger(rest))"
        }
        if value >= 1_000 {
            let thousands = value / 1_000
            let prefix = thousands == 1 ? "mil" : "\(spanishUnderThousand(thousands)) mil"
            let rest = value % 1_000
            return rest == 0 ? prefix : "\(prefix) \(spanishUnderThousand(rest))"
        }
        return spanishUnderThousand(value)
    }

    private static func spanishUnderThousand(_ value: Int) -> String {
        let basic = ["cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós", "veintitrés", "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve"]
        let tens = ["", "", "", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"]
        let hundreds = ["", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos"]
        if value < 30 { return basic[value] }
        if value == 100 { return "cien" }
        var parts: [String] = []
        let h = value / 100
        if h > 0 { parts.append(hundreds[h]) }
        let rest = value % 100
        if rest > 0 {
            if rest < 30 { parts.append(basic[rest]) }
            else { parts.append(tens[rest / 10] + (rest % 10 > 0 ? " y " + basic[rest % 10] : "")) }
        }
        return parts.joined(separator: " ")
    }

    private static func russianOrdinal(_ value: Int, suffix: String) -> String {
        let exact: [Int: String] = [
            0:"нулевой", 1:"первый", 2:"второй", 3:"третий", 4:"четвёртый", 5:"пятый",
            6:"шестой", 7:"седьмой", 8:"восьмой", 9:"девятый", 10:"десятый",
            11:"одиннадцатый", 12:"двенадцатый", 13:"тринадцатый", 14:"четырнадцатый",
            15:"пятнадцатый", 16:"шестнадцатый", 17:"семнадцатый", 18:"восемнадцатый",
            19:"девятнадцатый", 20:"двадцатый", 30:"тридцатый", 40:"сороковой",
            50:"пятидесятый", 60:"шестидесятый", 70:"семидесятый", 80:"восьмидесятый",
            90:"девяностый", 100:"сотый", 200:"двухсотый", 300:"трёхсотый",
            400:"четырёхсотый", 500:"пятисотый", 600:"шестисотый", 700:"семисотый",
            800:"восьмисотый", 900:"девятисотый"
        ]
        let masculine: String
        if let word = exact[value] {
            masculine = word
        } else if value >= 1_000, value < 1_000_000, value % 1_000 != 0 {
            let remainder = value % 1_000
            masculine = "\(russianInteger(value - remainder)) \(russianOrdinal(remainder, suffix: "й"))"
        } else if value == 1_000 {
            masculine = "тысячный"
        } else if value == 2_000 {
            masculine = "двухтысячный"
        } else if value > 0, value < 1_000 {
            let remainder = value >= 100 ? value % 100 : value % 10
            let leading = value - remainder
            masculine = "\(russianInteger(leading)) \(russianOrdinal(remainder, suffix: "й"))"
        } else {
            return russianInteger(value)
        }
        return inflectRussianOrdinal(masculine, suffix: suffix)
    }

    private static func inflectRussianOrdinal(_ phrase: String, suffix: String) -> String {
        guard suffix != "й", let space = phrase.lastIndex(of: " ") else {
            return inflectRussianOrdinalWord(phrase, suffix: suffix)
        }
        let head = phrase[...space]
        let tail = phrase[phrase.index(after: space)...]
        return String(head) + inflectRussianOrdinalWord(String(tail), suffix: suffix)
    }

    private static func inflectRussianOrdinalWord(_ word: String, suffix: String) -> String {
        let soft = word.hasSuffix("ий")
        let stem = String(word.dropLast(2))
        switch suffix {
        case "я": return stem + (soft ? "ья" : "ая")
        case "е": return stem + (soft ? "ье" : "ое")
        case "го": return stem + (soft ? "ьего" : "ого")
        case "му": return stem + (soft ? "ьему" : "ому")
        case "ом": return stem + (soft ? "ьем" : "ом")
        case "ую": return stem + (soft ? "ью" : "ую")
        default: return word
        }
    }

    private static func englishOrdinal(_ value: Int) -> String {
        let exact: [Int: String] = [
            1:"first", 2:"second", 3:"third", 4:"fourth", 5:"fifth", 6:"sixth", 7:"seventh",
            8:"eighth", 9:"ninth", 10:"tenth", 11:"eleventh", 12:"twelfth", 13:"thirteenth",
            14:"fourteenth", 15:"fifteenth", 16:"sixteenth", 17:"seventeenth", 18:"eighteenth",
            19:"nineteenth", 20:"twentieth", 30:"thirtieth", 40:"fortieth", 50:"fiftieth",
            60:"sixtieth", 70:"seventieth", 80:"eightieth", 90:"ninetieth"
        ]
        if let word = exact[value] { return word }
        if value > 20, value < 100 { return "\(englishInteger(value - value % 10)) \(exact[value % 10] ?? englishInteger(value % 10))" }
        return englishInteger(value)
    }

    // MARK: - Regex utility

    private static func replacingMatches(
        in source: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        transform: ([String]) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return source }
        let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = expression.matches(in: source, range: sourceRange)
        guard !matches.isEmpty else { return source }

        var result = source
        for match in matches.reversed() {
            let groups = (1..<match.numberOfRanges).map { index -> String in
                let range = match.range(at: index)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: source) else { return "" }
                return String(source[swiftRange])
            }
            guard let resultRange = Range(match.range, in: result) else { continue }
            result.replaceSubrange(resultRange, with: transform(groups))
        }
        return result
    }
}
