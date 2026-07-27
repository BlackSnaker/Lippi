import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HealthDashboardView: View {
    @ObservedObject var manager: HealthKitManager
    let lang: AppLang
    let onOpenPractice: () -> Void
    let onOpenEyes: () -> Void
    let onOpenGoals: () -> Void

    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var careCenter: LippiCareCenter
    @AppStorage("goal.progress.userState") private var userStateRaw: String = GoalUserState.calm.rawValue
    @AppStorage(GoalProgressNotificationScheduler.roadmapStorageKey) private var savedRoadmap: String = ""
    @AppStorage(AdaptiveGoalPlanRecordStore.storageKey) private var savedAdaptation: String = ""
    @StateObject private var checkIns = WellbeingCheckInStore()
    @State private var showsAdaptationConfirmation = false

    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var selectedState: GoalUserState {
        get { GoalUserState(rawValue: userStateRaw) ?? .calm }
        nonmutating set { userStateRaw = newValue.rawValue }
    }

    private var roadmap: GoalRoadmap? {
        guard let data = savedRoadmap.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GoalRoadmap.self, from: data)
    }

    private var adaptationRecord: AdaptiveGoalPlanRecord? {
        AdaptiveGoalPlanRecordStore.decode(savedAdaptation)
    }

    private var currentAudit: GoalPlanProgressAudit? {
        roadmap.flatMap { GoalPlanProgressAudit.make(roadmap: $0, tasks: store.tasks) }
    }

    private var currentPace: AdaptiveGoalPace {
        if let roadmap,
           let record = adaptationRecord,
           record.isPresent(in: roadmap),
           record.matchesCurrentContext(
               healthBand: manager.isEnabled ? manager.recommendation?.band : nil,
               userState: selectedState,
               audit: currentAudit
           ) {
            return record.pace
        }
        return AdaptiveGoalPaceEngine.evaluate(
            health: manager.isEnabled ? manager.recommendation : nil,
            audit: currentAudit,
            userState: selectedState
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            dailyRhythmCard
                .lippiMotionScene(0)

            careRhythmCard
                .lippiMotionScene(1)

            wellbeingCheckInCard
                .lippiMotionScene(2)

            HealthKitInsightCard(
                manager: manager,
                lang: lang,
                onUseBreathing: onOpenPractice,
                onOpenEyes: onOpenEyes
            )
            .lippiMotionScene(3)

            planAdaptationCard
                .lippiMotionScene(4)
        }
        .confirmationDialog(
            s("health.hub.plan.confirm.title"),
            isPresented: $showsAdaptationConfirmation,
            titleVisibility: .visible
        ) {
            Button(s("health.hub.plan.confirm.apply")) {
                applyCurrentPace()
            }
            Button(s("health.hub.plan.confirm.cancel"), role: .cancel) {}
        } message: {
            Text(s("health.hub.plan.confirm.message"))
        }
    }

    private var careRhythmCard: some View {
        let suggestion = careCenter.primarySuggestion
        let kind = suggestion?.kind ?? .steady
        let tone = careTone(kind)

        return GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(s("care.card.eyebrow"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tone)

                        Text(s("care.card.title"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(DS.textPrimary)

                        Text(s("care.card.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(safeSystemName: kind.icon, fallback: "heart.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tone)
                        .frame(width: 50, height: 50)
                        .background(tone.opacity(0.13), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(tone.opacity(0.22), lineWidth: 1)
                        )
                }

                if let suggestion {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(suggestion.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(suggestion.body)
                            .font(.subheadline)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(tone.opacity(0.18), lineWidth: 1)
                    )

                    if suggestion.action != .none {
                        Button {
                            performCareAction(suggestion.action)
                        } label: {
                            Label(suggestion.actionTitle, systemImage: kind.icon)
                                .labelStyle(TightLabelStyle())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text(s("care.card.quick"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        careQuickButton(.logWater, icon: "drop.fill", tone: Color(hex: 0x64D2FF))
                        careQuickButton(.logMeal, icon: "fork.knife", tone: Color(hex: 0xFFB340))
                        careQuickButton(.logMovement, icon: "figure.walk", tone: Color(hex: 0x30D158))
                        careQuickButton(.openEyes, icon: "eye.fill", tone: Color(hex: 0xBF5AF2))
                    }
                }

                Label(s("care.card.privacy"), systemImage: "lock.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func careQuickButton(_ action: LippiCareAction, icon: String, tone: Color) -> some View {
        Button {
            performCareAction(action)
        } label: {
            HStack(spacing: 8) {
                Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone)
                    .frame(width: 28, height: 28)
                    .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(s("care.action.\(action.rawValue)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(DS.glassFill(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97, opacity: 0.88))
    }

    private func performCareAction(_ action: LippiCareAction) {
        careCenter.record(action)
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        switch action {
        case .openEyes:
            onOpenEyes()
        case .openRecovery:
            onOpenPractice()
        case .openGoal:
            onOpenGoals()
        case .logMeal, .logMovement, .logWater, .none:
            break
        }
    }

    private func careTone(_ kind: LippiCareKind) -> Color {
        switch kind {
        case .eyeBreak: return Color(hex: 0xBF5AF2)
        case .recovery: return Color(hex: 0xFF6B7A)
        case .mealCheck: return Color(hex: 0xFFB340)
        case .movement: return Color(hex: 0x30D158)
        case .hydration: return Color(hex: 0x64D2FF)
        case .goalStep: return DS.accent
        case .steady: return Color(hex: 0x5AC8FA)
        }
    }

    private var dailyRhythmCard: some View {
        let pace = currentPace
        let tone = paceTone(pace.level)

        return GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s("health.hub.eyebrow"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tone)

                        Text(s("health.hub.title"))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(DS.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button {
                        Task { await manager.refresh() }
                    } label: {
                        Image(safeSystemName: "arrow.clockwise", fallback: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.82))
                    .foregroundStyle(DS.textSecondary)
                    .background(DS.glassFill(0.08), in: Circle())
                    .lippiSystemGlass(in: Circle(), tint: tone.opacity(0.08), interactive: true)
                    .disabled(!manager.isEnabled || manager.state == .refreshing)
                    .opacity(manager.isEnabled ? 1 : 0.45)
                    .accessibilityLabel(Text(s("healthkit.refresh")))
                }

                HStack(alignment: .center, spacing: 13) {
                    Image(safeSystemName: paceIcon(pace.level), fallback: "heart.fill")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(tone)
                        .frame(width: 54, height: 54)
                        .background(tone.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(tone.opacity(0.20), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("health.hub.pace.\(pace.level.rawValue)"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(s("adaptive.goal.pace.\(pace.level.rawValue).description"))
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    dashboardMetric(
                        icon: selectedState.icon,
                        value: selectedState.title(lang: lang),
                        title: s("health.hub.metric.feeling"),
                        tone: selectedState.tone
                    )
                    dashboardMetric(
                        icon: "timer",
                        value: L10n.fmt("health.hub.metric.minutes.value", lang, pace.focusMinutes),
                        title: s("health.hub.metric.focus"),
                        tone: Color(hex: 0x64D2FF)
                    )
                }

                if let updated = manager.lastUpdated {
                    HStack(spacing: 5) {
                        Image(safeSystemName: "checkmark.circle.fill", fallback: "checkmark.circle")
                        Text(s("health.hub.updated"))
                        Text(updated, style: .relative)
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func dashboardMetric(
        icon: String,
        value: String,
        title: String,
        tone: Color
    ) -> some View {
        HStack(spacing: 9) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(tone)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(DS.glassFill(0.06), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
    }

    private var wellbeingCheckInCard: some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .lightweight) {
            VStack(alignment: .leading, spacing: 15) {
                LippiSectionHeader(
                    title: s("health.hub.checkin.title"),
                    subtitle: s("health.hub.checkin.subtitle"),
                    icon: "face.smiling.inverse",
                    accent: selectedState.tone
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(GoalUserState.allCases) { state in
                        wellbeingButton(state)
                    }
                }

                Divider()
                    .overlay(DS.glassStroke(0.10))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(s("health.hub.checkin.week"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)

                        Spacer(minLength: 8)

                        if checkIns.entry(on: .now) != nil {
                            Label(s("health.hub.checkin.saved"), systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color(hex: 0x30D158))
                                .labelStyle(TightLabelStyle())
                        }
                    }

                    wellbeingWeek
                }

                Text(s("health.hub.checkin.impact"))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func wellbeingButton(_ state: GoalUserState) -> some View {
        let isSelected = selectedState == state

        return Button {
            selectedState = state
            checkIns.record(state)
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            VStack(spacing: 7) {
                Image(safeSystemName: state.icon, fallback: "circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(state.tone)
                    .frame(width: 34, height: 34)
                    .background(state.tone.opacity(isSelected ? 0.18 : 0.10), in: Circle())

                Text(state.title(lang: lang))
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(DS.text(isSelected ? 0.96 : 0.76))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? state.tone.opacity(0.10) : DS.glassFill(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? state.tone.opacity(0.34) : DS.glassStroke(0.09), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97, opacity: 0.88))
        .accessibilityLabel(Text("\(state.title(lang: lang)), \(state.subtitle(lang: lang))"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var wellbeingWeek: some View {
        HStack(spacing: 6) {
            ForEach(checkIns.datesForRecentWeek(), id: \.self) { date in
                let entry = checkIns.entry(on: date)
                let isToday = Calendar.current.isDateInToday(date)

                VStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(entry?.state.tone.opacity(entry == nil ? 0 : 0.16) ?? DS.glassFill(0.05))
                            .frame(width: 30, height: 30)

                        if let entry {
                            Image(safeSystemName: entry.state.icon, fallback: "circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(entry.state.tone)
                        } else {
                            Circle()
                                .fill(DS.textTertiary.opacity(0.40))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(isToday ? DS.accent.opacity(0.45) : Color.clear, lineWidth: 1)
                    )

                    Text(weekdayTitle(for: date))
                        .font(.caption2.weight(isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? DS.textSecondary : DS.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(weekAccessibilityLabel(date: date, entry: entry)))
            }
        }
    }

    @ViewBuilder
    private var planAdaptationCard: some View {
        if let roadmap {
            configuredPlanCard(roadmap)
        } else {
            emptyPlanCard
        }
    }

    private func configuredPlanCard(_ roadmap: GoalRoadmap) -> some View {
        let audit = GoalPlanProgressAudit.make(roadmap: roadmap, tasks: store.tasks)
        let record = adaptationRecord.flatMap { $0.roadmapID == roadmap.id ? $0 : nil }
        let pace: AdaptiveGoalPace
        if let record,
           record.isPresent(in: roadmap),
           record.matchesCurrentContext(
               healthBand: manager.isEnabled ? manager.recommendation?.band : nil,
               userState: selectedState,
               audit: audit
           ) {
            pace = record.pace
        } else {
            pace = AdaptiveGoalPaceEngine.evaluate(
                health: manager.isEnabled ? manager.recommendation : nil,
                audit: audit,
                userState: selectedState
            )
        }
        let isApplied = AdaptiveGoalPlanEngine.isApplied(to: roadmap, pace: pace, lang: lang)
            || (record?.pace == pace && record?.isPresent(in: roadmap) == true)
        let tone = paceTone(pace.level)

        return GlassCard(padding: 16, cornerRadius: 26, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s(isApplied ? "health.hub.plan.applied.title" : "health.hub.plan.suggestion.title"),
                    subtitle: roadmap.title,
                    icon: isApplied ? "checkmark.seal.fill" : "slider.horizontal.3",
                    accent: isApplied ? Color(hex: 0x30D158) : tone
                )

                HStack(alignment: .top, spacing: 11) {
                    Image(safeSystemName: paceIcon(pace.level), fallback: "heart.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tone)
                        .frame(width: 38, height: 38)
                        .background(tone.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(s("health.hub.pace.\(pace.level.rawValue)"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)

                        Text(s(isApplied ? "health.hub.plan.applied.subtitle" : "health.hub.plan.suggestion.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    planMetric(
                        value: "\(pace.dailyStepLimit)",
                        title: s("adaptive.goal.metric.steps"),
                        tone: tone
                    )
                    planMetric(
                        value: "\(pace.focusMinutes)",
                        title: s("adaptive.goal.metric.focus"),
                        tone: Color(hex: 0x64D2FF)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(pace.reasons.prefix(3), id: \.self) { reason in
                        explanationRow(
                            s("adaptive.goal.reason.\(reason.rawValue)"),
                            icon: "checkmark.circle.fill",
                            tone: tone
                        )
                    }
                }

                if isApplied {
                    appliedPlanSummary(record: record, pace: pace)
                } else {
                    proposedPlanChanges(audit: audit, pace: pace, hasPreviousRecord: record != nil)
                }

                Label(s("adaptive.goal.promise"), systemImage: "flag.checkered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    if !isApplied {
                        Button {
                            showsAdaptationConfirmation = true
                        } label: {
                            Label(s("health.hub.plan.review"), systemImage: "wand.and.stars")
                                .labelStyle(TightLabelStyle())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
                    }

                    Button(action: onOpenGoals) {
                        Label(s("health.hub.plan.open"), systemImage: "scope")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
                }
            }
        }
    }

    private var emptyPlanCard: some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .lightweight) {
            VStack(alignment: .leading, spacing: 13) {
                LippiSectionHeader(
                    title: s("health.hub.plan.empty.title"),
                    subtitle: s("health.hub.plan.empty.subtitle"),
                    icon: "scope",
                    accent: DS.accent
                )

                Text(s("health.hub.plan.empty.description"))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onOpenGoals) {
                    Label(s("health.hub.plan.empty.action"), systemImage: "sparkles")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
            }
        }
    }

    private func planMetric(value: String, title: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tone)
                .monospacedDigit()
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.opacity(0.07), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(tone.opacity(0.14), lineWidth: 1)
        )
    }

    private func appliedPlanSummary(
        record: AdaptiveGoalPlanRecord?,
        pace: AdaptiveGoalPace
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            explanationRow(
                L10n.fmt("health.hub.plan.change.limit", lang, pace.dailyStepLimit),
                icon: "list.number",
                tone: Color(hex: 0x30D158)
            )
            explanationRow(
                L10n.fmt("health.hub.plan.change.focus", lang, pace.focusMinutes),
                icon: "timer",
                tone: Color(hex: 0x64D2FF)
            )

            if let record, record.redistributedTaskCount > 0 {
                explanationRow(
                    L10n.fmt("health.hub.plan.change.rescheduled", lang, record.redistributedTaskCount),
                    icon: "calendar.badge.clock",
                    tone: Color(hex: 0xFF9F0A)
                )
            }

            if let appliedAt = record?.appliedAt {
                Label(
                    L10n.fmt("health.hub.plan.applied.date", lang, adaptationDate(appliedAt)),
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(hex: 0x30D158).opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func proposedPlanChanges(
        audit: GoalPlanProgressAudit?,
        pace: AdaptiveGoalPace,
        hasPreviousRecord: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasPreviousRecord {
                explanationRow(
                    s("health.hub.plan.changed_since_last"),
                    icon: "arrow.triangle.2.circlepath",
                    tone: Color(hex: 0xFF9F0A)
                )
            }

            explanationRow(
                L10n.fmt("health.hub.plan.proposal.limit", lang, pace.dailyStepLimit),
                icon: "list.number",
                tone: paceTone(pace.level)
            )
            explanationRow(
                L10n.fmt("health.hub.plan.proposal.focus", lang, pace.focusMinutes),
                icon: "timer",
                tone: Color(hex: 0x64D2FF)
            )

            if let overdue = audit?.overdueTasks, overdue > 0 {
                explanationRow(
                    L10n.fmt("health.hub.plan.proposal.reschedule", lang, overdue),
                    icon: "calendar.badge.clock",
                    tone: Color(hex: 0xFF9F0A)
                )
            }
        }
        .padding(12)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
    }

    private func explanationRow(_ text: String, icon: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(tone)
                .frame(width: 22, height: 22)

            Text(text)
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func applyCurrentPace() {
        guard let roadmap else { return }
        let pace = currentPace
        let previousRecord = adaptationRecord.flatMap { $0.roadmapID == roadmap.id ? $0 : nil }
        let adjusted = AdaptiveGoalPlanEngine.applying(
            to: roadmap,
            pace: pace,
            lang: lang,
            replacing: previousRecord
        )
        let redistributedCount = pace.shouldRedistributeOverdueSteps
            ? redistributeOverdueGoalTasks(for: roadmap, pace: pace)
            : 0

        guard let data = try? JSONEncoder().encode(adjusted) else { return }
        savedRoadmap = String(decoding: data, as: UTF8.self)
        let postAdaptationAudit = GoalPlanProgressAudit.make(roadmap: adjusted, tasks: store.tasks)

        let record = AdaptiveGoalPlanRecord(
            roadmapID: adjusted.id,
            appliedAt: .now,
            pace: pace,
            userState: selectedState,
            healthBand: manager.isEnabled ? manager.recommendation?.band : nil,
            activeTaskCount: postAdaptationAudit?.activeTasks ?? 0,
            completedTaskCount: postAdaptationAudit?.completedTasks ?? 0,
            overdueTaskCount: postAdaptationAudit?.overdueTasks ?? 0,
            redistributedTaskCount: redistributedCount,
            firstAction: AdaptiveGoalPlanEngine.firstAction(for: pace, lang: lang),
            habitTitle: AdaptiveGoalPlanEngine.habitTitle(lang: lang),
            habitDetail: AdaptiveGoalPlanEngine.habitDetail(for: pace, lang: lang)
        )
        if let encoded = AdaptiveGoalPlanRecordStore.encode(record) {
            savedAdaptation = encoded
        }

        GoalProgressNotificationScheduler.refresh(lang: lang)
        NotificationCenter.default.post(name: .lippiCareDidChange, object: nil)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func redistributeOverdueGoalTasks(
        for roadmap: GoalRoadmap,
        pace: AdaptiveGoalPace,
        now: Date = .now
    ) -> Int {
        let calendar = Calendar.current
        let overdue = store.tasks
            .filter { task in
                guard !task.isCompleted,
                      let dueDate = task.dueDate,
                      dueDate < now else { return false }
                return GoalPlanProgressAudit.isLinked(task, to: roadmap)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        for (index, item) in overdue.enumerated() {
            var updated = item
            let dayOffset = 1 + index * max(1, pace.spacingDays)
            let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            updated.dueDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: targetDay)
            store.update(updated)
        }
        return overdue.count
    }

    private func paceTone(_ level: AdaptiveGoalPaceLevel) -> Color {
        switch level {
        case .recovery: return Color(hex: 0xAF52DE)
        case .light: return Color(hex: 0x64D2FF)
        case .balanced: return Color(hex: 0x30D158)
        case .momentum: return DS.accent
        }
    }

    private func paceIcon(_ level: AdaptiveGoalPaceLevel) -> String {
        switch level {
        case .recovery: return "moon.stars.fill"
        case .light: return "leaf.fill"
        case .balanced: return "heart.circle.fill"
        case .momentum: return "bolt.heart.fill"
        }
    }

    private func weekdayTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.narrow)
                .locale(Locale(identifier: lang.localeIdentifier))
        )
    }

    private func weekAccessibilityLabel(date: Date, entry: WellbeingCheckIn?) -> String {
        let day = date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(Locale(identifier: lang.localeIdentifier))
        )
        if let entry {
            return "\(day), \(entry.state.title(lang: lang))"
        }
        return "\(day), \(s("health.hub.checkin.no_entry"))"
    }

    private func adaptationDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
                .locale(Locale(identifier: lang.localeIdentifier))
        )
    }
}
