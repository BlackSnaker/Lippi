import Foundation

private func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
    min(max(value, lower), upper)
}

struct VoicePCM: Sendable {
    var samples: [Float]
    var sampleRate: Int
}

struct SpeechPitchContour: Equatable, Sendable {
    var start: Float
    var middle: Float
    var end: Float

    var average: Float {
        start * 0.30 + middle * 0.40 + end * 0.30
    }
}

struct ExpressiveSpeechSegment: Equatable, Sendable {
    var text: String
    var speedScale: Float
    var pitch: SpeechPitchContour
    var pauseAfter: TimeInterval
    var intensityScale: Float
    var dynamicRangeScale: Float
    var articulationScale: Float
    var vowelDurationScale: Float
    var consonantAttackScale: Float
    var syllableCount: Int
    var vowelPositions: [Float]
    var stressedVowelPositions: [Float]
    var plosivePositions: [Float]
    var emphasisPosition: Float?
    var emphasisGain: Float
    var usesExpressionTag: Bool
}

enum ExpressiveSpeechPlanner {
    private enum Boundary {
        case statement
        case question
        case openQuestion
        case exclamation
        case continuation
        case reflective
    }

    private struct Clause {
        var text: String
        var boundary: Boundary
    }

    private struct PhoneticMetrics {
        var syllables: Int
        var vowelRatio: Float
        var consonantComplexity: Float
        var plosiveRatio: Float
        var vowelPositions: [Float]
        var stressedVowelPositions: [Float]
        var plosivePositions: [Float]
    }

    static func plan(
        text: String,
        language: AppLang,
        prosody: VoiceProsodyProfile
    ) -> [ExpressiveSpeechSegment] {
        let clauses = clauses(from: text, language: language)
        guard !clauses.isEmpty else { return [] }

        return clauses.enumerated().map { index, clause in
            let metrics = phoneticMetrics(clause.text, language: language)
            let rhythmPattern: [Float] = [0.22, -0.34, 0.41, -0.16, 0.30, -0.27]
            let rhythm = rhythmPattern[index % rhythmPattern.count]
                * 0.055 * prosody.rhythmVariationScale

            // Vowel-heavy phrases need a little more room, while dense
            // consonant clusters are slowed just enough to preserve attacks.
            let vowelTime = max(0, prosody.vowelDurationScale - 1)
                * metrics.vowelRatio * 0.44
            let articulationTime = max(0, prosody.articulationScale - 1)
                * metrics.consonantComplexity * 0.24
            let phoneticTempo = 1 - vowelTime - articulationTime
            let speedScale = clamp(
                prosody.tempoScale * (1 + rhythm) * phoneticTempo,
                lower: 0.78,
                upper: 1.18
            )

            let contour = pitchContour(
                for: clause.boundary,
                phraseIndex: index,
                phraseCount: clauses.count,
                prosody: prosody
            )
            let boundaryEnergy: Float
            switch clause.boundary {
            case .exclamation: boundaryEnergy = 0.045
            case .question: boundaryEnergy = 0.018
            case .openQuestion: boundaryEnergy = 0.010
            case .continuation: boundaryEnergy = 0.008
            case .statement, .reflective: boundaryEnergy = 0
            }

            let shouldBreathe = clauses.count > 1
                && index == clauses.count / 2
                && prosody.pauseScale >= 1.08
            let spokenText = shouldBreathe
                ? "<breath> " + clause.text
                : clause.text

            return ExpressiveSpeechSegment(
                text: spokenText,
                speedScale: speedScale,
                pitch: contour,
                pauseAfter: pauseDuration(
                    for: clause.boundary,
                    isLast: index == clauses.count - 1,
                    scale: prosody.pauseScale
                ),
                intensityScale: clamp(
                    prosody.intensityScale + boundaryEnergy,
                    lower: 0.86,
                    upper: 1.10
                ),
                dynamicRangeScale: clamp(
                    prosody.dynamicRangeScale + boundaryEnergy * 0.65,
                    lower: 0.74,
                    upper: 1.12
                ),
                articulationScale: prosody.articulationScale,
                vowelDurationScale: prosody.vowelDurationScale,
                consonantAttackScale: prosody.consonantAttackScale
                    * (1 + metrics.plosiveRatio * 0.035),
                syllableCount: metrics.syllables,
                vowelPositions: metrics.vowelPositions,
                stressedVowelPositions: metrics.stressedVowelPositions,
                plosivePositions: metrics.plosivePositions,
                emphasisPosition: emphasisPosition(
                    in: clause.text,
                    language: language
                ),
                emphasisGain: 0.045 * prosody.emphasisScale
                    + boundaryEnergy * 0.55,
                usesExpressionTag: shouldBreathe
            )
        }
    }

