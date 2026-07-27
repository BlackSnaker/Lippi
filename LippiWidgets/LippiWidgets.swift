import WidgetKit
import SwiftUI

// MARK: - Next task timeline

struct NextTaskEntry: TimelineEntry {
    let date: Date
    let title: String?
    let due: Date?
}

struct NextTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTaskEntry {
        .init(
            date: .now,
            title: "Подготовить главный шаг проекта",
            due: .now.addingTimeInterval(45 * 60)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTaskEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTaskEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(for: entry))))
    }

    private func loadEntry() -> NextTaskEntry {
        let defaults = UserDefaults(suiteName: WidgetShared.suiteID)
        let rawTitle = defaults?.string(forKey: WidgetShared.titleKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle?.isEmpty == false ? rawTitle : nil
        let timestamp = defaults?.double(forKey: WidgetShared.dueKey) ?? 0

        return .init(
            date: .now,
            title: title,
            due: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        )
    }

    private func nextRefresh(for entry: NextTaskEntry) -> Date {
        guard let due = entry.due else { return .now.addingTimeInterval(30 * 60) }
        if due <= .now { return .now.addingTimeInterval(10 * 60) }
        return .now.addingTimeInterval(due.timeIntervalSinceNow < 2 * 60 * 60 ? 5 * 60 : 20 * 60)
    }
}

private enum NextTaskTone {
    case clear
    case overdue
    case today
    case later

    init(due: Date?) {
        guard let due else { self = .clear; return }
        if due < .now { self = .overdue }
        else if Calendar.current.isDateInToday(due) { self = .today }
        else { self = .later }
    }

    var label: String {
        switch self {
        case .clear: "Свободный ритм"
        case .overdue: "Требует внимания"
        case .today: "Сегодня"
        case .later: "В плане"
        }
    }

    var icon: String {
        switch self {
        case .clear: "checkmark"
        case .overdue: "exclamationmark"
        case .today: "clock.fill"
        case .later: "calendar"
        }
    }

    var accent: Color {
        switch self {
        case .clear: Color(hex: 0x48D597)
        case .overdue: Color(hex: 0xFF6B72)
        case .today: Color(hex: 0xFFB44A)
        case .later: Color(hex: 0x5CB8FF)
        }
    }
}

struct NextTaskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextTaskEntry

    private var tone: NextTaskTone { NextTaskTone(due: entry.due) }
    private var taskTitle: String { entry.title ?? "План на сегодня свободен" }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineLayout
        case .accessoryCircular:
            circularLayout
        case .accessoryRectangular:
            rectangularLayout
        case .systemMedium:
            WidgetSurface(accent: tone.accent) { mediumLayout }
        default:
            WidgetSurface(accent: tone.accent) { smallLayout }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetBrandMark(section: "Следующий шаг", symbol: "arrow.up.right")

            Spacer(minLength: 10)

            Text(taskTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            dueFooter
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetBrandMark(section: "Следующий шаг", symbol: "arrow.up.right")

                Spacer(minLength: 10)

                Text(taskTitle)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)

                Text(entry.title == nil ? "Можно выбрать новое важное" : tone.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tone.accent.opacity(0.14))
                    Circle()
                        .stroke(tone.accent.opacity(0.34), lineWidth: 1)
                    Image(systemName: tone.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(tone.accent)
                }
                .frame(width: 48, height: 48)
                .widgetAccentable()

                if let due = entry.due {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(due, style: .relative)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(1)
                } else {
                    Text("без срока")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .frame(width: 102, alignment: .trailing)
        }
    }

    private var dueFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: tone.icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tone.accent)
                .widgetAccentable()

            if let due = entry.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("·")
                    .foregroundStyle(.white.opacity(0.34))
                Text(due, style: .relative)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            } else {
                Text("Можно добавить новый шаг")
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private var inlineLayout: some View {
        Label {
            if let due = entry.due {
                Text("\(taskTitle) · \(due, format: .dateTime.hour().minute())")
            } else {
                Text(taskTitle)
            }
        } icon: {
            Image(systemName: tone.icon)
        }
    }

    private var circularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: entry.title == nil ? "checkmark" : tone.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .widgetAccentable()
                if let due = entry.due {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                } else {
                    Text("Lippi")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    private var rectangularLayout: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: tone.icon)
                    .widgetAccentable()
                Text(tone.label)
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 0)
                if let due = entry.due {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
            Text(taskTitle)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }
}

struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextTaskWidget", provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
                .widgetURL(URL(string: "lippi://tasks"))
        }
        .configurationDisplayName("Следующий шаг")
        .description("Главная задача — спокойно и без лишнего шума.")
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

// MARK: - Shared Lippi widget design system

struct WidgetSurface<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetFamily) private var family

    let accent: Color
    let blurAccent: Color
    let content: Content

    init(
        accent: Color,
        blurAccent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.blurAccent = blurAccent ?? accent
        self.content = content()
    }

    private var padding: CGFloat { family == .systemSmall ? 14 : 16 }
    private var usesFullColor: Bool { renderingMode == .fullColor && showsBackground }

    var body: some View {
        ZStack {
            if usesFullColor {
                LinearGradient(
                    colors: [Color(hex: 0x111B2D), Color(hex: 0x09111F)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(blurAccent.opacity(0.16))
                    .frame(width: family == .systemSmall ? 124 : 190)
                    .blur(radius: 28)
                    .offset(x: family == .systemSmall ? 62 : 132, y: -58)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.10), .clear],
                            startPoint: .bottomTrailing,
                            endPoint: .center
                        )
                    )
            }

            content
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(ContainerRelativeShape())
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: 0x111B2D), Color(hex: 0x09111F)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct WidgetBrandMark: View {
    let section: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: 0x65BFFF))
                .widgetAccentable()
            Text("Lippi")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Text("·")
                .foregroundStyle(.white.opacity(0.28))
            Text(section)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.42))
        }
    }
}

private struct WidgetPanelModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let accent: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background(shape.fill(accent.opacity(0.08 + intensity * 0.20)))
            .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.75))
    }
}

extension View {
    func widgetGlassPanel<S: InsettableShape>(
        _ shape: S,
        accent: Color,
        intensity: Double = 0.14
    ) -> some View {
        modifier(WidgetPanelModifier(shape: shape, accent: accent, intensity: intensity))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
