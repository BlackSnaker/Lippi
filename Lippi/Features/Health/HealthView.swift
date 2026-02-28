import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Health Section (breathing & recovery)
// =======================================================
struct HealthView: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(HealthVoicePreferences.isEnabledKey) private var voiceEnabled: Bool = HealthVoicePreferences.defaultEnabled
    @AppStorage(HealthVoicePreferences.autoSpeakKey) private var voiceAutoSpeak: Bool = HealthVoicePreferences.defaultAutoSpeak
    @AppStorage(HealthVoicePlaybackSpeed.storageKey) private var voiceSpeedRaw: String = HealthVoicePlaybackSpeed.defaultSpeed.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var analytics = BreathingAnalyticsStore()
    @StateObject private var voiceAssistant = HealthVoiceAssistant()

    @State private var selectedPreset: BreathingPreset = .balance
    @State private var isRunning = false
    @State private var phaseIndex = 0
    @State private var phaseProgress: CGFloat = 0
    @State private var cycleCount = 1
    @State private var runnerTask: Task<Void, Never>?
    @State private var sessionStartedAt: Date?
    @State private var activeSegmentStartedAt: Date?
    @State private var accumulatedSessionDuration: TimeInterval = 0
    @State private var didAutoNarrate = false

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var completedCycles: Int { max(0, cycleCount - 1) }
    private var analyticsSeries: [BreathingDayPoint] { analytics.weekSeries() }
    private var analyticsWeekMinutes: Int { analyticsSeries.reduce(0) { $0 + $1.minutes } }
    private var voiceSpeed: HealthVoicePlaybackSpeed {
        HealthVoicePlaybackSpeed(rawValue: voiceSpeedRaw) ?? .defaultSpeed
    }

    private var activeStep: BreathingStep {
        let steps = selectedPreset.steps
        guard !steps.isEmpty else { return BreathingStep(phase: .inhale, duration: 4) }
        let safeIndex = min(max(phaseIndex, 0), steps.count - 1)
        return steps[safeIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroCard
                        coachCard
                        analyticsCard
                        voiceAssistantCard
                        Color.clear.frame(height: 84)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L10n.tr(.tab_health, lang))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 92) }
        }
        .onAppear {
            tryAutoNarrationIfNeeded()
        }
        .onDisappear {
            didAutoNarrate = false
            voiceAssistant.stop()
            resetSession(haptic: false, saveAnalytics: true)
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active {
                pauseSession()
                voiceAssistant.stop()
            }
        }
        .onChange(of: voiceEnabled) { _, newValue in
            if !newValue {
                voiceAssistant.stop()
            }
        }
        .onChange(of: selectedPreset) { oldPreset, _ in
            let shouldResume = isRunning
            resetSession(haptic: false, saveAnalytics: true, persistedPreset: oldPreset)
            if shouldResume {
                startSession()
            }
        }
    }

    private var heroCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("break.breathing.title"),
                    subtitle: s("break.breathing.subtitle"),
                    icon: "lungs.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                Text(s("break.breathing.description"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    HealthMetricChip(
                        icon: "repeat",
                        title: s("break.breathing.cycle"),
                        value: "\(cycleCount)"
                    )
                    HealthMetricChip(
                        icon: "waveform.path.ecg",
                        title: s("break.breathing.rate"),
                        value: L10n.fmt("break.breathing.rate_value", lang, selectedPreset.breathsPerMinute)
                    )
                }
            }
        }
    }

    private var coachCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(BreathingPreset.allCases) { preset in
                        Button {
                            guard selectedPreset != preset else { return }
                            BreathingHaptics.tap()
                            selectedPreset = preset
                        } label: {
                            Text(preset.title(using: s))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .foregroundStyle(selectedPreset == preset ? Color.white : DS.text(0.82))
                                .background(
                                    Capsule()
                                        .fill(selectedPreset == preset ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.glassFill(0.05)))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedPreset == preset ? DS.glassStroke(0.22) : DS.glassStroke(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                BreathingCoachWidget(
                    phase: activeStep.phase,
                    progress: phaseProgress,
                    isRunning: isRunning,
                    phaseTitle: s(activeStep.phase.titleKey),
                    phaseHint: s(activeStep.phase.hintKey)
                )

                HStack(spacing: 10) {
                    Button {
                        if isRunning {
                            pauseSession()
                        } else {
                            startSession()
                        }
                    } label: {
                        Label(
                            isRunning ? s("break.breathing.button.pause") : s("break.breathing.button.start"),
                            systemImage: isRunning ? "pause.fill" : "play.fill"
                        )
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))

                    Button {
                        resetSession()
                    } label: {
                        Label(s("break.breathing.button.reset"), systemImage: "arrow.counterclockwise")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            }
        }
    }

    private var analyticsCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("health.analytics.title"),
                    subtitle: s("health.analytics.subtitle"),
                    icon: "chart.line.uptrend.xyaxis",
                    accent: Color(hex: 0x30D158)
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                    spacing: 8
                ) {
                    HealthMetricChip(
                        icon: "waveform.path.ecg.rectangle.fill",
                        title: s("health.analytics.sessions"),
                        value: "\(analytics.totalSessions)"
                    )
                    HealthMetricChip(
                        icon: "timer",
                        title: s("health.analytics.minutes"),
                        value: L10n.fmt("health.analytics.minutes_value", lang, analytics.totalMinutes)
                    )
                    HealthMetricChip(
                        icon: "repeat.circle.fill",
                        title: s("health.analytics.avg_cycles"),
                        value: "\(analytics.averageCycles)"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(s("health.analytics.this_week"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.text(0.66))
                        Spacer()
                        Text(L10n.fmt("health.analytics.minutes_value", lang, analyticsWeekMinutes))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.text(0.90))
                            .monospacedDigit()
                    }

                    BreathingWeekMiniChart(points: analyticsSeries, lang: lang)

                    if analytics.totalSessions == 0 {
                        Text(s("health.analytics.empty"))
                            .font(.caption)
                            .foregroundStyle(DS.text(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.12), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(safeSystemName: "clock.arrow.circlepath", fallback: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.82))

                    Text(s("health.analytics.last_session"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.66))

                    Spacer()

                    Text(lastSessionText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }

    private var voiceAssistantCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("health.voice.title"),
                    subtitle: s("health.voice.subtitle"),
                    icon: "speaker.wave.3.fill",
                    accent: Color(hex: 0x5AC8FA)
                )

                Text(s("health.voice.description"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(s("health.voice.recommendations_title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.66))

                    ForEach(Array(recommendationLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(DS.text(0.62))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)

                            Text(line)
                                .font(.caption)
                                .foregroundStyle(DS.text(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.12), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    Button {
                        speakAnalyticsReport()
                    } label: {
                        Label(
                            s("health.voice.button.play"),
                            systemImage: voiceAssistant.isSpeaking ? "waveform" : "play.fill"
                        )
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))
                    .disabled(!voiceEnabled)
                    .opacity(voiceEnabled ? 1 : 0.55)

                    Button {
                        voiceAssistant.stop()
                    } label: {
                        Label(s("health.voice.button.stop"), systemImage: "stop.fill")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                    .disabled(!voiceAssistant.isSpeaking)
                    .opacity(voiceAssistant.isSpeaking ? 1 : 0.70)
                }

                HStack(spacing: 8) {
                    Image(safeSystemName: voiceAssistant.isSpeaking ? "waveform.and.mic" : "mic.fill", fallback: "mic.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.84))

                    Text(voiceAssistant.isSpeaking ? s("health.voice.status.speaking") : s("health.voice.status.ready"))
                        .font(.caption)
                        .foregroundStyle(DS.text(0.66))

                    Spacer()

                    Text(voiceSpeed.title(lang))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.84))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.glassStroke(0.12), lineWidth: 1)
                )

                if !voiceEnabled {
                    Text(s("health.voice.disabled_hint"))
                        .font(.caption)
                        .foregroundStyle(DS.text(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var lastSessionText: String {
        guard let last = analytics.lastSession else {
            return s("health.analytics.empty")
        }
        return formatSessionDate(last.startedAt)
    }

    private var recommendationLines: [String] {
        if analytics.totalSessions == 0 {
            return [
                s("health.voice.recommendation.first_session"),
                s("health.voice.recommendation.short_cycle")
            ]
        }

        var lines: [String] = []

        if analyticsWeekMinutes < 12 {
            lines.append(s("health.voice.recommendation.weekly_minutes"))
        }

        if analytics.averageCycles < 5 {
            lines.append(s("health.voice.recommendation.extend_exhale"))
        }

        if let last = analytics.lastSession {
            let days = Calendar.current.dateComponents([.day], from: last.startedAt, to: .now).day ?? 0
            if days >= 2 {
                lines.append(s("health.voice.recommendation.regularity"))
            }
        }

        if lines.isEmpty {
            lines = [
                s("health.voice.recommendation.keep_it_up"),
                s("health.voice.recommendation.progressive")
            ]
        }

        return Array(lines.prefix(3))
    }

    private var voiceNarrationText: String {
        let recommendationsText = recommendationLines.joined(separator: " ")
        if analytics.totalSessions == 0 {
            return "\(s("health.voice.report.empty")) \(s("health.voice.report.recommendations_intro")) \(recommendationsText)"
        }

        let summary = L10n.fmt(
            "health.voice.report.summary",
            lang,
            analytics.totalSessions,
            analytics.totalMinutes,
            analytics.averageCycles
        )
        let weekly = L10n.fmt("health.voice.report.weekly", lang, analyticsWeekMinutes)
        let last = L10n.fmt("health.voice.report.last_session", lang, lastSessionText)
        return [summary, weekly, last, s("health.voice.report.recommendations_intro"), recommendationsText]
            .joined(separator: " ")
    }

    private func speakAnalyticsReport() {
        guard voiceEnabled else { return }
        voiceAssistant.speak(
            voiceNarrationText,
            language: lang,
            speed: voiceSpeed
        )
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.62)
        #endif
    }

    private func tryAutoNarrationIfNeeded() {
        guard voiceEnabled, voiceAutoSpeak, !didAutoNarrate else { return }
        didAutoNarrate = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            speakAnalyticsReport()
        }
    }

    private func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.localeIdentifier)
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func commitActiveSegmentIfNeeded() {
        guard let startedAt = activeSegmentStartedAt else { return }
        accumulatedSessionDuration += max(0, Date().timeIntervalSince(startedAt))
        activeSegmentStartedAt = nil
    }

    private func persistSessionIfNeeded(using preset: BreathingPreset) {
        let duration = accumulatedSessionDuration
        let cycles = completedCycles
        guard duration >= 10 || cycles > 0 else { return }
        analytics.recordSession(
            startedAt: sessionStartedAt ?? .now,
            duration: duration,
            completedCycles: cycles,
            preset: preset
        )
    }

    private func clearSessionTracking() {
        sessionStartedAt = nil
        activeSegmentStartedAt = nil
        accumulatedSessionDuration = 0
    }

    private func startSession() {
        guard !isRunning else { return }
        isRunning = true
        if sessionStartedAt == nil {
            sessionStartedAt = .now
        }
        activeSegmentStartedAt = .now
        BreathingHaptics.start()
        runLoop()
    }

    private func pauseSession(haptic: Bool = true) {
        guard isRunning else { return }
        commitActiveSegmentIfNeeded()
        isRunning = false
        runnerTask?.cancel()
        runnerTask = nil
        if haptic {
            BreathingHaptics.pause()
        }
    }

    private func resetSession(
        haptic: Bool = true,
        saveAnalytics: Bool = true,
        persistedPreset: BreathingPreset? = nil
    ) {
        if isRunning {
            pauseSession(haptic: false)
        } else {
            commitActiveSegmentIfNeeded()
        }

        if saveAnalytics {
            persistSessionIfNeeded(using: persistedPreset ?? selectedPreset)
        }

        isRunning = false
        runnerTask?.cancel()
        runnerTask = nil
        phaseIndex = 0
        phaseProgress = 0
        cycleCount = 1
        clearSessionTracking()

        if haptic {
            BreathingHaptics.reset()
        }
    }

    private func runLoop() {
        runnerTask?.cancel()

        let fps = reduceMotion ? 24.0 : 60.0
        let frameNanos = UInt64((1_000_000_000.0 / fps).rounded())

        runnerTask = Task { @MainActor in
            while !Task.isCancelled && self.isRunning {
                let steps = self.selectedPreset.steps
                guard !steps.isEmpty else { return }

                let safeIndex = min(max(self.phaseIndex, 0), steps.count - 1)
                if self.phaseIndex != safeIndex {
                    self.phaseIndex = safeIndex
                }

                let step = steps[safeIndex]
                BreathingHaptics.phase(step.phase)

                let totalFrames = max(1, Int((step.duration * fps).rounded()))
                let startFrame = min(totalFrames, max(0, Int((self.phaseProgress * CGFloat(totalFrames)).rounded())))

                if startFrame >= totalFrames {
                    self.phaseProgress = 0
                } else {
                    for frame in startFrame...totalFrames {
                        guard !Task.isCancelled && self.isRunning else { return }
                        self.phaseProgress = CGFloat(frame) / CGFloat(totalFrames)
                        if frame < totalFrames {
                            try? await Task.sleep(nanoseconds: frameNanos)
                        }
                    }
                }

                self.phaseProgress = 0
                if safeIndex + 1 >= steps.count {
                    self.phaseIndex = 0
                    self.cycleCount += 1
                    BreathingHaptics.cycle()
                } else {
                    self.phaseIndex = safeIndex + 1
                }
            }
        }
    }
}

private struct BreathingCoachWidget: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let phase: BreathingPhase
    let progress: CGFloat
    let isRunning: Bool
    let phaseTitle: String
    let phaseHint: String

    private var phaseProgress: CGFloat {
        reduceMotion ? (progress > 0 ? 1 : 0) : min(max(progress, 0), 1)
    }

    private var sphereScale: CGFloat {
        let minScale: CGFloat = 0.72
        let maxScale: CGFloat = 1.0

        switch phase {
        case .inhale:
            return minScale + (maxScale - minScale) * phaseProgress
        case .hold:
            return maxScale
        case .exhale:
            return maxScale - (maxScale - minScale) * phaseProgress
        case .rest:
            return minScale
        }
    }

    private var ringProgress: CGFloat {
        isRunning ? max(0.02, phaseProgress) : 0.02
    }

    private var accent: Color {
        switch phase {
        case .inhale:
            return Color(hex: 0x64D2FF)
        case .hold:
            return Color(hex: 0xFFD60A)
        case .exhale:
            return Color(hex: 0x30D158)
        case .rest:
            return Color(hex: 0xBF5AF2)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.22))
                    .blur(radius: 22)
                    .frame(width: 214, height: 214)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.95),
                                accent.opacity(0.38),
                                Color(dynamicDark: 0xFFFFFF, light: 0xF8FAFC, darkAlpha: 0.12, lightAlpha: 0.20)
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 124
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(DS.glassStroke(0.20), lineWidth: 1)
                    )
                    .frame(width: 188, height: 188)
                    .scaleEffect(sphereScale)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.30), accent, accent.opacity(0.30)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 214, height: 214)

                VStack(spacing: 4) {
                    Text(phaseTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DS.text(0.95))
                        .lineLimit(1)
                    Text(phaseHint)
                        .font(.footnote)
                        .foregroundStyle(DS.text(0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .padding(.vertical, 4)
        }
    }
}