    private static func clauses(
        from text: String,
        language: AppLang
    ) -> [Clause] {
        var result: [Clause] = []
        var buffer = ""

        func flush(_ boundary: Boundary) {
            let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = ""
            guard !value.isEmpty else { return }
            result.append(Clause(text: value, boundary: boundary))
        }

        for character in text {
            buffer.append(character)
            switch character {
            case "?": flush(questionBoundary(for: buffer, language: language))
            case "!": flush(.exclamation)
            case "…": flush(.reflective)
            case ".": flush(.statement)
            case ";", ":": flush(.continuation)
            case "," where buffer.count >= 76:
                flush(.continuation)
            case " " where buffer.count >= 150:
                buffer = buffer.trimmingCharacters(in: .whitespaces) + ","
                flush(.continuation)
            default:
                break
            }
        }
        flush(.statement)

        // A one-word fragment generated in isolation sounds clipped. Attach it
        // to its neighbour so the acoustic model retains co-articulation.
        var merged: [Clause] = []
        for clause in result {
            let words = clause.text.split(whereSeparator: \.isWhitespace).count
            if words <= 2, !merged.isEmpty,
               merged[merged.count - 1].text.count + clause.text.count < 126 {
                let previous = merged.removeLast()
                merged.append(
                    Clause(
                        text: previous.text + " " + clause.text,
                        boundary: clause.boundary
                    )
                )
            } else {
                merged.append(clause)
            }
        }

        guard merged.count > 8 else { return merged }
        var bounded = Array(merged.prefix(7))
        let tail = merged.dropFirst(7).map(\.text).joined(separator: " ")
        bounded.append(Clause(text: tail, boundary: merged.last?.boundary ?? .statement))
        return bounded
    }

    private static func questionBoundary(
        for text: String,
        language: AppLang
    ) -> Boundary {
        let firstWord = text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .first
            .map(String.init) ?? ""
        let openers: Set<String>
        switch language {
        case .ru:
            openers = [
                "кто", "что", "где", "когда", "куда", "откуда", "почему",
                "зачем", "как", "какой", "какая", "какие", "сколько", "чей"
            ]
        case .en:
            openers = ["who", "what", "where", "when", "why", "how", "which", "whose"]
        case .de:
            openers = ["wer", "was", "wo", "wann", "warum", "wie", "welche", "wessen"]
        case .es:
            openers = ["quién", "qué", "dónde", "cuándo", "por", "cómo", "cuál", "cuánto"]
        }
        return openers.contains(firstWord) ? .openQuestion : .question
    }

