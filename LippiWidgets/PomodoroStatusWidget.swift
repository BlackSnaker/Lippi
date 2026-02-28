import WidgetKit
import SwiftUI

enum PomodoroWidgetPhase: String {
    case focus
    case shortBreak
    case longBreak
    case paused
    case stopped

    var title: String {
        switch self {
        case .focus: return "Фокус"
        case .shortBreak: return "Короткий перерыв"
        case .longBreak: return "Длинный перерыв"
        case .paused: return "Пауза"
        case .stopped: return "Остановлено"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "bolt.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "sparkles"
        case .paused: return "pause.fill"
        case .stopped: return "stop.fill"
        }
    }

    var accent: Color {
        switch self {
        case .focus: return Color(hex: 0x0A84FF)
        case .shortBreak: return Color(hex: 0x30D158)
        case .longBreak: return Color(hex: 0x64D2FF)
        case .paused: return Color(hex: 0xFF9F0A)
        case .stopped: return Color(hex: 0x8E9AAF)
        }
    }

    var glow: Color {
        switch self {
        case .focus: return Color(hex: 0x5AC8FA)
        case .shortBreak: return Color(hex: 0x7CF5A5)
        case .longBreak: return Color(hex: 0x9BE7FF)
        case .paused: return Color(hex: 0xFFC06A)
        case .stopped: return Color(hex: 0xAAB4C8)
        }
    }

    var subtitle: String {
        switch self {
        case .focus: return "Глубокая работа"
        case .shortBreak: return "Небольшая перезагрузка"
        case .longBreak: return "Восстановление внимания"
        case .paused: return "Ожидает продолжения"
        case .stopped: return "Можно начать в любой момент"
        }
    }
}

struct PomodoroStatusEntry: TimelineEntry {
    let date: Date
    let phase: PomodoroWidgetPhase
    let start: Date?
    let end: Date?
    let round: Int
}

struct PomodoroStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroStatusEntry {
        .init(
            date: .now,
            phase: .focus,
            start: .now,
            end: Date().addingTimeInterval(25 * 60),
            round: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroStatusEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroStatusEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(for: entry))))
    }

    private func loadEntry() -> PomodoroStatusEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.suiteID)

        let raw = defaults?.string(forKey: WidgetShared.pomodoroPhaseKey) ?? PomodoroWidgetPhase.stopped.rawValue
        let phase = PomodoroWidgetPhase(rawValue: raw) ?? .stopped

        let startTS = defaults?.double(forKey: WidgetShared.pomodoroStartKey) ?? 0
        let endTS = defaults?.double(forKey: WidgetShared.pomodoroEndKey) ?? 0

        let start = startTS > 0 ? Date(timeIntervalSince1970: startTS) : nil
        let end = endTS > 0 ? Date(timeIntervalSince1970: endTS) : nil
        let round = defaults?.integer(forKey: WidgetShared.pomodoroRoundKey) ?? 0

        return PomodoroStatusEntry(date: .now, phase: phase, start: start, end: end, round: max(round, 0))
    }

    private func nextRefresh(for entry: PomodoroStatusEntry) -> Date {
        switch entry.phase {
        case .focus, .shortBreak, .longBreak:
            return Date().addingTimeInterval(60)
        case .paused:
            return Date().addingTimeInterval(5 * 60)
        case .stopped:
            return Date().addingTimeInterval(20 * 60)
        }
    }
}

struct PomodoroStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PomodoroStatusProvider.Entry

    private var hasActiveTimer: Bool {
        guard entry.end != nil else { return false }
        return entry.phase == .focus || entry.phase == .shortBreak || entry.phase == .longBreak
    }

    private var progress: Double {
        guard let start = entry.start, let end = entry.end else { return 0 }
        let total = max(end.timeIntervalSince(start), 1)
        let done = max(Date().timeIntervalSince(start), 0)
        return min(max(done / total, 0), 1)
    }

    var body: some View {
        WidgetSurface(accent: entry.phase.accent, blurAccent: entry.phase.glow.opacity(0.45)) {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar

            Text(entry.phase.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            timerText(fontSize: 24)

            progressBar(maxWidth: 120)
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                topBar

                Text(entry.phase.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                timerText(fontSize: 28)

                Text(entry.phase.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)

                progressBar(maxWidth: 132)
            }

            Spacer(minLength: 0)

            PomodoroProgressRing(progress: progress, accent: entry.phase.accent, round: entry.round)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.phase.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(entry.phase.accent.opacity(0.38), in: Circle())

            Text("POMODORO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.7)

            Spacer(minLength: 0)

            Text("Раунд \(entry.round)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(entry.phase.accent.opacity(0.4), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func timerText(fontSize: CGFloat) -> some View {
        if let end = entry.end, hasActiveTimer {
            Text(timerInterval: Date()...end, countsDown: true)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        } else if entry.phase == .paused {
            Text("На паузе")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        } else {
            Text("Готов к старту")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
        }
    }

    private func progressBar(maxWidth: CGFloat?) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.white.opacity(0.16))
                .frame(height: 8)

            Capsule()
                .fill(entry.phase.accent)
                .frame(width: fillWidth(maxWidth: maxWidth), height: 8)
        }
        .frame(maxWidth: maxWidth, maxHeight: 8)
    }

    private func fillWidth(maxWidth: CGFloat?) -> CGFloat {
        let base = maxWidth ?? 140
        return max(10, base * CGFloat(progress))
    }
}

private struct PomodoroProgressRing: View {
    let progress: Double
    let accent: Color
    let round: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(progress, 0.02))
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.45), accent, accent.opacity(0.45)], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(round)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("раунд")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(width: 84, height: 84)
    }
}

struct PomodoroStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PomodoroStatusWidget", provider: PomodoroStatusProvider()) { entry in
            PomodoroStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Pomodoro")
        .description("Фаза фокуса, таймер и текущий раунд.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(false)
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