private struct HealthMetricChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.84))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.text(0.60))
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.90))
                    .lineLimit(1)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.glassStroke(0.12), lineWidth: 1)
        )
    }
}

private struct BreathingWeekMiniChart: View {
    let points: [BreathingDayPoint]
    let lang: AppLang

    private var maxMinutes: Int {
        max(points.map(\.minutes).max() ?? 0, 1)
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }

    private func barHeight(for minutes: Int) -> CGFloat {
        let maxHeight: CGFloat = 62
        if minutes <= 0 { return 6 }
        return max(8, CGFloat(minutes) / CGFloat(maxMinutes) * maxHeight)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(points) { point in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(DS.glassFill(0.05))
                            .frame(width: 18, height: 62)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x64D2FF), Color(hex: 0x30D158)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 18, height: barHeight(for: point.minutes))
                    }

                    Text(dayFormatter.string(from: point.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.text(0.62))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BreathingDayPoint: Identifiable, Hashable {
    let date: Date
    let minutes: Int
    var id: Date { date }
}

private struct BreathingSessionEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let duration: TimeInterval
    let completedCycles: Int
    let presetRawValue: String

    init(
        id: UUID = UUID(),
        startedAt: Date,
        duration: TimeInterval,
        completedCycles: Int,
        presetRawValue: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.completedCycles = completedCycles
        self.presetRawValue = presetRawValue
    }
}

