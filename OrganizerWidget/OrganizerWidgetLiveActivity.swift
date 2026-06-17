import ActivityKit
import WidgetKit
import SwiftUI

struct OrganizerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskTitle: String
        var categoryTitle: String
        var categorySymbol: String
        var startDate: Date
        var dueDate: Date?
        var isCompleted: Bool
    }

    var taskId: UUID
}

struct OrganizerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrganizerAttributes.self) { context in
            OrganizerLiveLockScreenView(context: context)
                .activityBackgroundTint(Color(hex: 0x06101D))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(OrganizerIslandLink.openTasks.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    OrganizerIslandTaskBadge(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    OrganizerIslandDueBadge(state: context.state, compact: false)
                }

                DynamicIslandExpandedRegion(.center) {
                    OrganizerIslandHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    OrganizerIslandGlassPanel(accent: OrganizerIslandCopy.accent(for: context.state)) {
                        OrganizerIslandProgress(state: context.state)

                        HStack(spacing: 8) {
                            OrganizerIslandActionLink(.openTasks)
                            OrganizerIslandActionLink(.complete(taskId: context.attributes.taskId))
                            OrganizerIslandActionLink(.focus)
                        }
                    }
                }
            } compactLeading: {
                OrganizerIslandCompactOrb(state: context.state)
            } compactTrailing: {
                OrganizerIslandDueBadge(state: context.state, compact: true)
            } minimal: {
                OrganizerIslandCompactOrb(state: context.state, minimal: true)
            }
            .widgetURL(OrganizerIslandLink.openTasks.url)
            .keylineTint(OrganizerIslandCopy.accent(for: context.state))
        }
    }
}

private struct OrganizerLiveLockScreenView: View {
    let context: ActivityViewContext<OrganizerAttributes>

