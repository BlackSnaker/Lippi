// EyeHealthSection.swift
// Lippi — Раздел «Здоровье глаз»
// Зависимости: EyeExerciseStore, EyeExerciseGameView, GlassCard, TightLabelStyle, LippiButtonStyle, AnimatedBackground
// Дополнительно (необязательно): Charts (защищено canImport(Charts))

import SwiftUI
#if canImport(Charts)
import Charts
#endif

// =======================================================
// MARK: - Входная точка раздела
// =======================================================
public struct EyeHealthHomeView: View {
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var showGame = false
    @State private var showStats = false
    @State private var showSettings = false

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
    private var tPrimary: Color { DS.textPrimary }
    private var tSecondary: Color { DS.textSecondary }
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        header

                        // ——— Быстрый старт ———
                        quickStartCard

                        // ——— Прогресс ———
                        GlassCard(style: .lightweight) { progressBlock }

                        // ——— Достижения ———
                        GlassCard(style: .lightweight) { achievementsBlock }

                        // ——— Советы ———
                        GlassCard(style: .lightweight) { tipsBlock }

                        Color.clear.frame(height: 84)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(s("eye.home.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 92) }
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
    }

    // Header
    private var header: some View {
        GlassCard(padding: 16, cornerRadius: 22, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    LippiSectionHeader(
                        title: s("eye.home.header_title"),
                        subtitle: s("eye.home.header_subtitle"),
                        icon: "eye.fill",
                        accent: Color(hex: 0x30D158)
                    )
                    Spacer()
                    capsule(weekGoalLeft == 0 ? s("eye.home.goal_done") : L10n.fmt("eye.home.goal_left", lang, weekGoalLeft))
                        .padding(.top, 2)
                }

                HStack(spacing: 8) {
                    heroMetric(icon: "flame.fill", title: s("eye.home.metric_streak"), value: L10n.fmt("eye.home.days_short", lang, eye.dayStreak))
                    heroMetric(icon: "calendar", title: s("eye.home.metric_week"), value: "\(weekSessionsCount)/7")
                    heroMetric(icon: "trophy.fill", title: s("eye.home.metric_achievements"), value: "\(unlockedAchievementsCount)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(s("eye.home.week_activity"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tSecondary)
                            .singleLine()
                        Spacer()
                        Text("\(weekSessionsCount)/7")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tPrimary)
                            .monospacedDigit()
                    }

                    FancyLinearProgressBar(progress: weekProgress, height: 10)
                        .transaction { $0.animation = nil }

                    Text(
                        weekGoalLeft == 0
                        ? s("eye.home.goal_done_subtitle")
                        : L10n.fmt("eye.home.goal_remaining_subtitle", lang, weekGoalLeft)
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.text(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                )
            }
        }
    }

    private var quickStartCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    LippiSectionHeader(
                        title: s("eye.home.quick_title"),
                        subtitle: s("eye.home.quick_subtitle"),
                        icon: "bolt.fill",
                        accent: Color(hex: 0x64D2FF)
                    )
                    Spacer()
                    Button { showSettings = true } label: {
                        Label(s("eye.home.settings"), systemImage: "gearshape")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                    .padding(.top, 2)
                }

                Text(L10n.fmt("eye.home.quick_description", lang, eye.settings.targetsPerSession))
                    .font(.footnote)
                    .foregroundStyle(tSecondary)

                HStack(spacing: 8) {
                    quickBadge(title: s("eye.home.metric_week"), value: "\(weekSessionsCount)/7", systemImage: "calendar")
                    quickBadge(title: s("eye.home.metric_achievements"), value: "\(unlockedAchievementsCount)/\(totalAchievementsCount)", systemImage: "trophy.fill")
                }

                HStack(spacing: 12) {
                    Button { showGame = true } label: {
                        Label(s("eye.home.start_training"), systemImage: "play.fill")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))