private final class BreathingAnalyticsStore: ObservableObject {
    @Published private(set) var sessions: [BreathingSessionEntry] = []

    private let fileURL: URL

    var totalSessions: Int { sessions.count }

    var totalMinutes: Int {
        let total = sessions.reduce(0) { $0 + $1.duration }
        return max(0, Int((total / 60).rounded()))
    }

    var averageCycles: Int {
        guard !sessions.isEmpty else { return 0 }
        let allCycles = sessions.reduce(0) { $0 + max(0, $1.completedCycles) }
        return Int((Double(allCycles) / Double(sessions.count)).rounded())
    }

    var lastSession: BreathingSessionEntry? {
        sessions.first
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.fileURL = (docs ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("breathing_sessions.json")
        load()
    }

    func recordSession(
        startedAt: Date,
        duration: TimeInterval,
        completedCycles: Int,
        preset: BreathingPreset
    ) {
        let clampedDuration = max(0, duration)
        guard clampedDuration >= 1 else { return }

        let entry = BreathingSessionEntry(
            startedAt: startedAt,
            duration: clampedDuration,
            completedCycles: max(0, completedCycles),
            presetRawValue: preset.rawValue
        )

        sessions.insert(entry, at: 0)
        if sessions.count > 1000 {
            sessions = Array(sessions.prefix(1000))
        }
        save()
    }

    func weekSeries(reference: Date = .now) -> [BreathingDayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)

        var days: [Date] = []
        days.reserveCapacity(7)
        for offset in (0..<7).reversed() {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                days.append(day)
            }
        }

