import Foundation

enum GoalRoadmapActivityStage: String, Sendable, Equatable {
    case preparing
    case research
    case planning
    case checking
    case refining
    case finalizing

    var progress: Double {
        switch self {
        case .preparing: return 0.10
        case .research: return 0.22
        case .planning: return 0.52
        case .checking: return 0.76
        case .refining: return 0.86
        case .finalizing: return 0.95
        }
    }

    var symbol: String {
        switch self {
        case .preparing: return "cpu.fill"
        case .research: return "books.vertical.fill"
        case .planning: return "point.topleft.down.curvedto.point.bottomright.up"
        case .checking: return "checklist.checked"
        case .refining: return "wand.and.stars"
        case .finalizing: return "checkmark.seal.fill"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .preparing: return L10n.tr("goals.island.preparing", lang)
        case .research: return L10n.tr("goals.island.research", lang)
        case .planning: return L10n.tr("goals.island.planning", lang)
        case .checking: return L10n.tr("goals.island.checking", lang)
        case .refining: return L10n.tr("goals.island.refining", lang)
        case .finalizing: return L10n.tr("goals.island.finalizing", lang)
        }
    }

    func detail(lang: AppLang) -> String {
        switch self {
        case .preparing: return L10n.tr("goals.processing.detail.preparing", lang)
        case .research: return L10n.tr("goals.processing.detail.research", lang)
        case .planning: return L10n.tr("goals.processing.detail.planning", lang)
        case .checking: return L10n.tr("goals.processing.detail.checking", lang)
        case .refining: return L10n.tr("goals.processing.detail.refining", lang)
        case .finalizing: return L10n.tr("goals.processing.detail.finalizing", lang)
        }
    }
}

enum GoalRoadmapActivityOutcome: Sendable, Equatable {
    case ready
    case draftReady
    case failed

    var symbol: String {
        switch self {
        case .ready, .draftReady: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var style: String {
        switch self {
        case .ready, .draftReady: return "success"
        case .failed: return "failure"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .ready: return L10n.tr("goals.island.ready", lang)
        case .draftReady: return L10n.tr("goals.island.draft_ready", lang)
        case .failed: return L10n.tr("goals.island.failed", lang)
        }
    }
}

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct GoalRoadmapActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var goalTitle: String
        var stageTitle: String
        var stageSymbol: String
        var style: String
        var progress: Double
        var startedAt: Date
        var isTerminal: Bool
    }

    var requestID: UUID
}

@available(iOS 16.2, *)
enum GoalRoadmapLiveActivityManager {
    static func start(goalTitle: String, lang: AppLang) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        await endAll()

        let now = Date()
        let attributes = GoalRoadmapActivityAttributes(requestID: UUID())
        let initialStage = GoalRoadmapActivityStage.preparing
        let state = GoalRoadmapActivityAttributes.ContentState(
            goalTitle: displayGoalTitle(goalTitle),
            stageTitle: initialStage.title(lang: lang),
            stageSymbol: initialStage.symbol,
            style: "active",
            progress: initialStage.progress,
            startedAt: now,
            isTerminal: false
        )
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(600))
        _ = try? Activity<GoalRoadmapActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    static func update(_ stage: GoalRoadmapActivityStage, lang: AppLang) async {
        for activity in Activity<GoalRoadmapActivityAttributes>.activities {
            var state = activity.content.state
            state.stageTitle = stage.title(lang: lang)
            state.stageSymbol = stage.symbol
            state.style = "active"
            state.progress = stage.progress
            state.isTerminal = false
            await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(600)))
        }
    }

    static func finish(_ outcome: GoalRoadmapActivityOutcome, lang: AppLang) async {
        for activity in Activity<GoalRoadmapActivityAttributes>.activities {
            var state = activity.content.state
            state.stageTitle = outcome.title(lang: lang)
            state.stageSymbol = outcome.symbol
            state.style = outcome.style
            state.progress = 1
            state.isTerminal = true

            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(outcome == .failed ? 1.4 : 2.2))
            )
        }
    }

    static func endAll() async {
        for activity in Activity<GoalRoadmapActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private static func displayGoalTitle(_ rawTitle: String) -> String {
        let compactTitle = rawTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard compactTitle.count > 58 else { return compactTitle }
        return String(compactTitle.prefix(55)) + "..."
    }
}
#endif
