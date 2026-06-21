import Foundation

struct GoalEvidenceSource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    let title: String
    let url: String
    let excerpt: String

    var host: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url
    }
}

struct OpenRoadmapSourceDefinition: Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let triggers: [String]
    let excerptHints: [String]
}

enum OpenRoadmapCatalog {
    static func candidates(for input: GoalPlannerInput) -> [OpenRoadmapSourceDefinition] {
        let text = "\(input.goal) \(input.context)".foldedForMatching
        let scored = sources.compactMap { source -> (OpenRoadmapSourceDefinition, Int)? in
            let score = source.triggers.reduce(into: 0) { partialResult, trigger in
                if text.contains(trigger) {
                    partialResult += trigger.count > 5 ? 3 : 2
                }
            }
            return score > 0 ? (source, score) : nil
        }

        return scored
            .sorted { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.title < rhs.0.title : lhs.1 > rhs.1
            }
            .prefix(2)
            .map(\.0)
    }

    private static let sources: [OpenRoadmapSourceDefinition] = [
        OpenRoadmapSourceDefinition(
            id: "roadmap-frontend",
            title: "Frontend Developer Roadmap",
            url: URL(string: "https://roadmap.sh/frontend")!,
            triggers: ["frontend", "front-end", "фронтенд", "веб", "web developer", "html", "css", "javascript", "react"],
            excerptHints: ["frontend", "roadmap", "learn", "html", "css", "javascript"]
        ),
        OpenRoadmapSourceDefinition(
            id: "mdn-learn-web",
            title: "MDN Learn web development",
            url: URL(string: "https://developer.mozilla.org/en-US/docs/Learn_web_development")!,
            triggers: ["frontend", "front-end", "фронтенд", "веб", "web developer", "html", "css", "javascript", "react"],
            excerptHints: ["web development", "learn", "html", "css", "javascript"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-python",
            title: "Python Developer Roadmap",
            url: URL(string: "https://roadmap.sh/python")!,
            triggers: ["python", "питон", "пайтон", "django", "flask", "fastapi"],
            excerptHints: ["python", "roadmap", "learn", "developer"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-backend",
            title: "Backend Developer Roadmap",
            url: URL(string: "https://roadmap.sh/backend")!,
            triggers: ["backend", "back-end", "бэкенд", "бекенд", "api", "сервер", "database", "база данных"],
            excerptHints: ["backend", "roadmap", "api", "database", "developer"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-ios",
            title: "iOS Developer Roadmap",
            url: URL(string: "https://roadmap.sh/ios")!,
            triggers: ["ios", "iphone", "swift", "xcode", "айос", "айфон"],
            excerptHints: ["ios", "swift", "roadmap", "developer"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-devops",
            title: "DevOps Roadmap",
            url: URL(string: "https://roadmap.sh/devops")!,
            triggers: ["devops", "dev ops", "девопс", "kubernetes", "docker", "terraform", "ci/cd"],
            excerptHints: ["devops", "roadmap", "cloud", "docker", "kubernetes"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-product-manager",
            title: "Product Manager Roadmap",
            url: URL(string: "https://roadmap.sh/product-manager")!,
            triggers: ["product manager", "product management", "продакт", "продуктовый менеджер", "mvp", "product"],
            excerptHints: ["product", "roadmap", "strategy", "market", "manager"]
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-ux-design",
            title: "UX Design Roadmap",
            url: URL(string: "https://roadmap.sh/ux-design")!,
            triggers: ["ux", "ui", "design", "дизайн", "прототип", "prototype", "figma"],
            excerptHints: ["ux", "design", "roadmap", "research", "user"]
        ),
        OpenRoadmapSourceDefinition(
            id: "cambridge-cefr",
            title: "Cambridge English: CEFR levels",
            url: URL(string: "https://www.cambridgeenglish.org/exams-and-tests/cefr/")!,
            triggers: ["англий", "english", "язык", "language", "a1", "a2", "b1", "b2", "cefr", "ielts", "toefl"],
            excerptHints: ["cefr", "language", "level", "english", "a1", "b1"]
        ),
        OpenRoadmapSourceDefinition(
            id: "cdc-healthy-weight",
            title: "CDC: Steps for losing weight",
            url: URL(string: "https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html")!,
            triggers: ["похуд", "вес", "weight", "fitness", "фитнес", "спорт", "бег", "run", "трениров", "exercise"],
            excerptHints: ["weight", "healthy", "physical activity", "sleep", "steps"]
        ),
        OpenRoadmapSourceDefinition(
            id: "who-physical-activity",
            title: "WHO: Physical activity",
            url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/physical-activity")!,
            triggers: ["похуд", "вес", "weight", "fitness", "фитнес", "спорт", "бег", "run", "трениров", "exercise"],
            excerptHints: ["physical activity", "health", "adults", "exercise"]
        ),
        OpenRoadmapSourceDefinition(
            id: "sba-business-plan",
            title: "U.S. Small Business Administration: Plan your business",
            url: URL(string: "https://www.sba.gov/business-guide/plan-your-business")!,
            triggers: ["бизнес", "business", "mvp", "стартап", "startup", "запуст", "launch", "продукт", "product", "тур", "tour"],
            excerptHints: ["business", "plan", "market", "launch", "financial"]
        )
    ]
}

struct OpenRoadmapRetriever {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func research(for input: GoalPlannerInput) async -> [GoalEvidenceSource] {
        let candidates = OpenRoadmapCatalog.candidates(for: input)
        guard !candidates.isEmpty else { return [] }

        return await withTaskGroup(of: (Int, GoalEvidenceSource?).self, returning: [GoalEvidenceSource].self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    (index, await fetch(candidate))
                }
            }

            var result: [(Int, GoalEvidenceSource)] = []
            for await (index, source) in group {
                if let source {
                    result.append((index, source))
                }
            }
            return result.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func fetch(_ source: OpenRoadmapSourceDefinition) async -> GoalEvidenceSource? {
        var request = URLRequest(url: source.url)
        request.httpMethod = "GET"
        request.timeoutInterval = 7
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("Lippi/1.0 roadmap research", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  !data.isEmpty,
                  let excerpt = extractExcerpt(from: data, hints: source.excerptHints) else {
                return nil
            }

            return GoalEvidenceSource(
                title: source.title,
                url: source.url.absoluteString,
                excerpt: excerpt
            )
        } catch {
            return nil
        }
    }

    private func extractExcerpt(from data: Data, hints: [String]) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        let text = attributed.string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { (72...420).contains($0.count) }

        let lowercasedHints = hints.map { $0.lowercased() }
        let best = sentences.max { lhs, rhs in
            relevance(of: lhs, hints: lowercasedHints) < relevance(of: rhs, hints: lowercasedHints)
        }
        guard let best, relevance(of: best, hints: lowercasedHints) > 0 else { return nil }

        return String(best.prefix(320)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func relevance(of sentence: String, hints: [String]) -> Int {
        let normalized = sentence.lowercased()
        return hints.reduce(into: 0) { score, hint in
            if normalized.contains(hint) {
                score += hint.count > 5 ? 2 : 1
            }
        }
    }
}

private extension String {
    var foldedForMatching: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
