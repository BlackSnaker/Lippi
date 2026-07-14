import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Pomodoro
// =======================================================
struct PomodoroView: View {
    @EnvironmentObject private var pomo: PomodoroManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    @State private var showCustomDuration = false
    @State private var lastHandledTimerEnd: Date?

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var isRunning: Bool {
        pomo.phase != .stopped && pomo.phase != .paused && pomo.startDate != nil
    }

    private var hasActiveSession: Bool {
        isRunning || pomo.phase == .paused
    }

    private var shouldRunTimer: Bool {
        scenePhase == .active && isRunning
    }

    private var phaseTitle: String {
        pomo.phase == .stopped ? s("pomodoro.ready.title") : titleForPhase(pomo.phase)
    }

    private var phaseIcon: String {
        switch pomo.phase {
        case .focus: return "bolt.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "sparkles"
        case .paused: return "pause.fill"
        case .stopped: return "timer"
        }
    }

    private var phaseTone: Color {
        switch pomo.phase {
        case .focus: return DS.accent
        case .shortBreak: return Color(hex: 0x30D158)
        case .longBreak: return Color(hex: 0x64D2FF)
        case .paused: return Color(hex: 0xFF9F0A)
        case .stopped: return DS.brandA
        }
    }

    private var phaseGuidance: String {
        switch pomo.phase {
        case .focus: return s("pomodoro.status.focus")
        case .shortBreak: return s("pomodoro.status.short_break")
        case .longBreak: return s("pomodoro.status.long_break")
        case .paused: return s("pomodoro.status.paused")
        case .stopped: return s("pomodoro.status.ready")
        }
    }

    private var roundsPerCycle: Int {
        max(pomo.config.roundsBeforeLongBreak, 1)
    }

