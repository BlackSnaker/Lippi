import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(Translation)
import Translation
#endif
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Goal Planner
// =======================================================
struct GoalPlannerView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage("goal.planner.lastRoadmap") private var savedRoadmap: String = ""

    @State private var goalText: String = ""
    @State private var contextText: String = ""
    @State private var horizon: GoalPlanningHorizon = .eightWeeks
    @State private var intensity: GoalPlanningIntensity = .balanced
    @State private var roadmap: GoalRoadmap?
    @State private var isGenerating = false
    @State private var isDrafting = false
    @State private var addedTasks = false
    @State private var generationIssue: String?

    private let engine = GoalRoadmapEngine()
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var canGenerate: Bool { !goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroCard
                        inputCard

                        if let generationIssue {
                            generationIssueCard(generationIssue)
                        }

                        if let roadmap {
                            roadmapOverview(roadmap)
                            clarityCard(roadmap)
                            if !(roadmap.evidence ?? []).isEmpty {
                                evidenceCard(roadmap)
                            }
                            milestonesCard(roadmap)
                            habitsAndRisksCard(roadmap)
                        } else if generationIssue != nil {
                            emptyPreviewCard
                        } else {
                            emptyPreviewCard
                        }

                        Color.clear.frame(height: 72)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                if isGenerating {
                    roadmapProcessingOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                }
            }
            .navigationTitle(s("goals.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s("common.close")) { dismiss() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .onAppear(perform: restoreRoadmap)
        }
    }

    private var heroCard: some View {
        GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DS.glassFill(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.brandSoftGradient).opacity(0.52))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.18), lineWidth: 1))

                        Image(safeSystemName: "wand.and.stars", fallback: "sparkles")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.text(0.96))
                    }
                    .frame(width: 52, height: 52)
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        tint: DS.accent.opacity(0.16)
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(GoalRoadmapEngine.primaryAIHeroEyebrow(lang: lang))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.textTertiary)
                            .textCase(.uppercase)
                            .singleLine()

                        Text(s("goals.hero.title"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(2)

                        Text(GoalRoadmapEngine.primaryAIHeroSubtitle(lang: lang))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    infoPill(title: GoalRoadmapEngine.primaryAIStatus(lang: lang), icon: "cpu")
                    infoPill(title: s("goals.ai.required"), icon: "sparkles")
                    infoPill(title: GoalRoadmapEngine.primaryAIPrivacyLabel(lang: lang), icon: "lock.shield.fill")
                }
            }
        }
    }

    private var roadmapProcessingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(reduceTransparency ? 0.28 : 0.12))
                .background(.ultraThinMaterial)
                .lippiSystemGlass(
                    in: Rectangle(),
                    tint: DS.accent.opacity(0.045),
                    forceSystemGlass: !reduceTransparency
                )
                .ignoresSafeArea()

            GlassCard(
                padding: 22,
                cornerRadius: 28,
                style: .full,
                forceSystemGlass: !reduceTransparency
            ) {
                VStack(spacing: 18) {
                    processingEmblem

                    VStack(spacing: 6) {
                        Text(s("goals.processing.title"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(s("goals.processing.subtitle"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        let activeStep = Int(timeline.date.timeIntervalSinceReferenceDate / 1.15) % processingSteps.count

                        VStack(alignment: .leading, spacing: 11) {
                            ForEach(Array(processingSteps.enumerated()), id: \.offset) { index, step in
                                processingStepRow(step, isActive: index == activeStep, isComplete: index < activeStep)
                            }
                        }
                    }

                    Text(s("goals.processing.notice"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 360)
            .padding(24)
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(s("goals.processing.title"))
        .accessibilityAddTraits(.isModal)
    }

    private var processingEmblem: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let fraction = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.45) / 1.45

            ZStack {
                Circle()
                    .stroke(DS.accent.opacity(0.18), lineWidth: 7)

                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        DS.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(fraction * 360))

                Image(safeSystemName: "sparkles", fallback: "wand.and.stars")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .frame(width: 74, height: 74)
            .lippiSystemGlass(
                in: Circle(),
                tint: DS.accent.opacity(0.12),
                forceSystemGlass: !reduceTransparency
            )
        }
        .frame(width: 74, height: 74)
    }

    private var processingSteps: [(title: String, icon: String)] {
        [
            (s("goals.processing.sources"), "books.vertical.fill"),
            (s("goals.processing.route"), "point.topleft.down.curvedto.point.bottomright.up"),
            (s("goals.processing.check"), "checklist.checked")
        ]
    }

    private func processingStepRow(_ step: (title: String, icon: String), isActive: Bool, isComplete: Bool) -> some View {
        let tone = isActive || isComplete ? DS.accent : DS.textTertiary

        return HStack(spacing: 10) {
            Image(safeSystemName: isComplete ? "checkmark.circle.fill" : step.icon, fallback: "circle")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .frame(width: 20)

            Text(step.title)
                .font(.subheadline.weight(isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? DS.textPrimary : DS.textSecondary)

            Spacer(minLength: 0)

            if isActive {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(step.title)
    }

    private var inputCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.input.title"),
                    subtitle: s("goals.input.subtitle"),
                    icon: "target",
                    accent: Color(hex: 0x64D2FF)
                )

                goalField
                contextEditor

                HStack(spacing: 10) {
                    optionPicker(
                        title: s("goals.input.horizon"),
                        icon: "calendar.badge.clock",
                        selection: $horizon,
                        values: GoalPlanningHorizon.allCases
                    )

                    optionPicker(
                        title: s("goals.input.intensity"),
                        icon: "gauge.with.dots.needle.67percent",
                        selection: $intensity,
                        values: GoalPlanningIntensity.allCases
                    )
                }
            }
        }
    }

    private var goalField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s("goals.input.goal_label"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.text(0.70))

            HStack(spacing: 10) {
                Image(safeSystemName: "flag.checkered", fallback: "flag.fill")
                    .foregroundStyle(DS.text(0.74))
                    .frame(width: 22)

                TextField(s("goals.input.goal_placeholder"), text: $goalText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(DS.textPrimary)
                    .submitLabel(.done)
            }
            .goalGlassField(tint: DS.accent)
        }
    }

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s("goals.input.context_label"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.text(0.70))

            HStack(alignment: .top, spacing: 10) {
                Image(safeSystemName: "text.alignleft", fallback: "text.justify")
                    .foregroundStyle(DS.text(0.74))
                    .frame(width: 22)
                    .padding(.top, 4)

                TextEditor(text: $contextText)
                    .frame(minHeight: 82, maxHeight: 132)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .foregroundStyle(DS.textPrimary)
                    .overlay(alignment: .topLeading) {
                        if contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(s("goals.input.context_placeholder"))
                                .font(.body)
                                .foregroundStyle(DS.textTertiary)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .goalGlassField(tint: Color(hex: 0x64D2FF))
        }
    }

    private func optionPicker<Value: GoalPlannerOption>(
        title: String,
        icon: String,
        selection: Binding<Value>,
        values: [Value]
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(DS.textTertiary)
                .labelStyle(TightLabelStyle())
                .singleLine()

            Picker(title, selection: selection) {
                ForEach(values) { value in
                    Text(value.title(lang: lang)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(DS.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DS.glassFill(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                tint: DS.accent.opacity(0.07),
                interactive: true
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
        }
    }

    private var emptyPreviewCard: some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("goals.preview.title"),
                    subtitle: s("goals.preview.subtitle"),
                    icon: "map.fill",
                    accent: Color(hex: 0x30D158)
                )

                HStack(spacing: 12) {
                    previewStep(index: "1", title: s("goals.preview.step_1"), tone: DS.brandA)
                    previewStep(index: "2", title: s("goals.preview.step_2"), tone: Color(hex: 0x64D2FF))
                    previewStep(index: "3", title: s("goals.preview.step_3"), tone: Color(hex: 0x30D158))
                }
            }
        }
    }

    private func generationIssueCard(_ message: String) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            HStack(alignment: .top, spacing: 12) {
                Image(safeSystemName: "exclamationmark.triangle.fill", fallback: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFF9F0A))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xFF9F0A).opacity(0.14), in: Circle())
                    .lippiSystemGlass(in: Circle(), tint: Color(hex: 0xFF9F0A).opacity(0.08))

                VStack(alignment: .leading, spacing: 5) {
                    Text(s("goals.error.title"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)

                    Text(message)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func roadmapOverview(_ roadmap: GoalRoadmap) -> some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(roadmap.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(2)

                        Text(roadmap.summary)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    confidenceBadge(roadmap.confidence)
                }

                HStack(spacing: 8) {
                    infoPill(title: roadmap.source.title(lang: lang), icon: roadmap.source.icon)
                    infoPill(title: horizon.title(lang: lang), icon: "calendar")
                    infoPill(title: intensity.title(lang: lang), icon: "dial.medium")
                }
            }
        }
    }

    private func clarityCard(_ roadmap: GoalRoadmap) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.clarity.title"),
                    subtitle: s("goals.clarity.subtitle"),
                    icon: "checklist.checked",
                    accent: Color(hex: 0x30D158)
                )

                VStack(spacing: 10) {
                    clarityBlock(
                        title: s("goals.success.title"),
                        icon: "target",
                        tone: Color(hex: 0x30D158),
                        items: roadmap.successCriteria
                    )

                    clarityBlock(
                        title: s("goals.next.title"),
                        icon: "figure.walk.motion",
                        tone: DS.accent,
                        items: roadmap.firstActions
                    )

                    if !roadmap.assumptions.isEmpty {
                        clarityBlock(
                            title: s("goals.assumptions.title"),
                            icon: "lightbulb.fill",
                            tone: Color(hex: 0xFFCC00),
                            items: roadmap.assumptions
                        )
                    }

                    if let questions = roadmap.clarifyingQuestions, !questions.isEmpty {
                        clarityBlock(
                            title: s("goals.questions.title"),
                            icon: "questionmark.bubble.fill",
                            tone: Color(hex: 0x64D2FF),
                            items: questions,
                            itemIcon: "questionmark.circle.fill"
                        )
                    }
                }
            }
        }
    }

    private func evidenceCard(_ roadmap: GoalRoadmap) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("goals.evidence.title"),
                    subtitle: s("goals.evidence.subtitle"),
                    icon: "books.vertical.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                VStack(spacing: 9) {
                    ForEach(roadmap.evidence ?? []) { source in
                        evidenceRow(source)
                    }
                }
            }
        }
    }

    private func evidenceRow(_ source: GoalEvidenceSource) -> some View {
        Group {
            if let url = URL(string: source.url) {
                Link(destination: url) {
                    evidenceContent(source)
                }
            } else {
                evidenceContent(source)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(source.title), \(s("goals.evidence.open"))")
    }

    private func evidenceContent(_ source: GoalEvidenceSource) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "book.closed.fill", fallback: "doc.text.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DS.text(0.92))
                .frame(width: 30, height: 30)
                .background(Color(hex: 0x64D2FF).opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    tint: Color(hex: 0x64D2FF).opacity(0.08)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Image(safeSystemName: "arrow.up.right", fallback: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.textTertiary)
                }

                Text(source.excerpt)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(3)

                Text(source.host)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x64D2FF))
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: Color(hex: 0x64D2FF).opacity(0.06),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func milestonesCard(_ roadmap: GoalRoadmap) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("goals.roadmap.title"),
                    subtitle: s("goals.roadmap.subtitle"),
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    accent: DS.accent
                )

                VStack(spacing: 10) {
                    ForEach(Array(roadmap.milestones.enumerated()), id: \.element.id) { index, milestone in
                        milestoneRow(milestone, index: index)
                    }
                }
            }
        }
    }

    private func habitsAndRisksCard(_ roadmap: GoalRoadmap) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.support.title"),
                    subtitle: s("goals.support.subtitle"),
                    icon: "sparkles.rectangle.stack.fill",
                    accent: Color(hex: 0xFF9F0A)
                )

                VStack(spacing: 9) {
                    ForEach(roadmap.habits) { habit in
                        supportRow(icon: "repeat.circle.fill", title: habit.title, detail: habit.detail, tone: Color(hex: 0x30D158))
                    }

                    ForEach(roadmap.risks) { risk in
                        supportRow(icon: "exclamationmark.triangle.fill", title: risk.title, detail: risk.mitigation, tone: Color(hex: 0xFF9F0A))
                    }
                }
            }
        }
    }

    private func milestoneRow(_ milestone: GoalMilestone, index: Int) -> some View {
        let tone = milestone.category.tint
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .fill(tone.opacity(0.18))
                        .overlay(Circle().stroke(tone.opacity(0.32), lineWidth: 1))
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                }
                .frame(width: 30, height: 30)
                .lippiSystemGlass(in: Circle(), tint: tone.opacity(0.10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)

                    Text(milestone.target)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        infoPill(title: milestone.timeframe, icon: "clock")
                        infoPill(title: milestone.category.title, icon: milestone.category.symbol)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(milestone.tasks.prefix(3), id: \.self) { task in
                    Label(task, systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.78))
                        .labelStyle(TightLabelStyle())
                        .lineLimit(2)
                }
            }
            .padding(.leading, 41)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tone.opacity(0.08)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: tone.opacity(0.08)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.13), lineWidth: 1))
    }

    private func supportRow(icon: String, title: String, detail: String, tone: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: icon, fallback: "sparkles")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(DS.text(0.92))
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    tint: tone.opacity(0.08)
                )
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(tone.opacity(0.24), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .singleLine()

                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: tone.opacity(0.07)
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func clarityBlock(
        title: String,
        icon: String,
        tone: Color,
        items: [String],
        itemIcon: String = "checkmark.circle.fill"
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.86))
                .labelStyle(TightLabelStyle())
                .singleLine()

            VStack(alignment: .leading, spacing: 7) {
                ForEach(items.prefix(4), id: \.self) { item in
                    Label(item, systemImage: itemIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.80))
                        .labelStyle(TightLabelStyle())
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tone.opacity(0.07)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: tone.opacity(0.07)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func previewStep(index: String, title: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(index)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.18), in: Circle())
                .lippiSystemGlass(in: Circle(), tint: tone.opacity(0.08))
                .overlay(Circle().stroke(tone.opacity(0.28), lineWidth: 1))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.82))
                .lineLimit(3)
                .minimumScaleFactor(0.84)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(12)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: tone.opacity(0.07)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func infoPill(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.text(0.82))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(DS.glassFill(0.08), in: Capsule())
            .lippiSystemGlass(in: Capsule(), tint: DS.accent.opacity(0.06))
            .overlay(Capsule().stroke(DS.glassStroke(0.13), lineWidth: 1))
            .singleLine()
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        let value = Int(max(0, min(1, confidence)) * 100)
        return VStack(spacing: 2) {
            Text("\(value)%")
                .font(.headline.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(s("goals.confidence"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .singleLine()
                .minimumScaleFactor(0.72)
        }
        .frame(width: 88, height: 62)
        .background(DS.glassFill(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: DS.accent.opacity(0.08)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            if let roadmap {
                Button { addFirstTasks(from: roadmap) } label: {
                    Label(addedTasks ? s("goals.action.added") : s("goals.action.add_tasks"), systemImage: addedTasks ? "checkmark.circle.fill" : "plus.circle.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: addedTasks ? .secondary : .primary))
            }

            if generationIssue != nil, roadmap == nil {
                Button {
                    createDraftRoadmap()
                } label: {
                    Label(isDrafting ? s("goals.action.drafting") : s("goals.action.draft"), systemImage: "doc.text.magnifyingglass")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .disabled(isDrafting)
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }

            Button {
                Task { await generateRoadmap() }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(DS.text())
                    } else {
                        Image(safeSystemName: "sparkles", fallback: "sparkles")
                    }
                    Text(isGenerating ? s("goals.action.generating") : s("goals.action.generate_ai"))
                        .singleLine()
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!canGenerate)
            .buttonStyle(LippiButtonStyle(kind: .primary))
            .opacity(canGenerate ? 1 : 0.55)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(DS.glassFill(0.10))
                .opacity(0.28)
                .ignoresSafeArea()
        )
        .lippiSystemGlass(in: Rectangle(), tint: DS.accent.opacity(0.05))
    }

    @MainActor
    private func generateRoadmap() async {
        guard canGenerate else { return }
        isGenerating = true
        addedTasks = false
        generationIssue = nil
        defer { isGenerating = false }

        let input = GoalPlannerInput(
            goal: goalText.trimmingCharacters(in: .whitespacesAndNewlines),
            context: contextText.trimmingCharacters(in: .whitespacesAndNewlines),
            horizon: horizon,
            intensity: intensity
        )

        do {
            let result = try await engine.buildAIRoadmap(input: input, lang: lang)
            roadmap = result
            generationIssue = nil
            saveRoadmap(result)

            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch let error as GoalPlannerEngineError {
            handleGenerationFailure(error, input: input)
        } catch {
            handleGenerationFailure(.generationFailed(error.localizedDescription), input: input)
        }
    }

    @MainActor
    private func handleGenerationFailure(_ error: GoalPlannerEngineError, input: GoalPlannerInput) {
        generationIssue = error.message(lang: lang)

        if error.shouldBuildDraftFallback {
            let draft = engine.buildDraftRoadmap(input: input, lang: lang)
            roadmap = draft
            saveRoadmap(draft)
        } else {
            roadmap = nil
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    private func createDraftRoadmap() {
        guard canGenerate || !goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isDrafting = true
        defer { isDrafting = false }

        let input = GoalPlannerInput(
            goal: goalText.trimmingCharacters(in: .whitespacesAndNewlines),
            context: contextText.trimmingCharacters(in: .whitespacesAndNewlines),
            horizon: horizon,
            intensity: intensity
        )

        let result = engine.buildDraftRoadmap(input: input, lang: lang)
        roadmap = result
        generationIssue = nil
        saveRoadmap(result)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func addFirstTasks(from roadmap: GoalRoadmap) {
        let calendar = Calendar.current
        let tasks = roadmap.milestones
            .prefix(2)
            .flatMap { milestone in
                milestone.tasks.prefix(2).map { (title: $0, category: milestone.category) }
            }
            .prefix(4)

        for (index, item) in tasks.enumerated() {
            let due = calendar.date(byAdding: .day, value: 2 + index * 2, to: .now)
            store.add(
                TaskItem(
                    title: item.title,
                    notes: roadmap.title,
                    dueDate: due,
                    category: item.category
                )
            )
        }

        addedTasks = true
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func restoreRoadmap() {
        guard roadmap == nil, !savedRoadmap.isEmpty else { return }
        guard let data = savedRoadmap.data(using: .utf8) else { return }
        roadmap = try? JSONDecoder().decode(GoalRoadmap.self, from: data)
        if goalText.isEmpty { goalText = roadmap?.title ?? "" }
    }

    private func saveRoadmap(_ roadmap: GoalRoadmap) {
        guard let data = try? JSONEncoder().encode(roadmap) else { return }
        savedRoadmap = String(decoding: data, as: UTF8.self)
    }
}

// =======================================================
// MARK: - Models
// =======================================================
protocol GoalPlannerOption: CaseIterable, Identifiable, Hashable, Codable where AllCases == [Self] {
    func title(lang: AppLang) -> String
}

enum GoalPlanningHorizon: String, GoalPlannerOption {
    case fourWeeks
    case eightWeeks
    case twelveWeeks

    var id: String { rawValue }
    var weeks: Int {
        switch self {
        case .fourWeeks: return 4
        case .eightWeeks: return 8
        case .twelveWeeks: return 12
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .fourWeeks: return L10n.tr("goals.horizon.4", lang)
        case .eightWeeks: return L10n.tr("goals.horizon.8", lang)
        case .twelveWeeks: return L10n.tr("goals.horizon.12", lang)
        }
    }
}

enum GoalPlanningIntensity: String, GoalPlannerOption {
    case light
    case balanced
    case focused

    var id: String { rawValue }

    func title(lang: AppLang) -> String {
        switch self {
        case .light: return L10n.tr("goals.intensity.light", lang)
        case .balanced: return L10n.tr("goals.intensity.balanced", lang)
        case .focused: return L10n.tr("goals.intensity.focused", lang)
        }
    }
}

enum GoalRoadmapSource: String, Codable {
    case ollama
    case foundationModels
    case localPlanner

    var icon: String {
        switch self {
        case .ollama: return "desktopcomputer"
        case .foundationModels: return "cpu.fill"
        case .localPlanner: return "sparkles"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .ollama: return L10n.tr("goals.source.ollama", lang)
        case .foundationModels: return L10n.tr("goals.source.ai", lang)
        case .localPlanner: return L10n.tr("goals.source.local", lang)
        }
    }
}

struct GoalPlannerInput: Codable, Hashable {
    var goal: String
    var context: String
    var horizon: GoalPlanningHorizon
    var intensity: GoalPlanningIntensity
}

struct GoalRoadmap: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var summary: String
    var source: GoalRoadmapSource
    var confidence: Double
    var createdAt = Date()
    var successCriteria: [String]
    var firstActions: [String]
    var assumptions: [String]
    var clarifyingQuestions: [String]? = nil
    var evidence: [GoalEvidenceSource]? = nil
    var milestones: [GoalMilestone]
    var habits: [GoalHabit]
    var risks: [GoalRisk]
}

struct GoalMilestone: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var timeframe: String
    var target: String
    var tasks: [String]
    var category: TaskCategory
}

struct GoalHabit: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

struct GoalRisk: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var mitigation: String
}

private struct GoalRoadmapPayload: Codable {
    var title: String
    var summary: String
    var confidence: Double?
    var successCriteria: [String]?
    var firstActions: [String]?
    var assumptions: [String]?
    var clarifyingQuestions: [String]?
    var milestones: [GoalMilestonePayload]
    var habits: [GoalSupportPayload]
    var risks: [GoalRiskPayload]

    func roadmap(
        source: GoalRoadmapSource,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource] = []
    ) -> GoalRoadmap? {
        let profile = GoalProfile(goal: input.goal, context: input.context)
        var seenMilestoneKeys = Set<String>()
        let uniqueMilestones = milestones.filter { item in
            let key = [
                item.title.trimmed,
                item.timeframe.trimmed,
                item.target.trimmed,
                item.tasks.map(\.trimmed).joined(separator: "|")
            ].joined(separator: "|").lowercased()
            return !key.isEmpty && seenMilestoneKeys.insert(key).inserted
        }
        let mappedMilestones = uniqueMilestones.prefix(5).map { item in
            GoalMilestone(
                title: item.title.nonEmpty(or: L10n.tr("goals.local.phase", lang)),
                timeframe: item.timeframe.nonEmpty(or: ""),
                target: item.target.nonEmpty(or: summary.nonEmpty(or: input.goal)),
                tasks: item.tasks.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.prefixArray(4),
                category: TaskCategory(rawValue: item.category) ?? profile.category
            )
        }.filter { !$0.title.isEmpty && !$0.target.isEmpty && !$0.tasks.isEmpty }

        guard !mappedMilestones.isEmpty else { return nil }

        let cleanCriteria = successCriteria.cleanLines(limit: 4)
        let cleanActions = firstActions.cleanLines(limit: 4)
        let cleanAssumptions = assumptions.cleanLines(limit: 3)
        let cleanQuestions = clarifyingQuestions.cleanLines(limit: 3)
        let cleanHabits = habits.prefix(4).map { GoalHabit(title: $0.title, detail: $0.detail) }
            .filter { !$0.title.trimmed.isEmpty && !$0.detail.trimmed.isEmpty }
        let cleanRisks = risks.prefix(3).map { GoalRisk(title: $0.title, mitigation: $0.mitigation) }
            .filter { !$0.title.trimmed.isEmpty && !$0.mitigation.trimmed.isEmpty }

        guard !cleanCriteria.isEmpty, !cleanActions.isEmpty, !cleanHabits.isEmpty, !cleanRisks.isEmpty else {
            return nil
        }

        return GoalRoadmap(
            title: title.nonEmpty(or: input.goal),
            summary: summary.nonEmpty(or: L10n.fmt("goals.local.summary", lang, input.goal, input.horizon.weeks, input.intensity.title(lang: lang).lowercased())),
            source: source,
            confidence: min(max(confidence ?? 0.78, 0.45), 0.96),
            successCriteria: cleanCriteria,
            firstActions: cleanActions,
            assumptions: cleanAssumptions,
            clarifyingQuestions: cleanQuestions.isEmpty ? nil : cleanQuestions,
            evidence: evidence.isEmpty ? nil : evidence,
            milestones: mappedMilestones,
            habits: cleanHabits,
            risks: cleanRisks
        )
    }
}

private struct GoalMilestonePayload: Codable {
    var title: String
    var timeframe: String
    var target: String
    var tasks: [String]
    var category: String
}

private struct GoalSupportPayload: Codable {
    var title: String
    var detail: String
}

private struct GoalRiskPayload: Codable {
    var title: String
    var mitigation: String
}

// =======================================================
// MARK: - Engine
// =======================================================
enum GoalPlannerEngineError: Error {
    case modelUnavailable
    case systemLocaleUnsupported
    case unsupportedLocale
    case translationUnavailable(String)
    case providersUnavailable(String)
    case invalidResponse
    case generationInterrupted
    case generationFailed(String)

    var shouldBuildDraftFallback: Bool {
        switch self {
        case .modelUnavailable, .systemLocaleUnsupported, .unsupportedLocale, .translationUnavailable, .providersUnavailable, .invalidResponse, .generationInterrupted, .generationFailed:
            return true
        }
    }

    func message(lang: AppLang) -> String {
        switch self {
        case .modelUnavailable:
            return L10n.tr("goals.error.unavailable", lang)
        case .systemLocaleUnsupported:
            return L10n.tr("goals.error.system_locale", lang)
        case .unsupportedLocale:
            return L10n.tr("goals.error.unsupported_locale", lang)
        case .translationUnavailable(let details):
            return L10n.fmt("goals.error.translation_unavailable", lang, details)
        case .providersUnavailable(let details):
            return L10n.fmt("goals.error.providers", lang, details)
        case .invalidResponse:
            return L10n.tr("goals.error.invalid", lang)
        case .generationInterrupted:
            return L10n.tr("goals.error.generation_interrupted", lang)
        case .generationFailed(let details):
            return L10n.fmt("goals.error.failed", lang, details)
        }
    }
}

private struct FoundationGoalInput {
    var goal: String
    var context: String
    var translatedFromUserLanguage: Bool
    var usedSemanticBridge: Bool
}

struct GoalRoadmapEngine {
    func buildAIRoadmap(input: GoalPlannerInput, lang: AppLang) async throws -> GoalRoadmap {
        let evidence = await OpenRoadmapRetriever().research(for: input)
        let configuration = OllamaConfiguration.stored
        var macProviderIssue: OllamaProviderError?

        if configuration.isEnabled {
            do {
                return try await generateOllamaRoadmap(
                    input: input,
                    lang: lang,
                    configuration: configuration,
                    evidence: evidence
                )
            } catch let error as OllamaProviderError {
                macProviderIssue = error
            } catch {
                macProviderIssue = .transport
            }
        }

        do {
            return try await generateFoundationModelsRoadmap(input: input, lang: lang, evidence: evidence)
        } catch let error as GoalPlannerEngineError {
            if let macProviderIssue {
                throw GoalPlannerEngineError.providersUnavailable(macProviderIssue.message(lang: lang))
            }
            throw error
        }
    }

    static func primaryAIStatus(lang: AppLang) -> String {
        let configuration = OllamaConfiguration.stored
        if configuration.isEnabled {
            return configuration.isConfigured
                ? L10n.tr("goals.ai.mac_ready", lang)
                : L10n.tr("goals.ai.mac_setup", lang)
        }
        return systemModelStatus(lang: lang)
    }

    static func primaryAIHeroEyebrow(lang: AppLang) -> String {
        prefersOllama
            ? L10n.tr("goals.hero.eyebrow.mac", lang)
            : L10n.tr("goals.hero.eyebrow", lang)
    }

    static func primaryAIHeroSubtitle(lang: AppLang) -> String {
        prefersOllama
            ? L10n.tr("goals.hero.subtitle.mac", lang)
            : L10n.tr("goals.hero.subtitle", lang)
    }

    static func primaryAIPrivacyLabel(lang: AppLang) -> String {
        prefersOllama
            ? L10n.tr("goals.hero.private.mac", lang)
            : L10n.tr("goals.hero.private", lang)
    }

    private static var prefersOllama: Bool {
        let configuration = OllamaConfiguration.stored
        return configuration.isEnabled && configuration.isConfigured
    }

    static func systemModelStatus(lang: AppLang) -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return L10n.tr("goals.ai.unavailable", lang) }
            return model.supportsLocale(.current)
                ? L10n.tr("goals.ai.available", lang)
                : L10n.tr("goals.ai.locale_unsupported", lang)
        }
        #endif
        return L10n.tr("goals.ai.unavailable", lang)
    }

    private func generateOllamaRoadmap(
        input: GoalPlannerInput,
        lang: AppLang,
        configuration: OllamaConfiguration,
        evidence: [GoalEvidenceSource]
    ) async throws -> GoalRoadmap {
        let provider = OllamaGoalProvider()
        let response = try await provider.generate(
            prompt: ollamaPrompt(for: input, lang: lang, evidence: evidence),
            configuration: configuration
        )

        if let payload = parsePayload(response),
           let roadmap = payload.roadmap(source: .ollama, input: input, lang: lang, evidence: evidence) {
            return roadmap
        }

        let repair = try await provider.generate(
            prompt: ollamaRepairPrompt(previous: response, input: input, lang: lang, evidence: evidence),
            configuration: configuration
        )
        guard let payload = parsePayload(repair),
              let roadmap = payload.roadmap(source: .ollama, input: input, lang: lang, evidence: evidence) else {
            throw OllamaProviderError.incompleteRoadmap
        }
        return roadmap
    }

    private func ollamaPrompt(for input: GoalPlannerInput, lang: AppLang, evidence: [GoalEvidenceSource]) -> String {
        """
        You are Lippi's evidence-first roadmap planner. Your job is to help a person reach a real goal without inventing details.
        Separate facts from the user's input, relevant open reference material, assumptions, and questions that need the user's answer.
        Build a small, realistic route that respects the user's stated outcome, timeframe, available time, limits, and preferred pace.
        Respond only with valid JSON. Do not add Markdown, explanations outside JSON, or a thinking trace.

        User goal:
        \(input.goal)

        User context:
        \(input.context.isEmpty ? L10n.tr("goals.ai.no_context", lang) : input.context)

        Planning horizon: \(input.horizon.weeks) weeks.
        Desired pace: \(input.intensity.rawValue).
        Output language: \(lang.aiOutputLanguage).

        Curated open reference material fetched by Lippi. This is the only external material you may use:
        \(evidencePromptSection(evidence))

        Return this exact JSON shape:
        {
          "title": "short specific roadmap title",
          "summary": "one clear sentence about the route",
          "confidence": 0.82,
          "successCriteria": ["observable sign of success", "measurable checkpoint"],
          "firstActions": ["action the user can take today", "next small action"],
          "assumptions": ["assumption made because context is missing"],
          "clarifyingQuestions": ["question only when the answer would materially change the route"],
          "milestones": [
            {"title": "phase title", "timeframe": "Weeks 1-2", "target": "concrete phase outcome", "tasks": ["short task 1", "short task 2", "short task 3"], "category": "work"}
          ],
          "habits": [{"title": "habit", "detail": "short cadence"}],
          "risks": [{"title": "risk", "mitigation": "specific mitigation"}]
        }

        Rules:
        - Return exactly 3 milestones for a 4- or 8-week horizon, and exactly 4 milestones for a 12-week horizon. Never repeat a milestone title, target, or task.
        - Return exactly 2 success criteria and 2 first actions. Return 1 or 2 habits and 1 or 2 risks.
        - Use the user's language for every JSON string value.
        - Keep tasks concrete and short.
        - Preserve dates, numbers, weekly time, constraints, and the real domain from the input.
        - Treat a fact as known only when it is present in the user input or reference material above.
        - Do not invent deadlines, metrics, resources, prerequisites, statistics, source names, or personal circumstances.
        - An assumption must only say what needs user confirmation; it must not claim that an unknown fact is true. Ask 1 to 3 clarifying questions only when the answer would change the proposed route; otherwise return an empty array.
        - Success criteria may use an explicit user metric or a deliverable that can be reviewed. Never invent user feedback, satisfaction, audience demand, conversion, revenue, health outcomes, or test results.
        - Use reference material only as a high-level route. Do not turn it into medical, legal, financial, or guaranteed-result advice.
        - Never claim that the references recommend a step unless their excerpt supports it.
        - Allowed categories: work, study, health, rest, home, other.
        """
    }

    private func ollamaRepairPrompt(
        previous: String,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource]
    ) -> String {
        """
        Convert the previous answer into valid JSON only. Keep only useful, grounded planning details. Do not invent missing facts or sources.

        User goal: \(input.goal)
        User context: \(input.context.isEmpty ? L10n.tr("goals.ai.no_context", lang) : input.context)
        Horizon: \(input.horizon.weeks) weeks.
        Output language: \(lang.aiOutputLanguage).
        Curated open reference material available to Lippi:
        \(evidencePromptSection(evidence))

        Required JSON shape:
        {"title":"string","summary":"string","confidence":0.82,"successCriteria":["string"],"firstActions":["string"],"assumptions":["string"],"clarifyingQuestions":["string"],"milestones":[{"title":"string","timeframe":"string","target":"string","tasks":["string"],"category":"work"}],"habits":[{"title":"string","detail":"string"}],"risks":[{"title":"string","mitigation":"string"}]}

        Previous answer:
        \(previous)
        """
    }

    private func generateFoundationModelsRoadmap(
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource]
    ) async throws -> GoalRoadmap {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { throw GoalPlannerEngineError.modelUnavailable }
            guard model.supportsLocale(.current) else { throw GoalPlannerEngineError.systemLocaleUnsupported }
            let foundationInput = try await prepareFoundationInput(input)

            let session = LanguageModelSession(
                model: model,
                instructions: foundationInstructions
            )

            do {
                let response = try await session.respond(
                    to: prompt(for: foundationInput, original: input, evidence: evidence),
                    options: GenerationOptions(temperature: 0.18, maximumResponseTokens: 2600)
                )
                if let payload = parsePayload(response.content),
                   let roadmap = payload.roadmap(source: .foundationModels, input: input, lang: lang, evidence: evidence) {
                    return annotateLanguageBridge(
                        roadmap,
                        lang: lang,
                        translatedInput: foundationInput.translatedFromUserLanguage,
                        semanticBridge: foundationInput.usedSemanticBridge
                    )
                }

                let repair = try await session.respond(
                    to: repairPrompt(original: response.content, input: foundationInput, originalInput: input, evidence: evidence),
                    options: GenerationOptions(temperature: 0.05, maximumResponseTokens: 2200)
                )
                guard let payload = parsePayload(repair.content),
                      let roadmap = payload.roadmap(source: .foundationModels, input: input, lang: lang, evidence: evidence) else {
                    throw GoalPlannerEngineError.invalidResponse
                }
                return annotateLanguageBridge(
                    roadmap,
                    lang: lang,
                    translatedInput: foundationInput.translatedFromUserLanguage,
                    semanticBridge: foundationInput.usedSemanticBridge
                )
            } catch let error as GoalPlannerEngineError {
                throw error
            } catch LanguageModelSession.GenerationError.unsupportedLanguageOrLocale(_) {
                throw GoalPlannerEngineError.unsupportedLocale
            } catch is LanguageModelSession.GenerationError {
                throw GoalPlannerEngineError.generationInterrupted
            } catch {
                throw classifyFoundationModelsError(error)
            }
        }
        #endif
        throw GoalPlannerEngineError.modelUnavailable
    }

    private func classifyFoundationModelsError(_ error: Error) -> GoalPlannerEngineError {
        if let plannerError = error as? GoalPlannerEngineError {
            return plannerError
        }

        let text = [
            String(reflecting: type(of: error)),
            String(reflecting: error),
            error.localizedDescription
        ].joined(separator: " ")

        if text.localizedCaseInsensitiveContains("unsupportedLanguageOrLocale")
            || text.localizedCaseInsensitiveContains("unsupported language")
            || text.localizedCaseInsensitiveContains("unsupported locale") {
            return .unsupportedLocale
        }

        if text.localizedCaseInsensitiveContains("FoundationModels")
            || text.localizedCaseInsensitiveContains("LanguageModelSession")
            || text.localizedCaseInsensitiveContains("GenerationError")
            || text.localizedCaseInsensitiveContains("error -1") {
            return .generationInterrupted
        }

        return .generationFailed(error.localizedDescription)
    }

    private func prepareFoundationInput(_ input: GoalPlannerInput) async throws -> FoundationGoalInput {
        let goal = input.goal.trimmed
        let context = input.context.trimmed
        let combined = "\(goal) \(context)"
        guard combined.containsCyrillic else {
            return FoundationGoalInput(goal: goal, context: context, translatedFromUserLanguage: false, usedSemanticBridge: false)
        }

        #if canImport(Translation)
        if #available(iOS 26.0, *) {
            do {
                let translator = TranslationSession(
                    installedSource: Locale.Language(identifier: "ru"),
                    target: Locale.Language(identifier: "en")
                )
                try await translator.prepareTranslation()
                let translatedGoal = try await translator.translate(goal)
                let translatedGoalText = translatedGoal.targetText.trimmed
                guard !translatedGoalText.isEmpty, !translatedGoalText.containsCyrillic else {
                    throw GoalPlannerEngineError.translationUnavailable("translation returned text in the original language")
                }

                let translatedContext: String
                if context.isEmpty {
                    translatedContext = ""
                } else {
                    translatedContext = try await translator.translate(context).targetText.trimmed
                    guard !translatedContext.containsCyrillic else {
                        throw GoalPlannerEngineError.translationUnavailable("context translation returned text in the original language")
                    }
                }
                return FoundationGoalInput(
                    goal: translatedGoalText,
                    context: translatedContext,
                    translatedFromUserLanguage: true,
                    usedSemanticBridge: false
                )
            } catch let error as GoalPlannerEngineError {
                if case .translationUnavailable = error {
                    return SemanticGoalBridge.makeInput(goal: goal, context: context)
                }
                throw error
            } catch {
                return SemanticGoalBridge.makeInput(goal: goal, context: context)
            }
        }
        #endif

        return SemanticGoalBridge.makeInput(goal: goal, context: context)
    }

    private var foundationInstructions: String {
        """
        You are Lippi's evidence-first roadmap planner inside an iPhone app.
        You must operate in English because the local system model may reject unsupported languages/locales.
        Build a route from the user's stated facts and the curated reference material supplied in the request.
        Separate facts, assumptions, and questions. Never invent a deadline, metric, resource, personal circumstance, or source.
        Return strict JSON only, without Markdown.
        Make the plan practical, safe, short, and measurable.
        Ask a clarifying question only when its answer materially changes the route. Do not promise guaranteed results.
        """
    }

    private func prompt(
        for input: FoundationGoalInput,
        original: GoalPlannerInput,
        evidence: [GoalEvidenceSource]
    ) -> String {
        let sourceNote: String
        if input.usedSemanticBridge {
            sourceNote = "The user wrote in Russian. Apple Translation was unavailable, so Lippi used its offline Russian-English goal translator before this request. The translated goal and context preserve the planning-relevant intent, domain, dates, quantities, weekly time, and explicit constraints. Do not request or use the original Russian text. State assumptions only for information that is missing from the English brief."
        } else if input.translatedFromUserLanguage {
            sourceNote = "The user wrote in Russian. Apple Translation converted the goal and context to English before this request. Do not use or request the original language text."
        } else {
            sourceNote = "The user provided English text."
        }

        return """
        Build a clear goal-achievement roadmap.

        User goal in English:
        \(input.goal)

        User context in English:
        \(input.context.isEmpty ? "No context provided" : input.context)

        Planning horizon: \(original.horizon.weeks) weeks
        Desired pace: \(original.intensity.rawValue)
        Output language: English
        Input was translated before planning: \(input.translatedFromUserLanguage ? "yes" : "no")
        Source-language handling: \(sourceNote)
        Curated open reference material fetched by Lippi. This is the only external material you may use:
        \(evidencePromptSection(evidence))

        Build a real, context-aware roadmap. Treat only the user brief and the reference material above as known facts. If context is thin, use assumptions or targeted questions instead of pretending certainty.

        Return strict JSON only, no Markdown:
        {
          "title": "short specific roadmap title",
          "summary": "one clear sentence explaining the route",
          "confidence": 0.82,
          "successCriteria": ["observable sign of success", "measurable checkpoint"],
          "firstActions": ["first action the user can do today", "second action"],
          "assumptions": ["assumption made because context is missing"],
          "clarifyingQuestions": ["question only when the answer would materially change the route"],
          "milestones": [
            {"title": "phase title", "timeframe": "Weeks 1-2", "target": "concrete outcome of this phase", "tasks": ["short task 1", "short task 2", "short task 3"], "category": "work"}
          ],
          "habits": [{"title": "habit", "detail": "short cadence"}],
          "risks": [{"title": "risk", "mitigation": "mitigation"}]
        }

        Allowed categories: work, study, health, rest, home, other.
        Rules:
        - Write all JSON string values in simple English.
        - Return exactly 3 milestones for a 4- or 8-week horizon, and exactly 4 milestones for a 12-week horizon. Never repeat a milestone title, target, or task.
        - Each task must be actionable, short, and understandable without extra explanation.
        - Success criteria must describe what the user will see or measure.
        - Do not invent deadlines, metrics, resources, prerequisites, statistics, source names, personal circumstances, feedback, satisfaction, demand, conversion, or revenue.
        - An assumption may only identify a fact that needs user confirmation; it must not claim that the fact is true.
        - Use reference material only as a high-level route. Do not claim that it recommends a step unless its excerpt supports it.
        - Return an empty clarifyingQuestions array unless an answer is necessary to choose a route.
        - Do not include medical, financial, legal, or guaranteed-outcome promises.
        - Do not produce generic productivity advice unless it directly matches the goal context.
        """
    }

    private func repairPrompt(
        original: String,
        input: FoundationGoalInput,
        originalInput: GoalPlannerInput,
        evidence: [GoalEvidenceSource]
    ) -> String {
        let sourceNote: String
        if input.usedSemanticBridge {
            sourceNote = "The user wrote in Russian. Apple Translation was unavailable, so Lippi created an offline English planning translation before this request. Keep the repaired JSON in English and preserve the translated intent, dates, quantities, time limits, and constraints."
        } else if input.translatedFromUserLanguage {
            sourceNote = "The user wrote in Russian. Apple Translation converted the goal and context to English before this request. Keep the repaired JSON in English."
        } else {
            sourceNote = "The user provided English text. Keep the repaired JSON in English."
        }

        return """
        The previous answer was not valid for the app. Convert it into strict JSON only using the exact schema below. Preserve useful context-specific planning ideas, but fix missing fields and invalid structure.

        Goal in English: \(input.goal)
        Context in English: \(input.context.isEmpty ? "No context provided" : input.context)
        Planning horizon: \(originalInput.horizon.weeks) weeks
        Desired pace: \(originalInput.intensity.rawValue)
        Output language: English
        Source-language handling: \(sourceNote)
        Curated open reference material available to Lippi:
        \(evidencePromptSection(evidence))

        Required JSON schema:
        {
          "title": "string",
          "summary": "string",
          "confidence": 0.82,
          "successCriteria": ["string", "string"],
          "firstActions": ["string", "string"],
          "assumptions": ["string"],
          "clarifyingQuestions": ["string"],
          "milestones": [
            {"title": "string", "timeframe": "string", "target": "string", "tasks": ["string", "string", "string"], "category": "work"}
          ],
          "habits": [{"title": "string", "detail": "string"}],
          "risks": [{"title": "string", "mitigation": "string"}]
        }

        Previous answer:
        \(original)
        """
    }

    private func evidencePromptSection(_ evidence: [GoalEvidenceSource]) -> String {
        guard !evidence.isEmpty else {
            return "No matching reference was available. Build only from the user's input and make uncertainty explicit."
        }

        return evidence.map { source in
            "- \(source.title): \(source.excerpt) [\(source.url)]"
        }.joined(separator: "\n")
    }

    private func annotateLanguageBridge(_ roadmap: GoalRoadmap, lang: AppLang, translatedInput: Bool, semanticBridge: Bool) -> GoalRoadmap {
        guard lang != .en || translatedInput || semanticBridge else { return roadmap }
        var annotated = roadmap
        let note: String
        if semanticBridge {
            note = L10n.tr("goals.assumption.ai_semantic_bridge", lang)
        } else {
            note = translatedInput ? L10n.tr("goals.assumption.ai_translated_bridge", lang) : L10n.tr("goals.assumption.ai_english_bridge", lang)
        }
        if !annotated.assumptions.contains(note) {
            annotated.assumptions.append(note)
        }
        return annotated
    }

    private func parsePayload(_ text: String) -> GoalRoadmapPayload? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GoalRoadmapPayload.self, from: data)
    }

    func buildDraftRoadmap(input: GoalPlannerInput, lang: AppLang) -> GoalRoadmap {
        let profile = GoalProfile(goal: input.goal, context: input.context)
        let phaseTitles = localPhaseTitles(for: profile.category, lang: lang)
        let tasks = localTaskBank(for: profile.category, lang: lang, intensity: input.intensity)
        let weeks = input.horizon.weeks
        let phaseCount = min(4, max(3, weeks / 2))
        let chunk = max(1, weeks / phaseCount)

        let milestones = (0..<phaseCount).map { index in
            let startWeek = index * chunk + 1
            let endWeek = index == phaseCount - 1 ? weeks : min(weeks, (index + 1) * chunk)
            let title = phaseTitles[safe: index] ?? phaseTitles.last ?? L10n.tr("goals.local.phase", lang)
            let phaseTasks = rotated(tasks, offset: index * 2).prefixArray(3)

            return GoalMilestone(
                title: title,
                timeframe: timeframe(start: startWeek, end: endWeek, lang: lang),
                target: targetText(goal: input.goal, index: index, category: profile.category, lang: lang),
                tasks: phaseTasks,
                category: profile.category
            )
        }

        return GoalRoadmap(
            title: input.goal,
            summary: summaryText(goal: input.goal, horizon: input.horizon, intensity: input.intensity, category: profile.category, lang: lang),
            source: .localPlanner,
            confidence: 0.52,
            successCriteria: draftSuccessCriteria(goal: input.goal, category: profile.category, lang: lang),
            firstActions: rotated(tasks, offset: 0).prefixArray(4),
            assumptions: draftAssumptions(input: input, lang: lang),
            milestones: milestones,
            habits: localHabits(for: profile.category, lang: lang, intensity: input.intensity),
            risks: localRisks(for: profile.category, lang: lang)
        )
    }

    private func timeframe(start: Int, end: Int, lang: AppLang) -> String {
        if start == end {
            return L10n.fmt("goals.local.week", lang, start)
        }
        return L10n.fmt("goals.local.weeks", lang, start, end)
    }

    private func summaryText(goal: String, horizon: GoalPlanningHorizon, intensity: GoalPlanningIntensity, category: TaskCategory, lang: AppLang) -> String {
        L10n.fmt("goals.local.summary", lang, goal, horizon.weeks, intensity.title(lang: lang).lowercased())
    }

    private func targetText(goal: String, index: Int, category: TaskCategory, lang: AppLang) -> String {
        let templates = [
            L10n.tr("goals.local.target_1", lang),
            L10n.tr("goals.local.target_2", lang),
            L10n.tr("goals.local.target_3", lang),
            L10n.tr("goals.local.target_4", lang)
        ]
        return String(format: templates[safe: index] ?? templates[0], locale: Locale(identifier: lang.localeIdentifier), goal)
    }

    private func localPhaseTitles(for category: TaskCategory, lang: AppLang) -> [String] {
        switch category {
        case .health:
            return [L10n.tr("goals.phase.health.1", lang), L10n.tr("goals.phase.health.2", lang), L10n.tr("goals.phase.health.3", lang), L10n.tr("goals.phase.health.4", lang)]
        case .study:
            return [L10n.tr("goals.phase.study.1", lang), L10n.tr("goals.phase.study.2", lang), L10n.tr("goals.phase.study.3", lang), L10n.tr("goals.phase.study.4", lang)]
        case .work:
            return [L10n.tr("goals.phase.work.1", lang), L10n.tr("goals.phase.work.2", lang), L10n.tr("goals.phase.work.3", lang), L10n.tr("goals.phase.work.4", lang)]
        default:
            return [L10n.tr("goals.phase.common.1", lang), L10n.tr("goals.phase.common.2", lang), L10n.tr("goals.phase.common.3", lang), L10n.tr("goals.phase.common.4", lang)]
        }
    }

    private func localTaskBank(for category: TaskCategory, lang: AppLang, intensity: GoalPlanningIntensity) -> [String] {
        var base: [String]
        switch category {
        case .health:
            base = ["goals.task.health.1", "goals.task.health.2", "goals.task.health.3", "goals.task.health.4", "goals.task.health.5"].map { L10n.tr($0, lang) }
        case .study:
            base = ["goals.task.study.1", "goals.task.study.2", "goals.task.study.3", "goals.task.study.4", "goals.task.study.5"].map { L10n.tr($0, lang) }
        case .work:
            base = ["goals.task.work.1", "goals.task.work.2", "goals.task.work.3", "goals.task.work.4", "goals.task.work.5"].map { L10n.tr($0, lang) }
        default:
            base = ["goals.task.common.1", "goals.task.common.2", "goals.task.common.3", "goals.task.common.4", "goals.task.common.5"].map { L10n.tr($0, lang) }
        }
        if intensity == .focused {
            base.insert(L10n.tr("goals.task.focused.extra", lang), at: min(2, base.count))
        }
        return base
    }

    private func localHabits(for category: TaskCategory, lang: AppLang, intensity: GoalPlanningIntensity) -> [GoalHabit] {
        [
            GoalHabit(title: L10n.tr("goals.habit.review.title", lang), detail: L10n.tr("goals.habit.review.detail", lang)),
            GoalHabit(title: L10n.tr("goals.habit.focus.title", lang), detail: intensity == .light ? L10n.tr("goals.habit.focus.light", lang) : L10n.tr("goals.habit.focus.detail", lang)),
            GoalHabit(title: L10n.tr("goals.habit.measure.title", lang), detail: L10n.tr("goals.habit.measure.detail", lang))
        ]
    }

    private func localRisks(for category: TaskCategory, lang: AppLang) -> [GoalRisk] {
        [
            GoalRisk(title: L10n.tr("goals.risk.scope.title", lang), mitigation: L10n.tr("goals.risk.scope.detail", lang)),
            GoalRisk(title: L10n.tr("goals.risk.energy.title", lang), mitigation: L10n.tr("goals.risk.energy.detail", lang)),
            GoalRisk(title: L10n.tr("goals.risk.feedback.title", lang), mitigation: L10n.tr("goals.risk.feedback.detail", lang))
        ]
    }

    private func draftSuccessCriteria(goal: String, category: TaskCategory, lang: AppLang) -> [String] {
        [
            L10n.fmt("goals.criteria.draft_1", lang, goal),
            L10n.tr("goals.criteria.draft_2", lang),
            L10n.tr("goals.criteria.draft_3", lang)
        ]
    }

    private func draftAssumptions(input: GoalPlannerInput, lang: AppLang) -> [String] {
        if input.context.trimmed.isEmpty {
            return [L10n.tr("goals.assumption.no_context", lang)]
        }
        return [L10n.tr("goals.assumption.draft", lang)]
    }

    private func rotated(_ values: [String], offset: Int) -> [String] {
        guard !values.isEmpty else { return [] }
        let start = offset % values.count
        return Array(values[start...] + values[..<start])
    }
}

