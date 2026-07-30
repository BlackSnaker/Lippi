import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    }

    private var monthCard: some View {
        GlassCard(padding: 16, cornerRadius: 28, style: .lightweight, forceSystemGlass: true) {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    monthNavigationButton(direction: -1, icon: "chevron.left")

                    VStack(spacing: 2) {
                        Text(monthTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("calendar.month.subtitle"))
                            .font(.caption)
                            .foregroundStyle(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    monthNavigationButton(direction: 1, icon: "chevron.right")
                }

                LazyVGrid(columns: weekdayColumns, spacing: 7) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DS.textTertiary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
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

    private func monthNavigationButton(direction: Int, icon: String) -> some View {
        Button {
            guard let month = calendar.date(byAdding: .month, value: direction, to: displayedMonth) else { return }
            withAnimation(reduceMotion ? nil : DS.motionState) {
                displayedMonth = monthStart(for: month)
                selectedDate = monthStart(for: month)
            }
        } label: {
            Image(safeSystemName: icon, fallback: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 44, height: 44)
                .background(DS.glassFill(0.08), in: Circle())
                .overlay(Circle().stroke(DS.glassStroke(0.11), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.82))
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
                    .foregroundStyle(isSelected ? Color.white : DS.textPrimary)

                HStack(spacing: 2) {
                    if unfinished > 0 {
                        Circle()
                            .fill(isSelected ? Color.white : DS.accent)
                            .frame(width: 4, height: 4)
                    }
                    if completed {
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.65) : Color(hex: 0x30D158))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 45)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? DS.accent : (isToday ? DS.accent.opacity(0.11) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isToday && !isSelected ? DS.accent.opacity(0.40) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(date: date, planCount: plans.count))
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
    }

    private var selectedPlansCard: some View {
        let dated = tasks(on: selectedDate)
        let undated = calendar.isDateInToday(selectedDate)
            ? store.tasks.filter { !$0.isCompleted && $0.dueDate == nil }
            : []

        return GlassCard(padding: 17, cornerRadius: 26, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: selectedDateTitle,
                    subtitle: dated.isEmpty && undated.isEmpty
                        ? s("calendar.day.empty")
                        : L10n.fmt("calendar.day.count", lang, dated.count + undated.count),
                    icon: "calendar.day.timeline.left",
                    accent: DS.accent
                )

                if dated.isEmpty && undated.isEmpty {
                    HStack(spacing: 12) {
                        Image(safeSystemName: "leaf.fill", fallback: "sparkles")
                            .foregroundStyle(Color(hex: 0x30D158))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: 0x30D158).opacity(0.10), in: Circle())
                        Text(s("calendar.day.empty_hint"))
                            .font(.subheadline)
                            .foregroundStyle(DS.textSecondary)
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

    private func taskRow(_ task: TaskItem, showsUnscheduled: Bool) -> some View {
        Button {
            store.toggle(task.id, stats: stats)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? Color(hex: 0x30D158).opacity(0.16) : task.category.tint.opacity(0.13))
                    Image(safeSystemName: task.isCompleted ? "checkmark" : task.category.symbol, fallback: "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(task.isCompleted ? Color(hex: 0x30D158) : task.category.tint)
                }
                .frame(width: 38, height: 38)

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

                Spacer(minLength: 8)

                Image(safeSystemName: task.isCompleted ? "checkmark.circle.fill" : "circle", fallback: "circle")
                    .foregroundStyle(task.isCompleted ? Color(hex: 0x30D158) : DS.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(s("calendar.task.toggle_hint"))
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
            GlassCard(padding: 17, cornerRadius: 24, style: .flat) {
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
