import Foundation

struct GoalEvidenceSource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    let title: String
    let url: String
    let excerpt: String
    var sourceType: String? = nil
    var planningUse: String? = nil
    var matchReason: String? = nil

    var host: String {
        URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url
    }
}

struct OpenRoadmapSourceDefinition: Hashable, Sendable {
    let id: String
    let title: String
    let url: URL
    let domain: GoalEvidenceDomain
    let sourceType: String
    let planningUse: String
    let triggers: [String]
    let excerptHints: [String]
    let priority: Int
}

enum GoalEvidenceDomain: String, Codable, Hashable, Sendable {
    case software
    case product
    case design
    case language
    case health
    case business
    case general
}

struct GoalDomainProfile: Hashable, Sendable {
    let domain: GoalEvidenceDomain
    let intent: String
    let sourceNeed: String
    let planningWarning: String

    func promptSection() -> String {
        """
        Goal domain profile:
        - domain: \(domain.rawValue)
        - likely intent: \(intent)
        - source need: \(sourceNeed)
        - planning warning: \(planningWarning)
        """
    }
}

enum OpenRoadmapCatalog {
    static func profile(for input: GoalPlannerInput) -> GoalDomainProfile {
        let text = "\(input.goal) \(input.context)".foldedForMatching

        if text.containsAny(["mvp", "стартап", "startup", "запуст", "launch", "продукт", "product"]) {
            return GoalDomainProfile(
                domain: .product,
                intent: "turn an idea into a validated product or launch plan",
                sourceNeed: "prefer product discovery, MVP validation, market learning, and business planning references",
                planningWarning: "do not invent demand, users, revenue, traction, conversion, or market proof"
            )
        }
        if text.containsAny(["бизнес", "business", "бизнес план", "business plan", "малый бизнес", "small business", "продаж", "sales", "маркетинг", "marketing", "рынок", "market", "клиент", "customer"]) {
            return GoalDomainProfile(
                domain: .business,
                intent: "make a business idea operational, validated, and measurable without inventing demand",
                sourceNeed: "prefer official business planning, market learning, operations, and validation references",
                planningWarning: "separate assumptions from facts; plan discovery and validation before sales or revenue claims"
            )
        }
        if text.containsAny(["ios", "iphone", "swift", "xcode", "frontend", "backend", "python", "api", "docker", "devops", "код", "программ"]) {
            return GoalDomainProfile(
                domain: .software,
                intent: "build technical skill or ship a software artifact",
                sourceNeed: "prefer official documentation, developer roadmaps, and implementation-oriented references",
                planningWarning: "separate learning, building, testing, and shipping; do not promise app-store, user, or revenue outcomes"
            )
        }
        if text.containsAny(["ui", "ux", "дизайн", "figma", "прототип", "interface", "интерфейс"]) {
            return GoalDomainProfile(
                domain: .design,
                intent: "improve a design skill or create a usable design artifact",
                sourceNeed: "prefer UX research, accessibility, prototype, and design-system references",
                planningWarning: "make every milestone produce an artifact: research notes, prototype, test result, or design decision"
            )
        }
        if text.containsAny(["англий", "english", "язык", "language", "a1", "a2", "b1", "b2", "cefr", "ielts", "toefl"]) {
            return GoalDomainProfile(
                domain: .language,
                intent: "reach a language level or improve language ability",
                sourceNeed: "prefer CEFR and study-practice references",
                planningWarning: "plan observable language practice and checks; do not guarantee a certified level without assessment"
            )
        }
        if text.containsAny(["похуд", "вес", "weight", "fitness", "фитнес", "спорт", "бег", "run", "трениров", "exercise", "сон", "здоров"]) {
            return GoalDomainProfile(
                domain: .health,
                intent: "improve health, fitness, weight, recovery, or routine",
                sourceNeed: "prefer public-health references and safety-first habit guidance",
                planningWarning: "do not diagnose, prescribe, or guarantee health outcomes; keep steps gentle and measurable"
            )
        }

        return GoalDomainProfile(
            domain: .general,
            intent: "make the goal concrete and turn it into a sustainable route",
            sourceNeed: "prefer broadly applicable planning references and the user's own context",
            planningWarning: "avoid generic productivity advice; ask clarifying questions when facts are missing"
        )
    }

