import SwiftUI
#if os(iOS)
import UIKit
#endif

private enum LippiCalendarScope: String, CaseIterable, Identifiable {
    case month
    case week

    var id: String { rawValue }
}

private enum LippiCalendarTaskFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed

    var id: String { rawValue }
}

struct LippiCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var stats: StatsStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var careCenter: LippiCareCenter
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(GoalProgressNotificationScheduler.roadmapStorageKey) private var savedRoadmap = ""
    @AppStorage("goal.progress.userState") private var userStateRaw = GoalUserState.calm.rawValue

    let onOpenRoadmap: () -> Void

    @State private var selectedDate = Date.now
    @State private var displayedMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now
    @State private var showAdaptationConfirmation = false
    @State private var adaptationResult: String?
    @State private var scope: LippiCalendarScope = .month
    @State private var taskFilter: LippiCalendarTaskFilter = .all
    @State private var editingTask: TaskItem?
    @State private var isPresentingTaskEditor = false
    @Namespace private var calendarGlassNamespace

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var calendar: Calendar {
        var value = Calendar.current
        value.locale = Locale(identifier: lang.localeIdentifier)
        return value
    }

    private var roadmap: GoalRoadmap? {
        guard let data = savedRoadmap.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GoalRoadmap.self, from: data)
    }

    private var userState: GoalUserState {
        GoalUserState(rawValue: userStateRaw) ?? .calm
    }

    private var intelligence: LippiCalendarIntelligence {
        LippiCalendarIntelligenceEngine.analyze(
            tasks: store.tasks,
            roadmap: roadmap,
            healthSnapshot: healthKit.snapshot,
            healthRecommendation: healthKit.recommendation,
            userState: userState,
            careSuggestion: careCenter.primarySuggestion,
            completedThisWeek: stats.last7Days.tasksDone,
            focusMinutesToday: stats.today.focusMinutes,
            now: .now,
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        calendarHero
                            .lippiMotionScene(0)
                        monthCard
                            .lippiMotionScene(1)
                        intelligenceCard
                            .lippiMotionScene(2)
                        selectedPlansCard
                            .lippiMotionScene(3)
                        roadmapCard
                            .lippiMotionScene(4)
                        Color.clear.frame(height: 28)
                    }
                    .lippiContentColumn()
                }
                .scrollIndicators(.hidden)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("calendar.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .clearNavBarBackgroundIfAvailable()
            .toolbar { calendarToolbar }
            .alert(s("calendar.adapt.confirm.title"), isPresented: $showAdaptationConfirmation) {
                Button(s("common.cancel"), role: .cancel) { }
                Button(s("calendar.adapt.confirm.action")) { applySuggestedSchedule() }
            } message: {
                Text(L10n.fmt("calendar.adapt.confirm.body", lang, intelligence.suggestions.count))
            }
            .sheet(isPresented: $isPresentingTaskEditor, onDismiss: {
                editingTask = nil
            }) {
                AddEditTaskView(
                    item: editingTask,
                    initialDueDate: editingTask == nil ? suggestedDueDate(for: selectedDate) : nil
                ) { task in
                    if editingTask == nil {
                        store.add(task)
                    } else {
                        store.update(task)
                    }
                }
            }
        }
        .background(Color.clear)
    }

    @ToolbarContentBuilder
    private var calendarToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(s("common.close")) { dismiss() }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    selectedDate = .now
                    displayedMonth = monthStart(for: .now)
                }
            } label: {
                Image(safeSystemName: "calendar.badge.clock", fallback: "calendar")
            }
            .accessibilityLabel(s("calendar.today"))
        }
    }

    private var calendarHero: some View {
        GlassCard(padding: 0, cornerRadius: 30, style: .full, forceSystemGlass: true) {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [
                        DS.accent.opacity(0.18),
                        Color(hex: 0x30D158).opacity(0.09),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(DS.accent.opacity(0.11))
                    .frame(width: 150, height: 150)
                    .offset(x: 52, y: 62)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(safeSystemName: "sparkles", fallback: "circle.fill")
                            .foregroundStyle(DS.accent)
                        Text(s("calendar.hero.eyebrow"))
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(DS.textSecondary)
                    }

                    Text(s("calendar.hero.title"))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.textPrimary)

                    Text(s("calendar.hero.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LippiGlassEffectGroup(spacing: 8) {
                        HStack(spacing: 8) {
                            heroMetric(
                                value: "\(intelligence.plansToday)",
                                title: s("calendar.metric.today"),
                                icon: "checklist",
                                tint: DS.accent
                            )
                            heroMetric(
                                value: "\(intelligence.focusMinutesToday)",
                                title: s("calendar.metric.focus"),
                                icon: "timer",
                                tint: Color(hex: 0x64D2FF)
                            )
                            heroMetric(
                                value: "\(intelligence.completedThisWeek)",
                                title: s("calendar.metric.week"),
                                icon: "checkmark.seal.fill",
                                tint: Color(hex: 0x30D158)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    private func heroMetric(value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(safeSystemName: icon, fallback: "circle.fill")
                    .font(.caption2.weight(.bold))
                Text(value)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(tint)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.glassFill(0.075), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 14, style: .continuous),
            tint: tint.opacity(0.08),
            forceSystemGlass: true
        )
    }

    private var monthCard: some View {
        GlassCard(padding: 16, cornerRadius: 28, style: .lightweight, forceSystemGlass: true) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    monthNavigationButton(direction: -1, icon: "chevron.left")

                    VStack(spacing: 2) {
                        Text(calendarHeaderTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                        Text(scope == .month ? s("calendar.month.subtitle") : s("calendar.week.subtitle"))
                            .font(.caption)
                            .foregroundStyle(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    monthNavigationButton(direction: 1, icon: "chevron.right")
                }

                calendarScopePicker

                LippiGlassEffectGroup(spacing: 7) {
                    LazyVGrid(columns: weekdayColumns, spacing: 7) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(DS.textTertiary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(Array(visibleDays.enumerated()), id: \.offset) { _, date in
                            if let date {
                                dayButton(date)
                            } else {
                                Color.clear.frame(height: 45)
                            }
                        }
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 48 else { return }
                    navigateCalendar(direction: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var calendarScopePicker: some View {
        LippiGlassEffectGroup(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LippiCalendarScope.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : DS.motionState) {
                            scope = item
                            displayedMonth = monthStart(for: selectedDate)
                        }
                    } label: {
                        Text(s("calendar.scope.\(item.rawValue)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item == scope ? DS.accent : DS.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                item == scope ? DS.accent.opacity(0.08) : DS.glassFill(0.035),
                                in: Capsule(style: .continuous)
                            )
                            .lippiSystemGlass(
                                in: Capsule(style: .continuous),
                                tint: item == scope ? DS.accent.opacity(0.13) : nil,
                                interactive: true,
                                forceSystemGlass: true
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == scope ? .isSelected : [])
                }
            }
        }
    }

    private func navigateCalendar(direction: Int) {
        let component: Calendar.Component = scope == .month ? .month : .weekOfYear
        let anchor = scope == .month ? displayedMonth : selectedDate
        guard let destination = calendar.date(byAdding: component, value: direction, to: anchor) else { return }

        withAnimation(reduceMotion ? nil : DS.motionState) {
            if scope == .month {
                displayedMonth = monthStart(for: destination)
                selectedDate = monthStart(for: destination)
            } else {
                selectedDate = destination
                displayedMonth = monthStart(for: destination)
            }
        }
    }

    private func monthNavigationButton(direction: Int, icon: String) -> some View {
        Button {
            navigateCalendar(direction: direction)
        } label: {
            Image(safeSystemName: icon, fallback: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 44, height: 44)
                .background(DS.glassFill(0.08), in: Circle())
                .overlay(Circle().stroke(DS.glassStroke(0.11), lineWidth: 1))
                .lippiSystemGlass(
                    in: Circle(),
                    tint: DS.accent.opacity(0.07),
                    interactive: true,
                    forceSystemGlass: true
                )
        }
        .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.82))
        .accessibilityLabel(s(direction < 0 ? "calendar.previous" : "calendar.next"))
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let plans = tasks(on: date)
        let unfinished = plans.filter { !$0.isCompleted }.count
        let completed = plans.contains(where: \.isCompleted)

        return Button {
            withAnimation(reduceMotion ? nil : DS.motionQuick) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(isSelected ? DS.accent : DS.textPrimary)

                HStack(spacing: 2) {
                    if unfinished > 0 {
                        Circle()
                            .fill(DS.accent)
                            .frame(width: 4, height: 4)
                    }
                    if completed {
                        Circle()
                            .fill(Color(hex: 0x30D158))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 45)
            .background { daySelectionSurface(isSelected: isSelected, isToday: isToday) }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(date: date, planCount: plans.count))
    }

    @ViewBuilder
    private func daySelectionSurface(isSelected: Bool, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

        if isSelected {
            if #available(iOS 26.0, *) {
                shape
                    .fill(Color.clear)
                    .glassEffect(
                        Glass.regular.tint(DS.accent.opacity(0.18)).interactive(),
                        in: shape
                    )
                    .glassEffectID("calendar.selected.day", in: calendarGlassNamespace)
                    .glassEffectTransition(.matchedGeometry)
            } else {
                shape
                    .fill(DS.accent.opacity(0.16))
                    .overlay(shape.stroke(DS.accent.opacity(0.34), lineWidth: 1))
            }
        } else if isToday {
            shape
                .fill(DS.accent.opacity(0.08))
                .overlay(shape.stroke(DS.accent.opacity(0.34), lineWidth: 1))
        } else {
            Color.clear
        }
    }

    private var intelligenceCard: some View {
        let accent = paceAccent(intelligence.pace.level)

        return GlassCard(padding: 17, cornerRadius: 28, style: .full, forceSystemGlass: true) {
            VStack(alignment: .leading, spacing: 15) {
                LippiSectionHeader(
                    title: s("calendar.intelligence.title"),
                    subtitle: s("calendar.intelligence.subtitle"),
                    icon: "sparkles",
                    accent: accent
                )

                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle().fill(accent.opacity(0.14))
                        Image(safeSystemName: paceIcon(intelligence.pace.level), fallback: "sparkles")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("health.hub.pace.\(intelligence.pace.level.rawValue)"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                        Text(intelligenceSummary)
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(intelligence.signals) { signal in
                        Label(s(signal.titleKey), systemImage: signal.icon)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .padding(.horizontal, 10)
                            .background(DS.glassFill(0.065), in: Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(DS.glassStroke(0.09), lineWidth: 1))
                            .lippiSystemGlass(
                                in: Capsule(style: .continuous),
                                tint: accent.opacity(0.055),
                                forceSystemGlass: true
                            )
                    }
                }

                if let nextStep = intelligence.nextGoalStep {
                    HStack(alignment: .top, spacing: 10) {
                        Image(safeSystemName: "scope", fallback: "target")
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s("calendar.intelligence.next_step"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DS.textTertiary)
                            Text(nextStep)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                        tint: accent.opacity(0.08),
                        forceSystemGlass: true
                    )
                }

                if intelligence.shouldOfferAdaptation {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(intelligence.suggestions.prefix(2)) { move in
                            suggestionRow(move)
                        }
                        if intelligence.suggestions.count > 2 {
                            Text(L10n.fmt("calendar.adapt.more", lang, intelligence.suggestions.count - 2))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DS.textTertiary)
                        }
                    }

                    Button {
                        showAdaptationConfirmation = true
                    } label: {
                        Label(s("calendar.adapt.action"), systemImage: "calendar.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))
                } else {
                    Label(s("calendar.adapt.clear"), systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x30D158))
                }

                if let adaptationResult {
                    Label(adaptationResult, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x30D158))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Label(s("calendar.intelligence.privacy"), systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.textTertiary)
            }
        }
    }

    private func suggestionRow(_ move: LippiCalendarMove) -> some View {
        HStack(spacing: 10) {
            Image(safeSystemName: "arrow.right", fallback: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(paceAccent(intelligence.pace.level))

            VStack(alignment: .leading, spacing: 2) {
                Text(move.taskTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                Text(move.proposedDate, format: .dateTime.locale(Locale(identifier: lang.localeIdentifier)).day().month(.abbreviated).hour().minute())
                    .font(.caption2)
                    .foregroundStyle(DS.textTertiary)
            }
            Spacer(minLength: 4)
            Text(s("calendar.move.\(move.reason.rawValue)"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 14, style: .continuous),
            tint: paceAccent(intelligence.pace.level).opacity(0.055),
            forceSystemGlass: true
        )
    }

    private var selectedPlansCard: some View {
        let allDated = tasks(on: selectedDate)
        let allUndated = calendar.isDateInToday(selectedDate)
            ? store.tasks.filter { !$0.isCompleted && $0.dueDate == nil }
            : []
        let dated = allDated.filter(matchesTaskFilter)
        let undated = allUndated.filter(matchesTaskFilter)
        let visibleCount = dated.count + undated.count
        let hasPlansBeforeFiltering = !(allDated.isEmpty && allUndated.isEmpty)

        return GlassCard(padding: 17, cornerRadius: 26, style: .full, forceSystemGlass: true) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: selectedDateTitle,
                    subtitle: dated.isEmpty && undated.isEmpty
                        ? s(hasPlansBeforeFiltering ? "calendar.day.filtered_empty" : "calendar.day.empty")
                        : L10n.fmt("calendar.day.count", lang, visibleCount),
                    icon: "calendar.day.timeline.left",
                    accent: DS.accent
                )

                selectedDayToolbar

                if dated.isEmpty && undated.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(safeSystemName: hasPlansBeforeFiltering ? "line.3.horizontal.decrease.circle" : "leaf.fill", fallback: "sparkles")
                                .foregroundStyle(hasPlansBeforeFiltering ? DS.accent : Color(hex: 0x30D158))
                                .frame(width: 38, height: 38)
                                .background(
                                    (hasPlansBeforeFiltering ? DS.accent : Color(hex: 0x30D158)).opacity(0.10),
                                    in: Circle()
                                )
                            Text(s(hasPlansBeforeFiltering ? "calendar.day.filtered_hint" : "calendar.day.empty_hint"))
                                .font(.subheadline)
                                .foregroundStyle(DS.textSecondary)
                        }

                        if !hasPlansBeforeFiltering {
                            Button(action: presentNewTask) {
                                Label(s("calendar.action.add"), systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LippiButtonStyle(kind: .secondary, forceSystemGlass: true))
                        }
                    }
                } else {
                    ForEach(dated) { task in
                        taskRow(task, showsUnscheduled: false)
                    }

                    if !undated.isEmpty {
                        Text(s("calendar.day.unscheduled"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.textTertiary)
                            .padding(.top, 4)
                        ForEach(undated.prefix(3)) { task in
                            taskRow(task, showsUnscheduled: true)
                        }
                    }
                }
            }
        }
    }

    private var selectedDayToolbar: some View {
        LippiGlassEffectGroup(spacing: 8) {
            HStack(spacing: 8) {
                dayNavigationButton(direction: -1, icon: "chevron.left")
                dayNavigationButton(direction: 1, icon: "chevron.right")

                Spacer(minLength: 4)

                Menu {
                    Picker(s("calendar.filter.title"), selection: $taskFilter) {
                        ForEach(LippiCalendarTaskFilter.allCases) { filter in
                            Label(
                                s("calendar.filter.\(filter.rawValue)"),
                                systemImage: filterIcon(filter)
                            )
                            .tag(filter)
                        }
                    }
                } label: {
                    Label(
                        s("calendar.filter.\(taskFilter.rawValue)"),
                        systemImage: "line.3.horizontal.decrease"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(DS.glassFill(0.045), in: Capsule(style: .continuous))
                    .lippiSystemGlass(
                        in: Capsule(style: .continuous),
                        tint: DS.accent.opacity(0.07),
                        interactive: true,
                        forceSystemGlass: true
                    )
                }

                Button(action: presentNewTask) {
                    Image(safeSystemName: "plus", fallback: "plus.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.accent)
                        .frame(width: 38, height: 38)
                        .background(DS.accent.opacity(0.08), in: Circle())
                        .lippiSystemGlass(
                            in: Circle(),
                            tint: DS.accent.opacity(0.13),
                            interactive: true,
                            forceSystemGlass: true
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s("calendar.action.add"))
            }
        }
    }

    private func dayNavigationButton(direction: Int, icon: String) -> some View {
        Button {
            guard let date = calendar.date(byAdding: .day, value: direction, to: selectedDate) else { return }
            withAnimation(reduceMotion ? nil : DS.motionQuick) {
                selectedDate = date
                displayedMonth = monthStart(for: date)
            }
        } label: {
            Image(safeSystemName: icon, fallback: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DS.textSecondary)
                .frame(width: 38, height: 38)
                .background(DS.glassFill(0.045), in: Circle())
                .lippiSystemGlass(
                    in: Circle(),
                    tint: DS.accent.opacity(0.055),
                    interactive: true,
                    forceSystemGlass: true
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(s(direction < 0 ? "calendar.day.previous" : "calendar.day.next"))
    }

    private func taskRow(_ task: TaskItem, showsUnscheduled: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                store.toggle(task.id, stats: stats)
            } label: {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? Color(hex: 0x30D158).opacity(0.16) : task.category.tint.opacity(0.13))
                    Image(safeSystemName: task.isCompleted ? "checkmark" : task.category.symbol, fallback: "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(task.isCompleted ? Color(hex: 0x30D158) : task.category.tint)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.title)
            .accessibilityHint(s("calendar.task.toggle_hint"))

            Button {
                presentEditor(for: task)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .strikethrough(task.isCompleted, color: DS.textTertiary)
                        .lineLimit(2)

                    if showsUnscheduled {
                        Text(s("calendar.day.no_date"))
                            .font(.caption2)
                            .foregroundStyle(DS.textTertiary)
                    } else if let date = task.dueDate {
                        Text(date, format: .dateTime.locale(Locale(identifier: lang.localeIdentifier)).hour().minute())
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(date < .now && !task.isCompleted ? Color(hex: 0xFF453A) : DS.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(s("calendar.action.edit"))

            Menu {
                Button {
                    presentEditor(for: task)
                } label: {
                    Label(s("calendar.action.edit"), systemImage: "pencil")
                }

                Button {
                    reschedule(task, daysFromToday: 1)
                } label: {
                    Label(s("calendar.action.tomorrow"), systemImage: "sunrise")
                }

                Button {
                    reschedule(task, daysFromToday: 7)
                } label: {
                    Label(s("calendar.action.next_week"), systemImage: "calendar.badge.plus")
                }

                if task.dueDate != nil {
                    Button {
                        var updated = task
                        updated.dueDate = nil
                        store.update(updated)
                    } label: {
                        Label(s("calendar.action.unschedule"), systemImage: "calendar.badge.minus")
                    }
                }
            } label: {
                Image(safeSystemName: "ellipsis", fallback: "ellipsis.circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DS.glassFill(0.05), in: Circle())
                    .lippiSystemGlass(
                        in: Circle(),
                        tint: task.category.tint.opacity(0.06),
                        interactive: true,
                        forceSystemGlass: true
                    )
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var roadmapCard: some View {
        if let roadmap {
            GlassCard(padding: 17, cornerRadius: 28, style: .full, forceSystemGlass: true) {
                VStack(alignment: .leading, spacing: 15) {
                    LippiSectionHeader(
                        title: s("calendar.roadmap.title"),
                        subtitle: roadmap.title,
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        accent: Color(hex: 0x64D2FF)
                    )

                    roadmapProgressHeader(roadmap)

                    ForEach(Array(roadmap.milestones.enumerated()), id: \.element.id) { index, milestone in
                        milestoneRow(
                            milestone,
                            index: index,
                            isLast: index == roadmap.milestones.count - 1,
                            roadmap: roadmap
                        )
                    }

                    Button(action: onOpenRoadmap) {
                        Label(s("calendar.roadmap.open"), systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            }
        } else {
            GlassCard(padding: 17, cornerRadius: 24, style: .flat, forceSystemGlass: true) {
                HStack(spacing: 13) {
                    Image(safeSystemName: "map.fill", fallback: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: 0x64D2FF))
                        .frame(width: 46, height: 46)
                        .background(Color(hex: 0x64D2FF).opacity(0.11), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("calendar.roadmap.empty.title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("calendar.roadmap.empty.body"))
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }

                    Spacer(minLength: 4)

                    Button(action: onOpenRoadmap) {
                        Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func roadmapProgressHeader(_ roadmap: GoalRoadmap) -> some View {
        let progress = roadmapProgress(roadmap)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s("calendar.roadmap.progress"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: 0x64D2FF))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.glassFill(0.09))
                    Capsule()
                        .fill(Color(hex: 0x64D2FF))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 7)
        }
    }

    private func milestoneRow(
        _ milestone: GoalMilestone,
        index: Int,
        isLast: Bool,
        roadmap: GoalRoadmap
    ) -> some View {
        let completion = milestoneCompletion(milestone, roadmap: roadmap)
        let isCurrent = currentMilestoneIndex(roadmap) == index
        let accent = completion >= 1 ? Color(hex: 0x30D158) : (isCurrent ? DS.accent : DS.textTertiary)

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(accent.opacity(0.15))
                    Image(safeSystemName: completion >= 1 ? "checkmark" : "\(index + 1).circle.fill", fallback: "circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 34, height: 34)

                if !isLast {
                    Rectangle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 2, height: 70)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(milestone.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if isCurrent {
                        Text(s("calendar.roadmap.current"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DS.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DS.accent.opacity(0.10), in: Capsule())
                            .lippiSystemGlass(
                                in: Capsule(),
                                tint: DS.accent.opacity(0.10),
                                forceSystemGlass: true
                            )
                    }
                }

                Text(milestone.timeframe)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)

                Text(milestone.target)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(
            .dateTime.locale(Locale(identifier: lang.localeIdentifier)).month(.wide).year()
        )
    }

    private var calendarHeaderTitle: String {
        guard scope == .week,
              let first = weekDays.first,
              let last = weekDays.last else { return monthTitle }

        if calendar.component(.month, from: first) == calendar.component(.month, from: last) {
            let start = first.formatted(
                .dateTime.locale(Locale(identifier: lang.localeIdentifier)).day()
            )
            let end = last.formatted(
                .dateTime.locale(Locale(identifier: lang.localeIdentifier)).day().month(.wide).year()
            )
            return "\(start)–\(end)"
        }

        let start = first.formatted(
            .dateTime.locale(Locale(identifier: lang.localeIdentifier)).day().month(.abbreviated)
        )
        let end = last.formatted(
            .dateTime.locale(Locale(identifier: lang.localeIdentifier)).day().month(.abbreviated).year()
        )
        return "\(start) – \(end)"
    }

    private var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) { return s("calendar.today") }
        return selectedDate.formatted(
            .dateTime.locale(Locale(identifier: lang.localeIdentifier)).weekday(.wide).day().month(.wide)
        )
    }

    private var weekdayColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: lang.localeIdentifier)
        var symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        let offset = max(0, calendar.firstWeekday - 1)
        if offset > 0, symbols.count == 7 {
            symbols = Array(symbols[offset...] + symbols[..<offset])
        }
        return symbols
    }

    private var monthDays: [Date?] {
        let first = monthStart(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result = Array<Date?>(repeating: nil, count: leading)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }
        while !result.isEmpty && result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    private var visibleDays: [Date?] {
        if scope == .week {
            return weekDays.map(Optional.some)
        }
        return monthDays
    }

    private var intelligenceSummary: String {
        if intelligence.overduePlans > 0 {
            return L10n.fmt("calendar.intelligence.overdue", lang, intelligence.overduePlans)
        }
        if intelligence.overloadedDays > 0 {
            return L10n.fmt("calendar.intelligence.overload", lang, intelligence.overloadedDays)
        }
        return L10n.fmt(
            "calendar.intelligence.steady",
            lang,
            intelligence.pace.dailyStepLimit,
            intelligence.pace.focusMinutes
        )
    }

    private func tasks(on date: Date) -> [TaskItem] {
        store.tasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: date)
            }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
    }

    private func matchesTaskFilter(_ task: TaskItem) -> Bool {
        switch taskFilter {
        case .all:
            return true
        case .active:
            return !task.isCompleted
        case .completed:
            return task.isCompleted
        }
    }

    private func filterIcon(_ filter: LippiCalendarTaskFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .active: return "circle"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private func presentNewTask() {
        editingTask = nil
        isPresentingTaskEditor = true
    }

    private func presentEditor(for task: TaskItem) {
        editingTask = task
        isPresentingTaskEditor = true
    }

    private func suggestedDueDate(for date: Date) -> Date {
        if calendar.isDateInToday(date) {
            return Date.now.addingTimeInterval(60 * 60)
        }
        return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date)
            ?? date.addingTimeInterval(18 * 60 * 60)
    }

    private func reschedule(_ task: TaskItem, daysFromToday: Int) {
        let today = calendar.startOfDay(for: .now)
        guard let destinationDay = calendar.date(
            byAdding: .day,
            value: daysFromToday,
            to: today
        ) else { return }

        let originalTime = task.dueDate.map {
            calendar.dateComponents([.hour, .minute], from: $0)
        }
        let dueDate = calendar.date(
            bySettingHour: originalTime?.hour ?? 18,
            minute: originalTime?.minute ?? 0,
            second: 0,
            of: destinationDay
        ) ?? destinationDay.addingTimeInterval(18 * 60 * 60)

        var updated = task
        updated.dueDate = dueDate
        store.update(updated)

        withAnimation(reduceMotion ? nil : DS.motionState) {
            selectedDate = destinationDay
            displayedMonth = monthStart(for: destinationDay)
        }
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func dayAccessibilityLabel(date: Date, planCount: Int) -> String {
        let day = date.formatted(
            .dateTime.locale(Locale(identifier: lang.localeIdentifier)).weekday(.wide).day().month(.wide)
        )
        return L10n.fmt("calendar.day.accessibility", lang, day, planCount)
    }

    private func paceAccent(_ level: AdaptiveGoalPaceLevel) -> Color {
        switch level {
        case .recovery: return Color(hex: 0xBF5AF2)
        case .light: return Color(hex: 0x30D158)
        case .balanced: return DS.accent
        case .momentum: return Color(hex: 0x64D2FF)
        }
    }

    private func paceIcon(_ level: AdaptiveGoalPaceLevel) -> String {
        switch level {
        case .recovery: return "moon.stars.fill"
        case .light: return "leaf.fill"
        case .balanced: return "equal.circle.fill"
        case .momentum: return "bolt.fill"
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: lang.localeIdentifier))
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]", with: "", options: .regularExpression)
    }

    private func taskIsCompleted(_ title: String, roadmap: GoalRoadmap) -> Bool {
        let target = normalized(title)
        return store.tasks.contains { task in
            task.isCompleted
                && (normalized(task.title) == target
                    || (GoalPlanProgressAudit.isLinked(task, to: roadmap) && normalized(task.title).contains(target)))
        }
    }

    private func milestoneCompletion(_ milestone: GoalMilestone, roadmap: GoalRoadmap) -> Double {
        guard !milestone.tasks.isEmpty else { return 0 }
        let completed = milestone.tasks.filter { taskIsCompleted($0, roadmap: roadmap) }.count
        return min(max(Double(completed) / Double(milestone.tasks.count), 0), 1)
    }

    private func roadmapProgress(_ roadmap: GoalRoadmap) -> Double {
        let allTasks = roadmap.milestones.flatMap(\.tasks)
        guard !allTasks.isEmpty else { return 0 }
        let completed = allTasks.filter { taskIsCompleted($0, roadmap: roadmap) }.count
        return min(max(Double(completed) / Double(allTasks.count), 0), 1)
    }

    private func currentMilestoneIndex(_ roadmap: GoalRoadmap) -> Int? {
        roadmap.milestones.firstIndex { milestoneCompletion($0, roadmap: roadmap) < 1 }
    }

    private func applySuggestedSchedule() {
        let moves = intelligence.suggestions
        guard !moves.isEmpty else { return }

        for move in moves {
            guard var task = store.tasks.first(where: { $0.id == move.taskID }), !task.isCompleted else { continue }
            task.dueDate = move.proposedDate
            store.update(task)
        }

        NotificationCenter.default.post(name: .lippiCareDidChange, object: nil)
        withAnimation(reduceMotion ? nil : DS.motionState) {
            adaptationResult = L10n.fmt("calendar.adapt.done", lang, moves.count)
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
