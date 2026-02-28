import WidgetKit
import SwiftUI

struct AssistantLauncherEntry: TimelineEntry {
    let date: Date
}

struct AssistantLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssistantLauncherEntry {
        AssistantLauncherEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (AssistantLauncherEntry) -> Void) {
        completion(AssistantLauncherEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AssistantLauncherEntry>) -> Void) {
        let entry = AssistantLauncherEntry(date: .now)
        let next = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private enum AssistantWidgetAction {
    case listen
    case menu

    var title: String {
        switch self {
        case .listen: return "Слушать"
        case .menu: return "Меню"
        }
    }

    var subtitle: String {
        switch self {
        case .listen: return "Сразу начать запись"
        case .menu: return "Открыть полный экран"
        }
    }

    var symbol: String {
        switch self {
        case .listen: return "waveform.and.mic"
        case .menu: return "slider.horizontal.3"
        }
    }

    var url: URL {
        let mode = self == .listen ? "listen" : "menu"
        return URL(string: "lippi://assistant?mode=\(mode)")!
    }
}

struct AssistantLauncherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AssistantLauncherEntry

    private let accent = Color(hex: 0x3AA8FF)
    private let glow = Color(hex: 0x8EDEFF)

    var body: some View {
        WidgetSurface(accent: accent, blurAccent: glow.opacity(0.55)) {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .widgetURL(AssistantWidgetAction.listen.url)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            HStack(spacing: 10) {
                assistantOrb
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Голосовой помощник")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text("Коснитесь, чтобы начать говорить")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }
            }

            calloutChip(title: AssistantWidgetAction.listen.title, symbol: AssistantWidgetAction.listen.symbol)
        }
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                header

                HStack(spacing: 10) {
                    assistantOrb
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Голосовой помощник")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("Быстрый запуск без лишних экранов")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                    }
                }

                Text("Тап по виджету запускает запись сразу.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                actionLink(.listen)
                actionLink(.menu)
            }
            .frame(width: 126)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("LIPPI AI")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .tracking(0.7)

            Spacer(minLength: 0)

            calloutChip(title: "Voice", symbol: "sparkles")
        }
    }

    private var assistantOrb: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x6ED6FF), Color(hex: 0x1A8FFF), Color(hex: 0x0A64FF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.34), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )

            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: glow.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func actionLink(_ action: AssistantWidgetAction) -> some View {
        Link(destination: action.url) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: action.symbol)
                        .font(.caption.weight(.semibold))
                        .frame(width: 14)
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text(action.subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func calloutChip(title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(accent.opacity(0.42), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct AssistantLauncherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AssistantLauncherWidget", provider: AssistantLauncherProvider()) { entry in
            AssistantLauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Голосовой помощник")
        .description("Быстрый запуск записи голоса и открытие полного меню помощника.")
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
