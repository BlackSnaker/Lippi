import SwiftUI

private enum StatsMetric: String, CaseIterable, Identifiable {
    case focus, tasks, both

    var id: String { rawValue }

    var title: String {
        let lang = L10n.currentLang
        switch self {
        case .focus: return L10n.tr("stats.metric.focus", lang)
        case .tasks: return L10n.tr("stats.metric.tasks", lang)
        case .both: return L10n.tr("stats.metric.both", lang)
        }
    }
}

struct StatsCardView: View {
    @EnvironmentObject private var stats: StatsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    @State private var daysWindow: Int = 7
    @State private var metric: StatsMetric = .both
    @State private var selected: DayStats?

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var data: [DayStats] { stats.series(last: daysWindow) }
    private var totals: (focus: Int, tasks: Int) { stats.totals(for: data) }
    private var activeDays: Int { data.filter(\.hasActivity).count }
    private var averageFocus: Int { totals.focus / max(daysWindow, 1) }
    private var rhythmProgress: Double { Double(activeDays) / Double(max(daysWindow, 1)) }
    private var rhythmPercent: Int { Int((rhythmProgress * 100).rounded()) }
    private var bestDay: DayStats? {
        data.max { lhs, rhs in
            let left = lhs.focusMinutes + lhs.tasksDone * 20
            let right = rhs.focusMinutes + rhs.tasksDone * 20
            return left < right
        }
    }
    private var selectedOrBestDay: DayStats? { selected ?? bestDay }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    var body: some View {
        GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 16) {
                header
                insightPanel
                metricGrid
                timelineHeader
                ReadableActivityTimeline(
                    data: data,
                    metric: metric,
                    lang: lang,
                    selected: $selected
                )
                footerHint
            }
        }
        .animation(reduceMotion ? nil : DS.motionState, value: daysWindow)
        .animation(reduceMotion ? nil : DS.motionState, value: metric)
        .animation(reduceMotion ? nil : DS.motionState, value: selected?.date)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                LippiSectionHeader(
                    title: s("stats.header.title"),
                    subtitle: s("stats.header.subtitle"),
                    icon: "chart.line.uptrend.xyaxis",
                    accent: Color(hex: 0x64D2FF)
                )

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Picker("", selection: $daysWindow) {
                    Text(s("stats.window.7")).singleLine().tag(7)
                    Text(s("stats.window.30")).singleLine().tag(30)
                }
                .pickerStyle(.segmented)

                Picker("", selection: $metric) {
                    ForEach(StatsMetric.allCases) { Text($0.title).singleLine().tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .controlSize(.small)
            .padding(6)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
            )
        }
    }

    private var insightPanel: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(DS.glassStroke(0.16), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: max(0, min(1, rhythmProgress)))
                    .stroke(
                        AngularGradient(colors: [DS.brandA, DS.brandB, Color(hex: 0x30D158)], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(rhythmPercent)%")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(DS.textPrimary)

                    Text(s("stats.insight.rhythm"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                }
            }
            .frame(width: 82, height: 82)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(DS.brandSoftGradient).opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(DS.glassStroke(0.16), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 7) {
                Label(insightTitle, systemImage: insightSymbol)
                    .font(.headline.weight(.bold))
                    .labelStyle(TightLabelStyle())
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text(insightBody)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.90)

                FancyLinearProgressBar(progress: rhythmProgress, height: 8)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.11))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.glassTint).opacity(0.50))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: DS.accent.opacity(0.10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.15), lineWidth: 1)
        )
    }

    private var insightTitle: String {
        if totals.focus == 0 && totals.tasks == 0 { return s("stats.insight.empty_title") }
        if activeDays == daysWindow { return s("stats.insight.stable_title") }
        if data.last?.hasActivity == true { return s("stats.insight.today_active_title") }
        return s("stats.insight.title")
    }

    private var insightSymbol: String {
        if totals.focus == 0 && totals.tasks == 0 { return "sparkles" }
        if activeDays == daysWindow { return "checkmark.seal.fill" }
        if data.last?.hasActivity == true { return "bolt.heart.fill" }
        return "waveform.path.ecg"
    }

    private var insightBody: String {
        if totals.focus == 0 && totals.tasks == 0 {
            return s("stats.insight.empty_body")
        }

        return L10n.fmt(
            "stats.insight.body",
            lang,
            formattedMinutes(totals.focus),
            totals.tasks,
            activeDays,
            daysWindow
        )
    }

    private var metricGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: 10) {
            metricTile(
                title: s("stats.kpi.focus_minutes"),
                value: formattedMinutes(totals.focus),
                detail: s("stats.kpi.period_total"),
                icon: "timer",
                tone: Color(hex: 0x64D2FF),
                progress: min(Double(totals.focus) / Double(daysWindow * 45), 1)
            )

            metricTile(
                title: s("stats.kpi.tasks"),
                value: "\(totals.tasks)",
                detail: s("stats.kpi.tasks_done"),
                icon: "checkmark.circle.fill",
                tone: Color(hex: 0x30D158),
                progress: min(Double(totals.tasks) / Double(max(daysWindow, 1)), 1)
            )

            metricTile(
                title: s("stats.kpi.streak_days"),
                value: "\(stats.productiveStreak)",
                detail: s("stats.kpi.streak_hint"),
                icon: "flame.fill",
                tone: Color(hex: 0xFF9F0A),
                progress: min(Double(stats.productiveStreak) / 7.0, 1)
            )

            metricTile(
                title: s("stats.kpi.avg_focus"),
                value: formattedMinutes(averageFocus),
                detail: s("stats.kpi.daily_average"),
                icon: "gauge.with.dots.needle.33percent",
                tone: Color(hex: 0x41D3BD),
                progress: min(Double(averageFocus) / 45.0, 1)
            )
        }
    }

    private func metricTile(title: String, value: String, detail: String, icon: String, tone: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(DS.glassFill(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(tone.opacity(0.22)))
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(DS.glassStroke(0.16), lineWidth: 1))

                    Image(safeSystemName: icon, fallback: "circle.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.text(0.94))
                }
                .frame(width: 34, height: 34)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .contentTransition(.numericText())

            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            FancyLinearProgressBar(progress: max(0, min(1, progress)), height: 6)
                .tint(tone)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.glassFill(0.10))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tone.opacity(0.07)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.glassStroke(0.13), lineWidth: 1)
        )
        .shadow(color: DS.depthShadow(0.10), radius: 7, x: 0, y: 4)
    }

    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(s("stats.timeline.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Spacer(minLength: 8)

                if let day = selectedOrBestDay {
                    Text(day.date, format: .dateTime.day().month(.abbreviated))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DS.glassFill(0.10), in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(DS.glassStroke(0.13), lineWidth: 1))
                }
            }

            HStack(spacing: 8) {
                legendChip(title: s("stats.legend.focus"), color: Color(hex: 0x64D2FF), symbol: "timer")
                legendChip(title: s("stats.legend.tasks"), color: Color(hex: 0x30D158), symbol: "checkmark")
                Spacer(minLength: 0)
            }
        }
    }

    private func legendChip(title: String, color: Color, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(Capsule(style: .continuous).fill(color.opacity(0.15)))
            )
            .overlay(Capsule(style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
            .singleLine()
    }

    private var footerHint: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DS.glassFill(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(DS.glassStroke(0.14), lineWidth: 1))

                Image(safeSystemName: selected == nil ? "hand.tap" : "sparkles", fallback: "sparkles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.text(0.9))
            }

            if let selected {
                Text(selected.summaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let bestDay, bestDay.hasActivity {
                Text(L10n.fmt("stats.footer.best_day", lang, formattedDay(bestDay.date), bestDay.summaryText))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(s("stats.footer.hint"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        if safeMinutes < 60 {
            return L10n.fmt("stats.minutes", lang, safeMinutes)
        }

        let hours = safeMinutes / 60
        let rest = safeMinutes % 60
        return rest == 0
        ? L10n.fmt("stats.hours", lang, hours)
        : L10n.fmt("stats.hours_minutes", lang, hours, rest)
    }

    private func formattedDay(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .locale(Locale(identifier: lang.localeIdentifier))
        )
    }
}

private struct ReadableActivityTimeline: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let data: [DayStats]
    let metric: StatsMetric
    let lang: AppLang
    @Binding var selected: DayStats?

    private var maxFocus: Double { max(1, Double(data.map(\.focusMinutes).max() ?? 0)) }
    private var maxTasks: Double { max(1, Double(data.map(\.tasksDone).max() ?? 0)) }
    private var isCompact: Bool { data.count > 12 }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = isCompact ? 3 : 7
            let available = geo.size.width - spacing * CGFloat(max(data.count - 1, 0))
            let itemWidth = max(isCompact ? 7 : 18, available / CGFloat(max(data.count, 1)))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(data) { day in
                    timelineDay(day, itemWidth: itemWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 9)
        }
        .frame(height: isCompact ? 156 : 168)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.10))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.glassTint).opacity(0.48))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: DS.accent.opacity(0.08)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
        .shadow(color: DS.depthShadow(0.10), radius: 8, x: 0, y: 5)
    }

    private func timelineDay(_ day: DayStats, itemWidth: CGFloat) -> some View {
        let isSelected = selected?.id == day.id

        return VStack(spacing: 7) {
            ZStack(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(Capsule(style: .continuous).stroke(DS.glassStroke(0.10), lineWidth: 1))
                    .frame(width: max(6, itemWidth * 0.62))

                if metric != .tasks {
                    focusBar(for: day, itemWidth: itemWidth)
                }

                if metric != .focus {
                    taskMark(for: day, itemWidth: itemWidth)
                }
            }
            .frame(width: itemWidth, height: isCompact ? 102 : 112, alignment: .bottom)
            .padding(.top, isSelected ? 3 : 6)
            .padding(.horizontal, isCompact ? 1 : 3)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? DS.glassFill(0.13) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(isSelected ? DS.glassStroke(0.18) : .clear, lineWidth: 1)
                    )
            )

            Text(dayLabel(for: day.date, selected: isSelected))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? DS.textPrimary : DS.textTertiary)
                .frame(width: itemWidth)
                .frame(minHeight: 14)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if reduceMotion {
                selected = day
            } else {
                withAnimation(DS.motionQuick) { selected = day }
            }

            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel(for: day)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            selected = day
        }
    }

    private func focusBar(for day: DayStats, itemWidth: CGFloat) -> some View {
        let height = barHeight(value: Double(day.focusMinutes), maxValue: maxFocus, minimum: day.focusMinutes > 0 ? 9 : 3)

        return Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x64D2FF), DS.brandA, DS.brandB.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(Capsule(style: .continuous).fill(DS.brandIridescent).opacity(0.35).blendMode(.screen))
            .frame(width: max(5, itemWidth * (isCompact ? 0.52 : 0.58)), height: height)
            .opacity(day.focusMinutes > 0 ? 1.0 : 0.20)
    }

    private func taskMark(for day: DayStats, itemWidth: CGFloat) -> some View {
        let taskCount = day.tasksDone
        let yOffset: CGFloat = metric == .tasks
        ? -barHeight(value: Double(taskCount), maxValue: maxTasks, minimum: taskCount > 0 ? 10 : 3) + 8
        : -barHeight(value: Double(day.focusMinutes), maxValue: maxFocus, minimum: day.focusMinutes > 0 ? 9 : 3) - 5

        return Group {
            if metric == .tasks {
                Capsule(style: .continuous)
                    .fill(Color(hex: 0x30D158).opacity(taskCount > 0 ? 0.95 : 0.18))
                    .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.22)).blendMode(.overlay))
                    .frame(
                        width: max(5, itemWidth * (isCompact ? 0.50 : 0.56)),
                        height: barHeight(value: Double(taskCount), maxValue: maxTasks, minimum: taskCount > 0 ? 10 : 3)
                    )
            } else if taskCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x30D158))
                        .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))

                    if !isCompact {
                        Text("\(min(taskCount, 9))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: isCompact ? 8 : 18, height: isCompact ? 8 : 18)
                .shadow(color: Color(hex: 0x30D158).opacity(0.24), radius: 5, x: 0, y: 2)
                .offset(y: yOffset)
            }
        }
    }

    private func barHeight(value: Double, maxValue: Double, minimum: CGFloat) -> CGFloat {
        let available: CGFloat = isCompact ? 96 : 106
        guard value > 0 else { return minimum }
        return max(minimum, CGFloat(value / max(maxValue, 1)) * available)
    }

    private func dayLabel(for date: Date, selected: Bool) -> String {
        if isCompact {
            let day = Calendar.current.component(.day, from: date)
            return selected || day % 5 == 0 ? "\(day)" : ""
        }

        return date.formatted(
            .dateTime
                .weekday(.narrow)
                .locale(Locale(identifier: lang.localeIdentifier))
        ).uppercased()
    }

    private func accessibilityLabel(for day: DayStats) -> String {
        let date = day.date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .locale(Locale(identifier: lang.localeIdentifier))
        )
        return "\(date): \(day.summaryText)"
    }
}
