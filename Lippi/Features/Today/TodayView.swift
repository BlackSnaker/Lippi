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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var showAdd = false
    @Binding var showGoalPlanner: Bool

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var performanceMode: Bool { DS.performanceEffectsReduced || reduceTransparency }
    private var activeTasksCount: Int { store.tasks.filter { !$0.isCompleted }.count }
    private var doneTasksCount: Int { store.tasks.filter { $0.isCompleted }.count }
    private var totalTasksCount: Int { max(store.tasks.count, 1) }
    private var hasUpcomingTask: Bool { store.upcoming() != nil }
    private var activeTasks: [TaskItem] { store.tasks.filter { !$0.isCompleted } }
    private var upcomingTasks: [TaskItem] {
        activeTasks.sorted { lhs, rhs in
            let left = lhs.dueDate ?? .distantFuture
            let right = rhs.dueDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
    }
    private var overdueTasksCount: Int {
        activeTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < Date()
        }.count
    }
    private var completionProgress: Double {
        min(max(Double(doneTasksCount) / Double(totalTasksCount), 0), 1)
    }
    private var completionPercent: Int { Int((completionProgress * 100).rounded()) }
    private var nextTask: TaskItem? { store.upcoming() }
    private var todayStatusText: String {
        if activeTasksCount == 0 && doneTasksCount > 0 { return s("today.status.clear") }
        if activeTasksCount == 0 { return s("today.status.empty") }
        if overdueTasksCount > 0 { return L10n.fmt("today.status.overdue", lang, overdueTasksCount) }
        if doneTasksCount == 0 { return s("today.status.start") }
        return L10n.fmt("today.status.progress", lang, completionPercent)
    }

    private var quickActionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return s("today.greeting.morning")
        case 12..<18: return s("today.greeting.day")
        default: return s("today.greeting.evening")
        }
    }

    private var todayBackdrop: some View {
        ZStack {
            AppBackdrop()

            LinearGradient(
                colors: [
                    Color.white.opacity(performanceMode ? 0.02 : 0.05),
                    Color.clear,
                    Color.black.opacity(performanceMode ? 0.08 : 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            if !performanceMode {
                RadialGradient(
                    colors: [DS.brandA.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 260
                )
                .offset(x: -26, y: -48)

                RadialGradient(
                    colors: [DS.brandB.opacity(0.14), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 280
                )
                .offset(x: 24, y: 40)
                .opacity(reduceMotion ? 0.85 : 1.0)
            }
        }
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                todayBackdrop

                ScrollView {
                    LazyVStack(spacing: 16) {
                        headerCard
                        smartGoalsEntry
                        quickActions
                        CountdownCardView()
                        todayPlanCard
                        StatsCardView()
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .transaction { $0.animation = nil }
            }
            .navigationTitle(s("today.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Label(s("today.toolbar.new_task"), systemImage: "plus.circle.fill")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            }
            // ✅ Нижний отступ под TabBar (чтобы контент не уходил под него)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 92)
            }
            .sheet(isPresented: $showAdd) {
                AddEditTaskView { store.add($0) }
                    .presentationDetents([.medium, .large])
            }
        }
        // ✅ Убираем системный фон NavigationStack “на всякий”
        .background(Color.clear)
    }

    // MARK: - Subviews
    private var headerCard: some View {
        GlassCard(padding: 18, cornerRadius: 30, style: .full) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)
                            .singleLine()

                        Text(greetingTitle)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.textPrimary)
                            .singleLine()

                        Text(s("today.header.subtitle"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textTertiary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.90)
                            .allowsTightening(true)

                        statusPill
                    }

                    Spacer(minLength: 0)

                    dayProgressBadge
                }

                focusSummaryPanel

                HStack(spacing: 8) {
                    heroMetricChip(title: s("today.metric.active"), value: "\(activeTasksCount)", systemImage: "circle", tone: DS.brandA)
                    heroMetricChip(title: s("today.metric.done"), value: "\(doneTasksCount)", systemImage: "checkmark.circle.fill", tone: Color(hex: 0x30D158))
                    heroMetricChip(title: s("today.metric.streak"), value: "\(stats.productiveStreak)", systemImage: "flame.fill", tone: Color(hex: 0xFF9F0A))
                }
            }
        }
    }

    private var smartGoalsEntry: some View {
        Button {
            showGoalPlanner = true
        } label: {
            GlassCard(padding: 16, cornerRadius: 24, style: .full) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DS.glassFill(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.brandSoftGradient).opacity(0.50))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.18), lineWidth: 1))

                        Image(safeSystemName: "wand.and.stars", fallback: "sparkles")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.text(0.96))
                    }
                    .frame(width: 48, height: 48)
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        tint: DS.accent.opacity(0.14),
                        interactive: true
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("goals.entry.title"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .singleLine()

                        Text(s("goals.entry.subtitle"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(safeSystemName: "arrow.up.forward", fallback: "chevron.right")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text(0.90))
                        .frame(width: 38, height: 38)
                        .background(DS.glassFill(0.10), in: Circle())
                        .lippiSystemGlass(in: Circle(), tint: DS.accent.opacity(0.09), interactive: true)
                        .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
                        .padding(.trailing, 46)
                }
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private var statusPill: some View {
        Label(todayStatusText, systemImage: statusSymbol)
            .font(.caption.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.text(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(Capsule().fill(statusTone.opacity(0.16)))
            )
            .lippiSystemGlass(
                in: Capsule(style: .continuous),
                tint: statusTone.opacity(0.09)
            )
            .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
            .singleLine()
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
        let task = nextTask

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DS.glassFill(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill((task?.category.tint ?? DS.brandA).opacity(0.24))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DS.glassStroke(0.18), lineWidth: 1)
                        )

                    Image(safeSystemName: task?.category.symbol ?? "sparkles", fallback: "sparkles")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text(0.94))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    Text(s("today.focus.title"))
                        .font(.caption.weight(.bold))
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
                                .singleLine()
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button { showAdd = true } label: {
                    Label(s("today.quick.new"), systemImage: "plus")
                        .labelStyle(TightLabelStyle())
                }
                .buttonStyle(LippiButtonStyle(kind: task == nil ? .primary : .secondary, compact: true))

                #if canImport(ActivityKit)
                if #available(iOS 16.2, *), let task {
                    Button {
                        Task { await LiveActivityManager.startTask(task) }
                    } label: {
                        Label(s("today.next.to_island"), systemImage: "wave.3.right")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))
                }
                #endif
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DS.brandSoftGradient)
                        .opacity(0.36)
                )
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: (task?.category.tint ?? DS.accent).opacity(0.10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.16), lineWidth: 1)
        )
    }

    private var dayProgressBadge: some View {
        ZStack {
            Circle()
                .stroke(DS.glassStroke(0.14), lineWidth: 7)

            Circle()
                .trim(from: 0, to: completionProgress)
                .stroke(
                    AngularGradient(colors: [DS.brandA, DS.brandB], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
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
        .frame(width: 76, height: 76)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DS.brandSoftGradient)
                        .opacity(0.55)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DS.glassStroke(0.16), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : DS.motionQuick, value: completionProgress)
    }

    private func heroMetricChip(title: String, value: String, systemImage: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(DS.glassFill(0.12))
                        .overlay(Circle().fill(tone.opacity(0.20)))
                        .overlay(Circle().stroke(DS.glassStroke(0.18), lineWidth: 1))

                    Image(safeSystemName: systemImage, fallback: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.90))
                }
                .frame(width: 24, height: 24)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
                .singleLine()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tone.opacity(0.10))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    private func categoryPill(_ category: TaskCategory) -> some View {
        Label(category.title, systemImage: category.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        .background(category.chipFill, in: Capsule())
        .lippiSystemGlass(
            in: Capsule(),
            tint: category.tint.opacity(0.08)
        )
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
        .lippiSystemGlass(
            in: Capsule(),
            tint: dueTone(for: task).opacity(0.08)
        )
        .overlay(Capsule().stroke(dueTone(for: task).opacity(0.28), lineWidth: 1))
        .singleLine()
    }

    private var todayPlanCard: some View {
        let preview = Array(upcomingTasks.prefix(3))

        return GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
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
                                .singleLine()
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(taskRowBackground(tone: Color(hex: 0x30D158)))
                } else {
                    VStack(spacing: 9) {
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
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(task.category.chipFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(task.category.chipStroke, lineWidth: 1)
                    )

                Image(safeSystemName: task.category.symbol, fallback: "circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.90))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .singleLine()

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
                    .frame(width: 30, height: 30)
                    .background(DS.glassFill(0.10), in: Circle())
                    .lippiSystemGlass(
                        in: Circle(),
                        tint: task.category.tint.opacity(0.08),
                        interactive: true
                    )
                    .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.88))
        }
        .padding(10)
        .background(taskRowBackground(tone: task.category.tint))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: task.category.tint.opacity(0.08)
        )
    }

    private func taskRowBackground(tone: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DS.glassFill(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tone.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DS.glassStroke(0.12), lineWidth: 1)
            )
    }

    private func markTaskDone(_ task: TaskItem) {
        var updated = task
        updated.isCompleted = true
        store.update(updated)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func dueSummary(for task: TaskItem) -> String {
        guard let due = task.dueDate else { return s("today.next.no_due") }

        let calendar = Calendar.current
        if due < Date() {
            return L10n.fmt("today.due.overdue", lang, Self.dueFormatter.string(from: due))
        }
        if calendar.isDateInToday(due) {
            return L10n.fmt("today.due.today", lang, Self.timeFormatter.string(from: due))
        }
        if calendar.isDateInTomorrow(due) {
            return L10n.fmt("today.due.tomorrow", lang, Self.timeFormatter.string(from: due))
        }
        return Self.dueFormatter.string(from: due)
    }

    private func dueTone(for task: TaskItem) -> Color {
        guard let due = task.dueDate else { return DS.textTertiary }
        if due < Date() { return Color(hex: 0xFF453A) }
        if Calendar.current.isDateInToday(due) { return Color(hex: 0xFF9F0A) }
        return task.category.tint
    }

    private var quickActions: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    LippiSectionHeader(
                        title: s("today.quick.title"),
                        subtitle: s("today.quick.subtitle"),
                        icon: "bolt.fill",
                        accent: Color(hex: 0x64D2FF)
                    )

                    Spacer()

                    Label(s("today.quick.today"), systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .foregroundStyle(DS.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.glassFill(0.08), in: Capsule())
                        .lippiSystemGlass(
                            in: Capsule(),
                            tint: Color(hex: 0x64D2FF).opacity(0.07)
                        )
                        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                        .padding(.top, 2)
                }

                LazyVGrid(columns: quickActionColumns, spacing: 10) {
                    quickActionTile(
                        title: s("today.quick.new"),
                        icon: "plus",
                        tone: DS.brandA
                    ) {
                        showAdd = true
                    }
                    .gridCellColumns(2)

                    quickActionTile(
                        title: s("today.quick.done"),
                        icon: "checkmark.circle",
                        tone: Color(hex: 0x30D158)
                    ) {
                        if let task = store.upcoming() {
                            var updated = task
                            updated.isCompleted = true
                            store.update(updated)
                            #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                        }
                    }
                    .opacity(hasUpcomingTask ? 1.0 : 0.56)
                    .allowsHitTesting(hasUpcomingTask)

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
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.glassFill(0.11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tone.opacity(0.28))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.glassStroke(0.16), lineWidth: 1)
                        )

                    Image(safeSystemName: icon, fallback: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.text(0.94))
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .singleLine()

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.glassFill(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tone.opacity(0.10))
                    )
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                tint: tone.opacity(0.08),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.986, opacity: 0.98))
    }
}


// =======================================================