    private static func pitchContour(
        for boundary: Boundary,
        phraseIndex: Int,
        phraseCount: Int,
        prosody: VoiceProsodyProfile
    ) -> SpeechPitchContour {
        let shape: (Float, Float, Float)
        switch boundary {
        case .statement: shape = (0.34, 0.14, -0.62)
        case .question: shape = (0.14, 0.46, 1.18)
        // Open questions normally resolve instead of ending with the strong
        // yes/no rise. Treating every question alike is a common synthetic
        // voice tell, especially in Russian.
        case .openQuestion: shape = (0.34, 0.16, -0.30)
        case .exclamation: shape = (0.52, 0.92, 0.18)
        case .continuation: shape = (0.20, 0.36, 0.38)
        case .reflective: shape = (0.08, -0.18, -0.74)
        }
        let position = phraseCount > 1
            ? Float(phraseIndex) / Float(phraseCount - 1)
            : 0
        let narrativeSlope = 0.10 - position * 0.20
        let range = prosody.pitchRangeScale
        return SpeechPitchContour(
            start: prosody.pitchSemitones + shape.0 * range + narrativeSlope,
            middle: prosody.pitchSemitones + shape.1 * range,
            end: prosody.pitchSemitones + shape.2 * range - narrativeSlope * 0.35
        )
    }

    private static func pauseDuration(
        for boundary: Boundary,
        isLast: Bool,
        scale: Float
    ) -> TimeInterval {
        if isLast { return 0.035 }
        let base: TimeInterval
        switch boundary {
        case .continuation: base = 0.105
        case .statement: base = 0.235
        case .question, .openQuestion: base = 0.255
        case .exclamation: base = 0.205
        case .reflective: base = 0.310
        }
        return min(max(base * Double(scale), 0.075), 0.42)
    }

    private static func phoneticMetrics(
        _ text: String,
        language: AppLang
    ) -> PhoneticMetrics {
        struct PhoneticLetter {
            var value: Character
            var isVowel: Bool
            var isPlosive: Bool
            var isStressed: Bool
        }

        let vowels: Set<Character>
        let plosives: Set<Character>
        switch language {
        case .ru:
            vowels = Set("аеиоуыэюя")
            plosives = Set("бпдтгкцч")
        case .en:
            vowels = Set("aeiouy")
            plosives = Set("bpdtgkqcxj")
        case .de:
            vowels = Set("aeiouy")
            plosives = Set("bpdtgkqcz")
        case .es:
            vowels = Set("aeiou")
            plosives = Set("bpdtgkqcx")
        }

        let decomposed = text
            .lowercased()
            .decomposedStringWithCanonicalMapping
        var letters: [PhoneticLetter] = []
        letters.reserveCapacity(decomposed.count)
        for scalar in decomposed.unicodeScalars {
            // Foundation includes combining marks in CharacterSet.letters on
            // Apple platforms. Consume them before the letter branch so an
            // acute modifies its vowel instead of becoming a phantom letter.
            if CharacterSet.nonBaseCharacters.contains(scalar) {
                guard let last = letters.indices.last else { continue }
                switch scalar.value {
                case 0x0301: // Combining acute: explicit lexical stress.
                    if letters[last].isVowel { letters[last].isStressed = true }
                case 0x0308: // Russian ё is е + diaeresis for Supertonic.
                    if language == .ru, letters[last].value == "е" {
                        letters[last].isStressed = true
                    }
                case 0x0306: // Russian й is и + breve and is a consonant.
                    if language == .ru, letters[last].value == "и" {
                        letters[last].isVowel = false
                        letters[last].isStressed = false
                    }
                default:
                    break
                }
                continue
            }
            if CharacterSet.letters.contains(scalar) {
                let character = Character(String(scalar))
                letters.append(
                    PhoneticLetter(
                        value: character,
                        isVowel: vowels.contains(character),
                        isPlosive: plosives.contains(character),
                        isStressed: false
                    )
                )
                continue
            }
        }

        let vowelCount = letters.filter(\.isVowel).count
        let consonantCount = max(letters.count - vowelCount, 0)
        let plosiveCount = letters.filter(\.isPlosive).count
        let total = max(letters.count, 1)
        let denominator = Float(max(letters.count - 1, 1))
        let vowelPositions = letters.indices.compactMap { index -> Float? in
            letters[index].isVowel ? Float(index) / denominator : nil
        }
        let stressedVowelPositions = letters.indices.compactMap { index -> Float? in
            letters[index].isStressed ? Float(index) / denominator : nil
        }
        let plosivePositions = letters.indices.compactMap { index -> Float? in
            letters[index].isPlosive ? Float(index) / denominator : nil
        }
        return PhoneticMetrics(
            syllables: max(vowelCount, 1),
            vowelRatio: Float(vowelCount) / Float(total),
            consonantComplexity: min(Float(consonantCount) / Float(max(vowelCount, 1)), 2.4) / 2.4,
            plosiveRatio: Float(plosiveCount) / Float(total),
            vowelPositions: vowelPositions,
            stressedVowelPositions: stressedVowelPositions,
            plosivePositions: plosivePositions
        )
    }

