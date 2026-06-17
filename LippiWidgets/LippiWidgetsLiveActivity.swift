import ActivityKit
import WidgetKit
import SwiftUI

enum PomodoroPhase: String, Codable, Hashable {
    case focus
    case shortBreak
    case longBreak
    case paused
    case stopped
}

struct PomodoroAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var phase: PomodoroPhase
        var startDate: Date
        var endDate: Date?
        var round: Int
    }

    var sessionId: UUID
}

struct LippiWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroAttributes.self) { context in
            PomodoroLiveLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: 0x06101D))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(PomodoroIslandLink.open.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PomodoroIslandPhaseBadge(phase: context.state.phase)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    PomodoroIslandCountdown(state: context.state, compact: false)
                }

                DynamicIslandExpandedRegion(.center) {
                    PomodoroIslandHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    PomodoroIslandGlassPanel(accent: PomodoroIslandCopy.accent(for: context.state.phase)) {
                        PomodoroIslandProgress(state: context.state)

                        HStack(spacing: 8) {
                            PomodoroIslandActionLink(.open)
                            PomodoroIslandActionLink(context.state.phase == .paused ? .resume : .pause)
                            PomodoroIslandActionLink(.stop, destructive: true)
                        }
                    }
                }
            } compactLeading: {
                PomodoroIslandCompactOrb(phase: context.state.phase)
            } compactTrailing: {
                PomodoroIslandCountdown(state: context.state, compact: true)
            } minimal: {
                PomodoroIslandCompactOrb(phase: context.state.phase, minimal: true)
            }
            .widgetURL(PomodoroIslandLink.open.url)
            .keylineTint(PomodoroIslandCopy.accent(for: context.state.phase))
        }
    }
}

private struct PomodoroLiveLockScreenView: View {
    let context: ActivityViewContext<PomodoroAttributes>

    var body: some View {
        HStack(spacing: 12) {
            PomodoroIslandPhaseBadge(phase: context.state.phase)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(context.state.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if context.state.round > 0 {
                        Text("R\(context.state.round)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PomodoroIslandCopy.accent(for: context.state.phase).opacity(0.20), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                    }
                }

                Text(PomodoroIslandCopy.status(for: context.state))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            PomodoroIslandCountdown(state: context.state, compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PomodoroIslandBackdrop(accent: PomodoroIslandCopy.accent(for: context.state.phase)))
    }
}

private struct PomodoroIslandHeader: View {
    let state: PomodoroAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("Lippi")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Circle()
                        .fill(PomodoroIslandCopy.accent(for: state.phase))
                        .frame(width: 4, height: 4)

                    Text(PomodoroIslandCopy.status(for: state))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
                        .lineLimit(1)
                }

                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.20),
                            PomodoroIslandCopy.accent(for: state.phase).opacity(0.12),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule(style: .continuous))
                )
        )
        .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
    }
}

private struct PomodoroIslandPhaseBadge: View {
    let phase: PomodoroPhase

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24),
                            PomodoroIslandCopy.accent(for: phase).opacity(0.36),
                            PomodoroIslandCopy.accent(for: phase).opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .shadow(color: PomodoroIslandCopy.accent(for: phase).opacity(0.30), radius: 8, x: 0, y: 3)

            Circle()
                .stroke(.white.opacity(0.30), lineWidth: 1)
                .frame(width: 42, height: 42)

            Circle()
                .fill(.white.opacity(0.34))
                .frame(width: 12, height: 12)
                .offset(x: -9, y: -10)
                .blur(radius: 0.3)

            Image(systemName: PomodoroIslandCopy.icon(for: phase))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(PomodoroIslandCopy.accessibilityTitle(for: phase))
    }
}

private struct PomodoroIslandCompactOrb: View {
    let phase: PomodoroPhase
    var minimal = false

    var body: some View {
        ZStack {
            Circle()
                .fill(PomodoroIslandCopy.accent(for: phase).opacity(0.24))
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.28), PomodoroIslandCopy.accent(for: phase).opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(minimal ? 3 : 2)
            Image(systemName: PomodoroIslandCopy.icon(for: phase))
                .font(.system(size: minimal ? 9 : 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: minimal ? 18 : 22, height: minimal ? 18 : 22)
    }
}

private struct PomodoroIslandCountdown: View {
    let state: PomodoroAttributes.ContentState
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 0 : 5) {
            if let end = state.endDate, state.phase != .paused {
                if !compact {
                    Image(systemName: "timer")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
                }

                Text(end, style: .timer)
                    .monospacedDigit()
                    .font(compact ? .caption2.weight(.bold) : .system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Image(systemName: state.phase == .paused ? "pause.fill" : "timer")
                    .font(compact ? .caption.weight(.bold) : .title3.weight(.bold))
                    .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
            }
        }
        .padding(.horizontal, compact ? 0 : 9)
        .padding(.vertical, compact ? 0 : 6)
        .background {
            if !compact {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
            }
        }
        .frame(minWidth: compact ? 28 : 56, alignment: .trailing)
    }
}

private struct PomodoroIslandProgress: View {
    let state: PomodoroAttributes.ContentState