private struct GoalProfile {
    let category: TaskCategory

    init(goal: String, context: String) {
        let text = "\(goal) \(context)".lowercased()
        if text.containsAny(["здоров", "спорт", "вес", "сон", "бег", "тело", "health", "fitness", "sleep", "run"]) {
            category = .health
        } else if text.containsAny(["уч", "курс", "экзам", "англ", "язык", "study", "learn", "course", "exam", "language"]) {
            category = .study
        } else if text.containsAny(["работ", "проект", "бизнес", "карьер", "продукт", "work", "career", "business", "project", "launch"]) {
            category = .work
        } else if text.containsAny(["дом", "ремонт", "сем", "home", "family"]) {
            category = .home
        } else if text.containsAny(["отдых", "баланс", "стресс", "rest", "balance", "stress"]) {
            category = .rest
        } else {
            category = .other
        }
    }
}

private enum SemanticGoalBridge {
    static func makeInput(goal: String, context: String) -> FoundationGoalInput {
        let translated = RussianGoalTranslator.translate(goal: goal, context: context)

        return FoundationGoalInput(
            goal: translated.goal,
            context: translated.context,
            translatedFromUserLanguage: true,
            usedSemanticBridge: true
        )
    }

}

// =======================================================
// MARK: - Helpers
// =======================================================
private extension View {
    func goalGlassField(tint: Color) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(DS.glassTint).opacity(0.28))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(tint.opacity(0.08)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 15, style: .continuous),
                tint: tint.opacity(0.08),
                interactive: true
            )
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var containsCyrillic: Bool {
        unicodeScalars.contains { scalar in
            (0x0400...0x04FF).contains(Int(scalar.value))
        }
    }

    func nonEmpty(or fallback: String) -> String {
        trimmed.isEmpty ? fallback : trimmed
    }

    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

private extension AppLang {
    var aiOutputLanguage: String {
        switch self {
        case .ru: return "Russian"
        case .en: return "English"
        case .de: return "German"
        case .es: return "Spanish"
        }
    }
}

private extension Optional where Wrapped == [String] {
    func cleanLines(limit: Int) -> [String] {
        guard let self else { return [] }
        return self
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
            .prefixArray(limit)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    func prefixArray(_ count: Int) -> [Element] {
        Array(prefix(count))
    }

    func ifEmpty(_ fallback: [Element]) -> [Element] {
        isEmpty ? fallback : self
    }
}
