import Foundation

/// Converts normalized display text into the exact Unicode representation
/// expected by the local character-level TTS model. This is deliberately a
/// separate step: the UI keeps readable precomposed Russian text, while the
/// model receives explicit stresses and canonical combining marks.
enum LocalVoicePronunciation {
    static func modelInput(_ source: String, language: AppLang) -> String {
        var text = source
        if language == .ru {
            text = RussianStressResolver.applyingStress(to: text)
        }

        // The bundled Unicode indexer contains combining marks, but not every
        // precomposed character (notably Russian ё/й and the ellipsis glyph).
        // NFD preserves pronunciation information as е+diaeresis and
        // и+breve instead of silently dropping the character.
        return text
            .replacingOccurrences(of: "…", with: "...")
            .decomposedStringWithCanonicalMapping
    }
}

private enum RussianStressResolver {
    /// A deliberately conservative lexicon. Unknown words are left untouched:
    /// a missing hint is safer than a confidently wrong guessed stress. The
    /// list focuses on Lippi's own vocabulary, dates, numbers, health terms and
    /// frequent orthoepic traps heard in assistant responses.
    private static let lexicon: [String: String] = [
        // Product and technology names.
        "липпи": "ли\u{301}ппи",
        "бонсай": "бонса\u{301}й",
        "помодоро": "помодо\u{301}ро",
        "айфон": "айфо\u{301}н",
        "ликвид": "ли\u{301}квид",
        "супертоник": "суперто\u{301}ник",
        "вижен": "ви\u{301}жен",

        // Assistant actions and confirmations.
        "готова": "гото\u{301}ва",
        "готово": "гото\u{301}во",
        "готовы": "гото\u{301}вы",
        "поняла": "поняла\u{301}",
        "приняла": "приняла\u{301}",
        "начала": "начала\u{301}",
        "создала": "создала\u{301}",
        "добавила": "доба\u{301}вила",
        "удалила": "удали\u{301}ла",
        "перенесла": "перенесла\u{301}",
        "запустила": "запусти\u{301}ла",
        "остановила": "останови\u{301}ла",
        "продолжила": "продолжи\u{301}ла",
        "напомню": "напомню\u{301}",
        "позвони": "позвони\u{301}",
        "позвонит": "позвони\u{301}т",
        "перезвони": "перезвони\u{301}",
        "звонит": "звони\u{301}т",
        "звонок": "звоно\u{301}к",
        "включи": "включи\u{301}",
        "включит": "включи\u{301}т",
        "обновить": "обнови\u{301}ть",
        "создать": "созда\u{301}ть",
        "добавить": "доба\u{301}вить",
        "удалить": "удали\u{301}ть",
        "перенести": "перенести\u{301}",
        "запустить": "запусти\u{301}ть",
        "продолжить": "продолжи\u{301}ть",
        "остановить": "останови\u{301}ть",
        "сделано": "сде\u{301}лано",
        "выполнено": "вы\u{301}полнено",
        "занята": "занята\u{301}",
        "занято": "за\u{301}нято",
        "заняты": "за\u{301}няты",

        // Time and calendar.
        "сегодня": "сего\u{301}дня",
        "завтра": "за\u{301}втра",
        "послезавтра": "послеза\u{301}втра",
        "сейчас": "сейча\u{301}с",
        "позже": "по\u{301}зже",
        "утром": "у\u{301}тром",
        "вечером": "ве\u{301}чером",
        "понедельник": "понеде\u{301}льник",
        "вторник": "вто\u{301}рник",
        "среда": "среда\u{301}",
        "четверг": "четве\u{301}рг",
        "пятница": "пя\u{301}тница",
        "суббота": "суббо\u{301}та",
        "воскресенье": "воскресе\u{301}нье",
        "января": "января\u{301}",
        "февраля": "февраля\u{301}",
        "марта": "ма\u{301}рта",
        "апреля": "апре\u{301}ля",
        "июня": "ию\u{301}ня",
        "июля": "ию\u{301}ля",
        "августа": "а\u{301}вгуста",
        "сентября": "сентября\u{301}",
        "октября": "октября\u{301}",
        "ноября": "ноября\u{301}",
        "декабря": "декабря\u{301}",
        "напоминание": "напомина\u{301}ние",
        "расписание": "расписа\u{301}ние",

        // Core product vocabulary.
        "задача": "зада\u{301}ча",
        "задачи": "зада\u{301}чи",
        "задачу": "зада\u{301}чу",
        "цели": "це\u{301}ли",
        "целей": "целе\u{301}й",
        "прогресс": "прогре\u{301}сс",
        "дорожная": "доро\u{301}жная",
        "этап": "эта\u{301}п",
        "этапа": "эта\u{301}па",
        "этапов": "эта\u{301}пов",
        "следующий": "сле\u{301}дующий",
        "действие": "де\u{301}йствие",
        "действия": "де\u{301}йствия",
        "фокус": "фо\u{301}кус",
        "перерыв": "переры\u{301}в",
        "пауза": "па\u{301}уза",
        "дыхание": "дыха\u{301}ние",
        "упражнение": "упражне\u{301}ние",
        "восстановление": "восстановле\u{301}ние",
        "самочувствие": "самочу\u{301}вствие",
        "рекомендация": "рекоменда\u{301}ция",
        "рекомендации": "рекоменда\u{301}ции",
        "активность": "акти\u{301}вность",
        "тренировка": "трениро\u{301}вка",
        "нагрузка": "нагру\u{301}зка",
        "энергия": "эне\u{301}ргия",
        "показатель": "показа\u{301}тель",
        "вариабельность": "вариабе\u{301}льность",
        "сердечного": "серде\u{301}чного",
        "ритма": "ри\u{301}тма",

        // Spoken numbers and units produced by LocalVoiceTextNormalizer.
        "один": "о\u{301}дин",
        "одна": "одна\u{301}",
        "одно": "одно\u{301}",
        "четыре": "четы\u{301}ре",
        "восемь": "во\u{301}семь",
        "девять": "де\u{301}вять",
        "десять": "де\u{301}сять",
        "одиннадцать": "оди\u{301}ннадцать",
        "двенадцать": "двена\u{301}дцать",
        "тринадцать": "трина\u{301}дцать",
        "четырнадцать": "четы\u{301}рнадцать",
        "пятнадцать": "пятна\u{301}дцать",
        "шестнадцать": "шестна\u{301}дцать",
        "семнадцать": "семна\u{301}дцать",
        "восемнадцать": "восемна\u{301}дцать",
        "девятнадцать": "девятна\u{301}дцать",
        "двадцать": "два\u{301}дцать",
        "тридцать": "три\u{301}дцать",
        "сорок": "со\u{301}рок",
        "пятьдесят": "пятьдеся\u{301}т",
        "шестьдесят": "шестьдеся\u{301}т",
        "семьдесят": "семьдеся\u{301}т",
        "восемьдесят": "во\u{301}семьдесят",
        "девяносто": "девяно\u{301}сто",
        "двести": "две\u{301}сти",
        "триста": "три\u{301}ста",
        "четыреста": "четы\u{301}реста",
        "пятьсот": "пятьсо\u{301}т",
        "шестьсот": "шестьсо\u{301}т",
        "семьсот": "семьсо\u{301}т",
        "восемьсот": "восемьсо\u{301}т",
        "девятьсот": "девятьсо\u{301}т",
        "тысяча": "ты\u{301}сяча",
        "тысячи": "ты\u{301}сячи",
        "минута": "мину\u{301}та",
        "минуты": "мину\u{301}ты",
        "минуту": "мину\u{301}ту",
        "секунда": "секу\u{301}нда",
        "секунды": "секу\u{301}нды",
        "часа": "часа\u{301}",
        "часов": "часо\u{301}в",
        "процент": "проце\u{301}нт",
        "процента": "проце\u{301}нта",
        "процентов": "проце\u{301}нтов",
        "километр": "киломе\u{301}тр",
        "километра": "киломе\u{301}тра",
        "километров": "киломе\u{301}тров",
        "метра": "ме\u{301}тра",
        "метров": "ме\u{301}тров",
        "литра": "ли\u{301}тра",
        "литров": "ли\u{301}тров",
        "калорий": "кало\u{301}рий",
        "килокалорий": "килокало\u{301}рий",
        "десятых": "деся\u{301}тых",
        "сотых": "со\u{301}тых",

        // Frequent orthoepic traps in arbitrary user-facing text.
        "каталог": "катало\u{301}г",
        "договор": "догово\u{301}р",
        "квартал": "кварта\u{301}л",
        "красивее": "краси\u{301}вее",
        "облегчить": "облегчи\u{301}ть",
        "углубить": "углуби\u{301}ть",
        "баловать": "балова\u{301}ть",
        "средства": "сре\u{301}дства",
        "торты": "то\u{301}рты",
        "аэропорты": "аэропо\u{301}рты",
        "шарфы": "ша\u{301}рфы",
        "банты": "ба\u{301}нты",
        "жалюзи": "жалюзи\u{301}",
        "эксперт": "экспе\u{301}рт",
        "маркетинг": "ма\u{301}ркетинг",
        "обеспечение": "обеспе\u{301}чение",
        "намерение": "наме\u{301}рение"
    ]

