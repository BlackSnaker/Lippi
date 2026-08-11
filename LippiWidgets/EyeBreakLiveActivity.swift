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
                    EyeBreakPhaseHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 9) {
                        EyeGazePath(state: context.state, compact: true)
                        .frame(height: 54)

                        EyeBreakPhaseProgress(state: context.state)

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
                EyeBreakCompactPhase(state: context.state)
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
                    EyeBreakLockScreenInstruction(state: state)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer(minLength: 8)
                EyeBreakCountdown(state: state, font: .title3)
            }

            EyeGazePath(state: state, compact: false)
            .frame(height: 48)

            EyeBreakPhaseProgress(state: state)

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

private struct EyeBreakPhaseHeader: View {
    let state: EyeBreakActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(EyeBreakCopy.movingLightTitle(state.languageCode))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(EyeBreakCopy.movingLightInstruction(state.languageCode))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EyeBreakLockScreenInstruction: View {
    let state: EyeBreakActivityAttributes.ContentState

    var body: some View {
        Text(EyeBreakCopy.movingLightInstruction(state.languageCode))
            .lineLimit(2)
    }
}

private struct EyeBreakCompactPhase: View {
    let state: EyeBreakActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "eye.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(EyeBreakPalette.cyan)

            ProgressView(
                timerInterval: state.startDate...state.endDate,
                countsDown: false
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(EyeBreakPalette.mint)
            .frame(width: 17)
            .scaleEffect(y: 1.6)
        }
        .accessibilityLabel(EyeBreakCopy.movingLightTitle(state.languageCode))
    }
}

private struct EyeBreakPhaseProgress: View {
    let state: EyeBreakActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EyeBreakPhase.allCases.indices, id: \.self) { index in
                ProgressView(
                    timerInterval: EyeBreakRoutine.dateInterval(
                        forPhaseAt: index,
                        state: state
                    ),
                    countsDown: false
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(EyeBreakPalette.mint)
                .scaleEffect(y: 0.72)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EyeBreakCopy.liveProgress(state.languageCode))
    }
}

private struct EyeGazePath: View {
    let state: EyeBreakActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        // Live Activities don't advance TimelineView schedules while the widget
        // extension is suspended. Date-relative progress stays live because the
        // system renders it from the interval without waking the extension.
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

            VStack(spacing: compact ? 3.2 : 2.6) {
                ForEach(EyeBreakPhase.allCases.indices, id: \.self) { index in
                    ProgressView(
                        timerInterval: EyeBreakRoutine.dateInterval(
                            forPhaseAt: index,
                            state: state
                        ),
                        countsDown: false
                    ) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(
                        LinearGradient(
                            colors: [
                                EyeBreakPalette.blue.opacity(0.34),
                                EyeBreakPalette.cyan,
                                .white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(y: compact ? 1.9 : 1.75)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? 0 : 180))
                    .shadow(
                        color: EyeBreakPalette.cyan.opacity(0.78),
                        radius: compact ? 4 : 5
                    )
                }
            }
            .padding(.horizontal, compact ? 16 : 20)
            .padding(.vertical, compact ? 7 : 6)
        }
        .accessibilityLabel(EyeBreakCopy.followAccessibility(state.languageCode))
    }
}

private enum EyeBreakPhase: String, CaseIterable {
    case settle
    case horizontal
    case vertical
    case circle
    case focus
    case blink

    var weight: Double {
        switch self {
        case .settle: 0.10
        case .horizontal: 0.20
        case .vertical: 0.17
        case .circle: 0.20
        case .focus: 0.20
        case .blink: 0.13
        }
    }

}

private enum EyeBreakRoutine {
    static func dateInterval(
        forPhaseAt proposedIndex: Int,
        state: EyeBreakActivityAttributes.ContentState
    ) -> ClosedRange<Date> {
        let duration = max(state.endDate.timeIntervalSince(state.startDate), 1)
        let phases = EyeBreakPhase.allCases
        let index = min(max(proposedIndex, 0), max(phases.count - 1, 0))
        let lowerProgress = phases.prefix(index).reduce(0) { $0 + $1.weight }
        let upperProgress = index == phases.count - 1
            ? 1
            : min(lowerProgress + phases[index].weight, 1)
        let start = state.startDate.addingTimeInterval(duration * lowerProgress)
        let end = state.startDate.addingTimeInterval(duration * upperProgress)
        return start...max(end, start.addingTimeInterval(0.001))
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

    static func movingLightTitle(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Follow the moving light"
        case "de": "Folge dem bewegten Licht"
        case "es": "Sigue la luz en movimiento"
        default: "Следите за движущимся светом"
        }
    }

