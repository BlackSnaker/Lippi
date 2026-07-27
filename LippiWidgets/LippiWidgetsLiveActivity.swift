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
            PomodoroLockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x0B1422))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(PomodoroActivityLink.open.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PomodoroActivityIcon(state: context.state, size: 40)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    PomodoroActivityTimer(state: context.state, font: .headline)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PomodoroActivityStyle.title(for: context.state.phase))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(PomodoroActivityStyle.subtitle(for: context.state.phase))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        PomodoroActivityProgress(state: context.state)

                        HStack(spacing: 8) {
                            PomodoroActivityAction(.open)
                            PomodoroActivityAction(context.state.phase == .paused ? .resume : .pause)
                            PomodoroActivityAction(.stop, destructive: true)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: PomodoroActivityStyle.icon(for: context.state.phase))
                    .foregroundStyle(PomodoroActivityStyle.accent(for: context.state.phase))
            } compactTrailing: {
                PomodoroActivityTimer(state: context.state, font: .caption2)
                    .frame(maxWidth: 45)
            } minimal: {
                Image(systemName: PomodoroActivityStyle.icon(for: context.state.phase))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PomodoroActivityStyle.accent(for: context.state.phase))
            }
            .widgetURL(PomodoroActivityLink.open.url)
            .keylineTint(PomodoroActivityStyle.accent(for: context.state.phase))
        }
    }
}
private struct PomodoroLockScreenView: View {
    let state: PomodoroAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                PomodoroActivityIcon(state: state, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(PomodoroActivityStyle.title(for: state.phase))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if state.round > 0 {
                            Text("R\(state.round)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(PomodoroActivityStyle.accent(for: state.phase))
                        }
                    }
                    Text(PomodoroActivityStyle.subtitle(for: state.phase))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                PomodoroActivityTimer(state: state, font: .title3)
            }

            PomodoroActivityProgress(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct PomodoroActivityIcon: View {
    let state: PomodoroAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(PomodoroActivityStyle.accent(for: state.phase).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .stroke(PomodoroActivityStyle.accent(for: state.phase).opacity(0.28), lineWidth: 1)
                )
            Image(systemName: PomodoroActivityStyle.icon(for: state.phase))
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(PomodoroActivityStyle.accent(for: state.phase))
        }
        .frame(width: size, height: size)
    }
}

private struct PomodoroActivityTimer: View {
    let state: PomodoroAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            if let end = state.endDate, state.phase != .paused, state.phase != .stopped {
                Text(end, style: .timer)
            } else if state.phase == .paused {
                Text("Пауза")
            } else {
                Text("Готово")
            }
        }
        .font(font.weight(.bold))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }
}

private struct PomodoroActivityProgress: View {
    let state: PomodoroAttributes.ContentState

    private var progress: Double {
        guard let end = state.endDate else { return state.phase == .stopped ? 0 : 0.5 }
        let total = max(end.timeIntervalSince(state.startDate), 1)
        return min(max(Date().timeIntervalSince(state.startDate) / total, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(PomodoroActivityStyle.accent(for: state.phase))
                    .frame(width: max(5, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Прогресс сессии")
        .accessibilityValue("\(Int(progress * 100)) процентов")
    }
}

private struct PomodoroActivityAction: View {
    let link: PomodoroActivityLink
    let destructive: Bool

    init(_ link: PomodoroActivityLink, destructive: Bool = false) {
        self.link = link
        self.destructive = destructive
    }

    var body: some View {
        Link(destination: link.url) {
            Label(link.title, systemImage: link.icon)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(destructive ? Color(hex: 0xFF777D) : .white)
                .background(
                    Capsule()
                        .fill(destructive ? Color(hex: 0xFF5A62).opacity(0.10) : .white.opacity(0.08))
                )
        }
    }
}

private enum PomodoroActivityLink {
    case open
    case pause
    case resume
    case stop

    var title: String {
        switch self {
        case .open: "Открыть"
        case .pause: "Пауза"
        case .resume: "Продолжить"
        case .stop: "Стоп"
        }
    }

    var icon: String {
        switch self {
        case .open: "arrow.up.right"
        case .pause: "pause.fill"
        case .resume: "play.fill"
        case .stop: "stop.fill"
        }
    }

    var url: URL {
        switch self {
        case .open: URL(string: "lippi://pomodoro?action=open")!
        case .pause: URL(string: "lippi://pomodoro?action=pause")!
        case .resume: URL(string: "lippi://pomodoro?action=resume")!
        case .stop: URL(string: "lippi://pomodoro?action=stop")!
        }
    }
}

private enum PomodoroActivityStyle {
    static func title(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: "Фокус"
        case .shortBreak: "Короткий отдых"
        case .longBreak: "Восстановление"
        case .paused: "Пауза"
        case .stopped: "Сессия завершена"
        }
    }

    static func subtitle(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: "Только самое важное"
        case .shortBreak: "Дайте вниманию выдохнуть"
        case .longBreak: "Восстановите силы"
        case .paused: "Продолжите в своём ритме"
        case .stopped: "Хорошая работа"
        }
    }

    static func icon(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: "scope"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "leaf.fill"
        case .paused: "pause.fill"
        case .stopped: "checkmark"
        }
    }

    static func accent(for phase: PomodoroPhase) -> Color {
        switch phase {
        case .focus: Color(hex: 0x55B8FF)
        case .shortBreak: Color(hex: 0x54D79A)
        case .longBreak: Color(hex: 0x70D9C9)
        case .paused: Color(hex: 0xFFB44A)
        case .stopped: Color(hex: 0x93A3BC)
        }
    }
}
