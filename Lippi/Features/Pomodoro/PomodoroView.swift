import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Pomodoro (dark Apple-style backdrop)
// =======================================================
struct PomodoroView: View {
    @EnvironmentObject private var pomo: PomodoroManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var tick: Date = .now
    @State private var customMinutesText: String = ""
    @State private var lastHandledTimerEnd: Date?

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    // Фон в стиле macOS/iOS Night
    private var pomoBackdrop: some View {
        AppBackdrop()
    }

    // MARK: - Progress
    private func progress(at now: Date) -> Double {
        guard let start = pomo.startDate, let end = pomo.endDate else { return 0 }
        let total = max(end.timeIntervalSince(start), 1)
        let done  = max(now.timeIntervalSince(start), 0)
        return min(max(done / total, 0), 1)
    }

    private var phaseTitle: String { titleForPhase(pomo.phase) }

    private var phaseIcon: String {
        switch pomo.phase {
        case .focus: return "bolt.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "sparkles"
        case .paused: return "pause.fill"
        case .stopped: return "stop.fill"
        }
    }

    private var isRunning: Bool {
        pomo.phase != .stopped && pomo.phase != .paused && pomo.startDate != nil
    }

    private var percentText: String {
        let p = progress(at: tick)
        return "\(Int((p * 100).rounded()))%"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ Фон внутри NavigationStack — не пропадёт
                pomoBackdrop

                ScrollView {
                    LazyVStack(spacing: 16) {

                        // =======================================================
                        // HERO
                        // =======================================================
                        GlassCard {
                            VStack(spacing: 14) {
                                HStack(spacing: 10) {
                                    Image(safeSystemName: phaseIcon, fallback: "circle")
                                        .foregroundStyle(DS.text(0.9))
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(DS.glassFill(0.10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(DS.brandSoftGradient)
                                                        .opacity(0.55)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s("pomodoro.hero.title"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(DS.text(0.65))
                                            .singleLine()

                                        Text(phaseTitle)
                                            .font(.title2.weight(.semibold))
                                            .foregroundStyle(DS.text(0.95))
                                            .singleLine()
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 6) {
                                        phaseStatusChip
                                        if pomo.round > 0 {
                                            chip(L10n.fmt("pomodoro.round", lang, pomo.round), systemImage: "circle.grid.2x2")
                                        }
                                    }
                                }

                                if let start = pomo.startDate, let end = pomo.endDate {
                                    let p = progress(at: tick)

                                    RingProgressView(progress: p)
                                        .transaction { $0.animation = nil }
                                        .frame(width: 210, height: 210)
                                        .padding(.top, 4)

                                    Text(timerInterval: start...end)
                                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(DS.text(0.95))
                                        .singleLine()

                                    FancyLinearProgressBar(progress: p, height: 12)

                                    HStack(spacing: 10) {
                                        chip(percentText, systemImage: "chart.bar.fill")
                                        chip(remainingText(start: start, end: end, now: tick), systemImage: "hourglass")
                                    }
                                    .padding(.top, 2)

                                } else if pomo.phase == .paused {
                                    VStack(spacing: 8) {
                                        Text(s("pomodoro.paused.title"))
                                            .font(.title3.weight(.medium))
                                            .foregroundStyle(DS.text(0.85))
                                            .singleLine()

                                        chip(s("pomodoro.paused.subtitle"), systemImage: "play.fill")
                                    }
                                    .padding(.vertical, 10)
                                } else {
                                    VStack(spacing: 8) {
                                        Text(s("pomodoro.ready.title"))
                                            .font(.title3.weight(.medium))
                                            .foregroundStyle(DS.text(0.85))
                                            .singleLine()

                                        chip(s("pomodoro.ready.subtitle"), systemImage: "bolt.fill")
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                        }

                        // =======================================================
                        // QUICK STARTS
                        // =======================================================
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    LippiSectionHeader(
                                        title: s("pomodoro.quick.title"),
                                        subtitle: s("pomodoro.quick.subtitle"),
                                        icon: "bolt.fill",
                                        accent: DS.accent
                                    )
                                    Spacer()
                                    chip(sortLabel, systemImage: "slider.horizontal.3")
                                        .padding(.top, 2)
                                }

                                HStack(spacing: 12) {
                                    Button { startFocus(25) } label: {
                                        Label("25", systemImage: "play.fill")
                                            .labelStyle(TightLabelStyle())
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LippiButtonStyle(kind: .primary))

                                    Button { startFocus(50) } label: {
                                        Text("50").singleLine().frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LippiButtonStyle(kind: .secondary))

                                    Button { pomo.startShortBreak() } label: {
                                        Label(s("pomodoro.quick.break"), systemImage: "cup.and.saucer")
                                            .labelStyle(TightLabelStyle())
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                                }
                            }
                        }

                        // =======================================================
                        // CUSTOM MINUTES
                        // =======================================================
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LippiSectionHeader(
                                    title: s("pomodoro.custom.title"),
                                    subtitle: s("pomodoro.custom.subtitle"),
                                    icon: "clock.badge",
                                    accent: Color(hex: 0x64D2FF)
                                )

                                HStack(spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(safeSystemName: "clock", fallback: "clock")
                                            .foregroundStyle(DS.text(0.75))

                                        TextField(s("pomodoro.custom.placeholder"), text: Binding(
                                            get: {
                                                if customMinutesText.isEmpty {
                                                    return String(Int(pomo.config.focusMinutes))
                                                }
                                                return customMinutesText
                                            },
                                            set: { customMinutesText = $0 }
                                        ))
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(DS.text(0.95))
                                        .monospacedDigit()
                                        .frame(width: 64)
                                        .singleLine()

                                        Text(s("pomodoro.custom.minutes_unit"))
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(DS.text(0.6))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                                    )

                                    Button {
                                        let minutes = resolvedCustomMinutes()
                                        pomo.config.focusMinutes = minutes
                                        startFocus(minutes)
                                        #if os(iOS)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
                                    } label: {
                                        Label(s("pomodoro.custom.start"), systemImage: "play.circle.fill")
                                            .labelStyle(TightLabelStyle())
                                    }
                                    .buttonStyle(LippiButtonStyle(kind: .primary))
                                }

                                Text(s("pomodoro.custom.range"))
                                    .font(.caption)
                                    .foregroundStyle(DS.text(0.55))
                                    .singleLine()
                            }
                        }

                        // =======================================================
                        // TRANSPORT
                        // =======================================================
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LippiSectionHeader(
                                    title: s("pomodoro.transport.title"),
                                    subtitle: s("pomodoro.transport.subtitle"),
                                    icon: "slider.horizontal.3",
                                    accent: Color(hex: 0x30D158)
                                )

                                HStack(spacing: 12) {
                                    Button(action: { pomo.pause() }) {
                                        Label(s("pomodoro.transport.pause"), systemImage: "pause.fill")
                                            .labelStyle(TightLabelStyle())
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(pomo.phase == .stopped || pomo.phase == .paused)
                                    .buttonStyle(LippiButtonStyle(kind: .secondary))

                                    Button(action: { pomo.resume() }) {
                                        Label(s("pomodoro.transport.resume"), systemImage: "play.fill")
                                            .labelStyle(TightLabelStyle())
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(pomo.phase != .paused)
                                    .buttonStyle(LippiButtonStyle(kind: .primary))

                                    Button(action: { pomo.stop() }) {
                                        Label(s("pomodoro.transport.stop"), systemImage: "stop.fill")
                                            .labelStyle(TightLabelStyle())
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(LippiButtonStyle(kind: .destructive))
                                }
                            }
                        }

                        // ✅ воздух под TabBar
                        Color.clear.frame(height: 84)
                    }
                    .padding(20)
                }
                .transaction { $0.animation = nil }
            }
            .navigationTitle(s("pomodoro.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)

            // ✅ нижний отступ под TabBar (на всякий, если скролл короткий)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 92) }

            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { t in
                guard scenePhase == .active else { return }
                guard isRunning else { return }
                tick = t
                guard let end = pomo.endDate else { return }
                if end <= t,
                   pomo.phase != .stopped,
                   pomo.phase != .paused,
                   pomo.startDate != nil {
                    guard lastHandledTimerEnd != end else { return }
                    lastHandledTimerEnd = end
                    PomodoroAlarmCenter.shared.start(phaseTitle: phaseTitle)
                    pomo.advance()
                }
            }
        }
    }

    // MARK: - Helpers

    private var phaseStatusChip: some View {
        Label(sortLabel, systemImage: phaseIcon)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        Capsule()
                            .fill(DS.brandSoftGradient)
                            .opacity(0.55)
                    )
            )
            .overlay(Capsule().stroke(DS.glassStroke(0.16), lineWidth: 1))
            .foregroundStyle(DS.text(0.9))
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.glassFill(0.10), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
            .foregroundStyle(DS.text(0.85))
    }

    private var sortLabel: String {
        sortByFocusModeLabel()
    }

    private func sortByFocusModeLabel() -> String {
        // лёгкая “деталь” без лишнего состояния: показывает состояние
        if pomo.phase == .focus { return s("pomodoro.phase.focus") }
        if pomo.phase == .shortBreak { return s("pomodoro.phase.short_break") }
        if pomo.phase == .longBreak { return s("pomodoro.phase.long_break_short") }
        if pomo.phase == .paused { return s("pomodoro.phase.paused") }
        return s("pomodoro.phase.stopped")
    }

    private func startFocus(_ minutes: Int) {
        pomo.startFocus(customMinutes: minutes)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    private func resolvedCustomMinutes() -> Int {
        let raw = Int(customMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Int(pomo.config.focusMinutes)
        return max(1, min(180, raw))
    }

    private func remainingText(start: Date, end: Date, now: Date) -> String {
        let total = end.timeIntervalSince(start)
        let left = max(end.timeIntervalSince(now), 0)
        if total <= 0 { return "0:00" }
        let mins = Int(left) / 60
        let secs = Int(left) % 60
        return L10n.fmt("pomodoro.remaining", lang, mins, secs)
    }

    private func titleForPhase(_ p: PomodoroPhase) -> String {
        switch p {
        case .focus: return s("pomodoro.phase.focus")
        case .shortBreak: return s("pomodoro.phase.short_break")
        case .longBreak: return s("pomodoro.phase.long_break")
        case .paused: return s("pomodoro.phase.paused")
        case .stopped: return s("pomodoro.phase.stopped")
        }
    }
}
