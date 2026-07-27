import WidgetKit
import SwiftUI

private enum OrganizerStorage {
    static let suiteID = "group.illumionix.lippi"
    static let titleKey = "nextTaskTitle"
    static let dueKey = "nextTaskDue"
}

private enum OrganizerTone {
    case clear
    case overdue
    case today
    case later

    init(due: Date?, hasTask: Bool) {
        guard hasTask else { self = .clear; return }
        guard let due else { self = .later; return }
        if due < .now { self = .overdue }
        else if Calendar.current.isDateInToday(due) { self = .today }
        else { self = .later }
    }

    var title: String {
        switch self {
        case .clear: "Всё спокойно"
        case .overdue: "Требует внимания"
        case .today: "Сегодня"
        case .later: "Следующий шаг"
        }
    }

    var icon: String {
        switch self {
        case .clear: "checkmark"
        case .overdue: "exclamationmark"
        case .today: "clock.fill"
        case .later: "arrow.up.right"
        }
    }

    var accent: Color {
        switch self {
        case .clear: Color(hex: 0x4BD79A)
        case .overdue: Color(hex: 0xFF6B72)
        case .today: Color(hex: 0xFFB44A)
        case .later: Color(hex: 0x61BCFF)
        }
    }
}

struct OrganizerEntry: TimelineEntry {
    let date: Date
    let title: String
    let due: Date?
    let hasTask: Bool
    let emoji: String
}

struct OrganizerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OrganizerEntry {
        .init(
            date: .now,
            title: "Подготовить презентацию",
            due: .now.addingTimeInterval(45 * 60),
            hasTask: true,
            emoji: "📌"
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OrganizerEntry {
        loadEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OrganizerEntry> {
        let entry = loadEntry(configuration: configuration)
        return Timeline(entries: [entry], policy: .after(nextRefresh(for: entry)))
    }

    private func loadEntry(configuration: ConfigurationAppIntent) -> OrganizerEntry {
        let defaults = UserDefaults(suiteName: OrganizerStorage.suiteID)
        let rawTitle = defaults?.string(forKey: OrganizerStorage.titleKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTask = rawTitle?.isEmpty == false
        let timestamp = defaults?.double(forKey: OrganizerStorage.dueKey) ?? 0
        let emoji = configuration.favoriteEmoji.trimmingCharacters(in: .whitespacesAndNewlines)

        return .init(
            date: .now,
            title: hasTask ? rawTitle! : "План на сегодня завершён",
            due: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil,
            hasTask: hasTask,
            emoji: emoji.isEmpty ? "📌" : emoji
        )
    }

    private func nextRefresh(for entry: OrganizerEntry) -> Date {
        guard let due = entry.due else { return .now.addingTimeInterval(30 * 60) }
        if due <= .now { return .now.addingTimeInterval(10 * 60) }
        return .now.addingTimeInterval(due.timeIntervalSinceNow < 2 * 60 * 60 ? 5 * 60 : 20 * 60)
    }
}

struct OrganizerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OrganizerEntry

    private var tone: OrganizerTone { .init(due: entry.due, hasTask: entry.hasTask) }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineLayout
        case .accessoryCircular:
            circularLayout
        case .accessoryRectangular:
            rectangularLayout
        case .systemMedium:
            OrganizerSurface(accent: tone.accent) { mediumLayout }
        default:
            OrganizerSurface(accent: tone.accent) { smallLayout }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 9)

            Text(entry.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            dueLine
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 9)

                Text(entry.title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)

                Text(entry.hasTask ? "Сделайте одно важное — остальное подождёт" : "Можно спокойно выбрать следующий шаг")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Text(entry.emoji)
                    .font(.system(size: 31))
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tone.accent.opacity(0.13))
                    )

                if let due = entry.due, entry.hasTask {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(due, style: .relative)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                } else {
                    Text(entry.hasTask ? "без срока" : "готово")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(width: 104, alignment: .trailing)
        }
    }

    private var header: some View {
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
            Text("План дня")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
            Spacer(minLength: 0)
            Image(systemName: tone.icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tone.accent)
                .widgetAccentable()
        }
    }

    private var dueLine: some View {
        HStack(spacing: 6) {
            Image(systemName: tone.icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tone.accent)
                .widgetAccentable()
            Text(tone.title)
                .font(.caption.weight(.medium))
            if let due = entry.due, entry.hasTask {
                Text("·")
                    .foregroundStyle(.white.opacity(0.32))
                Text(due, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white.opacity(0.68))
    }

    private var inlineLayout: some View {
        Label {
            if let due = entry.due, entry.hasTask {
                Text("\(entry.title) · \(due, format: .dateTime.hour().minute())")
            } else {
                Text(entry.title)
            }
        } icon: {
            Image(systemName: tone.icon)
        }
    }

    private var circularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.emoji)
                    .font(.system(size: 16))
                if let due = entry.due, entry.hasTask {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Image(systemName: tone.icon)
                        .font(.caption2.weight(.bold))
                        .widgetAccentable()
                }
            }
        }
    }

    private var rectangularLayout: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(entry.emoji)
                    .font(.caption)
                Text(tone.title)
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 0)
                if let due = entry.due, entry.hasTask {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
            Text(entry.title)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }
}

struct OrganizerWidget: Widget {
    let kind = "OrganizerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: OrganizerProvider()
        ) { entry in
            OrganizerWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "lippi://tasks"))
        }
        .configurationDisplayName("План дня")
        .description("Ближайшая задача в спокойном и ясном формате.")
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

#Preview(as: .systemSmall) {
    OrganizerWidget()
} timeline: {
    OrganizerEntry(
        date: .now,
        title: "Подготовить презентацию",
        due: .now.addingTimeInterval(35 * 60),
        hasTask: true,
        emoji: "📌"
    )
}

#Preview(as: .accessoryRectangular) {
    OrganizerWidget()
} timeline: {
    OrganizerEntry(
        date: .now,
        title: "Сверстать и отправить отчёт",
        due: .now.addingTimeInterval(115 * 60),
        hasTask: true,
        emoji: "✨"
    )
}

private struct OrganizerSurface<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetFamily) private var family

    let accent: Color
    let content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    private var padding: CGFloat { family == .systemSmall ? 14 : 16 }
    private var fullColor: Bool { renderingMode == .fullColor && showsBackground }

    var body: some View {
        ZStack {
            if fullColor {
                LinearGradient(
                    colors: [Color(hex: 0x111B2D), Color(hex: 0x09111F)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: family == .systemSmall ? 130 : 190)
                    .blur(radius: 30)
                    .offset(x: family == .systemSmall ? 64 : 135, y: -60)
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

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