        guard let firstDay = days.first else { return [] }

        var daySeconds: [Date: TimeInterval] = [:]
        for item in sessions {
            let day = calendar.startOfDay(for: item.startedAt)
            guard day >= firstDay else { continue }
            daySeconds[day, default: 0] += item.duration
        }

        return days.map { day in
            let minutes = max(0, Int((daySeconds[day, default: 0] / 60).rounded()))
            return BreathingDayPoint(date: day, minutes: minutes)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BreathingSessionEntry].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.startedAt > $1.startedAt }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(sessions) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}

private struct BreathingStep {
    let phase: BreathingPhase
    let duration: Double
}

private enum BreathingPhase: CaseIterable {
    case inhale
    case hold
    case exhale
    case rest

    var titleKey: String {
        switch self {
        case .inhale: return "break.breathing.phase.inhale"
        case .hold:   return "break.breathing.phase.hold"
        case .exhale: return "break.breathing.phase.exhale"
        case .rest:   return "break.breathing.phase.rest"
        }
    }

    var hintKey: String {
        switch self {
        case .inhale: return "break.breathing.hint.inhale"
        case .hold:   return "break.breathing.hint.hold"
        case .exhale: return "break.breathing.hint.exhale"
        case .rest:   return "break.breathing.hint.rest"
        }
    }
}

