import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - TODAY (with transparent nav bar)
// =======================================================
struct TodayView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var stats: StatsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var showAdd = false
    @State private var showImportantNow = false
    @State private var showStats = false
    @Binding var showGoalPlanner: Bool

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var taskOverview: TodayTaskOverview { store.todayOverview() }
    private var activeTasksCount: Int { taskOverview.active.count }
    private var completedTodayCount: Int { stats.today.tasksDone }
    private var focusedMinutesToday: Int { stats.today.focusMinutes }
    private var productiveStreak: Int { stats.productiveStreak }
    private var overdueTasks: [TaskItem] { taskOverview.overdue }
    private var dueTodayTasks: [TaskItem] { taskOverview.dueToday }
    private var upcomingTasks: [TaskItem] { taskOverview.upcoming }
    private var overdueTasksCount: Int { overdueTasks.count }
    private var dueTodayCount: Int { dueTodayTasks.count }
    private var completionProgress: Double {
        let todayWorkload = max(activeTasksCount + completedTodayCount, 1)
        return min(max(Double(completedTodayCount) / Double(todayWorkload), 0), 1)
    }
    private var completionPercent: Int { Int((completionProgress * 100).rounded()) }
    private var priorityTask: TaskItem? {
        if let overdue = upcomingTasks.first(where: { ($0.dueDate ?? .distantFuture) < .now }) {
            return overdue
        }
        if let today = upcomingTasks.first(where: { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }) {
            return today
        }
        return upcomingTasks.first
    }
    private var hasUpcomingTask: Bool { priorityTask != nil }
    private var todayStatusText: String {
        if activeTasksCount == 0 && completedTodayCount > 0 { return s("today.status.clear") }
        if activeTasksCount == 0 { return s("today.status.empty") }
        if overdueTasksCount > 0 { return L10n.fmt("today.status.overdue", lang, overdueTasksCount) }
        if completedTodayCount == 0 { return s("today.status.start") }
        return L10n.fmt("today.status.progress", lang, completionPercent)
    }

    private var appLocale: Locale { Locale(identifier: lang.rawValue) }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return s("today.greeting.morning")
        case 12..<18: return s("today.greeting.day")
        default: return s("today.greeting.evening")
        }
    }

    private var todayBackdrop: some View {
        AppBackdrop()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                todayBackdrop

                ScrollView {
                    LazyVStack(spacing: 16) {
                        headerCard
                        todayPlanCard
                            .lippiMotionScene(1)
                        quickActions
                            .lippiMotionScene(2)
                        smartGoalsEntry
                        statsSummaryEntry
                            .lippiMotionScene(4)
                    }
                    .lippiContentColumn()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("today.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .clearNavBarBackgroundIfAvailable()
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        smartGoalsToolbarButton
                            .buttonStyle(.glass)

                        addTaskToolbarButton
                            .buttonStyle(.glass)
                    }
                    .sharedBackgroundVisibility(.visible)
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        smartGoalsToolbarButton
                        addTaskToolbarButton
                    }
                }
            }
            // ✅ Нижний отступ под TabBar (чтобы контент не уходил под него)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }
            .sheet(isPresented: $showAdd) {
                AddEditTaskView { store.add($0) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showImportantNow) {
                importantNowSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStats) {
                statsSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        // ✅ Убираем системный фон NavigationStack “на всякий”
        .background(Color.clear)
    }

    // MARK: - Subviews
    private var smartGoalsToolbarButton: some View {
        Button { showGoalPlanner = true } label: {
            Image(safeSystemName: "wand.and.stars", fallback: "sparkles")
        }
        .accessibilityLabel(s("goals.nav_title"))
        .accessibilityHint(s("goals.entry.subtitle"))
    }

    private var addTaskToolbarButton: some View {
        Button { showAdd = true } label: {
            Image(safeSystemName: "plus", fallback: "plus.circle.fill")
        }
        .accessibilityLabel(s("today.toolbar.new_task"))
    }

    private var headerCard: some View {
        GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 16) {
                greetingHero

                Divider()
                    .overlay(DS.glassStroke(0.10))

                focusSummaryPanel

                Divider()
                    .overlay(DS.glassStroke(0.10))

                dailySnapshotStrip
            }
        }
        .lippiMagicAppear(delay: 0.03, y: 14, scale: 0.975)
    }

    private var greetingHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    greetingBlock
                    Spacer(minLength: 0)
                    dayProgressBadge
                }

                VStack(alignment: .leading, spacing: 10) {
                    greetingBlock
                    dayProgressBadge
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            dayBriefingButton
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(safeSystemName: "calendar", fallback: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)

                Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
            }

            Text(greetingTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(2)
        }
    }

    private var dayBriefingButton: some View {
        Button {
            showImportantNow = true
        } label: {
            HStack(spacing: 11) {
                Image(safeSystemName: statusSymbol, fallback: "sparkles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusTone)
                    .frame(width: 30, height: 30)
                    .background(statusTone.opacity(0.13), in: Circle())

                Text(todayStatusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 24, height: 44)
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(statusTone.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DS.glassStroke(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.988, opacity: 0.96))
        .accessibilityHint(Text(s("today.summary.title")))
    }

    private var smartGoalsEntry: some View {
        Button {
            showGoalPlanner = true
        } label: {
            GlassCard(padding: 15, cornerRadius: 22, style: .flat) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.accent.opacity(0.14))

                        Image(safeSystemName: "wand.and.stars", fallback: "sparkles")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.accent)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("goals.entry.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(2)

                        Text(s("goals.entry.subtitle"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .frame(width: 24, height: 44)
                }
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .lippiMagicAppear(delay: 0.10, y: 12, scale: 0.98)
    }

    private var statusSymbol: String {
        if overdueTasksCount > 0 { return "exclamationmark.circle.fill" }
        if activeTasksCount == 0 { return "checkmark.seal.fill" }
        return "sparkles"
    }

    private var statusTone: Color {
        if overdueTasksCount > 0 { return Color(hex: 0xFF453A) }
        if activeTasksCount == 0 { return Color(hex: 0x30D158) }
        return DS.brandA
    }

    private var focusSummaryPanel: some View {
        let task = priorityTask

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill((task?.category.tint ?? DS.brandA).opacity(0.14))

                    Image(safeSystemName: task?.category.symbol ?? "sparkles", fallback: "sparkles")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(task?.category.tint ?? DS.brandA)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(s("today.focus.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .textCase(.uppercase)
                        .singleLine()

                    Text(task?.title ?? s("today.focus.empty_title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    HStack(spacing: 7) {
                        if let task {
                            categoryPill(task.category)
                            dueChip(for: task)
                        } else {
                            Label(s("today.focus.empty_hint"), systemImage: "plus.circle")
                                .font(.caption.weight(.semibold))
                                .labelStyle(TightLabelStyle())
                                .foregroundStyle(DS.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if let task {
                    Button { markTaskDone(task) } label: {
                        Label(s("today.quick.done"), systemImage: "checkmark")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))
                } else {
                    Button { showAdd = true } label: {
                        Label(s("today.quick.new"), systemImage: "plus")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill((task?.category.tint ?? DS.accent).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
    }

    private var dailySnapshotStrip: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            dailySnapshotMetric(
                value: focusTimeText,
                title: s("today.metric.focus"),
                systemImage: "timer",
                tone: Color(hex: 0x64D2FF)
            )
            dailySnapshotMetric(
                value: "\(productiveStreak)",
                title: s("today.metric.streak"),
                systemImage: "flame.fill",
                tone: Color(hex: 0xFF9F0A)
            )
            dailySnapshotMetric(
                value: "\(completedTodayCount)",
                title: s("today.metric.done_today"),
                systemImage: "checkmark.circle.fill",
                tone: Color(hex: 0x30D158)
            )
        }
        .padding(.vertical, 2)
    }

    private var focusTimeText: String {
        L10n.fmt("today.metric.focus_minutes", lang, focusedMinutesToday)
    }

    private func dailySnapshotMetric(value: String, title: String, systemImage: String, tone: Color) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: systemImage, fallback: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tone)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                    .singleLine()

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var dayProgressBadge: some View {
        ZStack {
            Circle()
                .fill(DS.glassFill(0.055))

            Circle()
                .stroke(DS.glassStroke(0.12), lineWidth: 6)

            Circle()
                .trim(from: 0, to: completionProgress)
                .stroke(
                    AngularGradient(colors: [DS.brandA, DS.brandB], center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(completionPercent)%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()

                Text(s("today.progress.day"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .frame(width: 68, height: 68)
        .padding(2)
        .animation(reduceMotion ? nil : DS.motionQuick, value: completionProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completionPercent)% \(s("today.progress.day"))")
    }

    private var weeklyStatsSnapshot: (focus: Int, tasks: Int, activeDays: Int) {
        let data = stats.series(last: 7)
        let totals = stats.totals(for: data)
        return (
            focus: totals.focus,
            tasks: totals.tasks,
            activeDays: data.filter(\.hasActivity).count
        )
    }

    private var statsSummaryEntry: some View {
        let snapshot = weeklyStatsSnapshot
        let focus = L10n.fmt("today.metric.focus_minutes", lang, snapshot.focus)
        let summary = L10n.fmt(
            "stats.insight.body",
            lang,
            focus,
            snapshot.tasks,
            snapshot.activeDays,
            7
        )

        return Button {
            showStats = true
        } label: {
            GlassCard(padding: 15, cornerRadius: 22, style: .flat) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0x64D2FF).opacity(0.14))

                        Image(safeSystemName: "chart.line.uptrend.xyaxis", fallback: "chart.bar.fill")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x64D2FF))
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("stats.header.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(2)

                        Text(summary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .frame(width: 24, height: 44)
                }
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(s("stats.header.subtitle")))
    }

    private var statsSheet: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    StatsCardView()
                        .lippiContentColumn()
                }
                .scrollIndicators(.hidden)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("stats.header.title"))
            .navigationBarTitleDisplayMode(.inline)
            .clearNavBarBackgroundIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s("common.close")) {
                        showStats = false
                    }
                }
            }
        }
    }

    private var importantTasks: [TaskItem] {
        (overdueTasks + dueTodayTasks).sorted { lhs, rhs in
            let left = lhs.dueDate ?? .distantFuture
            let right = rhs.dueDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var importantNowSubtitle: String {
        if overdueTasksCount > 0 {
            return L10n.fmt("today.summary.overdue", lang, overdueTasksCount)
        }
        if dueTodayCount > 0 {
            return L10n.fmt("today.summary.due_today", lang, dueTodayCount)
        }
        return s("today.summary.clear")
    }

    @ViewBuilder
    private var importantNowSheet: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        importantNowHero
                            .lippiMotionScene(0)
                        importantNowFocusCard
                            .lippiMotionScene(1)
                        importantNowDeadlinesCard
                            .lippiMotionScene(2)
                        importantNowActionCard
                            .lippiMotionScene(3)

                        Color.clear.frame(height: 18)
                    }
                    .lippiContentColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("today.summary.title"))
            .navigationBarTitleDisplayMode(.inline)
            .clearNavBarBackgroundIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s("common.close")) {
                        showImportantNow = false
                    }
                }
            }
        }
        .lippiMagicAppear(delay: 0.05, y: 12, scale: 0.98)
    }

    private var importantNowHero: some View {
        GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DS.glassFill(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(statusTone.opacity(0.22)))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.18), lineWidth: 1))

                        Image(safeSystemName: statusSymbol, fallback: "sparkles")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.text(0.95))
                    }
                    .frame(width: 50, height: 50)
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        tint: statusTone.opacity(0.10)
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(s("today.summary.title"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(importantNowSubtitle)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    summaryMiniMetric(value: "\(overdueTasksCount)", title: s("today.summary.overdue_short"), tone: Color(hex: 0xFF453A))
                    summaryMiniMetric(value: "\(dueTodayCount)", title: s("today.summary.today_short"), tone: Color(hex: 0xFF9F0A))
                    summaryMiniMetric(value: "\(activeTasksCount)", title: s("today.metric.active"), tone: DS.brandA)
                }
            }
        }
    }

    private var importantNowFocusCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("today.summary.focus_section"),
                    subtitle: s("today.summary.focus_subtitle"),
                    icon: "target",
                    accent: DS.brandA
                )

                if let task = priorityTask {
                    importantTaskRow(task, prominent: true)
                } else {
                    readableSummaryRow(
                        title: s("today.summary.no_focus"),
                        subtitle: s("today.focus.empty_hint"),
                        icon: "checkmark.seal.fill",
                        tone: Color(hex: 0x30D158)
                    )
                }
            }
        }
    }

    private var importantNowDeadlinesCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("today.summary.deadlines_section"),
                    subtitle: importantNowSubtitle,
                    icon: "calendar.badge.clock",
                    accent: statusTone
                )

                if importantTasks.isEmpty {
                    readableSummaryRow(
                        title: s("today.summary.clear"),
                        subtitle: s("today.summary.clear_hint"),
                        icon: "sparkles",
                        tone: Color(hex: 0x30D158)
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(importantTasks.prefix(5)) { task in
                            importantTaskRow(task, prominent: false)
                        }
                    }
                }
            }
        }
    }

    private var importantNowActionCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("today.summary.actions_section"),
                    subtitle: s("today.summary.actions_subtitle"),
                    icon: "bolt.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                VStack(spacing: 10) {
                    if let task = priorityTask {
                        summaryActionButton(
                            title: s("today.summary.complete_focus"),
                            icon: "checkmark.circle.fill",
                            tone: Color(hex: 0x30D158)
                        ) {
                            markTaskDone(task)
                            showImportantNow = false
                        }
                    }

                    summaryActionButton(
                        title: s("today.summary.new_task"),
                        icon: "plus.circle.fill",
                        tone: DS.brandA
                    ) {
                        showImportantNow = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            showAdd = true
                        }
                    }

                    summaryActionButton(
                        title: s("today.summary.goals"),
                        icon: "wand.and.stars",
                        tone: Color(hex: 0x64D2FF)
                    ) {
                        showImportantNow = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            showGoalPlanner = true
                        }
                    }
                }
            }
        }
    }

    private func summaryMiniMetric(value: String, title: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.glassFill(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tone.opacity(0.08)))
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func importantTaskRow(_ task: TaskItem, prominent: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle()
                    .fill(task.category.tint.opacity(0.16))
                    .overlay(Circle().stroke(task.category.tint.opacity(0.28), lineWidth: 1))

                Image(safeSystemName: task.category.symbol, fallback: "circle.fill")
                    .font(.system(size: prominent ? 15 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.90))
            }
            .frame(width: prominent ? 36 : 32, height: prominent ? 36 : 32)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font((prominent ? Font.callout : Font.subheadline).weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 7) {
                    Text(task.category.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Circle()
                        .fill(DS.textTertiary)
                        .frame(width: 3, height: 3)
                        .padding(.top, 6)

                    Text(dueSummary(for: task))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(dueTone(for: task))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(task.category.tint.opacity(0.06)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: task.category.tint.opacity(0.06)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func readableSummaryRow(title: String, subtitle: String, icon: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: icon, fallback: "sparkles")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .frame(width: 26, height: 26)
                .background(tone.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func summaryActionButton(title: String, icon: String, tone: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(safeSystemName: icon, fallback: icon)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.94))
                    .frame(width: 30, height: 30)
                    .background(tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tone.opacity(0.08)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: tone.opacity(0.08),
                interactive: true
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle(scale: 0.986, opacity: 0.98))
    }

    private func categoryPill(_ category: TaskCategory) -> some View {
        Label(category.title, systemImage: category.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        .background(category.chipFill, in: Capsule())
        .overlay(Capsule().stroke(category.chipStroke, lineWidth: 1))
        .singleLine()
    }

    private func dueChip(for task: TaskItem) -> some View {
        Label(dueSummary(for: task), systemImage: task.dueDate == nil ? "calendar" : "clock")
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.text(0.78))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        .background(dueTone(for: task).opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(dueTone(for: task).opacity(0.28), lineWidth: 1))
        .singleLine()
    }

    private var todayPlanCard: some View {
        let preview = Array(upcomingTasks.prefix(2))

        return GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    LippiSectionHeader(
                        title: s("today.plan.title"),
                        subtitle: s("today.plan.subtitle"),
                        icon: "list.bullet.rectangle.portrait",
                        accent: DS.accent
                    )

                    Spacer()

                    Text(L10n.fmt("today.plan.count", lang, activeTasksCount))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(DS.glassFill(0.08), in: Capsule())
                        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                        .singleLine()
                        .padding(.top, 2)
                }

                if preview.isEmpty {
                    HStack(spacing: 10) {
                        Image(safeSystemName: "checkmark.seal.fill", fallback: "checkmark.circle.fill")
                            .imageScale(.large)
                            .foregroundStyle(Color(hex: 0x30D158))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(s("today.plan.empty_title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.textPrimary)
                                .singleLine()

                            Text(s("today.plan.empty_subtitle"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.textTertiary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 4) {
                        ForEach(preview) { task in
                            planTaskRow(task)
                        }

                        if upcomingTasks.count > preview.count {
                            Text(L10n.fmt("today.plan.more", lang, upcomingTasks.count - preview.count))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DS.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }

    private func planTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(task.category.tint.opacity(0.16))
                    .overlay(Circle().stroke(task.category.tint.opacity(0.28), lineWidth: 1))

                Image(safeSystemName: task.category.symbol, fallback: "circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.90))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 7) {
                    Text(task.category.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .singleLine()

                    Circle()
                        .fill(DS.textTertiary)
                        .frame(width: 3, height: 3)

                    Text(dueSummary(for: task))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(dueTone(for: task))
                        .singleLine()
                }
            }

            Spacer(minLength: 8)

            Button {
                markTaskDone(task)
            } label: {
                Image(safeSystemName: "checkmark", fallback: "checkmark")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.90))
                    .frame(width: 44, height: 44)
                    .background(DS.glassFill(0.10), in: Circle())
                    .lippiSystemGlass(
                        in: Circle(),
                        tint: task.category.tint.opacity(0.08),
                        interactive: true
                    )
                    .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.88))
            .accessibilityLabel(s("tasks.menu.mark_done"))
        }
        .padding(.vertical, 10)
    }

    private func markTaskDone(_ task: TaskItem) {
        guard !task.isCompleted else { return }
        store.toggle(task.id, stats: stats)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func dueSummary(for task: TaskItem) -> String {
        guard let due = task.dueDate else { return s("today.next.no_due") }

        let calendar = Calendar.current
        if due < Date() {
            return L10n.fmt("today.due.overdue", lang, dueDateText(due))
        }
        if calendar.isDateInToday(due) {
            return L10n.fmt("today.due.today", lang, dueTimeText(due))
        }
        if calendar.isDateInTomorrow(due) {
            return L10n.fmt("today.due.tomorrow", lang, dueTimeText(due))
        }
        return dueDateText(due)
    }

    private func dueTimeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(appLocale))
    }

    private func dueDateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(appLocale))
    }

    private func dueTone(for task: TaskItem) -> Color {
        guard let due = task.dueDate else { return DS.textTertiary }
        if due < Date() { return Color(hex: 0xFF453A) }
        if Calendar.current.isDateInToday(due) { return Color(hex: 0xFF9F0A) }
        return task.category.tint
    }

    private var quickActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(alignment: .leading, spacing: 10) {
            Text(s("today.quick.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 2)

            LippiGlassEffectGroup(spacing: 10) {
                layout {
                    quickActionTile(
                        title: s("today.quick.new"),
                        icon: "plus",
                        tone: DS.brandA
                    ) {
                        showAdd = true
                    }

                    quickActionTile(
                        title: s("today.quick.done"),
                        icon: "checkmark.circle",
                        tone: Color(hex: 0x30D158)
                    ) {
                        if let task = priorityTask { markTaskDone(task) }
                    }
                    .opacity(hasUpcomingTask ? 1.0 : 0.56)
                    .disabled(!hasUpcomingTask)

                    quickActionTile(
                        title: s("today.quick.eyes"),
                        icon: "eye",
                        tone: Color(hex: 0x64D2FF)
                    ) {
                        NotificationCenter.default.post(name: .suggestEyeExercise, object: nil)
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        #endif
                    }
                }
            }
        }
    }

    private func quickActionTile(
        title: String,
        icon: String,
        tone: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(tone.opacity(0.14))

                    Image(safeSystemName: icon, fallback: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tone)
                }
                .frame(width: 34, height: 34)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .singleLine()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.07))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: tone.opacity(0.07),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DS.glassStroke(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.986, opacity: 0.98))
    }
}


// =======================================================
