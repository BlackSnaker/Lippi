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
            OrganizerLockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x0B1422))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(OrganizerActivityLink.openTasks.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    OrganizerActivityIcon(state: context.state, size: 40)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    OrganizerDueView(state: context.state, compact: false)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.taskTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(OrganizerActivityStyle.status(for: context.state))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(OrganizerActivityStyle.accent(for: context.state))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        OrganizerActivityProgress(state: context.state)

                        HStack(spacing: 8) {
                            OrganizerActivityAction(.openTasks)
                            OrganizerActivityAction(.complete(taskId: context.attributes.taskId), emphasized: true)
                            OrganizerActivityAction(.focus)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isCompleted ? "checkmark" : context.state.categorySymbol)
                    .foregroundStyle(OrganizerActivityStyle.accent(for: context.state))
            } compactTrailing: {
                OrganizerDueView(state: context.state, compact: true)
            } minimal: {
                Image(systemName: context.state.isCompleted ? "checkmark" : context.state.categorySymbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(OrganizerActivityStyle.accent(for: context.state))
            }
            .widgetURL(OrganizerActivityLink.openTasks.url)
            .keylineTint(OrganizerActivityStyle.accent(for: context.state))
        }
    }
}
private struct OrganizerLockScreenView: View {
    let state: OrganizerAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                OrganizerActivityIcon(state: state, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.taskTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Label(state.categoryTitle, systemImage: state.categorySymbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                OrganizerDueView(state: state, compact: false)
            }

            OrganizerActivityProgress(state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct OrganizerActivityIcon: View {
    let state: OrganizerAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(OrganizerActivityStyle.accent(for: state).opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .stroke(OrganizerActivityStyle.accent(for: state).opacity(0.28), lineWidth: 1)
                )
            Image(systemName: state.isCompleted ? "checkmark" : state.categorySymbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(OrganizerActivityStyle.accent(for: state))
        }
        .frame(width: size, height: size)
    }
}

private struct OrganizerDueView: View {
    let state: OrganizerAttributes.ContentState
    let compact: Bool

    var body: some View {
        Group {
            if state.isCompleted {
                Image(systemName: "checkmark.circle.fill")
            } else if let due = state.dueDate {
                Text(due, format: .dateTime.hour().minute())
                    .monospacedDigit()
            } else {
                Image(systemName: "arrow.up.right")
            }
        }
        .font(compact ? .caption2.weight(.bold) : .title3.weight(.bold))
        .foregroundStyle(compact ? Color.white : OrganizerActivityStyle.accent(for: state))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct OrganizerActivityProgress: View {
    let state: OrganizerAttributes.ContentState

    private var progress: Double {
        if state.isCompleted { return 1 }
        guard let due = state.dueDate else { return 0.12 }
        let total = max(due.timeIntervalSince(state.startDate), 1)
        return min(max(Date().timeIntervalSince(state.startDate) / total, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(OrganizerActivityStyle.accent(for: state))
                    .frame(width: max(5, proxy.size.width * progress))
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Время до срока")
        .accessibilityValue(OrganizerActivityStyle.status(for: state))
    }
}

private struct OrganizerActivityAction: View {
    let action: OrganizerActivityLink
    let emphasized: Bool

    init(_ action: OrganizerActivityLink, emphasized: Bool = false) {
        self.action = action
        self.emphasized = emphasized
    }

    var body: some View {
        Link(destination: action.url) {
            Label(action.title, systemImage: action.icon)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(emphasized ? Color(hex: 0x07111F) : .white)
                .background(
                    Capsule()
                        .fill(emphasized ? OrganizerActivityStyle.actionColor : .white.opacity(0.08))
                )
        }
    }
}

private enum OrganizerActivityLink {
    case openTasks
    case complete(taskId: UUID)
    case focus

    var title: String {
        switch self {
        case .openTasks: "Задачи"
        case .complete: "Готово"
        case .focus: "Фокус"
        }
    }

    var icon: String {
        switch self {
        case .openTasks: "list.bullet"
        case .complete: "checkmark"
        case .focus: "scope"
        }
    }

    var url: URL {
        switch self {
        case .openTasks:
            URL(string: "lippi://tasks?action=open")!
        case .complete(let taskId):
            URL(string: "lippi://task/\(taskId.uuidString)?action=done")!
        case .focus:
            URL(string: "lippi://pomodoro?action=start&minutes=25")!
        }
    }
}

private enum OrganizerActivityStyle {
    static let actionColor = Color(hex: 0x61BCFF)

    static func accent(for state: OrganizerAttributes.ContentState) -> Color {
        if state.isCompleted { return Color(hex: 0x54D79A) }
        guard let due = state.dueDate else { return Color(hex: 0x61BCFF) }
        if due < .now { return Color(hex: 0xFF6B72) }
        if Calendar.current.isDateInToday(due) { return Color(hex: 0xFFB44A) }
        return Color(hex: 0x61BCFF)
    }

    static func status(for state: OrganizerAttributes.ContentState) -> String {
        if state.isCompleted { return "Выполнено" }
        guard let due = state.dueDate else { return "Без срока" }
        if due < .now { return "Требует внимания" }
        if Calendar.current.isDateInToday(due) { return "Сегодня" }
        return "В плане"
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
