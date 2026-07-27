import ActivityKit
import SwiftUI
import WidgetKit

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

struct GoalRoadmapLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GoalRoadmapActivityAttributes.self) { context in
            GoalRoadmapLockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x0B1422))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(GoalRoadmapLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GoalRoadmapIcon(state: context.state, size: 40)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(GoalRoadmapStyle.progressText(for: context.state))
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.stageTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.goalTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 9) {
                        GoalRoadmapProgress(state: context.state)
                        HStack {
                            Label("Умная цель", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.58))
                            Spacer(minLength: 0)
                            Label("Открыть маршрут", systemImage: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(GoalRoadmapStyle.accent(for: context.state))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.stageSymbol)
                    .foregroundStyle(GoalRoadmapStyle.accent(for: context.state))
            } compactTrailing: {
                Text(GoalRoadmapStyle.progressText(for: context.state))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: context.state.stageSymbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(GoalRoadmapStyle.accent(for: context.state))
            }
            .widgetURL(GoalRoadmapLink.url)
            .keylineTint(GoalRoadmapStyle.accent(for: context.state))
        }
    }
}

private struct GoalRoadmapLockScreenView: View {
    let state: GoalRoadmapActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                GoalRoadmapIcon(state: state, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.stageTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(state.goalTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(GoalRoadmapStyle.progressText(for: state))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    if !state.isTerminal {
                        Text(state.startedAt, style: .timer)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.52))
                            .monospacedDigit()
                    }
                }
            }

            GoalRoadmapProgress(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct GoalRoadmapIcon: View {
    let state: GoalRoadmapActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(GoalRoadmapStyle.accent(for: state).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .stroke(GoalRoadmapStyle.accent(for: state).opacity(0.28), lineWidth: 1)
                )
            Image(systemName: state.stageSymbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(GoalRoadmapStyle.accent(for: state))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(state.stageTitle)
    }
}

private struct GoalRoadmapProgress: View {
    let state: GoalRoadmapActivityAttributes.ContentState

    private var progress: Double { min(max(state.progress, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(GoalRoadmapStyle.accent(for: state))
                    .frame(width: max(5, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Прогресс построения маршрута")
        .accessibilityValue(GoalRoadmapStyle.progressText(for: state))
    }
}

private enum GoalRoadmapStyle {
    static func accent(for state: GoalRoadmapActivityAttributes.ContentState) -> Color {
        switch state.style {
        case "success": Color(hex: 0x54D79A)
        case "failure": Color(hex: 0xFFB44A)
        default: Color(hex: 0x59B9FF)
        }
    }

    static func progressText(for state: GoalRoadmapActivityAttributes.ContentState) -> String {
        if state.isTerminal && state.style == "success" { return "Готово" }
        return "\(Int(min(max(state.progress, 0), 1) * 100))%"
    }
}

private enum GoalRoadmapLink {
    static let url = URL(string: "lippi://goals?mode=progress")!
}
