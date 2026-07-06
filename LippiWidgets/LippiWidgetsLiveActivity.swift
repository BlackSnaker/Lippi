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
                .activityBackgroundTint(Color(hex: 0x1A3268))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(PomodoroIslandLink.open.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                .contentMargins(.all, 0)

                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                .contentMargins(.all, 0)

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                .contentMargins(.all, 0)

                DynamicIslandExpandedRegion(.bottom) {
                    PomodoroIslandReferenceCard(state: context.state)
                }
                .contentMargins(.all, 0)
            } compactLeading: {
                PomodoroIslandCompactOrb(phase: context.state.phase)
            } compactTrailing: {
                Color.clear
                    .frame(width: 1, height: 1)
            } minimal: {
                PomodoroIslandCompactOrb(phase: context.state.phase, minimal: true)
            }
            .widgetURL(PomodoroIslandLink.open.url)
            .keylineTint(PomodoroIslandCopy.accent(for: context.state.phase))
            .contentMargins(.all, 0, for: .expanded)
            .contentMargins(.all, 0, for: .compactLeading)
            .contentMargins(.all, 0, for: .compactTrailing)
            .contentMargins(.all, 0, for: .minimal)
        }
    }
}

private struct PomodoroLiveLockScreenView: View {
    let context: ActivityViewContext<PomodoroAttributes>

    var body: some View {
        HStack(spacing: 12) {
            PomodoroIslandPhaseBadge(state: context.state, size: 42)

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

private struct PomodoroIslandTitleBlock: View {
    let state: PomodoroAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PomodoroIslandCopy.displayTitle(for: state.phase, fallback: state.title))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(PomodoroIslandCopy.status(for: state))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PomodoroIslandPhaseBadge: View {
    let state: PomodoroAttributes.ContentState
    var size: CGFloat = 66

    private var phase: PomodoroPhase { state.phase }

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
                .frame(width: size, height: size)
                .pomodoroLiquidGlass(tint: PomodoroIslandCopy.accent(for: phase).opacity(0.24), in: Circle())
                .shadow(color: PomodoroIslandCopy.accent(for: phase).opacity(0.38), radius: size * 0.18, x: 0, y: size * 0.05)

            Circle()
                .stroke(.white.opacity(0.34), lineWidth: 1.2)
                .frame(width: size, height: size)

            Circle()
                .stroke(PomodoroIslandCopy.accent(for: phase).opacity(0.22), lineWidth: 1)
                .frame(width: size - 7, height: size - 7)

            Circle()
                .trim(from: 0, to: min(max(progress, 0.08), 1))
                .stroke(
                    PomodoroIslandCopy.accent(for: phase),
                    style: StrokeStyle(lineWidth: max(3, size * 0.075), lineCap: .butt)
                )
                .rotationEffect(.degrees(-88))
                .frame(width: size + 2, height: size + 2)

            Circle()
                .fill(.white.opacity(0.34))
                .frame(width: size * 0.30, height: size * 0.30)
                .offset(x: -size * 0.18, y: -size * 0.24)
                .blur(radius: 0.3)

            Image(systemName: PomodoroIslandCopy.icon(for: phase))
                .font(.system(size: max(15, size * 0.36), weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size + 4, height: size + 4)
        .accessibilityLabel(PomodoroIslandCopy.accessibilityTitle(for: phase))
    }

    private var progress: Double {
        guard let end = state.endDate else { return state.phase == .paused ? 0.72 : 0.12 }
        let total = max(end.timeIntervalSince(state.startDate), 1)
        let done = max(Date().timeIntervalSince(state.startDate), 0)
        return min(max(done / total, 0), 1)
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
                .font(.system(size: minimal ? 8 : 9, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: minimal ? 15 : 17, height: minimal ? 15 : 17)
    }
}

private struct PomodoroIslandCountdown: View {
    let state: PomodoroAttributes.ContentState
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 0 : 5) {
            if let end = state.endDate, state.phase != .paused {
                Text(end, style: .timer)
                    .monospacedDigit()
                    .font(compact ? .caption2.weight(.bold) : .system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Image(systemName: state.phase == .paused ? "pause.fill" : "timer")
                    .font(compact ? .caption.weight(.bold) : .system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
            }
        }
        .padding(.horizontal, compact ? 0 : 2)
        .padding(.vertical, compact ? 0 : 0)
        .background {
            if !compact {
                Color.clear
            }
        }
        .frame(minWidth: compact ? 28 : 82, alignment: .trailing)
    }
}

private struct PomodoroIslandProgress: View {
    let state: PomodoroAttributes.ContentState

    private var progress: Double {
        guard let end = state.endDate else { return state.phase == .paused ? 0.5 : 0 }
        let total = max(end.timeIntervalSince(state.startDate), 1)
        let done = max(Date().timeIntervalSince(state.startDate), 0)
        let measured = min(max(done / total, 0), 1)
        if state.phase == .shortBreak || state.phase == .longBreak {
            return max(measured, 0.36)
        }
        return measured
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(7, proxy.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0xCDEFFF).opacity(0.34),
                                Color(hex: 0x5F76AF).opacity(0.40),
                                Color(hex: 0x2E3D6E).opacity(0.44)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.20))
                            .frame(height: 2)
                    }

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x31F777),
                                PomodoroIslandCopy.accent(for: state.phase),
                                Color(hex: 0x18B94D)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.22))
                            .frame(height: 2)
                    }
                    .shadow(color: PomodoroIslandCopy.accent(for: state.phase).opacity(0.62), radius: 8, x: 0, y: 0)
            }
        }
        .frame(height: 7)
    }
}

private struct PomodoroIslandReferenceCard: View {
    let state: PomodoroAttributes.ContentState