private enum BreathingPreset: String, CaseIterable, Identifiable {
    case balance
    case recovery

    var id: String { rawValue }

    var steps: [BreathingStep] {
        switch self {
        case .balance:
            return [
                BreathingStep(phase: .inhale, duration: 4),
                BreathingStep(phase: .hold, duration: 2),
                BreathingStep(phase: .exhale, duration: 4),
                BreathingStep(phase: .rest, duration: 2)
            ]
        case .recovery:
            return [
                BreathingStep(phase: .inhale, duration: 4),
                BreathingStep(phase: .hold, duration: 1),
                BreathingStep(phase: .exhale, duration: 6),
                BreathingStep(phase: .rest, duration: 3)
            ]
        }
    }

    var breathsPerMinute: Int {
        let cycleDuration = steps.reduce(0) { $0 + $1.duration }
        guard cycleDuration > 0 else { return 0 }
        return max(1, Int((60.0 / cycleDuration).rounded()))
    }

    func title(using resolver: (String) -> String) -> String {
        switch self {
        case .balance:
            return resolver("break.breathing.preset.balance")
        case .recovery:
            return resolver("break.breathing.preset.recovery")
        }
    }
}

private enum BreathingHaptics {
    static func start() {
        #if os(iOS)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let soft = UIImpactFeedbackGenerator(style: .soft)
        medium.impactOccurred(intensity: 0.92)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            soft.impactOccurred(intensity: 0.68)
        }
        #endif
    }

    static func pause() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.54)
        #endif
    }

    static func reset() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.58)
        #endif
    }

    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.45)
        #endif
    }

    static func phase(_ phase: BreathingPhase) {
        #if os(iOS)
        switch phase {
        case .inhale:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        case .hold:
            UISelectionFeedbackGenerator().selectionChanged()
        case .exhale:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.48)
        case .rest:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.34)
        }
        #endif
    }

    static func cycle() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.60)
        }
        #endif
    }
}