                    Button { showStats = true } label: {
                        Label(s("eye.home.stats"), systemImage: "chart.line.uptrend.xyaxis")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            }
        }
    }

    private func heroMetric(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: icon, fallback: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.84))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    private func quickBadge(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: systemImage, fallback: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.84))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    // Прогресс (стрик, мини-график, итог по последней сессии)
    @ViewBuilder private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                LippiSectionHeader(
                    title: s("eye.home.progress_title"),
                    subtitle: s("eye.home.progress_subtitle"),
                    icon: "chart.bar.fill",
                    accent: Color(hex: 0x30D158)
                )
                Spacer()
                capsule(L10n.fmt("eye.home.streak_days", lang, eye.dayStreak))
                    .padding(.top, 2)
            }

            if let last = eye.history.first {
                let metricColumns = [GridItem(.adaptive(minimum: 118), spacing: 10)]
                LazyVGrid(columns: metricColumns, spacing: 10) {
                    statTile(title: s("eye.home.last"), value: "\(last.hits)/\(last.total)", sub: s("eye.home.hits"))
                    statTile(title: s("eye.home.avg_reaction"), value: ms(last.avgReaction), sub: nil)
                    statTile(title: s("eye.home.best_streak"), value: "\(last.bestStreak)", sub: s("eye.home.in_row"))
                }
            } else {
                HStack(spacing: 10) {
                    Image(safeSystemName: "sparkles", fallback: "sparkles")
                        .foregroundStyle(DS.text(0.84))
                    Text(s("eye.home.empty_training"))
                        .font(.footnote)
                        .foregroundStyle(tSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                )
            }

            HistoryMiniChart()
                .frame(height: 140)
                .padding(10)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                )
        }
    }

    private func ms(_ v: Double?) -> String {
        guard let v else { return s("eye.common.em_dash") }
        return L10n.fmt("eye.unit.ms", lang, Int((v*1000).rounded()))
    }

    private func statTile(title: String, value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(tSecondary)
                .singleLine()

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tPrimary)
                .singleLine()

            if let s = sub {
                Text(s)
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 78, alignment: .topLeading)
        .padding(10)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tSecondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(DS.glassFill(0.08), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.16), lineWidth: 1))
    }

    // Блок достижений
    @ViewBuilder private var achievementsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                LippiSectionHeader(
                    title: s("eye.home.achievements_title"),
                    subtitle: s("eye.home.achievements_subtitle"),
                    icon: "trophy.fill",
                    accent: Color(hex: 0xFF9F0A)
                )
                Spacer()
                capsule("\(unlockedAchievementsCount)/\(totalAchievementsCount)")
                    .padding(.top, 2)
            }
            Text(s("eye.home.achievements_hint"))
                .font(.footnote)
                .foregroundStyle(DS.textTertiary)
            AchievementsGrid().environmentObject(eye)
        }
    }

    // Советы (простые, без медицины)
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            LippiSectionHeader(
                title: s("eye.home.tips_title"),
                subtitle: s("eye.home.tips_subtitle"),
                icon: "lightbulb.fill",
                accent: Color(hex: 0xFFD60A)
            )
            Text(s("eye.home.tips_intro"))
                .font(.footnote)
                .foregroundStyle(DS.textTertiary)
            TipRow(icon: "clock", text: s("eye.home.tip_1"))
            TipRow(icon: "sun.max", text: s("eye.home.tip_2"))
            TipRow(icon: "eye", text: s("eye.home.tip_3"))
            TipRow(icon: "figure.walk", text: s("eye.home.tip_4"))
        }
    }
}

// =======================================================
// MARK: - Мини-график истории
// =======================================================
struct HistoryMiniChart: View {
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    var body: some View {
        #if canImport(Charts)
        if eye.history.isEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                )
                .overlay(
                    Text(s("eye.chart.empty"))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                )
        } else {
            let items = eye.history.prefix(20)
            Chart(Array(items.enumerated()), id: \.offset) { idx, h in
                if let v = h.avgReaction {
                    LineMark(x: .value(s("eye.chart.session"), items.count - idx), y: .value(s("eye.chart.seconds"), v))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .foregroundStyle(DS.brand)
                    PointMark(x: .value(s("eye.chart.session"), items.count - idx), y: .value(s("eye.chart.seconds"), v))
                        .symbolSize(24)
                        .foregroundStyle(DS.text(0.8))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(DS.text(0.10))
                    AxisValueLabel().foregroundStyle(DS.text(0.60)).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(DS.text(0.10))
                    AxisValueLabel().foregroundStyle(DS.text(0.60)).font(.caption2)
                }
            }
        }
        #else
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DS.glassFill(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
            )
            .overlay(
                Text(s("eye.chart.not_available")).font(.footnote).foregroundStyle(DS.textSecondary)
            )
        #endif
    }
}