    private static func emphasisPosition(
        in text: String,
        language: AppLang
    ) -> Float? {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        guard words.count >= 3 else { return nil }

        let stopwords: Set<String>
        switch language {
        case .ru:
            stopwords = [
                "а", "без", "бы", "в", "во", "для", "до", "же", "за", "и", "из",
                "или", "к", "как", "ли", "на", "не", "но", "о", "об", "от", "по",
                "при", "с", "со", "то", "у", "что", "это", "я", "ты", "мы", "вы"
            ]
        case .en:
            stopwords = ["a", "an", "and", "are", "as", "at", "for", "from", "in", "is", "of", "on", "or", "the", "to", "we", "you"]
        case .de:
            stopwords = ["aber", "als", "am", "an", "auf", "der", "die", "das", "ein", "eine", "für", "im", "in", "ist", "oder", "und", "zu"]
        case .es:
            stopwords = ["a", "al", "de", "del", "el", "en", "es", "la", "las", "los", "o", "para", "por", "un", "una", "y"]
        }
        let cueWords: Set<String> = [
            "главное", "важно", "сейчас", "сначала", "итог", "готово",
            "important", "now", "first", "wichtig", "jetzt", "primero", "ahora"
        ]

        var bestWord: Substring?
        var bestScore = Int.min
        for (index, word) in words.enumerated() {
            let raw = String(word)
            let lexical = raw
                .decomposedStringWithCanonicalMapping
                .unicodeScalars
                .filter { !CharacterSet.nonBaseCharacters.contains($0) }
                .map(String.init)
                .joined()
                .lowercased()
            let uppercase = raw.count > 1 && raw == raw.uppercased()
            let followsNegation = index > 0
                && ["не", "not", "nicht", "no"].contains(
                    String(words[index - 1]).lowercased()
                )
            let score = min(lexical.count, 14)
                + (raw.contains(where: \.isNumber) ? 4 : 0)
                + (uppercase ? 3 : 0)
                + (cueWords.contains(lexical) ? 5 : 0)
                + (followsNegation ? 4 : 0)
                + (index == words.count - 1 ? 1 : 0)
                - (stopwords.contains(lexical) ? 24 : 0)
            if score > bestScore {
                bestScore = score
                bestWord = word
            }
        }
        guard let bestWord, let range = text.range(of: bestWord) else { return nil }
        let start = text.distance(from: text.startIndex, to: range.lowerBound)
        let length = text.distance(from: range.lowerBound, to: range.upperBound)
        return clamp(
            Float(start) + Float(length) * 0.5,
            lower: 0,
            upper: Float(max(text.count, 1))
        ) / Float(max(text.count, 1))
    }
}

enum ExpressiveAudioRenderer {
    static func render(
        _ audio: VoicePCM,
        segment: ExpressiveSpeechSegment
    ) -> VoicePCM {
        var samples = trimSilence(audio.samples, sampleRate: audio.sampleRate)
        guard samples.count > 32 else { return VoicePCM(samples: samples, sampleRate: audio.sampleRate) }
        removeDCOffset(from: &samples)

        samples = applyVowelTiming(
            samples,
            positions: segment.vowelPositions,
            stressedPositions: segment.stressedVowelPositions,
            durationScale: segment.vowelDurationScale
        )
        samples = applyPitchContour(samples, contour: segment.pitch)

        applyArticulation(
            to: &samples,
            articulation: segment.articulationScale,
            attack: segment.consonantAttackScale
        )
        applyLocalizedConsonantAttacks(
            to: &samples,
            positions: segment.plosivePositions,
            attack: segment.consonantAttackScale,
            sampleRate: audio.sampleRate
        )
        applyDynamics(to: &samples, segment: segment)
        applyEdgeFades(to: &samples, sampleRate: audio.sampleRate)
        return VoicePCM(samples: samples, sampleRate: audio.sampleRate)
    }

