import Foundation

/// Converts display-oriented text into a form that a compact local TTS model
/// can pronounce reliably. The visible response is left unchanged; only the
/// private copy passed to Supertonic is normalized.
enum LocalVoiceTextNormalizer {
    static func normalize(_ source: String, language: AppLang) -> String {
        var text = source
            .replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: ". ")

        text = replacingAliases(in: text, language: language)
        text = replacingDates(in: text, language: language)
        text = replacingPhoneNumbers(in: text, language: language)
        text = replacingTimes(in: text, language: language)
        text = replacingFractions(in: text, language: language)
        text = replacingRanges(in: text, language: language)
        text = replacingTemperatures(in: text, language: language)
        text = replacingPercentages(in: text, language: language)
        text = replacingMeasurements(in: text, language: language)
        text = replacingOrdinals(in: text, language: language)
        text = replacingIdentifiers(in: text, language: language)
        text = replacingInitialisms(in: text, language: language)
        text = replacingDecimals(in: text, language: language)
        text = replacingIntegers(in: text, language: language)
        text = replacingSymbols(in: text, language: language)

        return text
            .replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"([,.!?;:])(?=[\p{L}\p{N}])"#, with: "$1 ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            let minuteWords = integerWords(minute, language: language)
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
            let lhs = spokenNumber(groups[0], language: language)
            let rhs = spokenNumber(groups[1], language: language)
            switch language {
            case .ru: return "\(lhs) из \(rhs)"
            case .en: return "\(lhs) out of \(rhs)"
            case .de: return "\(lhs) von \(rhs)"
            case .es: return "\(lhs) de \(rhs)"
            }
        }
    }

    private static func replacingRanges(in source: String, language: AppLang) -> String {
        replacingMatches(
            in: source,
            pattern: #"(?<!\d)(-?\d+(?:[.,]\d+)?)\s*[‑–—-]\s*(-?\d+(?:[.,]\d+)?)(?!\d)"#
        ) { groups in
            guard groups.count == 2 else { return groups.joined(separator: " ") }
            let lhs = spokenNumber(groups[0], language: language)
            let rhs = spokenNumber(groups[1], language: language)
            switch language {
            case .ru: return "от \(lhs) до \(rhs)"
            case .en: return "from \(lhs) to \(rhs)"
            case .de: return "von \(lhs) bis \(rhs)"
            case .es: return "de \(lhs) a \(rhs)"
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

    private enum MeasurementKind: String, CaseIterable {
        case calories, kilometers, meters, kilograms, grams, milliliters, liters, minutes, hours, days, steps

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
            case .hours: return ["час(?:а|ов)?", "hours?", "hrs?", "h"]
            case .days: return ["дн(?:я|ей)?", "days?", "tage?", "días?"]
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
                let amount = spokenNumber(raw, language: language)
                return "\(amount) \(measurementName(kind, rawAmount: raw, language: language))"
            }
        }
        return text
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
            case .hours: forms = ("час", "часа", "часов")
            case .days: forms = ("день", "дня", "дней")
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
            case .hours: forms = ("hour", "hours")
            case .days: forms = ("day", "days")
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
            case .hours: return normalized == "1" ? "Stunde" : "Stunden"
            case .days: return normalized == "1" ? "Tag" : "Tage"
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
            case .hours: forms = ("hora", "horas")
            case .days: forms = ("día", "días")
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
                ("iPhone", "айфон"), ("iOS", "ай о эс"),
                ("Lippi", "Липпи"), ("Bonsai", "Бонсай"),
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

    private static func spokenNumber(_ raw: String, language: AppLang) -> String {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        if normalized.contains("."),
           let separator = normalized.firstIndex(of: ".") {
            let integerPart = String(normalized[..<separator])
            let fractionPart = String(normalized[normalized.index(after: separator)...])
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

    private static func russianInteger(_ value: Int) -> String {
        if value == 0 { return "ноль" }
        if value < 0 { return "минус " + russianInteger(abs(value)) }
        guard value <= 999_999_999 else { return String(value).compactMap(\.wholeNumberValue).map { digitWord($0, language: .ru) }.joined(separator: " ") }

        let scales = [
            (1_000_000, "миллион", "миллиона", "миллионов", false),
            (1_000, "тысяча", "тысячи", "тысяч", true)
        ]
        var remainder = value
        var parts: [String] = []
        for (scale, one, few, many, feminine) in scales where remainder >= scale {
            let amount = remainder / scale
            parts.append(russianChunk(amount, feminine: feminine))
            parts.append(russianForm(amount, one: one, few: few, many: many))
            remainder %= scale
        }
        if remainder > 0 { parts.append(russianChunk(remainder, feminine: false)) }
        return parts.joined(separator: " ")
    }

    private static func russianChunk(_ value: Int, feminine: Bool) -> String {
        let hundreds = ["", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот"]
        let teens = ["десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
        let tens = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"]
        let ones = feminine
            ? ["", "одна", "две", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
            : ["", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
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

    private static func russianForm(_ value: Int, one: String, few: String, many: String) -> String {
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
