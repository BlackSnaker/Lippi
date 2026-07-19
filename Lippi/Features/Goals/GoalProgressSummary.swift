import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum GoalUserState: String, CaseIterable, Identifiable, Codable {
    case calm
    case energetic
    case tired
    case overloaded
    case uncertain

    var id: String { rawValue }

    func title(lang: AppLang) -> String {
        L10n.tr("goals.progress.state.\(rawValue)", lang)
    }

    func subtitle(lang: AppLang) -> String {
        L10n.tr("goals.progress.state.\(rawValue).hint", lang)
    }

    var icon: String {
        switch self {
        case .calm: return "leaf.fill"
        case .energetic: return "bolt.heart.fill"
        case .tired: return "moon.zzz.fill"
        case .overloaded: return "exclamationmark.triangle.fill"
        case .uncertain: return "questionmark.bubble.fill"
        }
    }

    var tone: Color {
        switch self {
        case .calm: return Color(hex: 0x30D158)
        case .energetic: return Color(hex: 0x64D2FF)
        case .tired: return Color(hex: 0xBF5AF2)
        case .overloaded: return Color(hex: 0xFF9F0A)
        case .uncertain: return DS.accent
        }
    }

    var promptLabel: String {
        switch self {
        case .calm: return "calm / steady"
        case .energetic: return "energetic / ready for more"
        case .tired: return "tired / low energy"
        case .overloaded: return "overloaded / needs less pressure"
        case .uncertain: return "uncertain / needs clarity"
        }
    }
}

enum GoalProgressSummarySource: String, Codable, Hashable {
    case ai
    case localDraft

    func title(lang: AppLang) -> String {
        switch self {
        case .ai: return L10n.tr("goals.progress.source.ai", lang)
        case .localDraft: return L10n.tr("goals.progress.source.local", lang)
        }
    }

    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .localDraft: return "doc.text.magnifyingglass"
        }
    }
}

struct GoalProgressSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var source: GoalProgressSummarySource
    var title: String
    var summary: String
    var progressScore: Double
    var forecastLabel: String
    var forecast: String
    var wins: [String]
    var supportiveSignals: [String]
    var risks: [String]
    var nextSteps: [String]
    var stateCare: [String]
    var checkInQuestion: String
    var confidence: Double

    var normalizedProgress: Double { min(max(progressScore, 0), 1) }
    var normalizedConfidence: Double { min(max(confidence, 0), 1) }
}

enum GoalProgressNotificationScheduler {
    static let enabledKey = "goal.progress.weekly.enabled"
    static let notificationID = "goal-progress.weekly-summary"
    static let roadmapStorageKey = "goal.planner.lastRoadmap"