    static func applyingStress(to source: String) -> String {
        guard source.range(of: #"[А-Яа-яЁёЙй]"#, options: .regularExpression) != nil else {
            return source
        }

        let expression = try! NSRegularExpression(
            pattern: #"[\p{L}\p{M}]+(?:-[\p{L}\p{M}]+)*"#
        )
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = expression.matches(in: source, range: range)
        let context = source
            .precomposedStringWithCanonicalMapping
            .lowercased()

        var result = source
        for match in matches.reversed() {
            guard let sourceRange = Range(match.range, in: source),
                  let resultRange = Range(match.range, in: result) else { continue }
            let original = String(source[sourceRange])
            if original.unicodeScalars.contains(where: { $0.value == 0x0301 }) {
                continue
            }
            let canonical = original.precomposedStringWithCanonicalMapping
            let key = canonical.lowercased()
            guard let stressed = contextualStress(for: key, context: context)
                    ?? lexicon[key] else { continue }
            result.replaceSubrange(
                resultRange,
                with: matchingCase(of: stressed, to: canonical)
            )
        }
        return result
    }

    private static func contextualStress(
        for word: String,
        context: String
    ) -> String? {
        switch word {
        case "замок":
            let castleCues = ["старин", "дворец", "экскурс", "башн", "крепост"]
            if castleCues.contains(where: context.contains) { return "за\u{301}мок" }
            let lockCues = ["двер", "ключ", "закры", "откры", "код", "умный дом"]
            if lockCues.contains(where: context.contains) { return "замо\u{301}к" }
            return nil
        case "плачу":
            let paymentCues = ["счёт", "счет", "оплат", "рубл", "карт", "покуп"]
            if paymentCues.contains(where: context.contains) { return "плачу\u{301}" }
            let cryingCues = ["слез", "груст", "обид", "гор", "рыда", "боль"]
            if cryingCues.contains(where: context.contains) { return "пла\u{301}чу" }
            return nil
        case "мука":
            let foodCues = [
                "тест", "хлеб", "пшен", "рецепт", "выпеч", "помол", "мешок",
                "килограмм", "кухн", "просе"
            ]
            if foodCues.contains(where: context.contains) { return "мука\u{301}" }
            let tormentCues = ["мучен", "невыносим", "сплошн", "душевн", "страдан"]
            if tormentCues.contains(where: context.contains) { return "му\u{301}ка" }
            return nil
        default:
            return nil
        }
    }

    private static func matchingCase(
        of replacement: String,
        to original: String
    ) -> String {
        if original == original.uppercased(), original != original.lowercased() {
            return replacement.uppercased()
        }
        guard original.first?.isUppercase == true,
              let first = replacement.first else { return replacement }
        return first.uppercased() + String(replacement.dropFirst())
    }
}
