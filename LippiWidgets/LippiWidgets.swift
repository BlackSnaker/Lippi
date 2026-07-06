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
        VStack(alignment: .leading, spacing: 9) {
            topBar

            if let title = entry.title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.74)

                dueLine
            } else {
                Spacer(minLength: 0)
                Text("План чист")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Можно запланировать новую цель")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
        }
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                topBar

                if let title = entry.title {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.68)
                } else {
                    Text("Сегодня нет срочных задач")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                    Text("Открой Lippi и запланируй следующий шаг")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            duePanel
                .frame(width: 128)
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    urgency.glow.opacity(0.68),
                                    urgency.accent.opacity(0.44),
                                    .white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(Circle().stroke(.white.opacity(0.34), lineWidth: 1))
                .shadow(color: urgency.glow.opacity(0.20), radius: 8, x: 0, y: 4)

            Text("LIPPI")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(0.7)
                .lineLimit(1)

            Spacer(minLength: 0)

            if family == .systemSmall {
                urgencyBadge
            } else {
                statusDot
            }
        }
    }

    private var dueLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
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
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                } else {
                    Text("Без дедлайна")
                        .font(.caption.weight(.semibold))
                }
            }

            HStack(spacing: 5) {
                Image(systemName: urgency.icon)
                    .font(.caption.weight(.semibold))
                if let due = entry.due {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("Без срока")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .foregroundStyle(.white.opacity(0.86))
    }

    private var duePanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let due = entry.due {
                Text(due, format: .dateTime.hour().minute())
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text(due, style: .relative)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Text("Без срока")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }

            urgencyBadge
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .widgetGlassPanel(RoundedRectangle(cornerRadius: 15, style: .continuous), accent: urgency.accent)
    }

    private var urgencyBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: urgency.icon)
                .font(.caption2.weight(.bold))
            Text(urgency.title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .widgetGlassPanel(Capsule(), accent: urgency.accent, intensity: 0.20)
    }

    private var statusDot: some View {
        Circle()
            .fill(urgency.accent)
            .frame(width: 7, height: 7)
            .shadow(color: urgency.glow.opacity(0.45), radius: 5, x: 0, y: 0)
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
        .contentMarginsDisabled()
    }
}

// MARK: - Shared widget visuals
struct WidgetSurface<Content: View>: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    @Environment(\.widgetFamily) private var family
    let accent: Color
    let blurAccent: Color
    @ViewBuilder var content: Content

    private var needsContrastFallback: Bool {
        widgetRenderingMode != .fullColor || !showsWidgetContainerBackground
    }

    private var shellShape: ContainerRelativeShape {
        ContainerRelativeShape()
    }

    private var contentPadding: CGFloat {
        family == .systemSmall ? 12 : 14
    }

    var body: some View {
        ZStack {
            if needsContrastFallback {
                shellShape
                    .fill(Color.black.opacity(0.86))
            }

            shellShape
                .fill(Color(hex: 0x07111F))

            shellShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color(hex: 0xDDF7FF).opacity(0.12),
                            Color(hex: 0x0B1B34).opacity(0.78),
                            Color(hex: 0x060A15).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [blurAccent.opacity(needsContrastFallback ? 0.42 : 0.78), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 170
            )
            .blur(radius: 18)

            RadialGradient(
                colors: [accent.opacity(needsContrastFallback ? 0.22 : 0.42), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 210
            )
            .blur(radius: 24)

            shellShape
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.30),
                            .white.opacity(0.10),
                            .clear,
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.screen)

            WidgetLiquidRefraction(accent: accent, glow: blurAccent)
                .clipShape(shellShape)

            VStack { content }
                .padding(contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(
            shellShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.48),
                            .white.opacity(0.18),
                            accent.opacity(0.20),
                            .black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .topLeading) {
            shellShape
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 96, height: 96)
                .blur(radius: 24)
                .offset(x: 32, y: 32)
                .allowsHitTesting(false)
        }
        .clipShape(shellShape)
        .modifier(WidgetBackgroundModifier())
    }
}

private struct WidgetLiquidRefraction: View {
    let accent: Color
    let glow: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.30), glow.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 150, height: 42)
                .blur(radius: 18)
                .rotationEffect(.degrees(-18))
                .offset(x: -34, y: -42)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, accent.opacity(0.20), .white.opacity(0.18)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 190, height: 34)
                .blur(radius: 16)
                .rotationEffect(.degrees(-14))
                .offset(x: 54, y: 38)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear, accent.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(6)
        }
        .allowsHitTesting(false)
    }
}

private struct WidgetGlassPanelModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let accent: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.white.opacity(0.10 + intensity * 0.22))
                    .overlay {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.24),
                                        accent.opacity(intensity),
                                        .black.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.34), .white.opacity(0.12), accent.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func widgetGlassPanel<S: InsettableShape>(
        _ shape: S,
        accent: Color,
        intensity: Double = 0.14
    ) -> some View {
        modifier(WidgetGlassPanelModifier(shape: shape, accent: accent, intensity: intensity))
    }
}

private struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) {
                WidgetContainerBackdrop()
            }
        } else {
            content
        }
    }
}

private struct WidgetContainerBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: 0xEEF9FF).opacity(0.26),
                Color(hex: 0x273A5C).opacity(0.42),
                Color(hex: 0x07111F).opacity(0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
