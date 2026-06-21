import Foundation

enum GoalRoadmapActivityStage: String, Sendable {
    case research
    case planning
    case checking

    var progress: Double {
        switch self {
        case .research: return 0.20
        case .planning: return 0.62
        case .checking: return 0.88
        }
    }

    var symbol: String {
        switch self {
        case .research: return "books.vertical.fill"
        case .planning: return "point.topleft.down.curvedto.point.bottomright.up"
        case .checking: return "checklist.checked"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .research: return L10n.tr("goals.island.research", lang)
        case .planning: return L10n.tr("goals.island.planning", lang)
        case .checking: return L10n.tr("goals.island.checking", lang)
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
        let state = GoalRoadmapActivityAttributes.ContentState(
            goalTitle: displayGoalTitle(goalTitle),
            stageTitle: GoalRoadmapActivityStage.research.title(lang: lang),
            stageSymbol: GoalRoadmapActivityStage.research.symbol,
            style: "active",
            progress: GoalRoadmapActivityStage.research.progress,
            startedAt: now,
            isTerminal: false
        )
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(150))
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
            await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(150)))
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