    private var completedRoundsInCycle: Int {
        let remainder = pomo.round % roundsPerCycle
        if pomo.phase == .longBreak, pomo.round > 0, remainder == 0 {
            return roundsPerCycle
        }
        return remainder
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        TimelineView(.animation(minimumInterval: 1.0, paused: !shouldRunTimer)) { timeline in
                            timerHero(at: timeline.date)
                        }
                        .lippiMotionScene(0)

                        if !hasActiveSession {
                            sessionSetupCard
                                .lippiMotionScene(1)
                        }

                        Color.clear.frame(height: 84)
                    }
                    .lippiContentColumn()
                }
                .scrollIndicators(.hidden)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("pomodoro.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .clearNavBarBackgroundIfAvailable()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }
            .task(id: shouldRunTimer) {
                guard shouldRunTimer else { return }
                while !Task.isCancelled {
                    let now = Date.now
                    if let end = pomo.endDate,
                       end <= now,
                       pomo.phase != .stopped,
                       pomo.phase != .paused,
                       pomo.startDate != nil,
                       lastHandledTimerEnd != end {
                        lastHandledTimerEnd = end
                        PomodoroAlarmCenter.shared.start(phaseTitle: phaseTitle)
                        pomo.advance()
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    // MARK: - Timer hero

    private func timerHero(at now: Date) -> some View {
        let currentProgress = progress(at: now)
        let currentTime = clockText(seconds: remainingSeconds(at: now))

        return GlassCard(
            padding: 18,
            cornerRadius: 30,
            style: .full,
            forceSystemGlass: false
        ) {
            VStack(spacing: 18) {
                timerHeader

                ZStack {
                    PomodoroProgressRing(progress: currentProgress, tone: phaseTone)
                        .transaction { $0.animation = nil }

                    VStack(spacing: 7) {
                        Text(currentTime)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text(timerCaption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(width: 244, height: 244)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(phaseTitle))
                .accessibilityValue(Text(currentTime))

                cycleProgress
                sessionControls

                if isRunning {
                    Button {
                        pomo.advance()
                    } label: {
                        Label(s("pomodoro.action.next"), systemImage: "forward.end.fill")
                            .labelStyle(PomodoroActionLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .ghost, compact: true, allowsMultiline: true))
                }
            }
            .animation(reduceMotion ? nil : DS.motionState, value: pomo.phase)
        }
    }

    private var timerHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.glassFill(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(phaseTone.opacity(0.16))
                    )

                Image(safeSystemName: phaseIcon, fallback: "timer")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(phaseTone)
            }
            .frame(width: 44, height: 44)
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                tint: phaseTone.opacity(0.09)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DS.glassStroke(0.13), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(s("pomodoro.hero.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)

                Text(phaseTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(phaseGuidance)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(L10n.fmt("pomodoro.cycle.progress", lang, completedRoundsInCycle, roundsPerCycle))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(DS.glassFill(0.08), in: Capsule())
                .overlay(Capsule().stroke(DS.glassStroke(0.12), lineWidth: 1))
                .accessibilityLabel(Text(L10n.fmt("pomodoro.cycle.accessibility", lang, completedRoundsInCycle, roundsPerCycle)))
        }
    }

    private var timerCaption: String {
        switch pomo.phase {
        case .stopped:
            return s("pomodoro.timer.selected")
        case .paused:
            return s("pomodoro.paused.subtitle")
        case .focus, .shortBreak, .longBreak:
            return s("pomodoro.timer.remaining")
        }
    }

    private var cycleProgress: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(s("pomodoro.cycle.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.fmt("pomodoro.cycle.next", lang, roundsPerCycle))
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                ForEach(0..<roundsPerCycle, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(cycleTone(for: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: 7)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(12)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(DS.glassStroke(0.09), lineWidth: 1)
        )
    }

    private func cycleTone(for index: Int) -> Color {
        if index < completedRoundsInCycle {
            return phaseTone.opacity(0.90)
        }
        if index == completedRoundsInCycle, pomo.phase == .focus {
            return phaseTone.opacity(0.34)
        }
        return DS.glassStroke(0.12)
    }

    // MARK: - Contextual controls

    private var sessionControls: some View {
        VStack(spacing: 10) {
            sessionPrimaryAction
            sessionSecondaryAction
        }
    }

    @ViewBuilder
    private var sessionPrimaryAction: some View {
        switch pomo.phase {
        case .stopped:
            Button {
                showCustomDuration = false
                startFocus(pomo.config.focusMinutes)
            } label: {
                Label(s("pomodoro.action.start_focus"), systemImage: "play.fill")
                    .labelStyle(PomodoroActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))

        case .paused:
            Button {
                pomo.resume()
            } label: {
                Label(s("pomodoro.transport.resume"), systemImage: "play.fill")
                    .labelStyle(PomodoroActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))

        case .focus, .shortBreak, .longBreak:
            Button {
                pomo.pause()
            } label: {
                Label(s("pomodoro.transport.pause"), systemImage: "pause.fill")
                    .labelStyle(PomodoroActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
        }
    }

    @ViewBuilder
    private var sessionSecondaryAction: some View {
        if pomo.phase == .stopped {
            Menu {
                Button {
                    startBreak(long: false)
                } label: {
                    Label(
                        "\(titleForPhase(.shortBreak)) · \(minutesText(pomo.config.shortBreakMinutes))",
                        systemImage: "cup.and.saucer.fill"
                    )
                }

                Button {
                    startBreak(long: true)
                } label: {
                    Label(
                        "\(titleForPhase(.longBreak)) · \(minutesText(pomo.config.longBreakMinutes))",
                        systemImage: "sparkles"
                    )
                }
            } label: {
                Label(s("pomodoro.action.break_menu"), systemImage: "cup.and.saucer")
                    .labelStyle(PomodoroActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
        } else {
            Button {
                pomo.stop()
            } label: {
                Label(s("pomodoro.transport.stop"), systemImage: "stop.fill")
                    .labelStyle(PomodoroActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .destructive, allowsMultiline: true))
        }
    }

    // MARK: - Setup

    private var sessionSetupCard: some View {
        GlassCard(
            padding: 16,
            cornerRadius: 26,
            style: .lightweight,
            forceSystemGlass: false
        ) {
            VStack(alignment: .leading, spacing: 16) {
                LippiSectionHeader(
                    title: s("pomodoro.setup.title"),
                    subtitle: s("pomodoro.setup.subtitle"),
                    icon: "clock.badge",
                    accent: Color(hex: 0x64D2FF)
                )

                durationChoices

                if showCustomDuration {
                    customDurationEditor
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }

                Divider()
                    .overlay(DS.glassStroke(0.09))

                rhythmSummary
            }
        }
        .animation(reduceMotion ? nil : DS.motionState, value: showCustomDuration)
    }

    private var durationChoices: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            durationPresetButton(minutes: 25)
            durationPresetButton(minutes: 50)
            customDurationButton
        }
    }

    private func durationPresetButton(minutes: Int) -> some View {
        let isSelected = !showCustomDuration && pomo.config.focusMinutes == minutes

        return Button {
            withAnimation(reduceMotion ? nil : DS.motionState) {
                pomo.config.focusMinutes = minutes
                showCustomDuration = false
            }
            selectionHaptic()
        } label: {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                Text(s("pomodoro.custom.minutes_unit"))
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? DS.accent : DS.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DS.accent.opacity(0.13) : DS.glassFill(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.30) : DS.glassStroke(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customDurationButton: some View {
        let isSelected = showCustomDuration || ![25, 50].contains(pomo.config.focusMinutes)

        return Button {
            withAnimation(reduceMotion ? nil : DS.motionState) {
                showCustomDuration.toggle()
            }
            selectionHaptic()
        } label: {
            VStack(spacing: 4) {
                Image(safeSystemName: "slider.horizontal.3", fallback: "clock")
                    .font(.system(size: 15, weight: .semibold))

                Text(s("pomodoro.preset.custom"))
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? DS.accent : DS.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? DS.accent.opacity(0.13) : DS.glassFill(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.30) : DS.glassStroke(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var customDurationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $pomo.config.focusMinutes, in: 1...180, step: 1) {
                HStack(spacing: 10) {
                    Image(safeSystemName: "clock", fallback: "clock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(s("pomodoro.custom.title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)

                        Text(minutesText(pomo.config.focusMinutes))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DS.textSecondary)
                    }
                }
            }
            .tint(DS.accent)

            Text(s("pomodoro.custom.range"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(12)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(DS.glassStroke(0.09), lineWidth: 1)
        )
    }

    private var rhythmSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            rhythmMetric(
                title: s("pomodoro.phase.focus"),
                value: minutesText(pomo.config.focusMinutes),
                icon: "bolt.fill",
                tone: DS.accent
            )
            rhythmMetric(
                title: s("pomodoro.phase.short_break"),
                value: minutesText(pomo.config.shortBreakMinutes),
                icon: "cup.and.saucer.fill",
                tone: Color(hex: 0x30D158)
            )
            rhythmMetric(
                title: s("pomodoro.phase.long_break_short"),
                value: minutesText(pomo.config.longBreakMinutes),
                icon: "sparkles",
                tone: Color(hex: 0x64D2FF)
            )
        }
    }

    private func rhythmMetric(title: String, value: String, icon: String, tone: Color) -> some View {
        HStack(spacing: 8) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timer values and actions

    private func progress(at now: Date) -> Double {
        guard let duration = pomo.sessionTotalDuration, hasActiveSession else { return 0 }
        let total = max(duration, 1)
        let remaining = remainingSeconds(at: now)
        return min(max(1 - (remaining / total), 0), 1)
    }

    private func remainingSeconds(at now: Date) -> TimeInterval {
        if pomo.phase == .paused {
            return max(pomo.pausedSessionRemaining ?? 0, 0)
        }
        if let end = pomo.endDate, isRunning {
            return max(end.timeIntervalSince(now), 0)
        }
        return TimeInterval(max(pomo.config.focusMinutes, 1) * 60)
    }

    private func clockText(seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(ceil(seconds)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func minutesText(_ minutes: Int) -> String {
        "\(minutes) \(s("pomodoro.custom.minutes_unit"))"
    }

    private func startFocus(_ minutes: Int) {
        pomo.startFocus(customMinutes: minutes)
    }

    private func startBreak(long: Bool) {
        showCustomDuration = false
        if long {
            pomo.startLongBreak()
        } else {
            pomo.startShortBreak()
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func selectionHaptic() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func titleForPhase(_ phase: PomodoroPhase) -> String {
        switch phase {
        case .focus: return s("pomodoro.phase.focus")
        case .shortBreak: return s("pomodoro.phase.short_break")
        case .longBreak: return s("pomodoro.phase.long_break")
        case .paused: return s("pomodoro.phase.paused")
        case .stopped: return s("pomodoro.phase.stopped")
        }
    }
}

private struct PomodoroProgressRing: View {
    let progress: Double
    let tone: Color

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.glassFill(0.045))
                .overlay(Circle().fill(DS.glassTint).opacity(0.24))

            Circle()
                .stroke(DS.glassStroke(0.11), lineWidth: 13)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [tone.opacity(0.64), tone, DS.brandB, tone],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .overlay(
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .padding(7)
        )
        .accessibilityHidden(true)
    }
}

private struct PomodoroActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 7) {
            configuration.icon

            configuration.title
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
