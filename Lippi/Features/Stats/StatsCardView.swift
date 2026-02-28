import SwiftUI
#if canImport(Charts)
import Charts
#endif

// =======================================================
// MARK: - STATS CARD (UI) — Premium + compiler-friendly
// локальные текстовые токены
// =======================================================
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
    @State private var showHint = false

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private let tPrimary = DS.text(0.94)
    private let tSecondary = DS.text(0.72)

    var body: some View {
        GlassCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                header
                kpis
                chart
                footerHint
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            LippiSectionHeader(
                title: s("stats.header.title"),
                subtitle: s("stats.header.subtitle"),
                icon: "chart.bar.xaxis",
                accent: Color(hex: 0x64D2FF)
            )

            Spacer(minLength: 8)

            // Premium “segmented capsule”
            HStack(spacing: 10) {
                Picker("", selection: $daysWindow) {
                    Text(s("stats.window.7")).singleLine().tag(7)
                    Text(s("stats.window.30")).singleLine().tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Picker("", selection: $metric) {
                    ForEach(StatsMetric.allCases) { Text($0.title).singleLine().tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }
            .padding(6)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.stroke, lineWidth: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(DS.strokeInner, lineWidth: 1)
                            .padding(1)
                            .blendMode(.overlay)
                    )
            )
        }
    }

    private var kpis: some View {
        let data = stats.series(last: daysWindow)
        let totals = stats.totals(for: data)
        let avgFocus = totals.focus / max(daysWindow, 1)

        return HStack(spacing: 10) {
            kpi(icon: "bolt.fill",    tint: AnyShapeStyle(DS.brand),                 title: s("stats.kpi.focus_minutes"),  value: "\(totals.focus)")
            kpi(icon: "checkmark",    tint: AnyShapeStyle(DS.text(0.9)),             title: s("stats.kpi.tasks"),          value: "\(totals.tasks)")
            kpi(icon: "flame.fill",   tint: AnyShapeStyle(Color(hex: 0xFF6B6B)),     title: s("stats.kpi.streak_days"),    value: "\(stats.productiveStreak)")
            kpi(icon: "gauge.medium", tint: AnyShapeStyle(Color(hex: 0x41D3BD)),     title: s("stats.kpi.avg_focus"),      value: "\(avgFocus)")
        }
    }

    private func kpi(icon: String, tint: AnyShapeStyle, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.glassFill(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tSecondary)
                    .singleLine()
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tPrimary)
                .singleLine()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(kpiBackground)
        .overlay(kpiOverlay)
        .shadow(color: DS.depthShadow(0.14), radius: 6, x: 0, y: 3)
    }

    private var kpiBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(DS.glassFill(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.glassTint)
                    .opacity(0.55)
            )
    }

    private var kpiOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(DS.stroke, lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(DS.strokeInner, lineWidth: 1)
                    .padding(1)
                    .blendMode(.overlay)
            )
    }

    @ViewBuilder
    private var chart: some View {
        let data = stats.series(last: daysWindow)
        #if canImport(Charts)
        chartsView(data: data)
        #else
        SimpleBars(data: data, metric: metric, selected: $selected, showHint: $showHint)
            .frame(height: 190)
        #endif
    }

    #if canImport(Charts)
    private func chartsView(data: [DayStats]) -> some View {
        let panel = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return Chart {
            ForEach(data, id: \.date) { day in
                if metric == .focus || metric == .both {
                    BarMark(
                        x: .value(s("stats.axis.date"), day.date, unit: .day),
                        y: .value(s("stats.axis.focus_minutes"), day.focusMinutes)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(DS.brand)
                    .opacity(selected?.date == day.date ? 1 : 0.88)
                }

                if metric == .tasks || metric == .both {
                    LineMark(
                        x: .value(s("stats.axis.date"), day.date, unit: .day),
                        y: .value(s("stats.axis.tasks"), day.tasksDone)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .foregroundStyle(DS.text(0.92))

                    PointMark(
                        x: .value(s("stats.axis.date"), day.date, unit: .day),
                        y: .value(s("stats.axis.tasks"), day.tasksDone)
                    )
                    .symbolSize(selected?.date == day.date ? 70 : 32)
                    .foregroundStyle(DS.text(selected?.date == day.date ? 0.95 : 0.55))
                }

                if let s = selected, s.date == day.date {
                    RuleMark(x: .value(self.s("stats.axis.selected_date"), s.date, unit: .day))
                        .foregroundStyle(DS.text(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
        .chartXAxis { axisX }
        .chartYAxis { axisY }
        .frame(height: 230)
        .padding(10)
        .background(panelBackground(panel))
        .overlay(panelOverlay(panel))
        .shadow(color: DS.depthShadow(0.14), radius: 8, x: 0, y: 5)
        .chartOverlay { proxy in
            overlayGesture(proxy: proxy, data: data)
        }
    }

    private var axisX: some Charts.AxisContent {
        Charts.AxisMarks(values: .stride(by: .day, count: daysWindow == 7 ? 1 : 5)) { _ in
            Charts.AxisGridLine().foregroundStyle(DS.text(0.08))
            Charts.AxisTick().foregroundStyle(DS.text(0.25))
            Charts.AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                .foregroundStyle(DS.text(0.78))
                .font(.caption2)
        }
    }

    private var axisY: some Charts.AxisContent {
        Charts.AxisMarks(position: .leading) { _ in
            Charts.AxisGridLine().foregroundStyle(DS.text(0.08))
            Charts.AxisTick().foregroundStyle(DS.text(0.25))
            Charts.AxisValueLabel()
                .foregroundStyle(DS.text(0.55))
                .font(.caption2)
        }
    }

    private func panelBackground(_ panel: RoundedRectangle) -> some View {
        panel
            .fill(DS.glassFill(0.10))
            .overlay(panel.fill(DS.glassTint).opacity(0.58))
    }

    private func panelOverlay(_ panel: RoundedRectangle) -> some View {
        panel
            .stroke(DS.stroke, lineWidth: 1)
            .overlay(panel.stroke(DS.strokeInner, lineWidth: 1).padding(1).blendMode(.overlay))
    }

    private func overlayGesture(proxy: Charts.ChartProxy, data: [DayStats]) -> some View {
        GeometryReader { _ in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let x: Date = proxy.value(atX: value.location.x) else { return }
                            selectNearest(to: x, in: data)
                        }
                        .onEnded { _ in
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            #endif
                            if reduceMotion {
                                showHint = true
                            } else {
                                withAnimation(DS.motionFadeQuick) { showHint = true }
                            }
                        }
                )
        }
    }

    private func selectNearest(to date: Date, in data: [DayStats]) {
        let nearest = data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        if nearest?.date != selected?.date {
            selected = nearest
        }
    }
    #endif

    private var footerHint: some View {
        let selectedDay = selected
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DS.glassFill(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(DS.glassStroke(0.14), lineWidth: 1))
                Image(systemName: selectedDay == nil ? "hand.tap" : "sparkles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.text(0.9))
            }

            if let selectedDay {
                Text(selectedDay.date, format: .dateTime.day().month(.wide))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tPrimary)
                    .singleLine()

                Spacer(minLength: 6)

                Label("\(selectedDay.focusMinutes)", systemImage: "bolt.fill")
                    .font(.footnote.weight(.semibold))
                    .labelStyle(TightLabelStyle())
                    .foregroundStyle(tSecondary)
                    .singleLine()

                Label("\(selectedDay.tasksDone)", systemImage: "checkmark")
                    .font(.footnote.weight(.semibold))
                    .labelStyle(TightLabelStyle())
                    .foregroundStyle(tSecondary)
                    .singleLine()
            } else {
                Text(s("stats.footer.hint"))
                    .font(.subheadline)
                    .foregroundStyle(tSecondary)
                    .singleLine()
            }

            Spacer()
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct SimpleBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: [DayStats]
    let metric: StatsMetric
    @Binding var selected: DayStats?
    @Binding var showHint: Bool

    var maxValue: Double {
        switch metric {
        case .focus: return max(60, Double(data.map{$0.focusMinutes}.max() ?? 0))
        case .tasks: return max(5, Double(data.map{$0.tasksDone}.max() ?? 0))
        case .both:  return max(60, Double(data.map{$0.focusMinutes}.max() ?? 0))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(max(data.count,1))

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(data, id: \.date) { d in
                    bar(d: d, w: w, totalH: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .background(backgroundPanel)
            .overlay(overlayPanel)
            .shadow(color: DS.depthShadow(0.14), radius: 8, x: 0, y: 5)
        }
    }

    private func bar(d: DayStats, w: CGFloat, totalH: CGFloat) -> some View {
        let value: Double = {
            switch metric {
            case .focus, .both: return Double(d.focusMinutes)
            case .tasks:        return Double(d.tasksDone)
            }
        }()
        let h = max(2, CGFloat(value / maxValue) * (totalH - 24))
        let isSel = (selected?.date == d.date)

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(DS.brand)
            .opacity(isSel ? 1.0 : 0.65)
            .frame(width: max(10, w - 8), height: h)
            .overlay {
                if isSel {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DS.glassStroke(0.20), lineWidth: 1)
                        .shadow(color: DS.glassFill(0.08), radius: 4)
                }
            }
            .onTapGesture {
                if reduceMotion {
                    selected = d
                    showHint = true
                } else {
                    withAnimation(DS.motionQuick) {
                        selected = d
                        showHint = true
                    }
                }
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
            }
    }

    private var backgroundPanel: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(DS.glassFill(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassTint)
                    .opacity(0.58)
            )
    }

    private var overlayPanel: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(DS.stroke, lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(DS.strokeInner, lineWidth: 1)
                    .padding(1)
                    .blendMode(.overlay)
            )
    }
}
