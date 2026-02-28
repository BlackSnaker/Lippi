import WidgetKit
import SwiftUI

private enum WG {
    static let suiteID = "group.illumionix.lippi"
    static let titleKey = "nextTaskTitle"
    static let dueKey = "nextTaskDue"
}

private enum OrganizerUrgency {
    case none
    case overdue
    case today
    case upcoming

    var title: String {
        switch self {
        case .none: return "Свободно"
        case .overdue: return "Просрочено"
        case .today: return "Сегодня"
        case .upcoming: return "Запланировано"
        }
    }

    var icon: String {
        switch self {
        case .none: return "sparkles"
        case .overdue: return "exclamationmark.triangle.fill"
        case .today: return "clock.fill"
        case .upcoming: return "calendar"
        }
    }

    var accent: Color {
        switch self {
        case .none: return Color(hex: 0x30D158)
        case .overdue: return Color(hex: 0xFF453A)
        case .today: return Color(hex: 0xFF9F0A)
        case .upcoming: return Color(hex: 0x64D2FF)
        }
    }

    var glow: Color {
        switch self {
        case .none: return Color(hex: 0x7EF7AD)
        case .overdue: return Color(hex: 0xFF7A70)
        case .today: return Color(hex: 0xFFC06A)
        case .upcoming: return Color(hex: 0x9BE7FF)
        }
    }
}

struct OrganizerEntry: TimelineEntry {
    let date: Date
    let title: String
    let due: Date?
}

struct OrganizerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OrganizerEntry {
        OrganizerEntry(date: .now, title: "Следующая задача", due: .now.addingTimeInterval(45 * 60))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OrganizerEntry {
        loadEntry()
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OrganizerEntry> {
        let entry = loadEntry()
        return Timeline(entries: [entry], policy: .after(nextRefresh(for: entry)))
    }

    private func loadEntry() -> OrganizerEntry {
        let defaults = UserDefaults(suiteName: WG.suiteID)
        let title = defaults?.string(forKey: WG.titleKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = (title?.isEmpty == false) ? title! : "Нет активных задач"

        let dueTimestamp = defaults?.double(forKey: WG.dueKey) ?? 0
        let due = dueTimestamp > 0 ? Date(timeIntervalSince1970: dueTimestamp) : nil

        return OrganizerEntry(date: .now, title: safeTitle, due: due)
    }

    private func nextRefresh(for entry: OrganizerEntry) -> Date {
        guard let due = entry.due else { return Date().addingTimeInterval(30 * 60) }

        let now = Date()
        if due <= now { return now.addingTimeInterval(10 * 60) }
        if due.timeIntervalSince(now) <= 2 * 60 * 60 {
            return now.addingTimeInterval(5 * 60)
        }

        return now.addingTimeInterval(20 * 60)
    }
}

struct OrganizerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OrganizerEntry

    private var urgency: OrganizerUrgency {
        guard let due = entry.due else { return .none }
        if due < .now { return .overdue }
        if Calendar.current.isDateInToday(due) { return .today }
        return .upcoming
    }

    var body: some View {
        OrganizerWidgetSurface(accent: urgency.accent, glow: urgency.glow) {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .applyWidgetBackground()
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            topBar

            Text(entry.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.84)

            dueLine
        }
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                topBar

                Text(entry.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                dueLine

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            rightPanel
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(urgency.accent.opacity(0.42), in: Circle())

            Text("ОРГАНАЙЗЕР")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.6)

            Spacer(minLength: 0)

            urgencyBadge
        }
    }

    private var dueLine: some View {
        HStack(spacing: 6) {
            Image(systemName: urgency.icon)
                .font(.caption.weight(.semibold))

            if let due = entry.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
                Text(due, style: .relative)
                    .font(.caption)
            } else {
                Text("Без дедлайна")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.white.opacity(0.86))
    }

    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let due = entry.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(due, style: .relative)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            } else {
                Text("Без срока")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }

            urgencyBadge
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var urgencyBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: urgency.icon)
                .font(.caption2.weight(.bold))
            Text(urgency.title)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(urgency.accent.opacity(0.42), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct OrganizerWidget: Widget {
    let kind: String = "OrganizerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: OrganizerProvider()) { entry in
            OrganizerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Органайзер")
        .description("Показывает ближайшую задачу и её срок.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(false)
    }
}

#Preview(as: .systemSmall) {
    OrganizerWidget()
} timeline: {
    OrganizerEntry(date: .now, title: "Подготовить презентацию", due: .now.addingTimeInterval(35 * 60))
}

#Preview(as: .systemMedium) {
    OrganizerWidget()
} timeline: {
    OrganizerEntry(date: .now, title: "Сверстать и отправить отчёт", due: .now.addingTimeInterval(115 * 60))
}

private struct OrganizerWidgetSurface<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    let accent: Color
    let glow: Color
    @ViewBuilder var content: Content

    private var needsContrastFallback: Bool {
        widgetRenderingMode != .fullColor || !showsWidgetContainerBackground
    }

    var body: some View {
        ZStack {
            if needsContrastFallback {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            }

            LinearGradient(
                colors: [Color(hex: 0x0B101B), Color(hex: 0x121A2A), Color(hex: 0x1A253A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(colors: [glow.opacity(0.42), .clear], center: .topLeading, startRadius: 0, endRadius: 150)
                .blur(radius: 14)

            RadialGradient(colors: [accent.opacity(0.24), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 180)
                .blur(radius: 20)

            content
                .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center)
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension View {
    @ViewBuilder
    func widgetContainerBackgroundForVisibility() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            modifier(WidgetContainerBackgroundModifier())
        } else {
            self
        }
    }

    @ViewBuilder
    func applyWidgetBackground() -> some View {
        widgetContainerBackgroundForVisibility()
    }
}

private struct WidgetContainerBackgroundModifier: ViewModifier {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    private var fallbackBackgroundColor: Color {
        (widgetRenderingMode == .fullColor && showsWidgetContainerBackground)
            ? .clear
            : Color.black.opacity(0.72)
    }

    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) {
            fallbackBackgroundColor
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