    static func compose(
        _ rendered: [(audio: VoicePCM, pauseAfter: TimeInterval)]
    ) -> VoicePCM? {
        guard let first = rendered.first else { return nil }
        let sampleRate = first.audio.sampleRate
        var output: [Float] = []
        for item in rendered {
            guard item.audio.sampleRate == sampleRate else { continue }
            if !output.isEmpty {
                appendCrossfaded(
                    item.audio.samples,
                    to: &output,
                    sampleRate: sampleRate,
                    milliseconds: 7
                )
            } else {
                output = item.audio.samples
            }
            let silenceCount = Int(item.pauseAfter * Double(sampleRate))
            if silenceCount > 0 {
                output.append(contentsOf: repeatElement(0, count: silenceCount))
            }
        }
        return VoicePCM(samples: output, sampleRate: sampleRate)
    }

    static func wavData(_ audio: VoicePCM) -> Data {
        var pcm = [Int16]()
        pcm.reserveCapacity(audio.samples.count)
        for sample in audio.samples {
            let clamped = min(max(sample, -1), 1)
            pcm.append(Int16(clamped * Float(Int16.max)))
        }

        let pcmByteCount = pcm.count * MemoryLayout<Int16>.size
        var data = Data(capacity: 44 + pcmByteCount)
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + pcmByteCount))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(audio.sampleRate))
        data.appendLittleEndian(UInt32(audio.sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(pcmByteCount))
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    /// Applies one continuous pitch trajectory. The previous implementation
    /// rendered three independently resampled chunks and crossfaded them near
    /// arbitrary thirds of the waveform. Even quiet sample boundaries can sit
    /// inside a phoneme and sound like a repeated or clipped syllable. A smooth
    /// cumulative warp has no internal edit points, so co-articulation remains
    /// intact across the whole phrase.
    private static func applyPitchContour(
        _ input: [Float],
        contour: SpeechPitchContour
    ) -> [Float] {
        guard input.count > 64 else { return input }
        let averageScale = pow(2, contour.average / 12)
        let outputCount = max(
            2,
            Int((Float(input.count) / max(averageScale, 0.88)).rounded())
        )
        let denominator = Float(max(outputCount - 1, 1))
        var rates = [Float](repeating: 1, count: outputCount)
        for index in rates.indices {
            let progress = Float(index) / denominator
            let semitones: Float
            if progress <= 0.5 {
                semitones = smoothMix(
                    contour.start,
                    contour.middle,
                    progress: progress * 2
                )
            } else {
                semitones = smoothMix(
                    contour.middle,
                    contour.end,
                    progress: (progress - 0.5) * 2
                )
            }
            rates[index] = pow(2, semitones / 12)
        }

        var positions = [Float](repeating: 0, count: outputCount)
        if outputCount > 1 {
            for index in 1..<outputCount {
                positions[index] = positions[index - 1]
                    + (rates[index - 1] + rates[index]) * 0.5
            }
        }
        let pathLength = max(positions.last ?? 1, 0.0001)
        let inputEnd = Float(input.count - 1)
        var output = [Float](repeating: 0, count: outputCount)
        for index in output.indices {
            let position = positions[index] / pathLength * inputEnd
            output[index] = cubicSample(input, at: position)
        }
        return output
    }

    private static func smoothMix(
        _ start: Float,
        _ end: Float,
        progress: Float
    ) -> Float {
        let value = clamp(progress, lower: 0, upper: 1)
        let smooth = value * value * (3 - 2 * value)
        return start + (end - start) * smooth
    }

    private static func cubicSample(
        _ input: [Float],
        at position: Float
    ) -> Float {
        let center = Int(position.rounded(.down))
        let fraction = position - Float(center)
        let p0 = input[max(center - 1, 0)]
        let p1 = input[min(center, input.count - 1)]
        let p2 = input[min(center + 1, input.count - 1)]
        let p3 = input[min(center + 2, input.count - 1)]
        let a = (-p0 + 3 * p1 - 3 * p2 + p3) * 0.5
        let b = (2 * p0 - 5 * p1 + 4 * p2 - p3) * 0.5
        let c = (-p0 + p2) * 0.5
        return ((a * fraction + b) * fraction + c) * fraction + p1
    }

    private static func applyVowelTiming(
        _ input: [Float],
        positions: [Float],
        stressedPositions: [Float],
        durationScale: Float
    ) -> [Float] {
        let delta = clamp(durationScale - 1, lower: -0.05, upper: 0.09)
        let stressDelta: Float = stressedPositions.isEmpty ? 0 : 0.014
        guard (abs(delta) > 0.002 || stressDelta > 0),
              !positions.isEmpty,
              input.count > 64 else {
            return input
        }

        var output: [Float] = []
        output.reserveCapacity(Int(Float(input.count) * (1 + max(delta, 0) * 0.65)))
        var inputPosition: Float = 0
        let end = Float(input.count - 1)
        let maximumCount = Int(Float(input.count) * 1.12)
        while inputPosition < end, output.count < maximumCount {
            let lower = Int(inputPosition)
            let upper = min(lower + 1, input.count - 1)
            let fraction = inputPosition - Float(lower)
            output.append(input[lower] + (input[upper] - input[lower]) * fraction)

            let progress = inputPosition / end
            var vowelWeight: Float = 0
            for center in positions {
                let distance = (progress - center) / 0.018
                vowelWeight = max(vowelWeight, exp(-(distance * distance) * 0.5))
            }
            var stressWeight: Float = 0
            for center in stressedPositions {
                let distance = (progress - center) / 0.022
                stressWeight = max(stressWeight, exp(-(distance * distance) * 0.5))
            }
            inputPosition += 1 / max(
                1 + delta * vowelWeight + stressDelta * stressWeight,
                0.88
            )
        }
        if let last = input.last, output.last != last {
            output.append(last)
        }
        return output
    }

    private static func trimSilence(_ input: [Float], sampleRate: Int) -> [Float] {
        guard !input.isEmpty else { return [] }
        let peak = input.reduce(Float.zero) { max($0, abs($1)) }
        let threshold = min(max(peak * 0.0035, 0.00035), 0.0020)
        // Preserve quiet consonant attacks and releases. Cutting too close to
        // the threshold makes consecutive words sound as if they restart.
        let padding = max(Int(Float(sampleRate) * 0.026), 1)
        let first = input.firstIndex { abs($0) >= threshold } ?? input.startIndex
        let last = input.lastIndex { abs($0) >= threshold } ?? input.index(before: input.endIndex)
        let lower = max(first - padding, input.startIndex)
        let upper = min(last + padding, input.index(before: input.endIndex))
        guard lower <= upper else { return input }
        return Array(input[lower...upper])
    }

    private static func removeDCOffset(from samples: inout [Float]) {
        guard !samples.isEmpty else { return }
        let mean = samples.reduce(Float.zero, +) / Float(samples.count)
        guard abs(mean) > 0.00001 else { return }
        for index in samples.indices {
            samples[index] -= mean
        }
    }

    private static func applyArticulation(
        to samples: inout [Float],
        articulation: Float,
        attack: Float
    ) {
        guard samples.count > 1 else { return }
        let sharpen = clamp((attack - 1) * 0.42, lower: -0.05, upper: 0.075)
        let soften = clamp((1 - articulation) * 0.34, lower: 0, upper: 0.12)
        var previousInput = samples[0]
        var smoothed = samples[0]
        for index in 1..<samples.count {
            let input = samples[index]
            let transient = input + (input - previousInput) * sharpen
            smoothed = smoothed * 0.68 + transient * 0.32
            samples[index] = transient * (1 - soften) + smoothed * soften
            previousInput = input
        }
    }

    private static func applyLocalizedConsonantAttacks(
        to samples: inout [Float],
        positions: [Float],
        attack: Float,
        sampleRate: Int
    ) {
        let strength = clamp((attack - 1) * 0.55, lower: -0.035, upper: 0.065)
        guard abs(strength) > 0.002, !positions.isEmpty, !samples.isEmpty else { return }
        let radius = max(sampleRate / 240, 24)
        for position in positions {
            let center = Int(position * Float(samples.count - 1))
            let lower = max(center - radius, 0)
            let upper = min(center + radius, samples.count - 1)
            guard lower < upper else { continue }
            for index in lower...upper {
                let distance = abs(Float(index - center)) / Float(radius)
                let gain = 1 + strength * max(1 - distance, 0)
                samples[index] *= gain
            }
        }
    }

    private static func applyDynamics(
        to samples: inout [Float],
        segment: ExpressiveSpeechSegment
    ) {
        guard !samples.isEmpty else { return }
        let count = Float(samples.count)
        let syllables = Float(min(max(segment.syllableCount, 1), 36))
        for index in samples.indices {
            let progress = Float(index) / max(count - 1, 1)
            let sign: Float = samples[index] < 0 ? -1 : 1
            let magnitude = abs(samples[index])
            let threshold: Float = 0.16
            let shaped = magnitude > threshold
                ? threshold + (magnitude - threshold) * segment.dynamicRangeScale
                : magnitude
            // A small non-periodic micro-dynamic movement avoids the robotic
            // metronome effect without modulating every syllable equally.
            let syllableMotion = 1
                + sin(progress * syllables * 2 * .pi) * 0.0035
                + sin(progress * syllables * 0.93 * .pi + 0.7) * 0.0015
            var lexicalStress: Float = 1
            for center in segment.stressedVowelPositions {
                let distance = (progress - center) / 0.024
                lexicalStress += 0.012 * exp(-(distance * distance) * 0.5)
            }
            let emphasis: Float
            if let center = segment.emphasisPosition {
                let distance = (progress - center) / 0.105
                emphasis = 1 + segment.emphasisGain * exp(-(distance * distance) * 0.5)
            } else {
                emphasis = 1
            }
            let value = sign * shaped * segment.intensityScale
                * syllableMotion * lexicalStress * emphasis
            samples[index] = value / (1 + max(abs(value) - 0.88, 0) * 1.6)
        }
    }

    private static func applyEdgeFades(to samples: inout [Float], sampleRate: Int) {
        let fade = min(max(sampleRate / 250, 24), samples.count / 3)
        guard fade > 1 else { return }
        for index in 0..<fade {
            let gain = Float(index) / Float(fade - 1)
            samples[index] *= gain
            samples[samples.count - 1 - index] *= gain
        }
    }

    private static func appendCrossfaded(
        _ incoming: [Float],
        to output: inout [Float],
        sampleRate: Int,
        milliseconds: Int
    ) {
        guard !incoming.isEmpty else { return }
        guard !output.isEmpty else {
            output = incoming
            return
        }
        let desired = sampleRate * milliseconds / 1_000
        let overlap = min(desired, output.count, incoming.count)
        guard overlap > 1 else {
            output.append(contentsOf: incoming)
            return
        }
        let start = output.count - overlap
        for index in 0..<overlap {
            let progress = Float(index) / Float(overlap - 1)
            let mix = progress * progress * (3 - 2 * progress)
            output[start + index] = output[start + index] * (1 - mix)
                + incoming[index] * mix
        }
        output.append(contentsOf: incoming.dropFirst(overlap))
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