    var body: some View {
        ZStack {
            PomodoroIslandExpandedSurface(accent: PomodoroIslandCopy.accent(for: state.phase))
                .frame(maxWidth: .infinity)
                .frame(height: 178)
                .offset(y: -10)

            VStack(spacing: 7) {
                HStack(spacing: 14) {
                    PomodoroIslandPhaseBadge(state: state, size: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(PomodoroIslandCopy.displayTitle(for: state.phase, fallback: state.title))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text(PomodoroIslandCopy.status(for: state))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(PomodoroIslandCopy.accent(for: state.phase))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: 4)

                    PomodoroIslandCountdown(state: state, compact: false)
                }
                .padding(.horizontal, 17)
                .padding(.top, 5)

                PomodoroIslandProgress(state: state)
                    .padding(.horizontal, 18)

                HStack(spacing: 10) {
                    PomodoroIslandActionLink(.open, style: .bright)
                    PomodoroIslandActionLink(state.phase == .paused ? .resume : .pause, style: .regular)
                    PomodoroIslandActionLink(.stop, destructive: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 126)
        .padding(.horizontal, 2)
        .offset(y: -25)
    }
}

private struct PomodoroIslandExpandedSurface: View {
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Color(hex: 0x102B69).opacity(0.42))
                .pomodoroLiquidGlass(tint: Color(hex: 0xB9F6FF).opacity(0.22), in: RoundedRectangle(cornerRadius: 44, style: .continuous))

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xE5FFFF).opacity(0.36),
                            Color(hex: 0x5D8DDD).opacity(0.34),
                            Color(hex: 0x1E3A82).opacity(0.58),
                            Color(hex: 0x071A4A).opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [
                    Color(hex: 0xDFFFFF).opacity(0.50),
                    Color(hex: 0x9EF4FF).opacity(0.22),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 170
            )
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

            RadialGradient(
                colors: [
                    accent.opacity(0.34),
                    accent.opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.12, y: 0.42),
                startRadius: 0,
                endRadius: 150
            )
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

            RadialGradient(
                colors: [
                    Color(hex: 0x0A1B52).opacity(0.38),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 210
            )
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.30),
                            .white.opacity(0.07),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(.white.opacity(0.38), lineWidth: 1.2)

            RoundedRectangle(cornerRadius: 39, style: .continuous)
                .strokeBorder(Color(hex: 0x9CEEFF).opacity(0.16), lineWidth: 1)
                .padding(4)

            Capsule(style: .continuous)
                .fill(.white.opacity(0.26))
                .frame(width: 118, height: 18)
                .blur(radius: 18)
                .offset(x: -112, y: -58)
                .blendMode(.screen)
        }
        .compositingGroup()
        .shadow(color: Color(hex: 0x8CEBFF).opacity(0.26), radius: 18, x: 0, y: 7)
        .shadow(color: Color(hex: 0x071235).opacity(0.38), radius: 24, x: 0, y: 16)
    }
}

private struct PomodoroIslandButtonSurface: View {
    let style: PomodoroIslandActionLink.Style
    let destructive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(buttonFill)
                .pomodoroLiquidGlass(tint: glassTint, in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(buttonFill)
                .opacity(style == .bright ? 0.78 : 0.58)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(style == .bright ? 0.46 : 0.26),
                            .white.opacity(0.07),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(style == .bright ? 0.55 : 0.24), lineWidth: 1)
        }
    }

    private var glassTint: Color {
        if destructive { return Color(hex: 0x637DB8).opacity(0.28) }
        if style == .bright { return Color(hex: 0xD9FBFF).opacity(0.34) }
        return Color(hex: 0x9EBBFF).opacity(0.24)
    }

    private var buttonFill: LinearGradient {
        if destructive {
            return LinearGradient(
                colors: [
                    Color(hex: 0x617FC2).opacity(0.42),
                    Color(hex: 0x394F83).opacity(0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if style == .bright {
            return LinearGradient(
                colors: [
                    Color(hex: 0xE4FFFF).opacity(0.64),
                    Color(hex: 0x9AEFFF).opacity(0.42),
                    Color(hex: 0x5279AE).opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(hex: 0x8BADFF).opacity(0.40),
                Color(hex: 0x415D99).opacity(0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    @ViewBuilder
    func pomodoroLiquidGlass<S: Shape>(tint: Color, in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self
        }
    }
}

private struct PomodoroIslandActionLink: View {
    enum Style {
        case bright
        case regular
    }

    let action: PomodoroIslandLink
    var style: Style = .regular
    var destructive: Bool = false

    init(_ action: PomodoroIslandLink, style: Style = .regular, destructive: Bool = false) {
        self.action = action
        self.style = style
        self.destructive = destructive
    }

    var body: some View {
        Link(destination: action.url) {
            Label(action.title, systemImage: action.symbol)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(destructive ? Color(hex: 0xFF7A73) : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(PomodoroIslandButtonSurface(style: style, destructive: destructive))
                .shadow(color: buttonShadow, radius: style == .bright ? 10 : 6, x: 0, y: 4)
        }
    }

    private var buttonShadow: Color {
        if destructive { return Color(hex: 0x1C2D55).opacity(0.34) }
        if style == .bright { return Color(hex: 0xB7F8FF).opacity(0.30) }
        return Color(hex: 0x395DA8).opacity(0.26)
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
    static func displayTitle(for phase: PomodoroPhase, fallback: String) -> String {
        switch phase {
        case .focus: return fallback.isEmpty ? "Фокус" : fallback
        case .shortBreak: return "Перерыв"
        case .longBreak: return "Перерыв"
        case .paused: return "Пауза"
        case .stopped: return "Стоп"
        }
    }

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