    var body: some View {
        HStack(spacing: 12) {
            OrganizerIslandTaskBadge(state: context.state)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.taskTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Label(context.state.categoryTitle, systemImage: context.state.categorySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            OrganizerIslandDueBadge(state: context.state, compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(OrganizerIslandBackdrop(accent: OrganizerIslandCopy.accent(for: context.state)))
    }
}

private struct OrganizerIslandHeader: View {
    let state: OrganizerAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("Lippi")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    Circle()
                        .fill(OrganizerIslandCopy.accent(for: state))
                        .frame(width: 4, height: 4)

                    Text(OrganizerIslandCopy.status(for: state))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(OrganizerIslandCopy.accent(for: state))
                        .lineLimit(1)
                }

                Text(state.taskTitle)
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
                            OrganizerIslandCopy.accent(for: state).opacity(0.12),
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

private struct OrganizerIslandTaskBadge: View {
    let state: OrganizerAttributes.ContentState

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24),
                            OrganizerIslandCopy.accent(for: state).opacity(0.36),
                            OrganizerIslandCopy.accent(for: state).opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .shadow(color: OrganizerIslandCopy.accent(for: state).opacity(0.30), radius: 8, x: 0, y: 3)

            Circle()
                .stroke(.white.opacity(0.30), lineWidth: 1)
                .frame(width: 42, height: 42)

            Circle()
                .fill(.white.opacity(0.34))
                .frame(width: 12, height: 12)
                .offset(x: -9, y: -10)
                .blur(radius: 0.3)

            Image(systemName: state.isCompleted ? "checkmark.circle.fill" : state.categorySymbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct OrganizerIslandCompactOrb: View {
    let state: OrganizerAttributes.ContentState
    var minimal = false

    var body: some View {
        ZStack {
            Circle()
                .fill(OrganizerIslandCopy.accent(for: state).opacity(0.24))
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.28), OrganizerIslandCopy.accent(for: state).opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(minimal ? 3 : 2)
            Image(systemName: state.isCompleted ? "checkmark.circle.fill" : state.categorySymbol)
                .font(.system(size: minimal ? 9 : 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: minimal ? 18 : 22, height: minimal ? 18 : 22)
    }
}

private struct OrganizerIslandDueBadge: View {
    let state: OrganizerAttributes.ContentState
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 0 : 5) {
            if state.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(compact ? .caption.weight(.bold) : .title3.weight(.bold))
                    .foregroundStyle(Color(hex: 0x30D158))
            } else if let due = state.dueDate {
                VStack(alignment: .trailing, spacing: compact ? 0 : 2) {
                    Text(due, format: .dateTime.hour().minute())
                        .font(compact ? .caption2.weight(.bold) : .system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !compact {
                        Text(due, style: .relative)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(OrganizerIslandCopy.accent(for: state))
                            .lineLimit(1)
                    }
                }
            } else {
                if !compact {
                    Text("без срока")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Image(systemName: "sparkles")
                    .font(compact ? .caption.weight(.bold) : .title3.weight(.bold))
                    .foregroundStyle(OrganizerIslandCopy.accent(for: state))
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
        .frame(minWidth: compact ? 26 : 58, alignment: .trailing)
    }
}

private struct OrganizerIslandProgress: View {
    let state: OrganizerAttributes.ContentState

    private var progress: Double {
        guard !state.isCompleted else { return 1 }
        guard let due = state.dueDate else { return 0 }
        let total = max(due.timeIntervalSince(state.startDate), 1)
        let done = max(Date().timeIntervalSince(state.startDate), 0)
        return min(max(done / total, 0), 1)
    }

    var body: some View {
        HStack(spacing: 8) {
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
                                    OrganizerIslandCopy.accent(for: state),
                                    Color(hex: 0x64D2FF)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width)
                        .shadow(color: OrganizerIslandCopy.accent(for: state).opacity(0.45), radius: 5, x: 0, y: 0)
                }
            }
            .frame(height: 7)

            Text(OrganizerIslandCopy.status(for: state))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct OrganizerIslandGlassPanel<Content: View>: View {
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

private struct OrganizerIslandActionLink: View {
    let action: OrganizerIslandLink

    init(_ action: OrganizerIslandLink) {
        self.action = action
    }

    var body: some View {
        Link(destination: action.url) {
            Label(action.title, systemImage: action.symbol)
                .font(.caption2.weight(.bold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: 0x30B0FF).opacity(action.isFocus ? 0.18 : 0.14))
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
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
        }
    }
}

private struct OrganizerIslandBackdrop: View {
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

private enum OrganizerIslandLink {
    case openTasks
    case complete(taskId: UUID)
    case focus

    var title: String {
        switch self {
        case .openTasks: return "Задачи"
        case .complete: return "Готово"
        case .focus: return "Фокус"
        }
    }

    var symbol: String {
        switch self {
        case .openTasks: return "list.bullet"
        case .complete: return "checkmark"
        case .focus: return "bolt.fill"
        }
    }

    var isFocus: Bool {
        if case .focus = self { return true }
        return false
    }

    var url: URL {
        switch self {
        case .openTasks:
            return URL(string: "lippi://tasks?action=open")!
        case .complete(let taskId):
            return URL(string: "lippi://task/\(taskId.uuidString)?action=done")!
        case .focus:
            return URL(string: "lippi://pomodoro?action=start&minutes=25")!
        }
    }
}

private enum OrganizerIslandCopy {
    static func accent(for state: OrganizerAttributes.ContentState) -> Color {
        if state.isCompleted { return Color(hex: 0x30D158) }
        guard let due = state.dueDate else { return Color(hex: 0x64D2FF) }
        if due < Date() { return Color(hex: 0xFF453A) }
        if Calendar.current.isDateInToday(due) { return Color(hex: 0xFF9F0A) }
        return Color(hex: 0x64D2FF)
    }

    static func status(for state: OrganizerAttributes.ContentState) -> String {
        if state.isCompleted { return "Выполнено" }
        guard let due = state.dueDate else { return "Без дедлайна" }
        if due < Date() { return "Просрочено" }
        if Calendar.current.isDateInToday(due) { return "Сегодня" }
        return "Запланировано"
    }
}

extension OrganizerAttributes {
    fileprivate static var preview: OrganizerAttributes {
        OrganizerAttributes(taskId: UUID())
    }
}

extension OrganizerAttributes.ContentState {
    fileprivate static var todayPreview: OrganizerAttributes.ContentState {
        OrganizerAttributes.ContentState(
            taskTitle: "Подготовить отчёт",
            categoryTitle: "Работа",
            categorySymbol: "briefcase.fill",
            startDate: .now.addingTimeInterval(-20 * 60),
            dueDate: .now.addingTimeInterval(40 * 60),
            isCompleted: false
        )
    }

    fileprivate static var donePreview: OrganizerAttributes.ContentState {
        OrganizerAttributes.ContentState(
            taskTitle: "Проверить план дня",
            categoryTitle: "Личное",
            categorySymbol: "person.fill",
            startDate: .now.addingTimeInterval(-30 * 60),
            dueDate: .now.addingTimeInterval(10 * 60),
            isCompleted: true
        )
    }
}

#Preview("Task", as: .dynamicIsland(.expanded), using: OrganizerAttributes.preview) {
    OrganizerWidgetLiveActivity()
} contentStates: {
    OrganizerAttributes.ContentState.todayPreview
    OrganizerAttributes.ContentState.donePreview
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
