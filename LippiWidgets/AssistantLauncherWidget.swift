import WidgetKit
import SwiftUI

struct AssistantLauncherEntry: TimelineEntry {
    let date: Date
}

struct AssistantLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssistantLauncherEntry { .init(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (AssistantLauncherEntry) -> Void) {
        completion(.init(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AssistantLauncherEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
}

private enum AssistantWidgetAction {
    case listen
    case menu

    var title: String { self == .listen ? "Говорить" : "Команды" }
    var subtitle: String { self == .listen ? "Начать запись" : "Открыть помощника" }
    var symbol: String { self == .listen ? "waveform.and.mic" : "square.grid.2x2" }
    var url: URL {
        URL(string: "lippi://assistant?mode=\(self == .listen ? "listen" : "menu")")!
    }
}

struct AssistantLauncherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AssistantLauncherEntry

    private let accent = Color(hex: 0x59B9FF)

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Спросить Lippi", systemImage: "waveform.and.mic")
                .widgetURL(AssistantWidgetAction.listen.url)
        case .accessoryCircular:
            circularLayout
                .widgetURL(AssistantWidgetAction.listen.url)
        case .accessoryRectangular:
            rectangularLayout
                .widgetURL(AssistantWidgetAction.listen.url)
        case .systemMedium:
            WidgetSurface(accent: accent) { mediumLayout }
        default:
            WidgetSurface(accent: accent) { smallLayout }
                .widgetURL(AssistantWidgetAction.listen.url)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetBrandMark(section: "Голосом", symbol: "mic.fill")

            Spacer(minLength: 6)

            voiceMark(size: 40)

            Spacer(minLength: 5)

            Text("Говорите —\nя рядом")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 2)

            Text("Коснитесь, чтобы начать")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetBrandMark(section: "Голосовой помощник", symbol: "mic.fill")

                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    voiceMark(size: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Мысль — сразу в дело")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("Задачи, фокус и цели голосом")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                actionLink(.listen, emphasized: true)
                actionLink(.menu, emphasized: false)
            }
            .frame(width: 116)
        }
    }

    private func voiceMark(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(accent.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                )
            Image(systemName: "waveform")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(accent)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
    }

    private func actionLink(_ action: AssistantWidgetAction, emphasized: Bool) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.caption.weight(.semibold))
                    .frame(width: 15)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                    Text(action.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.58)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(emphasized ? Color(hex: 0x07111F) : .white)
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(emphasized ? accent : .white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(emphasized ? 0 : 0.10), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    private var circularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 20, weight: .semibold))
                .widgetAccentable()
        }
    }

    private var rectangularLayout: some View {
        HStack(spacing: 9) {
            Image(systemName: "waveform.and.mic")
                .font(.title2.weight(.semibold))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text("Спросить Lippi")
                    .font(.headline.weight(.semibold))
                Text("Коснитесь и говорите")
                    .font(.caption.weight(.medium))
                    .opacity(0.72)
            }
            Spacer(minLength: 0)
        }
    }
}

struct AssistantLauncherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AssistantLauncherWidget", provider: AssistantLauncherProvider()) { entry in
            AssistantLauncherWidgetView(entry: entry)
        }
        .configurationDisplayName("Спросить Lippi")
        .description("Голосовой помощник на главном и заблокированном экране.")
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
