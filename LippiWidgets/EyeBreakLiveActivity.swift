import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

enum EyeBreakLiveActivityMode: String, Codable, Hashable {
    case pointOnly
    case cameraAvailable
}

struct EyeBreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var mode: EyeBreakLiveActivityMode
        var languageCode: String
    }

    var sessionID: UUID
}

struct EyeBreakLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EyeBreakActivityAttributes.self) { context in
            EyeBreakLockScreenView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x07111F))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(EyeBreakLink.forMode(context.state.mode))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EyeBreakOrb(size: 42)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EyeBreakCountdown(state: context.state, font: .headline)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(EyeBreakCopy.title(context.state.languageCode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(EyeBreakCopy.islandSubtitle(context.state))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 9) {
                        EyeGazePath(
                            startDate: context.state.startDate,
                            endDate: context.state.endDate,
                            compact: true
                        )
                        .frame(height: 54)

                        HStack(spacing: 8) {
                            Link(destination: EyeBreakLink.forMode(context.state.mode)) {
                                Label(
                                    EyeBreakCopy.openAction(context.state),
                                    systemImage: context.state.mode == .cameraAvailable
                                        ? "camera.viewfinder"
                                        : "arrow.up.right"
                                )
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .contentShape(Capsule())
                            }
                            .eyeLiveGlass(
                                in: Capsule(),
                                tint: EyeBreakPalette.cyan.opacity(0.16),
                                interactive: true
                            )

                            Button(intent: FinishEyeBreakIntent()) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EyeBreakPalette.mint)
                                    .frame(width: 31, height: 31)
                            }
                            .buttonStyle(.plain)
                            .eyeLiveGlass(
                                in: Circle(),
                                tint: EyeBreakPalette.mint.opacity(0.12),
                                interactive: true
                            )
                        }
                    }
                }
            } compactLeading: {
                ZStack {
                    Image(systemName: "eye.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EyeBreakPalette.cyan)
                    Circle()
                        .fill(EyeBreakPalette.mint)
                        .frame(width: 4, height: 4)
                }
            } compactTrailing: {
                EyeBreakCountdown(state: context.state, font: .caption2)
                    .frame(maxWidth: 45)
            } minimal: {
                EyeBreakOrb(size: 24)
            }
            .widgetURL(EyeBreakLink.forMode(context.state.mode))
            .keylineTint(EyeBreakPalette.cyan)
        }
    }
}

private struct EyeBreakLockScreenView: View {
    let state: EyeBreakActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                EyeBreakOrb(size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(EyeBreakCopy.title(state.languageCode))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(EyeBreakCopy.lockScreenSubtitle(state))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                EyeBreakCountdown(state: state, font: .title3)
            }

            EyeGazePath(
                startDate: state.startDate,
                endDate: state.endDate,
                compact: false
            )
            .frame(height: 48)

            HStack(spacing: 8) {
                Label(
                    EyeBreakCopy.privacyLabel(state),
                    systemImage: state.mode == .cameraAvailable ? "lock.shield.fill" : "camera.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(EyeBreakPalette.mint)

                Spacer(minLength: 4)

                Button(intent: FinishEyeBreakIntent()) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EyeBreakPalette.mint)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .eyeLiveGlass(
                    in: Circle(),
                    tint: EyeBreakPalette.mint.opacity(0.12),
                    interactive: true
                )

                Link(destination: EyeBreakLink.forMode(state.mode)) {
                    Label(EyeBreakCopy.openAction(state), systemImage: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .eyeLiveGlass(
                    in: Capsule(),
                    tint: EyeBreakPalette.cyan.opacity(0.16),
                    interactive: true
                )
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }
}

struct FinishEyeBreakIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Finish eye break"
    static let description = IntentDescription("Ends the current short eye exercise.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        for activity in Activity<EyeBreakActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

private struct EyeBreakCountdown: View {
    let state: EyeBreakActivityAttributes.ContentState
    let font: Font

    var body: some View {
        Text(timerInterval: state.startDate...state.endDate, countsDown: true)
            .font(font.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .accessibilityLabel(EyeBreakCopy.countdownLabel(state.languageCode))
    }
}

private struct EyeBreakOrb: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            EyeBreakPalette.cyan.opacity(0.36),
                            EyeBreakPalette.blue.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.52
                    )
                )

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            EyeBreakPalette.cyan,
                            EyeBreakPalette.violet,
                            EyeBreakPalette.mint,
                            EyeBreakPalette.cyan
                        ],
                        center: .center
                    ),
                    lineWidth: max(1, size * 0.045)
                )
                .padding(size * 0.12)

            Image(systemName: "eye.fill")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .eyeLiveGlass(in: Circle(), tint: EyeBreakPalette.blue.opacity(0.10))
        .accessibilityHidden(true)
    }
}

