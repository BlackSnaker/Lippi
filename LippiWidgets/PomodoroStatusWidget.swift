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
        case .focus: "Фокус"
        case .shortBreak: "Короткий отдых"
        case .longBreak: "Восстановление"
        case .paused: "Пауза"
        case .stopped: "Готов к фокусу"
        }
    }

    var subtitle: String {
        switch self {
        case .focus: "Оставьте только важное"
        case .shortBreak: "Дайте вниманию выдохнуть"
        case .longBreak: "Время восстановить силы"
        case .paused: "Продолжите, когда будете готовы"
        case .stopped: "Начните с одного спокойного шага"
        }
    }

    var icon: String {
        switch self {
        case .focus: "scope"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "leaf.fill"
        case .paused: "pause.fill"
        case .stopped: "play.fill"
        }
    }

    var accent: Color {
        switch self {
        case .focus: Color(hex: 0x55B8FF)
        case .shortBreak: Color(hex: 0x54D79A)
        case .longBreak: Color(hex: 0x70D9C9)
        case .paused: Color(hex: 0xFFB44A)
        case .stopped: Color(hex: 0x93A3BC)
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
        .init(date: .now, phase: .focus, start: .now, end: .now.addingTimeInterval(25 * 60), round: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroStatusEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroStatusEntry>) -> Void) {
        let entry = loadEntry()
        let interval: TimeInterval = entry.isActive ? 60 : (entry.phase == .paused ? 5 * 60 : 20 * 60)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(interval))))
    }

    private func loadEntry() -> PomodoroStatusEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.suiteID)
        let rawPhase = defaults?.string(forKey: WidgetShared.pomodoroPhaseKey) ?? PomodoroWidgetPhase.stopped.rawValue
        let start = defaults?.double(forKey: WidgetShared.pomodoroStartKey) ?? 0
        let end = defaults?.double(forKey: WidgetShared.pomodoroEndKey) ?? 0

        return .init(
            date: .now,
            phase: PomodoroWidgetPhase(rawValue: rawPhase) ?? .stopped,
            start: start > 0 ? Date(timeIntervalSince1970: start) : nil,
            end: end > 0 ? Date(timeIntervalSince1970: end) : nil,
            round: max(defaults?.integer(forKey: WidgetShared.pomodoroRoundKey) ?? 0, 0)
        )
    }
}

private extension PomodoroStatusEntry {
    var isActive: Bool {
        guard let end, end > date else { return false }
        return phase == .focus || phase == .shortBreak || phase == .longBreak
    }

    var progress: Double {
        guard let start, let end else { return 0 }
        let total = max(end.timeIntervalSince(start), 1)
        return min(max(date.timeIntervalSince(start) / total, 0), 1)
    }
}

struct PomodoroStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PomodoroStatusEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineLayout
        case .accessoryCircular:
            circularLayout
        case .accessoryRectangular:
            rectangularLayout
        case .systemMedium:
            WidgetSurface(accent: entry.phase.accent) { mediumLayout }
        default:
            WidgetSurface(accent: entry.phase.accent) { smallLayout }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetBrandMark(section: entry.phase.title, symbol: entry.phase.icon)

            Spacer(minLength: 8)

            timer(fontSize: 31)

            Text(entry.phase.subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                progressLine
                roundLabel
            }
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetBrandMark(section: "Ритм внимания", symbol: entry.phase.icon)

                Spacer(minLength: 7)

                Text(entry.phase.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.phase.accent)
                    .widgetAccentable()

                timer(fontSize: 36)

                Text(entry.phase.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            focusRing
                .frame(width: 88, height: 88)
        }
    }

    @ViewBuilder
    private func timer(fontSize: CGFloat) -> some View {
        if entry.isActive, let end = entry.end {
            Text(timerInterval: entry.date...end, countsDown: true)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        } else if entry.phase == .paused {
            Text("На паузе")
                .font(.system(size: fontSize * 0.66, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        } else {
            Text("25:00")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var progressLine: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(entry.phase.accent)
                    .frame(width: max(5, proxy.size.width * entry.progress))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
    }

    private var roundLabel: some View {
        Text(entry.round > 0 ? "R\(entry.round)" : "START")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.62))
    }

    private var focusRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(entry.progress, entry.isActive ? 0.025 : 0))
                .stroke(entry.phase.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: 2) {
                Image(systemName: entry.phase.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(entry.phase.accent)
                    .widgetAccentable()
                Text(entry.round > 0 ? "раунд \(entry.round)" : "начать")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
    }

    private var inlineLayout: some View {
        Label {
            if entry.isActive, let end = entry.end {
                Text(timerInterval: entry.date...end, countsDown: true)
            } else {
                Text(entry.phase.title)
            }
        } icon: {
            Image(systemName: entry.phase.icon)
        }
    }

    private var circularLayout: some View {
        Gauge(value: entry.progress) {
            Image(systemName: entry.phase.icon)
                .widgetAccentable()
        } currentValueLabel: {
            if entry.isActive, let end = entry.end {
                Text(timerInterval: entry.date...end, countsDown: true)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            } else {
                Image(systemName: entry.phase.icon)
                    .font(.caption.weight(.bold))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangularLayout: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: entry.phase.icon)
                    .widgetAccentable()
                Text(entry.phase.title)
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 0)
                if entry.round > 0 {
                    Text("Раунд \(entry.round)")
                        .font(.caption2.weight(.medium))
                }
            }
            HStack(alignment: .lastTextBaseline) {
                timer(fontSize: 22)
                Spacer(minLength: 5)
                Image(systemName: entry.isActive ? "chevron.right" : "play.fill")
                    .font(.caption.weight(.bold))
                    .widgetAccentable()
            }
        }
    }
}

struct PomodoroStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PomodoroStatusWidget", provider: PomodoroStatusProvider()) { entry in
            PomodoroStatusWidgetView(entry: entry)
                .widgetURL(URL(string: "lippi://pomodoro"))
        }
        .configurationDisplayName("Фокус Lippi")
        .description("Текущий ритм фокуса и отдыха одним взглядом.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
        .contentMarginsDisabled()
    }
}