    static func movingLightInstruction(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Guide your eyes along the bright end of the track"
        case "de": "Folge mit den Augen dem hellen Ende der Spur"
        case "es": "Sigue con la mirada el extremo luminoso de la pista"
        default: "Ведите взгляд за светлым краем дорожки"
        }
    }

    static func liveProgress(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Progress of the one-minute eye exercise"
        case "de": "Fortschritt der einminütigen Augenübung"
        case "es": "Progreso del ejercicio visual de un minuto"
        default: "Ход минутного упражнения для глаз"
        }
    }

    static func phaseTitle(_ phase: EyeBreakPhase, language: String) -> String {
        switch language.lowercased() {
        case "en":
            switch phase {
            case .settle: "Settle your gaze"
            case .horizontal: "Left and right"
            case .vertical: "Up and down"
            case .circle: "Slow circle"
            case .focus: "Change focus"
            case .blink: "Slow blinks"
            }
        case "de":
            switch phase {
            case .settle: "Blick entspannen"
            case .horizontal: "Links und rechts"
            case .vertical: "Oben und unten"
            case .circle: "Langsamer Kreis"
            case .focus: "Fokus wechseln"
            case .blink: "Langsam blinzeln"
            }
        case "es":
            switch phase {
            case .settle: "Relaja la mirada"
            case .horizontal: "Izquierda y derecha"
            case .vertical: "Arriba y abajo"
            case .circle: "Círculo lento"
            case .focus: "Cambia el enfoque"
            case .blink: "Parpadea despacio"
            }
        default:
            switch phase {
            case .settle: "Расслабьте взгляд"
            case .horizontal: "Влево и вправо"
            case .vertical: "Вверх и вниз"
            case .circle: "Медленный круг"
            case .focus: "Смена фокуса"
            case .blink: "Медленно моргайте"
            }
        }
    }

    static func phaseInstruction(_ phase: EyeBreakPhase, language: String) -> String {
        switch language.lowercased() {
        case "en":
            switch phase {
            case .settle: "Relax your shoulders and breathe out"
            case .horizontal: "Follow the light without turning your head"
            case .vertical: "Move only your eyes, gently"
            case .circle: "Trace the circle without rushing"
            case .focus: "Look beyond the screen, then back to the point"
            case .blink: "Blink fully and slowly"
            }
        case "de":
            switch phase {
            case .settle: "Schultern lockern und ausatmen"
            case .horizontal: "Dem Licht folgen, ohne den Kopf zu drehen"
            case .vertical: "Nur die Augen sanft bewegen"
            case .circle: "Den Kreis langsam nachzeichnen"
            case .focus: "Über den Bildschirm hinaus und zurück blicken"
            case .blink: "Vollständig und langsam blinzeln"
            }
        case "es":
            switch phase {
            case .settle: "Relaja los hombros y exhala"
            case .horizontal: "Sigue la luz sin girar la cabeza"
            case .vertical: "Mueve solo los ojos, con suavidad"
            case .circle: "Recorre el círculo sin prisa"
            case .focus: "Mira más allá de la pantalla y vuelve al punto"
            case .blink: "Parpadea por completo y despacio"
            }
        default:
            switch phase {
            case .settle: "Расслабьте плечи и спокойно выдохните"
            case .horizontal: "Следите за светом, не поворачивая голову"
            case .vertical: "Мягко двигайте только глазами"
            case .circle: "Опишите круг взглядом, не торопясь"
            case .focus: "Посмотрите за экран, затем снова на точку"
            case .blink: "Моргайте полностью и медленно"
            }
        }
    }

    static func phaseProgress(_ current: Int, total: Int, language: String) -> String {
        switch language.lowercased() {
        case "en": "Step \(current) of \(total)"
        case "de": "Schritt \(current) von \(total)"
        case "es": "Paso \(current) de \(total)"
        default: "Этап \(current) из \(total)"
        }
    }

    static func followAccessibility(_ language: String) -> String {
        switch language.lowercased() {
        case "en": "Follow the guided eye exercise"
        case "de": "Der geführten Augenübung folgen"
        case "es": "Sigue el ejercicio visual guiado"
        default: "Следуйте подсказкам упражнения для глаз"
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