private struct EyeGazePath: View {
    let startDate: Date
    let endDate: Date
    let compact: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            GeometryReader { proxy in
                let inset: CGFloat = compact ? 16 : 20
                let dotSize: CGFloat = compact ? 14 : 16
                let availableWidth = max(proxy.size.width - inset * 2, 1)
                let elapsed = max(timeline.date.timeIntervalSince(startDate), 0)
                let cycleDuration = 6.0
                let cycle = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
                let horizontal = CGFloat(cycle < 0.5 ? cycle * 2 : (1 - cycle) * 2)
                let wave = CGFloat(sin(cycle * .pi * 2))
                let x = inset + availableWidth * horizontal
                let y = proxy.size.height * (0.50 + wave * 0.22)
                let pulse = 1 + CGFloat((sin(elapsed * 3.2) + 1) * 0.06)

                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                        .fill(.white.opacity(0.055))
                        .overlay {
                            RoundedRectangle(cornerRadius: compact ? 18 : 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            EyeBreakPalette.cyan.opacity(0.46),
                                            .white.opacity(0.12),
                                            EyeBreakPalette.violet.opacity(0.38)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }

                    Path { path in
                        path.move(to: CGPoint(x: inset, y: proxy.size.height * 0.5))
                        path.addCurve(
                            to: CGPoint(x: proxy.size.width - inset, y: proxy.size.height * 0.5),
                            control1: CGPoint(x: proxy.size.width * 0.30, y: proxy.size.height * 0.18),
                            control2: CGPoint(x: proxy.size.width * 0.70, y: proxy.size.height * 0.82)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: [
                                EyeBreakPalette.blue.opacity(0.12),
                                EyeBreakPalette.cyan.opacity(0.42),
                                EyeBreakPalette.violet.opacity(0.16)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, EyeBreakPalette.cyan, EyeBreakPalette.blue],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: dotSize
                            )
                        )
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(pulse)
                        .overlay(Circle().stroke(.white.opacity(0.86), lineWidth: 1))
                        .shadow(color: EyeBreakPalette.cyan.opacity(0.98), radius: compact ? 8 : 11)
                        .position(x: x, y: y)
                }
            }
        }
        .accessibilityLabel("Follow the moving light with your eyes")
    }
}

private enum EyeBreakLink {
    static func forMode(_ mode: EyeBreakLiveActivityMode) -> URL {
        switch mode {
        case .cameraAvailable:
            return URL(string: "lippi://eye?mode=camera")!
        case .pointOnly:
            return URL(string: "lippi://eye?mode=point")!
        }
    }
}

private enum EyeBreakPalette {
    static let blue = Color(hex: 0x3D8CFF)
    static let cyan = Color(hex: 0x5AC8FA)
    static let mint = Color(hex: 0x55E0B5)
    static let violet = Color(hex: 0x9A7CFF)
}

private enum EyeBreakCopy {
    static func title(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Rest your eyes"
        case "de": "Augen entspannen"
        case "es": "Descansa la vista"
        default: "Отдохните глазами"
        }
    }

    static func islandSubtitle(_ state: EyeBreakActivityAttributes.ContentState) -> String {
        switch state.languageCode.lowercased() {
        case "en": "Follow the point gently"
        case "de": "Folge dem Punkt ganz sanft"
        case "es": "Sigue el punto suavemente"
        default: "Мягко следите за точкой"
        }
    }

    static func lockScreenSubtitle(_ state: EyeBreakActivityAttributes.ContentState) -> String {
        switch state.languageCode.lowercased() {
        case "en": state.mode == .cameraAvailable
            ? "Follow the point. Precise camera mode is available in Lippi."
            : "Follow the point — the exercise works without camera access."
        case "de": state.mode == .cameraAvailable
            ? "Folge dem Punkt. Der präzise Kameramodus ist in Lippi verfügbar."
            : "Folge dem Punkt — die Übung funktioniert ohne Kamerazugriff."
        case "es": state.mode == .cameraAvailable
            ? "Sigue el punto. El modo preciso con cámara está disponible en Lippi."
            : "Sigue el punto; el ejercicio funciona sin acceso a la cámara."
        default: state.mode == .cameraAvailable
            ? "Следите за точкой. Точный режим с камерой доступен в Lippi."
            : "Следите за точкой — упражнение работает без доступа к камере."
        }
    }

    static func openAction(_ state: EyeBreakActivityAttributes.ContentState) -> String {
        switch state.languageCode.lowercased() {
        case "en": state.mode == .cameraAvailable ? "Camera mode" : "Open in Lippi"
        case "de": state.mode == .cameraAvailable ? "Kameramodus" : "In Lippi öffnen"
        case "es": state.mode == .cameraAvailable ? "Modo cámara" : "Abrir en Lippi"
        default: state.mode == .cameraAvailable ? "Режим с камерой" : "Открыть в Lippi"
        }
    }

    static func privacyLabel(_ state: EyeBreakActivityAttributes.ContentState) -> String {
        switch state.languageCode.lowercased() {
        case "en": state.mode == .cameraAvailable ? "Camera only in the app" : "No camera"
        case "de": state.mode == .cameraAvailable ? "Kamera nur in der App" : "Ohne Kamera"
        case "es": state.mode == .cameraAvailable ? "Cámara solo en la app" : "Sin cámara"
        default: state.mode == .cameraAvailable ? "Камера только в приложении" : "Без камеры"
        }
    }

    static func countdownLabel(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Time remaining"
        case "de": "Verbleibende Zeit"
        case "es": "Tiempo restante"
        default: "Осталось времени"
        }
    }
}

private extension View {
    @ViewBuilder
    func eyeLiveGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: shape
            )
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
}