    static func refresh(lang: AppLang) {
        let defaults = UserDefaults.standard
        let hasStoredRoadmap = !(defaults.string(forKey: roadmapStorageKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let enabled: Bool
        if defaults.object(forKey: enabledKey) == nil {
            enabled = true
            defaults.set(true, forKey: enabledKey)
        } else {
            enabled = defaults.bool(forKey: enabledKey)
        }

        guard enabled, hasStoredRoadmap else {
            NotificationManager.shared.cancel(ids: [notificationID])
            return
        }

        NotificationManager.shared.scheduleWeekly(
            id: notificationID,
            title: L10n.tr("goals.progress.notification.title", lang),
            body: L10n.tr("goals.progress.notification.body", lang),
            weekday: 1,
            hour: 18,
            minute: 0,
            userInfo: ["url": "lippi://goals?mode=progress"]
        )
    }
}

@MainActor
struct GoalProgressSummaryEngine {
    func buildSummary(
        roadmap: GoalRoadmap,
        tasks: [TaskItem],
        stats: StatsStore,
        userState: GoalUserState,
        stateNote: String,
        lang: AppLang
    ) async -> (summary: GoalProgressSummary, issue: String?) {
        let facts = GoalProgressFacts(
            roadmap: roadmap,
            tasks: tasks,
            stats: stats,
            userState: userState,
            stateNote: stateNote
        )
        let configuration = BonsaiConfiguration.stored

        if configuration.isEnabled {
            do {
                let provider = BonsaiGoalProvider()
                try provider.ensureReady(configuration: configuration)
                let text = try await provider.generateProgressSummary(
                    prompt: prompt(for: roadmap, facts: facts, lang: lang),
                    configuration: configuration
                )
                if let summary = parseSummary(text, lang: lang) {
                    return (summary, nil)
                }
                return (localSummary(for: roadmap, facts: facts, lang: lang), L10n.tr("goals.progress.error.malformed", lang))
            } catch let error as BonsaiProviderError {
                return (localSummary(for: roadmap, facts: facts, lang: lang), error.message(lang: lang))
            } catch {
                return (localSummary(for: roadmap, facts: facts, lang: lang), L10n.fmt("goals.progress.error.failed", lang, error.localizedDescription))
            }
        }

        return (localSummary(for: roadmap, facts: facts, lang: lang), L10n.tr("goals.progress.error.local", lang))
    }

    private func prompt(for roadmap: GoalRoadmap, facts: GoalProgressFacts, lang: AppLang) -> String {
        let audit = facts.audit?.promptSection() ?? "No tracked roadmap tasks have been added in Lippi yet."
        let milestones = roadmap.milestones.enumerated().map { index, milestone in
            """
            \(index + 1). \(milestone.title)
            timeframe: \(milestone.timeframe)
            target: \(milestone.target)
            tasks: \(milestone.tasks.joined(separator: " | "))
            """
        }.joined(separator: "\n")
        let upcoming = facts.upcomingTasks.isEmpty ? "none" : facts.upcomingTasks.joined(separator: "; ")
        let overdue = facts.overdueTasks.isEmpty ? "none" : facts.overdueTasks.joined(separator: "; ")
        let stateNote = facts.stateNote.isEmpty ? "none" : facts.stateNote

        return """
        Build a friendly weekly-style progress summary for this Lippi goal. Answer in \(lang.aiOutputLanguageName).

        Goal:
        title: \(roadmap.title)
        summary: \(roadmap.summary)
        created at: \(roadmap.createdAt)
        success criteria: \(roadmap.successCriteria.joined(separator: " | "))
        first actions: \(roadmap.firstActions.joined(separator: " | "))

        Roadmap milestones:
        \(milestones)

        User state:
        self-reported state: \(facts.userState.promptLabel)
        user note: \(stateNote)

        App facts:
        last 7 days focus minutes: \(facts.last7FocusMinutes)
        last 7 days completed tasks: \(facts.last7TasksDone)
        active days in the last 7 days: \(facts.last7ActiveDays)
        last 30 days focus minutes: \(facts.last30FocusMinutes)
        last 30 days completed tasks: \(facts.last30TasksDone)
        productive streak days: \(facts.productiveStreak)
        active tasks in app: \(facts.activeTaskCount)
        overdue tasks in app: \(facts.overdueTaskCount)
        due soon tasks: \(facts.dueSoonTaskCount)
        upcoming task titles: \(upcoming)
        overdue task titles: \(overdue)

        Roadmap task audit:
        \(audit)

        Rules:
        - Use only these facts. Do not invent sleep, mood, diagnosis, motivation, resources, income, users, demand, or hidden reasons.
        - The forecast must be soft and conditional, not a guarantee. Name uncertainty when there is not enough tracked data.
        - Reflect the user's self-reported state gently. If tired or overloaded, reduce pressure and suggest smaller next steps.
        - Summarize successes first, then risks, then a kind next step.
        - No blame. No clinical, legal, or financial advice.
        - Return valid JSON only.
        """
    }

    private func parseSummary(_ text: String, lang: AppLang) -> GoalProgressSummary? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(GoalProgressSummaryPayload.self, from: data) else {
            return nil
        }

        return GoalProgressSummary(
            source: .ai,
            title: payload.title.cleaned(or: L10n.tr("goals.progress.result.title", lang)),
            summary: payload.summary.cleaned(or: L10n.tr("goals.progress.local.summary.empty", lang)),
            progressScore: payload.progressScore,
            forecastLabel: payload.forecastLabel.cleaned(or: L10n.tr("goals.progress.forecast.careful", lang)),
            forecast: payload.forecast.cleaned(or: L10n.tr("goals.progress.local.forecast.uncertain", lang)),
            wins: payload.wins.cleaned(limit: 4, fallback: [L10n.tr("goals.progress.local.win.started", lang)]),
            supportiveSignals: payload.supportiveSignals.cleaned(limit: 4, fallback: [L10n.tr("goals.progress.local.signal.review", lang)]),
            risks: payload.risks.cleaned(limit: 3, fallback: [L10n.tr("goals.progress.local.risk.unclear", lang)]),
            nextSteps: payload.nextSteps.cleaned(limit: 3, fallback: [L10n.tr("goals.progress.local.next.review", lang)]),
            stateCare: payload.stateCare.cleaned(limit: 3, fallback: [L10n.tr("goals.progress.local.care.default", lang)]),
            checkInQuestion: payload.checkInQuestion.cleaned(or: L10n.tr("goals.progress.local.question", lang)),
            confidence: payload.confidence
        )
    }

    private func localSummary(for roadmap: GoalRoadmap, facts: GoalProgressFacts, lang: AppLang) -> GoalProgressSummary {
        let completion = facts.audit?.completionRate ?? 0
        let activity = Double(facts.last7ActiveDays) / 7.0
        let overduePenalty = min(Double(facts.overdueTaskCount) * 0.08, 0.28)
        let statePenalty: Double = facts.userState == .overloaded ? 0.12 : (facts.userState == .tired ? 0.08 : 0)
        let score = min(max((completion * 0.48) + (activity * 0.36) + min(Double(facts.productiveStreak) / 14.0, 0.16) - overduePenalty - statePenalty, 0.10), 0.92)

        let forecastLabel: String
        let forecast: String
        if facts.audit == nil {
            forecastLabel = L10n.tr("goals.progress.forecast.early", lang)
            forecast = L10n.tr("goals.progress.local.forecast.early", lang)
        } else if facts.overdueTaskCount > 0 || facts.userState == .overloaded {
            forecastLabel = L10n.tr("goals.progress.forecast.adjust", lang)
            forecast = L10n.tr("goals.progress.local.forecast.adjust", lang)
        } else if score >= 0.62 {
            forecastLabel = L10n.tr("goals.progress.forecast.good", lang)
            forecast = L10n.tr("goals.progress.local.forecast.good", lang)
        } else {
            forecastLabel = L10n.tr("goals.progress.forecast.careful", lang)
            forecast = L10n.tr("goals.progress.local.forecast.uncertain", lang)
        }

        var wins: [String] = []
        if facts.last7FocusMinutes > 0 {
            wins.append(L10n.fmt("goals.progress.local.win.focus", lang, facts.last7FocusMinutes))
        }
        if facts.last7TasksDone > 0 {
            wins.append(L10n.fmt("goals.progress.local.win.tasks", lang, facts.last7TasksDone))
        }
        if let audit = facts.audit, audit.completedTasks > 0 {
            wins.append(L10n.fmt("goals.progress.local.win.roadmap", lang, audit.completedTasks))
        }
        if wins.isEmpty {
            wins.append(L10n.tr("goals.progress.local.win.started", lang))
        }

        var risks: [String] = []
        if facts.overdueTaskCount > 0 {
            risks.append(L10n.fmt("goals.progress.local.risk.overdue", lang, facts.overdueTaskCount))
        }
        if facts.userState == .overloaded || facts.userState == .tired {
            risks.append(L10n.tr("goals.progress.local.risk.energy", lang))
        }
        if facts.audit == nil {
            risks.append(L10n.tr("goals.progress.local.risk.no_tracking", lang))
        }
        if risks.isEmpty {
            risks.append(L10n.tr("goals.progress.local.risk.unclear", lang))
        }

        let nextSteps = Array((facts.audit?.suggestions(lang: lang) ?? []).prefix(2)) + Array(roadmap.firstActions.prefix(1))

        return GoalProgressSummary(
            source: .localDraft,
            title: L10n.tr("goals.progress.result.title", lang),
            summary: L10n.fmt("goals.progress.local.summary", lang, roadmap.title, facts.last7ActiveDays, facts.last7FocusMinutes, facts.last7TasksDone),
            progressScore: score,
            forecastLabel: forecastLabel,
            forecast: forecast,
            wins: Array(wins.prefix(4)),
            supportiveSignals: [
                L10n.fmt("goals.progress.local.signal.activity", lang, facts.last7ActiveDays),
                L10n.fmt("goals.progress.local.signal.streak", lang, facts.productiveStreak)
            ],
            risks: Array(risks.prefix(3)),
            nextSteps: Array(nextSteps.isEmpty ? [L10n.tr("goals.progress.local.next.review", lang)] : nextSteps.prefix(3)),
            stateCare: careSuggestions(for: facts.userState, lang: lang),
            checkInQuestion: L10n.tr("goals.progress.local.question", lang),
            confidence: facts.audit == nil ? 0.48 : 0.68
        )
    }

    private func careSuggestions(for state: GoalUserState, lang: AppLang) -> [String] {
        switch state {
        case .calm:
            return [L10n.tr("goals.progress.care.calm", lang)]
        case .energetic:
            return [L10n.tr("goals.progress.care.energetic", lang)]
        case .tired:
            return [L10n.tr("goals.progress.care.tired", lang)]
        case .overloaded:
            return [L10n.tr("goals.progress.care.overloaded", lang)]
        case .uncertain:
            return [L10n.tr("goals.progress.care.uncertain", lang)]
        }
    }
}

struct GoalProgressSummaryCard: View {
    let roadmap: GoalRoadmap
    let summary: GoalProgressSummary?
    let isSummarizing: Bool
    let issue: String?
    let lang: AppLang
    @Binding var userState: GoalUserState
    @Binding var stateNote: String
    @Binding var weeklyEnabled: Bool
    let onGenerate: () -> Void
    let onWeeklyChanged: () -> Void

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .full) {
            VStack(alignment: .leading, spacing: 15) {
                LippiSectionHeader(
                    title: L10n.tr("goals.progress.card.title", lang),
                    subtitle: L10n.tr("goals.progress.card.subtitle", lang),
                    icon: "heart.text.square.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                statePicker
                stateNoteField
                weeklyToggle

                if let issue {
                    issueBanner(issue)
                }

                Button(action: onGenerate) {
                    HStack(spacing: 10) {
                        if isSummarizing {
                            ProgressView()
                                .tint(DS.textPrimary)
                        } else {
                            Image(safeSystemName: "sparkles", fallback: "sparkles")
                        }

                        Text(isSummarizing ? L10n.tr("goals.progress.action.loading", lang) : L10n.tr(summary == nil ? "goals.progress.action.generate" : "goals.progress.action.refresh", lang))
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSummarizing)
                .buttonStyle(LippiButtonStyle(kind: .primary))
            }
        }
        .onChange(of: weeklyEnabled) { _, _ in onWeeklyChanged() }
        .accessibilityElement(children: .contain)
    }

    private var statePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.tr("goals.progress.state.title", lang))
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textTertiary)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(GoalUserState.allCases) { state in
                    stateButton(state)
                }
            }
        }
    }

    private func stateButton(_ state: GoalUserState) -> some View {
        let selected = state == userState
        return Button {
            userState = state
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            HStack(spacing: 8) {
                Image(safeSystemName: state.icon, fallback: "circle.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? DS.textPrimary : state.tone)
                    .frame(width: 26, height: 26)
                    .background(state.tone.opacity(selected ? 0.22 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title(lang: lang))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .singleLine()

                    Text(state.subtitle(lang: lang))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.glassFill(selected ? 0.13 : 0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(state.tone.opacity(selected ? 0.12 : 0.04)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                tint: state.tone.opacity(selected ? 0.09 : 0.04),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? state.tone.opacity(0.30) : DS.glassStroke(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var stateNoteField: some View {
        TextField(L10n.tr("goals.progress.state.note_placeholder", lang), text: $stateNote, axis: .vertical)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2...4)
            .foregroundStyle(DS.textPrimary)
            .padding(12)
            .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private var weeklyToggle: some View {
        Toggle(isOn: $weeklyEnabled) {
            Label(L10n.tr("goals.progress.weekly.title", lang), systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.bold))
                .labelStyle(TightLabelStyle())
                .foregroundStyle(DS.textPrimary)
        }
        .tint(DS.accent)
        .padding(12)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func issueBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "info.circle.fill", fallback: "info.circle")
                .foregroundStyle(Color(hex: 0xFF9F0A))

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .background(Color(hex: 0xFF9F0A).opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xFF9F0A).opacity(0.16), lineWidth: 1))
    }
}

struct GoalProgressSummaryPage: View {
    let summary: GoalProgressSummary
    let lang: AppLang

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 16) {
                header
                forecastPanel
                section(title: L10n.tr("goals.progress.wins.title", lang), icon: "checkmark.seal.fill", tone: Color(hex: 0x30D158), items: summary.wins)
                section(title: L10n.tr("goals.progress.signals.title", lang), icon: "waveform.path.ecg", tone: Color(hex: 0x64D2FF), items: summary.supportiveSignals)
                section(title: L10n.tr("goals.progress.risks.title", lang), icon: "exclamationmark.triangle.fill", tone: Color(hex: 0xFF9F0A), items: summary.risks)
                section(title: L10n.tr("goals.progress.next.title", lang), icon: "figure.walk.motion", tone: DS.accent, items: summary.nextSteps)
                section(title: L10n.tr("goals.progress.care.title", lang), icon: "heart.fill", tone: Color(hex: 0xBF5AF2), items: summary.stateCare)
                checkInQuestion
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            progressRing

            VStack(alignment: .leading, spacing: 7) {
                Text(summary.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(summary.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    infoChip(summary.source.title(lang: lang), icon: summary.source.icon, tone: DS.accent)
                    infoChip(L10n.fmt("goals.progress.confidence", lang, Int((summary.normalizedConfidence * 100).rounded())), icon: "scope", tone: Color(hex: 0x64D2FF))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(DS.glassStroke(0.15), lineWidth: 8)

            Circle()
                .trim(from: 0, to: summary.normalizedProgress)
                .stroke(
                    AngularGradient(colors: [DS.brandA, DS.brandB, Color(hex: 0x30D158)], center: .center),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int((summary.normalizedProgress * 100).rounded()))%")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)

                Text(L10n.tr("goals.progress.score", lang))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .frame(width: 84, height: 84)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(DS.brandSoftGradient).opacity(0.58))
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(DS.glassStroke(0.15), lineWidth: 1))
    }

    private var forecastPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(summary.forecastLabel, systemImage: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .labelStyle(TightLabelStyle())

            Text(summary.forecast)
                .font(.callout.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.10))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.brandSoftGradient).opacity(0.42))
        )
        .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), tint: DS.accent.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private func section(title: String, icon: String, tone: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .labelStyle(TightLabelStyle())
                .foregroundStyle(DS.textPrimary)

            VStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    summaryRow(item, tone: tone)
                }
            }
        }
    }

    private func summaryRow(_ text: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(tone.opacity(0.82))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private var checkInQuestion: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(safeSystemName: "questionmark.bubble.fill", fallback: "questionmark.circle.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 34, height: 34)
                .background(DS.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("goals.progress.question.title", lang))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textTertiary)
                    .textCase(.uppercase)

                Text(summary.checkInQuestion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: DS.accent.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.glassStroke(0.13), lineWidth: 1))
    }

    private func infoChip(_ text: String, icon: String, tone: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.bold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(DS.glassFill(0.08))
                    .overlay(Capsule(style: .continuous).fill(tone.opacity(0.12)))
            )
            .overlay(Capsule(style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
            .singleLine()
    }
}

