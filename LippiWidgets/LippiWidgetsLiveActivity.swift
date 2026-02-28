import ActivityKit
import WidgetKit
import SwiftUI

struct LippiWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }

    var name: String
}

struct LippiWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LippiWidgetsAttributes.self) { context in
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x0A84FF).opacity(0.3))
                        .frame(width: 34, height: 34)
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Фокус-сессия")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(context.attributes.name)  \(context.state.emoji)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer(minLength: 0)

                Text("LIVE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0x0A84FF).opacity(0.4), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x0B101B), Color(hex: 0x1A253A)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .activityBackgroundTint(Color(hex: 0x0B101B))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color(hex: 0x64D2FF))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.emoji)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text("Lippi Focus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text("Держи темп и не теряй концентрацию")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(hex: 0x64D2FF))
            } compactTrailing: {
                Text(context.state.emoji)
            } minimal: {
                Image(systemName: "bolt.fill")
            }
            .keylineTint(Color(hex: 0x64D2FF))
        }
    }
}

extension LippiWidgetsAttributes {
    fileprivate static var preview: LippiWidgetsAttributes {
        LippiWidgetsAttributes(name: "Фокус")
    }
}

extension LippiWidgetsAttributes.ContentState {
    fileprivate static var smiley: LippiWidgetsAttributes.ContentState {
        LippiWidgetsAttributes.ContentState(emoji: "😀")
    }

    fileprivate static var starEyes: LippiWidgetsAttributes.ContentState {
        LippiWidgetsAttributes.ContentState(emoji: "🤩")
    }
}

#Preview("Notification", as: .content, using: LippiWidgetsAttributes.preview) {
    LippiWidgetsLiveActivity()
} contentStates: {
    LippiWidgetsAttributes.ContentState.smiley
    LippiWidgetsAttributes.ContentState.starEyes
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
