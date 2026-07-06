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
                .activityBackgroundTint(GoalRoadmapIslandStyle.backdrop(for: context.state))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(GoalRoadmapIslandLink.open.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GoalRoadmapIslandBadge(state: context.state, size: 42)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    GoalRoadmapElapsed(state: context.state, compact: false)
                }

                DynamicIslandExpandedRegion(.center) {
                    GoalRoadmapIslandHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GoalRoadmapIslandPanel(state: context.state)
                }
            } compactLeading: {
                GoalRoadmapIslandBadge(state: context.state, size: 22)
            } compactTrailing: {
                Color.clear
                    .frame(width: 1, height: 1)
            } minimal: {
                GoalRoadmapIslandBadge(state: context.state, size: 18)
            }
            .widgetURL(GoalRoadmapIslandLink.open.url)
            .keylineTint(GoalRoadmapIslandStyle.accent(for: context.state))
            .contentMargins(.all, 0, for: .expanded)
            .contentMargins(.all, 0, for: .compactLeading)
            .contentMargins(.all, 0, for: .compactTrailing)
            .contentMargins(.all, 0, for: .minimal)
        }
    }
}

private struct GoalRoadmapLockScreenView: View {
    let state: GoalRoadmapActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            GoalRoadmapIslandBadge(state: state, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.stageTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.goalTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            GoalRoadmapElapsed(state: state, compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(GoalRoadmapIslandBackdrop(accent: GoalRoadmapIslandStyle.accent(for: state)))
    }
}

private struct GoalRoadmapIslandHeader: View {
    let state: GoalRoadmapActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Lippi")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Text(state.stageTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GoalRoadmapIslandStyle.accent(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct GoalRoadmapIslandPanel: View {
    let state: GoalRoadmapActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(state.goalTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: state.isTerminal ? state.stageSymbol : "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GoalRoadmapIslandStyle.accent(for: state))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.88), GoalRoadmapIslandStyle.accent(for: state)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * min(max(state.progress, 0), 1)))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.08))
                .goalRoadmapLiquidGlass(
                    tint: GoalRoadmapIslandStyle.accent(for: state).opacity(0.20),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }
}

private struct GoalRoadmapIslandBadge: View {
    let state: GoalRoadmapActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.34), GoalRoadmapIslandStyle.accent(for: state).opacity(0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .goalRoadmapLiquidGlass(
                    tint: GoalRoadmapIslandStyle.accent(for: state).opacity(0.25),
                    in: Circle()
                )

            Circle()
                .stroke(.white.opacity(0.34), lineWidth: max(1, size * 0.025))

            if !state.isTerminal {
                Circle()
                    .trim(from: 0.08, to: min(max(state.progress, 0.16), 0.92))
                    .stroke(.white.opacity(0.90), style: StrokeStyle(lineWidth: max(2, size * 0.065), lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.10)
            }

            Image(systemName: state.stageSymbol)
                .font(.system(size: max(8, size * 0.34), weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(state.stageTitle)
    }
}

private struct GoalRoadmapElapsed: View {
    let state: GoalRoadmapActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        Group {
            if state.isTerminal {
                Image(systemName: state.stageSymbol)
                    .foregroundStyle(GoalRoadmapIslandStyle.accent(for: state))
            } else {
                Text(state.startedAt, style: .timer)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .font(compact ? .caption2.weight(.bold) : .subheadline.weight(.bold))
        .foregroundStyle(.white)
        .frame(minWidth: compact ? 26 : 42, alignment: .trailing)
    }
}

private struct GoalRoadmapIslandBackdrop: View {
    let accent: Color

    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x06101D), Color(hex: 0x10224B), accent.opacity(0.34)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum GoalRoadmapIslandStyle {
    static func accent(for state: GoalRoadmapActivityAttributes.ContentState) -> Color {
        switch state.style {
        case "success": return Color(hex: 0x30D158)
        case "failure": return Color(hex: 0xFF9F0A)
        default: return Color(hex: 0x64D2FF)
        }
    }

    static func backdrop(for state: GoalRoadmapActivityAttributes.ContentState) -> Color {
        state.style == "failure" ? Color(hex: 0x3B2412) : Color(hex: 0x10224B)
    }
}

private enum GoalRoadmapIslandLink {
    case open

    var url: URL {
        URL(string: "lippi://goals?action=open")!
    }
}

private extension View {
    @ViewBuilder
    func goalRoadmapLiquidGlass<S: Shape>(tint: Color, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: shape)
        } else {
            self
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