    private var progress: Double {
        guard let end = state.endDate else { return state.phase == .paused ? 0.5 : 0 }
        let total = max(end.timeIntervalSince(state.startDate), 1)
        let done = max(Date().timeIntervalSince(state.startDate), 0)
        return min(max(done / total, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(7, proxy.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.12))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.82),
                                PomodoroIslandCopy.accent(for: state.phase),
                                Color(hex: 0x64D2FF)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .shadow(color: PomodoroIslandCopy.accent(for: state.phase).opacity(0.45), radius: 5, x: 0, y: 0)
            }
        }
        .frame(height: 7)
    }
}

private struct PomodoroIslandGlassPanel<Content: View>: View {
    let accent: Color
    let content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 9) {
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.075))
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.18), accent.opacity(0.12), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct PomodoroIslandActionLink: View {
    let action: PomodoroIslandLink
    var destructive: Bool = false

    init(_ action: PomodoroIslandLink, destructive: Bool = false) {
        self.action = action
        self.destructive = destructive
    }

    var body: some View {
        Link(destination: action.url) {
            Label(action.title, systemImage: action.symbol)
                .font(.caption2.weight(.bold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(destructive ? Color(hex: 0xFFB3AD) : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(destructive ? Color(hex: 0xFF453A).opacity(0.13) : Color(hex: 0x30B0FF).opacity(0.16))
                        .overlay(
                            LinearGradient(
                                colors: [.white.opacity(0.17), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(Capsule(style: .continuous))
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(destructive ? 0.16 : 0.22), lineWidth: 1)
                )
        }
    }
}

private struct PomodoroIslandBackdrop: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x06101D),
                    Color(hex: 0x0B1728),
                    Color(hex: 0x13243B)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.40), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 190
            )

            RadialGradient(
                colors: [Color(hex: 0xEAF8FF).opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 180
            )
        }
    }
}

private enum PomodoroIslandLink {
    case open
    case pause
    case resume
    case stop

    var title: String {
        switch self {
        case .open: return "Открыть"
        case .pause: return "Пауза"
        case .resume: return "Дальше"
        case .stop: return "Стоп"
        }
    }

    var symbol: String {
        switch self {
        case .open: return "arrow.up.forward"
        case .pause: return "pause.fill"
        case .resume: return "play.fill"
        case .stop: return "stop.fill"
        }
    }

    var url: URL {
        switch self {
        case .open:
            return URL(string: "lippi://pomodoro?action=open")!
        case .pause:
            return URL(string: "lippi://pomodoro?action=pause")!
        case .resume:
            return URL(string: "lippi://pomodoro?action=resume")!
        case .stop:
            return URL(string: "lippi://pomodoro?action=stop")!
        }
    }
}

private enum PomodoroIslandCopy {
    static func icon(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: return "bolt.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "sparkles"
        case .paused: return "pause.fill"
        case .stopped: return "stop.fill"
        }
    }

    static func accent(for phase: PomodoroPhase) -> Color {
        switch phase {
        case .focus: return Color(hex: 0x30B0FF)
        case .shortBreak: return Color(hex: 0x30D158)
        case .longBreak: return Color(hex: 0xBF8CFF)
        case .paused: return Color(hex: 0xFFD60A)
        case .stopped: return Color(hex: 0x8E8E93)
        }
    }

    static func status(for state: PomodoroAttributes.ContentState) -> String {
        switch state.phase {
        case .focus: return state.round > 0 ? "Фокус - раунд \(state.round)" : "Фокус без отвлечений"
        case .shortBreak: return "Короткий перерыв"
        case .longBreak: return "Длинный перерыв"
        case .paused: return "Таймер на паузе"
        case .stopped: return "Сессия завершена"
        }
    }

    static func accessibilityTitle(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: return "Фокус"
        case .shortBreak: return "Перерыв"
        case .longBreak: return "Длинный перерыв"
        case .paused: return "Пауза"
        case .stopped: return "Стоп"
        }
    }
}

extension PomodoroAttributes {
    fileprivate static var preview: PomodoroAttributes {
        PomodoroAttributes(sessionId: UUID())
    }
}

extension PomodoroAttributes.ContentState {
    fileprivate static var focusPreview: PomodoroAttributes.ContentState {
        PomodoroAttributes.ContentState(
            title: "Фокус",
            phase: .focus,
            startDate: .now.addingTimeInterval(-9 * 60),
            endDate: .now.addingTimeInterval(16 * 60),
            round: 2
        )
    }

    fileprivate static var pausedPreview: PomodoroAttributes.ContentState {
        PomodoroAttributes.ContentState(
            title: "Пауза",
            phase: .paused,
            startDate: .now.addingTimeInterval(-10 * 60),
            endDate: nil,
            round: 2
        )
    }
}

#Preview("Pomodoro", as: .dynamicIsland(.expanded), using: PomodoroAttributes.preview) {
    LippiWidgetsLiveActivity()
} contentStates: {
    PomodoroAttributes.ContentState.focusPreview
    PomodoroAttributes.ContentState.pausedPreview
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
