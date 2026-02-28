import WidgetKit
import SwiftUI

// MARK: - Next Task Timeline
struct NextTaskEntry: TimelineEntry {
    let date: Date
    let title: String?
    let due: Date?
}

struct NextTaskProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTaskEntry {
        .init(date: .now, title: "Сфокусироваться на главной задаче", due: .now.addingTimeInterval(45 * 60))
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
        let rawTitle = defaults?.string(forKey: WidgetShared.titleKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (rawTitle?.isEmpty == false) ? rawTitle : nil

        let dueTimestamp = defaults?.double(forKey: WidgetShared.dueKey) ?? 0
        let due = dueTimestamp > 0 ? Date(timeIntervalSince1970: dueTimestamp) : nil

        return NextTaskEntry(date: .now, title: title, due: due)
    }

    private func nextRefresh(for entry: NextTaskEntry) -> Date {
        guard let due = entry.due else { return Date().addingTimeInterval(30 * 60) }

        let now = Date()
        if due <= now { return now.addingTimeInterval(10 * 60) }
        if due.timeIntervalSince(now) <= 2 * 60 * 60 {
            return now.addingTimeInterval(5 * 60)
        }

        return now.addingTimeInterval(20 * 60)
    }
}

private enum TaskUrgencyStyle {
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
        case .none: return Color(hex: 0x34C759)
        case .overdue: return Color(hex: 0xFF453A)
        case .today: return Color(hex: 0xFF9F0A)
        case .upcoming: return Color(hex: 0x64D2FF)
        }
    }

    var glow: Color {
        switch self {
        case .none: return Color(hex: 0x7DFFB0)
        case .overdue: return Color(hex: 0xFF7A70)
        case .today: return Color(hex: 0xFFC06A)
        case .upcoming: return Color(hex: 0x9BE7FF)
        }
    }
}

struct NextTaskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NextTaskProvider.Entry

    private var urgency: TaskUrgencyStyle {
        guard let due = entry.due else { return .none }
        if due < .now { return .overdue }
        if Calendar.current.isDateInToday(due) { return .today }
        return .upcoming
    }

    var body: some View {
        WidgetSurface(accent: urgency.accent, blurAccent: urgency.glow.opacity(0.48)) {
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

            if let title = entry.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.84)

                dueLine
            } else {
                Spacer(minLength: 0)
                Text("План чист")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Можно запланировать новую цель")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                topBar

                if let title = entry.title {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    dueLine
                } else {
                    Text("Сегодня нет срочных задач")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("Открой Lippi и запланируй следующий шаг")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            duePanel
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(urgency.accent.opacity(0.42), in: Circle())

            Text("LIPPI")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.7)

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

    private var duePanel: some View {
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
                .stroke(.white.opacity(0.16), lineWidth: 1)
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
        .background(urgency.accent.opacity(0.45), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextTaskWidget", provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
        }
        .configurationDisplayName("Следующая задача")
        .description("Показывает ближайшую задачу и её дедлайн.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(false)
    }
}

// MARK: - Shared widget visuals
struct WidgetSurface<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    let accent: Color
    let blurAccent: Color
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

            RadialGradient(
                colors: [blurAccent, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 150
            )
            .blur(radius: 14)

            RadialGradient(
                colors: [accent.opacity(0.26), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 190
            )
            .blur(radius: 20)

            VStack { content }
                .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(WidgetBackgroundModifier())
    }
}

private struct WidgetBackgroundModifier: ViewModifier {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    private var fallbackBackgroundColor: Color {
        (widgetRenderingMode == .fullColor && showsWidgetContainerBackground)
            ? .clear
            : Color.black.opacity(0.72)
    }

    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                fallbackBackgroundColor
            }
        } else {
            content
        }
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
