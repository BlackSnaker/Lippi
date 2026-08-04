// EyeHealthSection.swift
// Lippi — Раздел «Здоровье глаз»
// Зависимости: EyeExerciseStore, EyeExerciseGameView, GlassCard, TightLabelStyle, LippiButtonStyle, AnimatedBackground
// Дополнительно (необязательно): Charts (защищено canImport(Charts))

import SwiftUI
#if canImport(Charts)
import Charts
#endif

private struct EyeCameraFeatureChip: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.accent)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .padding(.horizontal, 5)
        .background(DS.glassFill(0.045), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(DS.glassStroke(0.09), lineWidth: 1)
        )
    }
}

// =======================================================
// MARK: - Входная точка раздела
// =======================================================
public struct EyeHealthHomeView: View {
    @EnvironmentObject private var eye: EyeExerciseStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage("lippi.eyeTechnologyIntro.seen.v1") private var hasSeenTechnologyIntro = false
    @State private var showGame = false
    @State private var showCameraGuide = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showTechnologyIntro = false
    @State private var didEvaluateTechnologyIntro = false

    private var totalSessions: Int { eye.history.count }
    private var weekSessionsCount: Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: .now) else { return totalSessions }
        return eye.history.filter { $0.date >= weekStart }.count
    }
    private var weekProgress: Double {
        min(max(Double(weekSessionsCount) / 7.0, 0), 1)
    }
    private var weekGoalLeft: Int { max(0, 7 - weekSessionsCount) }
    private var unlockedAchievementsCount: Int { eye.achievements.count }
    private var totalAchievementsCount: Int { EyeAchievement.allCases.count }
    private var achievementProgress: Double {
        guard totalAchievementsCount > 0 else { return 0 }
        return Double(unlockedAchievementsCount) / Double(totalAchievementsCount)
    }
    private var lastSession: EyeSessionHistory? { eye.history.first }
    private var lastAccuracy: Int {
        guard let lastSession, lastSession.total > 0 else { return 0 }
        return Int((Double(lastSession.hits) / Double(lastSession.total) * 100).rounded())
    }
    private var nextAchievement: EyeAchievement? {
        EyeAchievement.allCases.first { !eye.achievements.contains($0) }
    }
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroCard
                            .lippiMotionScene(0)

                        if let recommendation = healthEyeRecommendation {
                            healthEyeCard(recommendation)
                                .lippiMotionScene(1)
                        }

                        cameraComfortCard
                            .lippiMotionScene(2)

                        progressCard
                            .lippiMotionScene(3)

                        achievementsCard
                            .lippiMotionScene(4)

                        dailyTipCard
                            .lippiMotionScene(5)

                        Color.clear.frame(height: 84)
                    }
                    .lippiContentColumn()
                }
                .lippiScrollPerformance()
            }
            .navigationTitle(s("eye.home.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .clearNavBarBackgroundIfAvailable()
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
        }
        .sheet(isPresented: $showGame) {
            NavigationStack {
                EyeExerciseGameView()
                    .environmentObject(eye)
                    .navigationTitle(s("eye.home.trainer_title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showStats) { EyeStatsView().environmentObject(eye) }
        .sheet(isPresented: $showSettings) { EyeSettingsView().environmentObject(eye) }
        .fullScreenCover(isPresented: $showCameraGuide) {
            EyeComfortCameraView()
                .environmentObject(eye)
        }
        .fullScreenCover(isPresented: $showTechnologyIntro) {
            EyeTechnologyIntroView {
                hasSeenTechnologyIntro = true
                showTechnologyIntro = false
            }
        }
        .onAppear {
            guard !didEvaluateTechnologyIntro else { return }
            didEvaluateTechnologyIntro = true
            guard !hasSeenTechnologyIntro else { return }
            DispatchQueue.main.async { showTechnologyIntro = true }
        }
    }

    private var cameraComfortCard: some View {
        GlassCard(padding: 17, cornerRadius: 26, style: .lightweight, forceSystemGlass: false) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: 0x64D2FF).opacity(0.14))

                        Image(safeSystemName: "camera.viewfinder", fallback: "camera.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x64D2FF))
                    }
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.glassStroke(0.12), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("eye.camera.card_title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)

                        Text(s("eye.camera.card_subtitle"))
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Text(s("eye.camera.local_badge"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: 0x30D158))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(hex: 0x30D158).opacity(0.11), in: Capsule())
                }

                HStack(spacing: 8) {
                    EyeCameraFeatureChip(icon: "eye.fill", title: s("eye.camera.chip_tracking"))
                    EyeCameraFeatureChip(icon: "drop.fill", title: s("eye.camera.metric_redness"))
                    EyeCameraFeatureChip(icon: "moon.zzz.fill", title: s("eye.camera.metric_fatigue"))
                }

                Button { showCameraGuide = true } label: {
                    Label(s("eye.camera.start"), systemImage: "camera.fill")
                        .labelStyle(EyeActionLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true, forceSystemGlass: true))

                Button { showTechnologyIntro = true } label: {
                    Label(s("eye.intro.revisit"), systemImage: "sparkles.rectangle.stack.fill")
                        .labelStyle(EyeActionLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true, forceSystemGlass: true))
            }
        }
    }

    private var healthEyeRecommendation: HealthWellnessRecommendation? {
        guard healthKit.isEnabled,
              let recommendation = healthKit.recommendation,
              recommendation.suggestsEyeBreak else { return nil }
        return recommendation
    }

    private func healthEyeCard(_ recommendation: HealthWellnessRecommendation) -> some View {
        GlassCard(padding: 15, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 11) {
                    Image(safeSystemName: "heart.text.square.fill", fallback: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFF375F))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: 0xFF375F).opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("healthkit.eyes.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("healthkit.eyes.description"))
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    eye.settings.targetsPerSession = min(eye.settings.targetsPerSession, 12)
                    eye.settings.maxTimePerTarget = max(eye.settings.maxTimePerTarget, 3)
                    showGame = true
                } label: {
                    Label(s("healthkit.eyes.start"), systemImage: "eye.fill")
                        .labelStyle(EyeActionLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
            }
        }
    }

    // MARK: - Primary focus

    private var heroCard: some View {
        GlassCard(
            padding: 18,
            cornerRadius: 30,
            style: .full,
            forceSystemGlass: false
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: 0x30D158).opacity(0.14))

                        Image(safeSystemName: "eye.fill", fallback: "eye")
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x30D158))
                    }
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.glassStroke(0.13), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("eye.home.header_title"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)

                        Text(s("eye.home.header_subtitle"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button { showSettings = true } label: {
                        Image(safeSystemName: "gearshape", fallback: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(DS.glassFill(0.07), in: Circle())
                            .overlay(Circle().stroke(DS.glassStroke(0.12), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.96, opacity: 0.88))
                    .accessibilityLabel(Text(s("eye.home.settings")))
                }

                weeklyGoalSummary
                primaryActions
            }
        }
    }

    private var weeklyGoalSummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))

        return layout {
            EyeProgressRing(
                progress: weekProgress,
                value: "\(min(weekSessionsCount, 7))/7",
                caption: s("eye.home.metric_week"),
                tone: Color(hex: 0x30D158)
            )
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 10) {
                Text(weekGoalLeft == 0 ? s("eye.home.goal_done") : s("eye.home.week_activity"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    weekGoalLeft == 0
                    ? s("eye.home.goal_done_subtitle")
                    : L10n.fmt("eye.home.goal_remaining_subtitle", lang, weekGoalLeft)
                )
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    inlineMetric(
                        icon: "flame.fill",
                        value: L10n.fmt("eye.home.days_short", lang, eye.dayStreak),
                        title: s("eye.home.metric_streak"),
                        tone: Color(hex: 0xFF9F0A)
                    )
                    inlineMetric(
                        icon: "checkmark.circle.fill",
                        value: "\(totalSessions)",
                        title: s("eye.stats.sessions"),
                        tone: Color(hex: 0x64D2FF)
                    )
                }
            }
        }
        .padding(14)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
    }

    private func inlineMetric(icon: String, value: String, title: String, tone: Color) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            Button { showGame = true } label: {
                Label(s("eye.home.start_training"), systemImage: "play.fill")
                    .labelStyle(EyeActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))

            Button { showStats = true } label: {
                Label(s("eye.home.stats"), systemImage: "chart.line.uptrend.xyaxis")
                    .labelStyle(EyeActionLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
        }
    }

    // MARK: - Progress

    private var progressCard: some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .lightweight) {
            VStack(alignment: .leading, spacing: 16) {
                LippiSectionHeader(
                    title: s("eye.home.progress_title"),
                    subtitle: s("eye.home.progress_subtitle"),
                    icon: "scope",
                    accent: Color(hex: 0x64D2FF)
                )

                if let lastSession {
                    accuracyHighlight(for: lastSession)
                    supportingProgressMetrics(for: lastSession)
                } else {
                    emptyProgress
                }
            }
        }
    }

    private func accuracyHighlight(for session: EyeSessionHistory) -> some View {
        let progress = Double(lastAccuracy) / 100
        let tone = accuracyTone(progress)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))

        return layout {
            EyeProgressRing(
                progress: progress,
                value: "\(lastAccuracy)%",
                caption: s("eye.stats.accuracy"),
                tone: tone
            )
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 6) {
                Text(s("eye.home.last"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)

                Text(L10n.fmt("eye.stats.accuracy_detail", lang, session.hits, session.total))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(s("eye.stats.accuracy_hint"))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tone.opacity(0.13), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tone.opacity(0.16), lineWidth: 1)
        )
    }

    private func supportingProgressMetrics(for session: EyeSessionHistory) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            supportingProgressMetric(
                icon: "timer",
                title: s("eye.home.avg_reaction"),
                value: milliseconds(session.avgReaction),
                tone: Color(hex: 0x64D2FF)
            )
            supportingProgressMetric(
                icon: "flame.fill",
                title: s("eye.home.best_streak"),
                value: "\(session.bestStreak)",
                tone: Color(hex: 0xFF9F0A)
            )
        }
    }

    private func supportingProgressMetric(icon: String, title: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(safeSystemName: icon, fallback: "circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tone)
                    .frame(width: 36, height: 36)
                    .background(tone.opacity(0.12), in: Circle())

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(14)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.glassStroke(0.09), lineWidth: 1)
        )
    }

    private func accuracyTone(_ progress: Double) -> Color {
        if progress >= 0.85 { return Color(hex: 0x30D158) }
        if progress >= 0.60 { return Color(hex: 0xFF9F0A) }
        return Color(hex: 0xFF453A)
    }

    private var emptyProgress: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(safeSystemName: "sparkles", fallback: "eye")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x64D2FF))
                .frame(width: 40, height: 40)
                .background(Color(hex: 0x64D2FF).opacity(0.12), in: Circle())

            Text(s("eye.home.empty_training"))
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Milestones and care

    private var achievementsCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("eye.home.achievements_title"),
                    subtitle: s("eye.home.achievements_subtitle"),
                    icon: "trophy.fill",
                    accent: Color(hex: 0xFF9F0A)
                )

                HStack(alignment: .firstTextBaseline) {
                    Text("\(unlockedAchievementsCount)/\(totalAchievementsCount)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(DS.textPrimary)

                    Spacer()

                    Text(achievementSummaryText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FancyLinearProgressBar(progress: achievementProgress, height: 8)
                    .transaction { $0.animation = nil }

                HStack(spacing: 8) {
                    ForEach(EyeAchievement.allCases) { achievement in
                        achievementDot(achievement)
                    }
                }
            }
        }
    }

    private var achievementSummaryText: String {
        if let nextAchievement {
            return L10n.fmt("eye.home.next_achievement", lang, nextAchievement.title(lang))
        }
        return s("eye.home.all_achievements_done")
    }

    private func achievementDot(_ achievement: EyeAchievement) -> some View {
        let isUnlocked = eye.achievements.contains(achievement)

        return ZStack {
            Circle()
                .fill(isUnlocked ? Color(hex: 0xFF9F0A).opacity(0.16) : DS.glassFill(0.055))

            Image(safeSystemName: isUnlocked ? "checkmark" : "lock.fill", fallback: "circle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isUnlocked ? Color(hex: 0xFF9F0A) : DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .overlay(Circle().stroke(DS.glassStroke(isUnlocked ? 0.15 : 0.08), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(achievement.title(lang)))
        .accessibilityValue(Text(isUnlocked ? s("eye.achievement.unlocked") : s("eye.achievement.locked")))
    }

    private var dailyTipCard: some View {
        let tip = dailyTip

        return GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            HStack(alignment: .top, spacing: 14) {
                Image(safeSystemName: tip.icon, fallback: "lightbulb.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD60A))
                    .frame(width: 42, height: 42)
                    .background(Color(hex: 0xFFD60A).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(s("eye.home.tip_of_day"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text(tip.text)
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var dailyTip: (icon: String, text: String) {
        let tips = [
            ("clock", s("eye.home.tip_1")),
            ("sun.max.fill", s("eye.home.tip_2")),
            ("eye.fill", s("eye.home.tip_3")),
            ("figure.walk", s("eye.home.tip_4"))
        ]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return tips[(day - 1) % tips.count]
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value else { return s("eye.common.em_dash") }
        return L10n.fmt("eye.unit.ms", lang, Int((value * 1000).rounded()))
    }
}

private struct EyeActionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            configuration.icon
            configuration.title
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EyeProgressRing: View {
    let progress: Double
    let value: String
    let caption: String
    let tone: Color

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.glassStroke(0.10), lineWidth: 10)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(colors: [tone.opacity(0.60), tone, DS.brandB], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)

                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(15)
        }
        .accessibilityElement(children: .combine)
    }
}

// =======================================================
// MARK: - Мини-график истории
// =======================================================
struct HistoryMiniChart: View {
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    let showsAxes: Bool

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    init(showsAxes: Bool = true) {
        self.showsAxes = showsAxes
    }

    var body: some View {
        #if canImport(Charts)
        if eye.history.isEmpty {
            emptyState(text: s("eye.chart.empty"))
        } else {
            let items = Array(eye.history.prefix(12).reversed())
            Chart(Array(items.enumerated()), id: \.offset) { idx, h in
                if let v = h.avgReaction {
                    let milliseconds = v * 1000

                    AreaMark(
                        x: .value(s("eye.chart.session"), idx + 1),
                        y: .value(s("eye.stats.avg_reaction"), milliseconds)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x64D2FF).opacity(0.22), Color(hex: 0x64D2FF).opacity(0.015)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value(s("eye.chart.session"), idx + 1),
                        y: .value(s("eye.stats.avg_reaction"), milliseconds)
                    )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color(hex: 0x64D2FF))

                    if idx == items.count - 1 {
                        PointMark(
                            x: .value(s("eye.chart.session"), idx + 1),
                            y: .value(s("eye.stats.avg_reaction"), milliseconds)
                        )
                        .symbolSize(46)
                        .foregroundStyle(Color(hex: 0x64D2FF))
                    }
                }
            }
            .chartXAxis {
                if showsAxes {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel()
                            .foregroundStyle(DS.textTertiary)
                            .font(.caption2)
                    }
                }
            }
            .chartYAxis {
                if showsAxes {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(DS.glassStroke(0.08))
                        AxisValueLabel()
                            .foregroundStyle(DS.textTertiary)
                            .font(.caption2)
                    }
                }
            }
            .chartPlotStyle { plot in
                plot
                    .background(DS.glassFill(0.025))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        #else
        emptyState(text: s("eye.chart.not_available"))
        #endif
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 8) {
            Image(safeSystemName: "chart.line.uptrend.xyaxis", fallback: "chart.bar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0x64D2FF))

            Text(text)
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.glassFill(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// =======================================================
// MARK: - Экран статистики
// =======================================================
struct EyeStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var totalSessions: Int { eye.history.count }
    private var totalHits: Int { eye.history.reduce(0) { $0 + $1.hits } }
    private var totalMisses: Int { eye.history.reduce(0) { $0 + $1.misses } }
    private var totalAttempts: Int { totalHits + totalMisses }
    private var accuracyProgress: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalHits) / Double(totalAttempts)
    }
    private var accuracyPercent: Int { Int((accuracyProgress * 100).rounded()) }
    private var bestStreak: Int { eye.history.map(\.bestStreak).max() ?? 0 }
    private var averageReaction: Double? {
        let values = eye.history.compactMap(\.avgReaction)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)
                content
            }
            .navigationTitle(s("eye.stats.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .clearNavBarBackgroundIfAvailable()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(s("eye.common.done")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 16)
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                summaryCard
                    .lippiMotionScene(0)

                chartCard
                    .lippiMotionScene(1)

                sessionsCard
                    .lippiMotionScene(2)
            }
            .lippiContentColumn()
        }
        .scrollIndicators(.hidden)
        .lippiScrollPerformance()
    }

    private var summaryCard: some View {
        GlassCard(
            padding: 18,
            cornerRadius: 28,
            style: .full,
            forceSystemGlass: false
        ) {
            VStack(alignment: .leading, spacing: 16) {
                LippiSectionHeader(
                    title: s("eye.stats.totals_title"),
                    subtitle: s("eye.stats.totals_subtitle"),
                    icon: "scope",
                    accent: Color(hex: 0x30D158)
                )

                accuracySummary
                overviewMetrics
            }
        }
    }

    private var accuracySummary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))

        return layout {
            EyeProgressRing(
                progress: accuracyProgress,
                value: "\(accuracyPercent)%",
                caption: s("eye.stats.accuracy"),
                tone: Color(hex: 0x30D158)
            )
            .frame(width: 124, height: 124)

            VStack(alignment: .leading, spacing: 7) {
                Text(s("eye.stats.accuracy"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Text(L10n.fmt("eye.stats.accuracy_detail", lang, totalHits, totalAttempts))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                FancyLinearProgressBar(progress: accuracyProgress, height: 8)
                    .transaction { $0.animation = nil }

                Text(s("eye.stats.accuracy_hint"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
    }

    private var overviewMetrics: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            overviewMetric(
                icon: "checkmark.circle.fill",
                title: s("eye.stats.sessions"),
                value: "\(totalSessions)",
                tone: Color(hex: 0x64D2FF)
            )
            overviewMetric(
                icon: "timer",
                title: s("eye.stats.avg_reaction"),
                value: milliseconds(averageReaction),
                tone: Color(hex: 0xAF52DE)
            )
            overviewMetric(
                icon: "flame.fill",
                title: s("eye.stats.best_streak"),
                value: "\(bestStreak)",
                tone: Color(hex: 0xFF9F0A)
            )
        }
    }

    private func overviewMetric(icon: String, title: String, value: String, tone: Color) -> some View {
        HStack(spacing: 9) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 30, height: 30)
                .background(tone.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
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
        .padding(10)
        .background(DS.glassFill(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chartCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("eye.stats.reaction_title"),
                    subtitle: s("eye.stats.reaction_subtitle"),
                    icon: "waveform.path.ecg",
                    accent: Color(hex: 0x64D2FF)
                )

                HistoryMiniChart(showsAxes: true)
                    .environmentObject(eye)
                    .frame(height: 200)
            }
        }
    }

    private var sessionsCard: some View {
        let recentSessions = Array(eye.history.prefix(30))

        return GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("eye.stats.sessions_title"),
                    subtitle: s("eye.stats.sessions_subtitle"),
                    icon: "list.bullet",
                    accent: Color(hex: 0x30D158)
                )

                if recentSessions.isEmpty {
                    Text(s("eye.stats.history_empty"))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                } else {
                    ForEach(recentSessions) { session in
                        sessionRow(session)

                        if session.id != recentSessions.last?.id {
                            Divider().overlay(DS.glassStroke(0.08))
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: EyeSessionHistory) -> some View {
        let progress = session.total > 0 ? Double(session.hits) / Double(session.total) : 0
        let percent = Int((progress * 100).rounded())
        let metricLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 7))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(safeSystemName: modeIcon(session.mode), fallback: "eye")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x64D2FF))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0x64D2FF).opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.mode.title(lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("\(percent)%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(accuracyTone(progress))
            }

            FancyLinearProgressBar(progress: progress, height: 6)
                .transaction { $0.animation = nil }

            metricLayout {
                sessionMetric(title: s("eye.stats.hits"), value: "\(session.hits)/\(session.total)")
                sessionMetric(title: s("eye.stats.misses"), value: "\(session.misses)")
                sessionMetric(title: s("eye.stats.avg_reaction"), value: milliseconds(session.avgReaction))
            }

            if let report = session.healthAnalysis {
                HStack(alignment: .top, spacing: 9) {
                    Image(safeSystemName: report.source == .bonsai ? "sparkles" : "eye.fill", fallback: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(analysisTone(report.level))

                    Text(report.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    Text(L10n.fmt("eye.analysis.rest", lang, report.restMinutes))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(DS.glassFill(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func sessionMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accuracyTone(_ progress: Double) -> Color {
        if progress >= 0.85 { return Color(hex: 0x30D158) }
        if progress >= 0.60 { return Color(hex: 0xFF9F0A) }
        return Color(hex: 0xFF453A)
    }

    private func analysisTone(_ level: EyeHealthComfortLevel) -> Color {
        switch level {
        case .comfortable: return Color(hex: 0x30D158)
        case .gentleRest: return Color(hex: 0xFF9F0A)
        case .extendedRest: return Color(hex: 0xFF453A)
        case .limitedReading: return Color(hex: 0x64D2FF)
        }
    }

    private func modeIcon(_ mode: EyeGameMode) -> String {
        switch mode {
        case .classic: return "scope"
        case .moving: return "move.3d"
        case .color: return "paintpalette.fill"
        case .peripheral: return "viewfinder"
        case .tracking: return "eye.trianglebadge.exclamationmark"
        }
    }

    private func milliseconds(_ value: Double?) -> String {
        guard let value else { return s("eye.common.em_dash") }
        return L10n.fmt("eye.unit.ms", lang, Int((value * 1000).rounded()))
    }
}

// =======================================================
// MARK: - Экран настроек
// =======================================================
struct EyeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    @State private var s: EyeExerciseSettings = .init()
    @State private var didEdit = false
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func t(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.profile_title"),
                                    subtitle: t("eye.settings.profile_subtitle"),
                                    icon: "eye.fill",
                                    accent: Color(hex: 0x64D2FF)
                                )

                                HStack(spacing: 8) {
                                    settingChip(L10n.fmt("eye.settings.targets_value", lang, s.targetsPerSession), icon: "target")
                                    settingChip(L10n.fmt("eye.settings.seconds_short_value", lang, String(format: "%.1f", s.maxTimePerTarget)), icon: "timer")
                                    settingChip("\(Int(s.dotSize)) pt", icon: "circle.fill")
                                }
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.session_title"),
                                    subtitle: t("eye.settings.session_subtitle"),
                                    icon: "scope",
                                    accent: Color(hex: 0x30D158)
                                )

                                settingStepperRow(
                                    icon: "target",
                                    title: t("eye.settings.targets_per_session"),
                                    valueText: "\(s.targetsPerSession)"
                                ) {
                                    Stepper("", value: $s.targetsPerSession, in: 6...60, step: 2).labelsHidden()
                                }

                                settingSliderRow(
                                    icon: "timer",
                                    title: t("eye.settings.time_per_target"),
                                    valueText: L10n.fmt("eye.settings.seconds_short_value", lang, String(format: "%.1f", s.maxTimePerTarget))
                                ) {
                                    Slider(value: $s.maxTimePerTarget, in: 0.6...5, step: 0.1)
                                }

                                settingSliderRow(
                                    icon: "circle.grid.2x2.fill",
                                    title: t("eye.settings.dot_size"),
                                    valueText: "\(Int(s.dotSize)) pt"
                                ) {
                                    Slider(value: $s.dotSize, in: 18...60, step: 1)
                                }
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.adaptive_title"),
                                    subtitle: t("eye.settings.adaptive_subtitle"),
                                    icon: "chart.line.uptrend.xyaxis",
                                    accent: Color(hex: 0xBF5AF2)
                                )

                                settingToggleRow(
                                    icon: "wand.and.stars",
                                    title: t("eye.settings.adaptive_toggle"),
                                    subtitle: t("eye.settings.adaptive_toggle_subtitle"),
                                    isOn: $s.enableAdaptive
                                )

                                settingStepperRow(
                                    icon: "repeat",
                                    title: t("eye.settings.adaptive_step"),
                                    valueText: L10n.fmt("eye.settings.adaptive_step_value", lang, s.adaptiveStepEvery)
                                ) {
                                    Stepper("", value: $s.adaptiveStepEvery, in: 1...5).labelsHidden()
                                }

                                settingSliderRow(
                                    icon: "minimize",
                                    title: t("eye.settings.min_size"),
                                    valueText: "×\(String(format: "%.1f", s.minDotScale))"
                                ) {
                                    Slider(value: $s.minDotScale, in: 0.4...1, step: 0.05)
                                }

                                settingSliderRow(
                                    icon: "hourglass",
                                    title: t("eye.settings.min_time"),
                                    valueText: "×\(String(format: "%.1f", s.minTimeScale))"
                                ) {
                                    Slider(value: $s.minTimeScale, in: 0.3...1, step: 0.05)
                                }
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.modes_title"),
                                    subtitle: t("eye.settings.modes_subtitle"),
                                    icon: "square.grid.2x2.fill",
                                    accent: Color(hex: 0x5AC8FA)
                                )

                                settingToggleRow(icon: "move.3d", title: t("eye.mode.moving"), isOn: $s.enableMoving)
                                settingToggleRow(icon: "paintpalette.fill", title: t("eye.mode.color"), isOn: $s.enableColor)
                                settingToggleRow(icon: "circle.lefthalf.filled", title: t("eye.mode.peripheral"), isOn: $s.enablePeripheral)
                                settingToggleRow(icon: "dot.scope", title: t("eye.mode.tracking"), isOn: $s.enableTracking)
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.breaks_title"),
                                    subtitle: t("eye.settings.breaks_subtitle"),
                                    icon: "cup.and.saucer.fill",
                                    accent: Color(hex: 0xFF9F0A)
                                )

                                settingToggleRow(
                                    icon: "bell.badge.fill",
                                    title: t("eye.settings.breaks_toggle"),
                                    subtitle: t("eye.settings.breaks_toggle_subtitle"),
                                    isOn: $s.enableBreaks
                                )

                                settingStepperRow(
                                    icon: "number",
                                    title: t("eye.settings.breaks_frequency"),
                                    valueText: L10n.fmt("eye.settings.breaks_frequency_value", lang, s.breakAfterTargets)
                                ) {
                                    Stepper("", value: $s.breakAfterTargets, in: 4...30, step: 2).labelsHidden()
                                }

                                settingStepperRow(
                                    icon: "timer",
                                    title: t("eye.settings.breaks_duration"),
                                    valueText: L10n.fmt("eye.settings.seconds_value", lang, s.breakDurationSec)
                                ) {
                                    Stepper("", value: $s.breakDurationSec, in: 10...60, step: 5).labelsHidden()
                                }
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.auto_title"),
                                    subtitle: t("eye.settings.auto_subtitle"),
                                    icon: "sparkles",
                                    accent: Color(hex: 0x30D158)
                                )

                                settingToggleRow(
                                    icon: "eye.fill",
                                    title: t("eye.settings.auto_toggle"),
                                    subtitle: t("eye.settings.auto_toggle_subtitle"),
                                    isOn: $s.autoSuggestEnabled
                                )

                                settingStepperRow(
                                    icon: "clock.badge.checkmark",
                                    title: t("eye.settings.auto_threshold"),
                                    valueText: L10n.fmt("settings.unit.minutes", lang, s.suggestThresholdMinutes)
                                ) {
                                    Stepper("", value: $s.suggestThresholdMinutes, in: 20...120, step: 5).labelsHidden()
                                }

                                settingStepperRow(
                                    icon: "gobackward",
                                    title: t("eye.settings.auto_cooldown"),
                                    valueText: L10n.fmt("settings.unit.minutes", lang, s.cooldownMinutes)
                                ) {
                                    Stepper("", value: $s.cooldownMinutes, in: 15...180, step: 5).labelsHidden()
                                }
                            }
                        }

                        GlassCard(style: .lightweight) {
                            VStack(alignment: .leading, spacing: 10) {
                                LippiSectionHeader(
                                    title: t("eye.settings.feedback_title"),
                                    subtitle: t("eye.settings.feedback_subtitle"),
                                    icon: "waveform",
                                    accent: Color(hex: 0xFF453A)
                                )

                                settingToggleRow(icon: "speaker.wave.2.fill", title: t("eye.settings.sound"), isOn: $s.soundEnabled)
                                settingToggleRow(icon: "iphone.radiowaves.left.and.right", title: t("eye.settings.haptics"), isOn: $s.hapticsEnabled)
                            }
                        }

                        Color.clear.frame(height: 96)
                    }
                }
                .scrollIndicators(.hidden)
                .lippiScrollPerformance()
                .lippiContentColumn()
            }
            .navigationTitle(t("eye.settings.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .clearNavBarBackgroundIfAvailable()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("eye.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("eye.common.save")) { save() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        save()
                    } label: {
                        Label(t("eye.settings.save_settings"), systemImage: "checkmark.seal.fill")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))
                    .opacity(didEdit ? 1 : 0.84)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(DS.glassFill(0.12))
                        .opacity(0.16)
                        .ignoresSafeArea()
                )
                .lippiSystemGlass(
                    in: Rectangle(),
                    tint: DS.accent.opacity(0.05),
                    prominent: true
                )
            }
            .onAppear { s = eye.settings }
            .onChange(of: s) { _, _ in didEdit = true }
        }
    }

    private func save() {
        eye.settings = s
        didEdit = false
        dismiss()
    }

    private func settingChip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.text(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.glassFill(0.10), in: Capsule())
            .lippiSystemGlass(
                in: Capsule(),
                tint: DS.accent.opacity(0.07)
            )
            .overlay(Capsule().stroke(DS.glassStroke(0.15), lineWidth: 1))
    }

    private func settingToggleRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.84))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(DS.text(0.93))
                    .singleLine()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DS.text(0.62))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            tint: DS.accent.opacity(0.07),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private func settingStepperRow<Control: View>(
        icon: String,
        title: String,
        valueText: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.84))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(DS.text(0.93))
                    .singleLine()
                Text(valueText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.text(0.64))
                    .singleLine()
            }

            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            tint: DS.accent.opacity(0.07),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private func settingSliderRow<SliderView: View>(
        icon: String,
        title: String,
        valueText: String,
        @ViewBuilder slider: () -> SliderView
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(safeSystemName: icon, fallback: icon)
                    .foregroundStyle(DS.text(0.84))
                    .frame(width: 22, height: 22)

                Text(title)
                    .foregroundStyle(DS.text(0.93))
                    .singleLine()

                Spacer(minLength: 8)

                Text(valueText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.70))
                    .monospacedDigit()
            }

            slider()
                .tint(DS.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            tint: DS.accent.opacity(0.07),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }
}