// =======================================================
// MARK: - Достижения
// =======================================================
struct AchievementsGrid: View {
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(EyeAchievement.allCases) { a in
                let unlocked = eye.achievements.contains(a)
                let statusText = unlocked ? s("eye.achievement.unlocked") : s("eye.achievement.locked")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DS.glassFill(unlocked ? 0.16 : 0.08))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                                )
                            Image(systemName: unlocked ? "seal.fill" : "seal")
                                .foregroundStyle(unlocked ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.textTertiary))
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Spacer(minLength: 6)

                        Circle()
                            .fill(unlocked ? Color(hex: 0x30D158) : DS.glassStroke(0.18))
                            .frame(width: 8, height: 8)
                    }

                    Text(a.title(lang))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Text(statusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(unlocked ? DS.text(0.86) : DS.textSecondary)
                        .singleLine()
                }
                .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
                .padding(12)
                .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.screen)
                        )
                )
                .shadow(color: DS.depthShadow(0.10), radius: 4, x: 0, y: 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(a.title(lang)), \(statusText)"))
            }
        }
    }
}

// =======================================================
// MARK: - Вспомогательные UI
// =======================================================
private struct TipRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )

                Image(safeSystemName: icon, fallback: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.text(0.88))
            }
            .frame(width: 22, height: 22)

            Text(text)
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }
}

// =======================================================
// MARK: - Экран статистики
// =======================================================
struct EyeStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var eye: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    private let totalColumns = [GridItem(.adaptive(minimum: 132), spacing: 10)]
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)
                content
            }
            .navigationTitle(s("eye.stats.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(s("eye.common.done")) { dismiss() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
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
                GlassCard(style: .lightweight) { HistoryMiniChart().environmentObject(eye).frame(height: 180) }
                GlassCard(style: .lightweight) { totals }
                GlassCard(style: .lightweight) { sessionsList }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var totals: some View {
        let totalSessions = eye.history.count
        let totalHits = eye.history.reduce(0) { $0 + $1.hits }
        let totalMiss = eye.history.reduce(0) { $0 + $1.misses }
        let bestStreak = eye.history.map(\.bestStreak).max() ?? 0
        let avgReactionAll: Double? = {
            let arr = eye.history.compactMap { $0.avgReaction }
            guard !arr.isEmpty else { return nil }
            return arr.reduce(0,+) / Double(arr.count)
        }()

        return VStack(alignment: .leading, spacing: 12) {
            LippiSectionHeader(
                title: s("eye.stats.totals_title"),
                subtitle: s("eye.stats.totals_subtitle"),
                icon: "sum",
                accent: Color(hex: 0x64D2FF)
            )
            LazyVGrid(columns: totalColumns, spacing: 10) {
                stat(s("eye.stats.sessions"), "\(totalSessions)")
                stat(s("eye.stats.hits"), "\(totalHits)")
                stat(s("eye.stats.misses"), "\(totalMiss)")
                stat(s("eye.stats.best_streak"), "\(bestStreak)")
                stat(s("eye.stats.avg_reaction"), avgReactionAll.map { L10n.fmt("eye.unit.ms", lang, Int(($0*1000).rounded())) } ?? s("eye.common.em_dash"))
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            LippiSectionHeader(
                title: s("eye.stats.sessions_title"),
                subtitle: s("eye.stats.sessions_subtitle"),
                icon: "list.bullet",
                accent: Color(hex: 0x30D158)
            )
            if eye.history.isEmpty {
                Text(s("eye.stats.history_empty")).font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(eye.history) { h in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(h.mode.title(lang))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.textPrimary)
                            Spacer()
                            Text(h.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(DS.textTertiary)
                        }
                        HStack(spacing: 8) {
                            sessionTag(L10n.fmt("eye.stats.result", lang, h.hits, h.total))
                            sessionTag(L10n.fmt("eye.stats.misses_value", lang, h.misses))
                            sessionTag(L10n.fmt("eye.stats.streak_value", lang, h.bestStreak))
                            if let avg = h.avgReaction {
                                sessionTag(L10n.fmt("eye.stats.avg_value", lang, L10n.fmt("eye.unit.ms", lang, Int((avg*1000).rounded()))))
                            }
                        }
                    }
                    .padding(12)
                    .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func sessionTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DS.glassFill(0.08), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
            .singleLine()
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
                .padding(20)
            }
            .navigationTitle(t("eye.settings.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("eye.common.cancel")) { dismiss() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("eye.common.save")) { save() }
                        .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))
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
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }
}