    static func candidates(for input: GoalPlannerInput) -> [OpenRoadmapSourceDefinition] {
        let profile = profile(for: input)
        let text = "\(input.goal) \(input.context)".foldedForMatching
        let scored = sources.compactMap { source -> (OpenRoadmapSourceDefinition, Int)? in
            let score = source.triggers.reduce(into: 0) { partialResult, trigger in
                if text.contains(trigger) {
                    partialResult += trigger.count > 5 ? 4 : 2
                }
            }
            let domainBoost = source.domain == profile.domain ? 5 : 0
            let adjacentBoost = isAdjacent(source.domain, profile.domain) ? 2 : 0
            let totalScore = score + domainBoost + adjacentBoost + source.priority
            return totalScore > source.priority ? (source, totalScore) : nil
        }

        return scored
            .sorted { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.title < rhs.0.title : lhs.1 > rhs.1
            }
            .prefix(3)
            .map(\.0)
    }

    private static func isAdjacent(_ source: GoalEvidenceDomain, _ profile: GoalEvidenceDomain) -> Bool {
        switch (source, profile) {
        case (.business, .product), (.product, .business), (.design, .product), (.product, .design), (.software, .product), (.product, .software):
            return true
        default:
            return false
        }
    }

    private static let sources: [OpenRoadmapSourceDefinition] = [
        OpenRoadmapSourceDefinition(
            id: "roadmap-frontend",
            title: "Frontend Developer Roadmap",
            url: URL(string: "https://roadmap.sh/frontend")!,
            domain: .software,
            sourceType: "roadmap",
            planningUse: "sequence technical learning from fundamentals into implementation and practice artifacts",
            triggers: ["frontend", "front-end", "фронтенд", "веб", "web developer", "html", "css", "javascript", "react"],
            excerptHints: ["frontend", "roadmap", "learn", "html", "css", "javascript"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "mdn-learn-web",
            title: "MDN Learn web development",
            url: URL(string: "https://developer.mozilla.org/en-US/docs/Learn_web_development")!,
            domain: .software,
            sourceType: "official learning documentation",
            planningUse: "ground beginner web milestones in fundamentals, practice, and reference-backed learning",
            triggers: ["frontend", "front-end", "фронтенд", "веб", "web developer", "html", "css", "javascript", "react"],
            excerptHints: ["web development", "learn", "html", "css", "javascript"],
            priority: 4
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-python",
            title: "Python Developer Roadmap",
            url: URL(string: "https://roadmap.sh/python")!,
            domain: .software,
            sourceType: "roadmap",
            planningUse: "structure Python learning into syntax, tooling, projects, and framework practice",
            triggers: ["python", "питон", "пайтон", "django", "flask", "fastapi"],
            excerptHints: ["python", "roadmap", "learn", "developer"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-backend",
            title: "Backend Developer Roadmap",
            url: URL(string: "https://roadmap.sh/backend")!,
            domain: .software,
            sourceType: "roadmap",
            planningUse: "sequence backend learning across APIs, databases, security, deployment, and practice projects",
            triggers: ["backend", "back-end", "бэкенд", "бекенд", "api", "сервер", "database", "база данных"],
            excerptHints: ["backend", "roadmap", "api", "database", "developer"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-ios",
            title: "iOS Developer Roadmap",
            url: URL(string: "https://roadmap.sh/ios")!,
            domain: .software,
            sourceType: "roadmap",
            planningUse: "sequence iOS learning across Swift, app structure, UI, persistence, testing, and release practice",
            triggers: ["ios", "iphone", "swift", "xcode", "айос", "айфон"],
            excerptHints: ["ios", "swift", "roadmap", "developer"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "swift-docs",
            title: "Swift.org Documentation",
            url: URL(string: "https://www.swift.org/documentation/")!,
            domain: .software,
            sourceType: "official documentation",
            planningUse: "anchor Swift learning in official language and tooling references",
            triggers: ["swift", "ios", "xcode", "айос", "айфон"],
            excerptHints: ["swift", "documentation", "language", "package", "tooling"],
            priority: 4
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-devops",
            title: "DevOps Roadmap",
            url: URL(string: "https://roadmap.sh/devops")!,
            domain: .software,
            sourceType: "roadmap",
            planningUse: "break infrastructure goals into tooling, automation, deployment, and reliability checkpoints",
            triggers: ["devops", "dev ops", "девопс", "kubernetes", "docker", "terraform", "ci/cd"],
            excerptHints: ["devops", "roadmap", "cloud", "docker", "kubernetes"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-product-manager",
            title: "Product Manager Roadmap",
            url: URL(string: "https://roadmap.sh/product-manager")!,
            domain: .product,
            sourceType: "roadmap",
            planningUse: "turn product goals into discovery, prioritization, validation, and delivery checkpoints",
            triggers: ["product manager", "product management", "продакт", "продуктовый менеджер", "mvp", "product"],
            excerptHints: ["product", "roadmap", "strategy", "market", "manager"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "roadmap-ux-design",
            title: "UX Design Roadmap",
            url: URL(string: "https://roadmap.sh/ux-design")!,
            domain: .design,
            sourceType: "roadmap",
            planningUse: "sequence UX work through research, information architecture, prototyping, testing, and iteration",
            triggers: ["ux", "ui", "design", "дизайн", "прототип", "prototype", "figma"],
            excerptHints: ["ux", "design", "roadmap", "research", "user"],
            priority: 2
        ),
        OpenRoadmapSourceDefinition(
            id: "cambridge-cefr",
            title: "Cambridge English: CEFR levels",
            url: URL(string: "https://www.cambridgeenglish.org/exams-and-tests/cefr/")!,
            domain: .language,
            sourceType: "assessment framework",
            planningUse: "map language goals to observable level descriptors and assessment checkpoints",
            triggers: ["англий", "english", "язык", "language", "a1", "a2", "b1", "b2", "cefr", "ielts", "toefl"],
            excerptHints: ["cefr", "language", "level", "english", "a1", "b1"],
            priority: 4
        ),
        OpenRoadmapSourceDefinition(
            id: "cdc-healthy-weight",
            title: "CDC: Steps for losing weight",
            url: URL(string: "https://www.cdc.gov/healthy-weight-growth/losing-weight/index.html")!,
            domain: .health,
            sourceType: "public health guidance",
            planningUse: "keep weight and fitness goals gradual, behavioral, and safety-oriented",
            triggers: ["похуд", "вес", "weight", "fitness", "фитнес", "спорт", "бег", "run", "трениров", "exercise"],
            excerptHints: ["weight", "healthy", "physical activity", "sleep", "steps"],
            priority: 4
        ),
        OpenRoadmapSourceDefinition(
            id: "who-physical-activity",
            title: "WHO: Physical activity",
            url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/physical-activity")!,
            domain: .health,
            sourceType: "public health fact sheet",
            planningUse: "frame activity goals around sustainable movement and high-level health guidance",
            triggers: ["похуд", "вес", "weight", "fitness", "фитнес", "спорт", "бег", "run", "трениров", "exercise"],
            excerptHints: ["physical activity", "health", "adults", "exercise"],
            priority: 4
        ),
        OpenRoadmapSourceDefinition(
            id: "sba-business-plan",
            title: "U.S. Small Business Administration: Plan your business",
            url: URL(string: "https://www.sba.gov/business-guide/plan-your-business")!,
            domain: .business,
            sourceType: "official business guidance",
            planningUse: "ground business goals in planning, validation, market learning, and operational assumptions",
            triggers: ["бизнес", "business", "mvp", "стартап", "startup", "запуст", "launch", "продукт", "product", "тур", "tour"],
            excerptHints: ["business", "plan", "market", "launch", "financial"],
            priority: 4
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
                excerpt: excerpt,
                sourceType: source.sourceType,
                planningUse: source.planningUse,
                matchReason: "Matched \(source.domain.rawValue) goal signals"
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
        let scored: [(sentence: String, score: Int)] = sentences.map { sentence in
            (sentence: sentence, score: relevance(of: sentence, hints: lowercasedHints))
        }
        let relevant = scored.filter { $0.score > 0 }
        let sorted = relevant.sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.sentence.count < rhs.sentence.count : lhs.score > rhs.score
        }
        let ranked = sorted.prefix(3).map { $0.sentence }
        guard !ranked.isEmpty else { return nil }

        return String(ranked.joined(separator: ". ").prefix(620)).trimmingCharacters(in: .whitespacesAndNewlines)
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

    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}