private struct GoalProgressFacts {
    var audit: GoalPlanProgressAudit?
    var last7FocusMinutes: Int
    var last7TasksDone: Int
    var last7ActiveDays: Int
    var last30FocusMinutes: Int
    var last30TasksDone: Int
    var productiveStreak: Int
    var activeTaskCount: Int
    var overdueTaskCount: Int
    var dueSoonTaskCount: Int
    var upcomingTasks: [String]
    var overdueTasks: [String]
    var userState: GoalUserState
    var stateNote: String

    init(roadmap: GoalRoadmap, tasks: [TaskItem], stats: StatsStore, userState: GoalUserState, stateNote: String) {
        let last7 = stats.series(last: 7)
        let last30 = stats.series(last: 30)
        let total7 = stats.totals(for: last7)
        let total30 = stats.totals(for: last30)
        let active = tasks.filter { !$0.isCompleted }
        let now = Date()
        let soonLimit = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let overdue = active.filter { ($0.dueDate ?? .distantFuture) < now }
        let dueSoon = active.filter {
            guard let due = $0.dueDate else { return false }
            return due >= now && due <= soonLimit
        }

        self.audit = GoalPlanProgressAudit.make(roadmap: roadmap, tasks: tasks)
        self.last7FocusMinutes = total7.focus
        self.last7TasksDone = total7.tasks
        self.last7ActiveDays = last7.filter(\.hasActivity).count
        self.last30FocusMinutes = total30.focus
        self.last30TasksDone = total30.tasks
        self.productiveStreak = stats.productiveStreak
        self.activeTaskCount = active.count
        self.overdueTaskCount = overdue.count
        self.dueSoonTaskCount = dueSoon.count
        self.upcomingTasks = active.sorted(by: Self.dueSort).prefix(5).map(\.title)
        self.overdueTasks = overdue.sorted(by: Self.dueSort).prefix(5).map(\.title)
        self.userState = userState
        self.stateNote = stateNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func dueSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let left = lhs.dueDate ?? .distantFuture
        let right = rhs.dueDate ?? .distantFuture
        if left == right { return lhs.createdAt < rhs.createdAt }
        return left < right
    }
}

private struct GoalProgressSummaryPayload: Decodable {
    var title: String
    var summary: String
    var progressScore: Double
    var forecastLabel: String
    var forecast: String
    var wins: [String]
    var supportiveSignals: [String]
    var risks: [String]
    var nextSteps: [String]
    var stateCare: [String]
    var checkInQuestion: String
    var confidence: Double
}

private extension String {
    func cleaned(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}

private extension Array where Element == String {
    func cleaned(limit: Int, fallback: [String]) -> [String] {
        let values = map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? fallback : Array(values.prefix(limit))
    }
}

private extension AppLang {
    var aiOutputLanguageName: String {
        switch self {
        case .ru: return "Russian"
        case .en: return "English"
        case .de: return "German"
        case .es: return "Spanish"
        }
    }
}
