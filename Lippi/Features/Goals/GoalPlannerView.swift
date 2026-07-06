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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var chatDraftText = ""
    @State private var plannerMode: GoalPlannerMode = .assistant
    @State private var manualTitle: String = ""
    @State private var manualSummary: String = ""
    @State private var manualSuccessText: String = ""
    @State private var manualFirstActionsText: String = ""
    @State private var manualHabitText: String = ""
    @State private var manualRiskText: String = ""
    @State private var manualMilestones: [ManualRoadmapMilestone] = ManualRoadmapMilestone.starter

    private let engine = GoalRoadmapEngine()
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private func manualText(_ ru: String, _ en: String) -> String { lang == .ru ? ru : en }
    private var trimmedGoalText: String { goalText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedContextText: String { contextText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedManualTitle: String { manualTitle.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasGoalInput: Bool { !trimmedGoalText.isEmpty }
    private var canGenerate: Bool { hasGoalInput && !isGenerating }
    private var canCreateManualRoadmap: Bool { !trimmedManualTitle.isEmpty && !isGenerating }
    private var currentInput: GoalPlannerInput {
        GoalPlannerInput(
            goal: trimmedGoalText,
            context: trimmedContextText,
            horizon: horizon,
            intensity: intensity
        )
    }
    private var currentBrief: GoalRequestBrief {
        GoalRequestBrief.make(input: currentInput, fallbackLang: lang)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ScrollView {
                    LazyVStack(spacing: 16) {
                        plannerModeSwitcher
                            .lippiMotionScene(0)

                        if plannerMode == .assistant {
                            smartGoalChatCard
                                .lippiMotionScene(1)
                        } else {
                            manualRoadmapCard
                                .lippiMotionScene(1)
                        }

                        if let roadmap {
                            if let audit = progressAudit(for: roadmap), audit.shouldSuggestAdjustment {
                                adaptationCard(audit)
                                    .lippiMotionScene(2)
                            }
                            roadmapOverview(roadmap)
                                .lippiMotionScene(3)
                            clarityCard(roadmap)
                                .lippiMotionScene(4)
                            if !(roadmap.evidence ?? []).isEmpty {
                                evidenceCard(roadmap)
                                    .lippiMotionScene(5)
                            }
                            milestonesCard(roadmap)
                                .lippiMotionScene(6)
                            habitsAndRisksCard(roadmap)
                                .lippiMotionScene(7)
                        }

                        Color.clear.frame(height: 72)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .lippiScrollPerformance()
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

    private var plannerModeSwitcher: some View {
        GlassCard(
            padding: 8,
            cornerRadius: 24,
            style: .lightweight,
            forceSystemGlass: !reduceTransparency
        ) {
            HStack(spacing: 8) {
                ForEach(GoalPlannerMode.allCases) { mode in
                    plannerModeButton(mode)
                }
            }
        }
    }

    private func plannerModeButton(_ mode: GoalPlannerMode) -> some View {
        let isSelected = plannerMode == mode
        let tone = mode == .assistant ? DS.accent : Color(hex: 0x30D158)

        return Button {
            guard plannerMode != mode else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                plannerMode = mode
                generationIssue = nil
            }

            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            HStack(spacing: 9) {
                Image(safeSystemName: mode.icon, fallback: "sparkles")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? DS.textPrimary : tone)
                    .frame(width: 28, height: 28)
                    .background(tone.opacity(isSelected ? 0.22 : 0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title(lang: lang))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .singleLine()

                    Text(mode.subtitle(lang: lang))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.text(0.62))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(isSelected ? 0.13 : 0.055))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tone.opacity(isSelected ? 0.12 : 0.04)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: tone.opacity(isSelected ? 0.10 : 0.04),
                interactive: true
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? tone.opacity(0.28) : DS.glassStroke(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var manualRoadmapCard: some View {
        GlassCard(
            padding: 0,
            cornerRadius: 30,
            style: .full,
            forceSystemGlass: !reduceTransparency
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    LippiSectionHeader(
                        title: manualText("Ручная дорожная карта", "Manual roadmap"),
                        subtitle: manualText("Собери маршрут сам: этапы, критерии и первые действия", "Build it yourself: stages, criteria, and first actions"),
                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                        accent: Color(hex: 0x30D158)
                    )

                    manualRoadmapHint
                    manualTextField(
                        title: manualText("Цель", "Goal"),
                        placeholder: manualText("Например: запустить MVP за 4 месяца", "Example: launch an MVP in 4 months"),
                        icon: "flag.checkered",
                        text: $manualTitle,
                        tint: DS.accent
                    )

                    manualTextEditor(
                        title: manualText("Контекст", "Context"),
                        placeholder: manualText("Что уже есть, какие ограничения, сколько времени в неделю?", "What already exists, constraints, weekly capacity?"),
                        icon: "text.alignleft",
                        text: $manualSummary,
                        minHeight: 82,
                        tint: Color(hex: 0x64D2FF)
                    )

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
                .padding(.horizontal, 16)
                .padding(.top, 16)

                manualCriteriaSection
                    .padding(.horizontal, 16)

                manualMilestonesSection
                    .padding(.horizontal, 16)

                manualSupportSection
                    .padding(.horizontal, 16)

                manualPreviewFooter
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    private var manualRoadmapHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "hand.draw.fill", fallback: "hand.point.up.left.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x30D158))
                .frame(width: 28, height: 28)
                .background(Color(hex: 0x30D158).opacity(0.16), in: Circle())
                .lippiSystemGlass(in: Circle(), tint: Color(hex: 0x30D158).opacity(0.08))

            VStack(alignment: .leading, spacing: 4) {
                Text(manualText("Без ожидания модели", "No model required"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Text(manualText("Заполни только цель, если нужен быстрый черновик. Этапы, действия и критерии можно уточнить вручную.", "Fill only the goal for a quick draft. You can refine stages, actions, and criteria manually."))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.075))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x30D158).opacity(0.06)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: Color(hex: 0x30D158).opacity(0.06)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private var manualCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LippiSectionHeader(
                title: manualText("Результат", "Outcome"),
                subtitle: manualText("Что считать успехом и с чего начать", "Define success and the first moves"),
                icon: "checkmark.seal.fill",
                accent: DS.accent
            )

            manualTextEditor(
                title: manualText("Критерии успеха", "Success criteria"),
                placeholder: manualText("По одному критерию на строку", "One criterion per line"),
                icon: "checklist.checked",
                text: $manualSuccessText,
                minHeight: 76,
                tint: DS.accent
            )

            manualTextEditor(
                title: manualText("Первые действия", "First actions"),
                placeholder: manualText("Что сделать в ближайшие 24-48 часов?", "What should happen in the next 24-48 hours?"),
                icon: "bolt.fill",
                text: $manualFirstActionsText,
                minHeight: 76,
                tint: Color(hex: 0xFF9F0A)
            )
        }
        .padding(13)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: DS.accent.opacity(0.055)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private var manualMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LippiSectionHeader(
                title: manualText("Этапы", "Stages"),
                subtitle: manualText("Каждый этап станет частью дорожной карты", "Each stage becomes part of the roadmap"),
                icon: "map.fill",
                accent: Color(hex: 0x64D2FF)
            )

            VStack(spacing: 12) {
                ForEach($manualMilestones) { milestone in
                    let index = manualMilestones.firstIndex { $0.id == milestone.wrappedValue.id } ?? 0
                    manualMilestoneEditor(milestone: milestone, index: index)
                }
            }

            Button {
                addManualMilestone()
            } label: {
                Label(manualText("Добавить этап", "Add stage"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .disabled(manualMilestones.count >= 6)
            .buttonStyle(LippiButtonStyle(kind: .secondary))
            .opacity(manualMilestones.count >= 6 ? 0.55 : 1)
        }
        .padding(13)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: Color(hex: 0x64D2FF).opacity(0.055)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private func manualMilestoneEditor(milestone: Binding<ManualRoadmapMilestone>, index: Int) -> some View {
        let tone = manualMilestoneTone(index)
        let canDelete = manualMilestones.count > 1

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(tone.opacity(0.20), in: Circle())
                    .lippiSystemGlass(in: Circle(), tint: tone.opacity(0.08))
                    .overlay(Circle().stroke(tone.opacity(0.30), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(manualText("Этап \(index + 1)", "Stage \(index + 1)"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)

                    Text(manualText("Срок, цель этапа и конкретные шаги", "Timeframe, stage outcome, and concrete steps"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textTertiary)
                }

                Spacer(minLength: 8)

                if canDelete {
                    Button {
                        removeManualMilestone(id: milestone.wrappedValue.id)
                    } label: {
                        Image(safeSystemName: "trash.fill", fallback: "trash")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .ghost, compact: true))
                    .accessibilityLabel(manualText("Удалить этап", "Delete stage"))
                }
            }

            manualTextField(
                title: manualText("Название", "Title"),
                placeholder: manualText("Например: собрать первый прототип", "Example: assemble the first prototype"),
                icon: "text.cursor",
                text: milestone.title,
                tint: tone
            )

            HStack(spacing: 10) {
                manualTextField(
                    title: manualText("Срок", "Timeframe"),
                    placeholder: manualDefaultTimeframe(index: index),
                    icon: "calendar",
                    text: milestone.timeframe,
                    tint: tone
                )

                manualCategoryPicker(selection: milestone.category, tone: tone)
            }

            manualTextEditor(
                title: manualText("Результат этапа", "Stage result"),
                placeholder: manualText("Как понять, что этап завершен?", "How will you know the stage is done?"),
                icon: "target",
                text: milestone.target,
                minHeight: 66,
                tint: tone
            )

            manualTextEditor(
                title: manualText("Задачи этапа", "Stage tasks"),
                placeholder: manualText("По одной задаче на строку", "One task per line"),
                icon: "list.bullet.rectangle.fill",
                text: milestone.tasksText,
                minHeight: 88,
                tint: tone
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.glassFill(0.065))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tone.opacity(0.055)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            tint: tone.opacity(0.055)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private var manualSupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LippiSectionHeader(
                title: manualText("Поддержка", "Support"),
                subtitle: manualText("Ритм и защита от срывов", "Cadence and protection from drift"),
                icon: "shield.lefthalf.filled",
                accent: Color(hex: 0xBF5AF2)
            )

            manualTextEditor(
                title: manualText("Привычки", "Habits"),
                placeholder: manualText("Например: еженедельный обзор по воскресеньям", "Example: weekly review every Sunday"),
                icon: "repeat.circle.fill",
                text: $manualHabitText,
                minHeight: 70,
                tint: Color(hex: 0x30D158)
            )

            manualTextEditor(
                title: manualText("Риски и корректировки", "Risks and adjustments"),
                placeholder: manualText("Что может помешать и как план менять без паники?", "What can block progress, and how should the plan adapt?"),
                icon: "exclamationmark.triangle.fill",
                text: $manualRiskText,
                minHeight: 76,
                tint: Color(hex: 0xFF9F0A)
            )
        }
        .padding(13)
        .background(DS.glassFill(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: Color(hex: 0xBF5AF2).opacity(0.05)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private var manualPreviewFooter: some View {
        let activeStages = manualMilestones.filter { $0.hasContent }.count
        let taskCount = manualMilestones.reduce(0) { $0 + manualLines($1.tasksText, limit: 20).count }
        let firstActionCount = manualLines(manualFirstActionsText, limit: 8).count

        return HStack(spacing: 8) {
            manualMetricPill(value: "\(max(activeStages, 1))", title: manualText("этапа", "stages"), icon: "map.fill", tone: Color(hex: 0x64D2FF))
            manualMetricPill(value: "\(taskCount + firstActionCount)", title: manualText("шагов", "steps"), icon: "checklist.checked", tone: DS.accent)
            manualMetricPill(value: horizon.title(lang: lang), title: manualText("горизонт", "horizon"), icon: "calendar", tone: Color(hex: 0x30D158))
        }
    }

    private func manualMetricPill(value: String, title: String, icon: String, tone: Color) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tone)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .singleLine()
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DS.glassFill(0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: tone.opacity(0.06)
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
    }

    private func manualTextField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.70))
                .labelStyle(TightLabelStyle())
                .singleLine()

            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(1...2)
                .textFieldStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(DS.textPrimary)
                .submitLabel(.done)
                .goalGlassField(tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func manualTextEditor(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        minHeight: CGFloat,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.70))
                .labelStyle(TightLabelStyle())
                .singleLine()

            TextEditor(text: text)
                .frame(minHeight: minHeight, maxHeight: max(minHeight + 74, 140))
                .scrollContentBackground(.hidden)
                .font(.body.weight(.medium))
                .foregroundStyle(DS.textPrimary)
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .font(.body.weight(.medium))
                            .foregroundStyle(DS.textTertiary)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .goalGlassField(tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func manualCategoryPicker(selection: Binding<TaskCategory>, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(manualText("Категория", "Category"), systemImage: "square.grid.2x2.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.70))
                .labelStyle(TightLabelStyle())
                .singleLine()

            Picker(manualText("Категория", "Category"), selection: selection) {
                ForEach(TaskCategory.allCases) { category in
                    Label(category.title, systemImage: category.symbol).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(DS.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(DS.glassTint).opacity(0.28))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(tone.opacity(0.08)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 15, style: .continuous),
                tint: tone.opacity(0.08),
                interactive: true
            )
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var smartGoalChatCard: some View {
        let brief = currentBrief
        let questions = hasGoalInput
            ? GoalGuidanceQuestionBuilder.questions(for: currentInput, brief: brief, lang: brief.responseLanguage)
            : []
        let displayedGoal = hasGoalInput ? trimmedGoalText : (roadmap?.title ?? "")
        let hasDisplayedGoal = !displayedGoal.trimmed.isEmpty

        return GlassCard(
            padding: 0,
            cornerRadius: 30,
            style: .full,
            forceSystemGlass: !reduceTransparency
        ) {
            VStack(spacing: 0) {
                roadmapChatHeader(brief, showsCloseButton: false)

                VStack(alignment: .leading, spacing: 12) {
                    chatMessageBubble(
                        text: hasDisplayedGoal ? s("goals.chat.goal_received") : s("goals.chat.ask_goal"),
                        icon: "sparkles",
                        tone: DS.accent
                    )

                    if hasDisplayedGoal {
                        chatMessageBubble(
                            title: s("goals.chat.user_goal"),
                            text: displayedGoal,
                            icon: "flag.checkered",
                            tone: Color(hex: 0x30D158),
                            isUser: true
                        )
                    }

                    if hasGoalInput {
                        if !trimmedContextText.isEmpty {
                            chatMessageBubble(
                                title: s("goals.chat.user_context"),
                                text: trimmedContextText,
                                icon: "text.alignleft",
                                tone: Color(hex: 0x64D2FF),
                                isUser: true
                            )
                        }

                        chatPlanningControls(brief)

                        if roadmap == nil && !isGenerating {
                            chatMessageBubble(
                                text: trimmedContextText.isEmpty ? s("goals.chat.context_needed") : s("goals.chat.context_ready"),
                                icon: trimmedContextText.isEmpty ? "questionmark.bubble.fill" : "checkmark.seal.fill",
                                tone: trimmedContextText.isEmpty ? Color(hex: 0x64D2FF) : Color(hex: 0x30D158)
                            )

                            VStack(spacing: 9) {
                                ForEach(questions, id: \.self) { question in
                                    chatQuestionBubble(question)
                                }
                            }
                        }
                    }

                    if isGenerating {
                        chatProcessingPanel
                    } else {
                        if let generationIssue {
                            chatIssuePanel(generationIssue)
                        }

                        if let roadmap,
                           let audit = progressAudit(for: roadmap),
                           audit.shouldSuggestAdjustment {
                            chatAdaptationPanel(audit)
                        }

                        if roadmap != nil {
                            chatReadyPanel
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private func chatPlanningControls(_ brief: GoalRequestBrief) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(s("goals.chat.controls_title"), systemImage: "slider.horizontal.3")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.70))
                .labelStyle(TightLabelStyle())

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

            HStack(spacing: 8) {
                infoPill(title: L10n.fmt("goals.brief.language", lang, brief.responseLanguage.title), icon: "globe")
                infoPill(title: GoalRoadmapEngine.primaryAIPrivacyLabel(lang: lang), icon: "lock.shield.fill")
            }
        }
        .padding(12)
        .background(DS.glassFill(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: DS.accent.opacity(0.06)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.11), lineWidth: 1))
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

    private var roadmapChatOverlay: some View {
        let brief = currentBrief
        let questions = GoalGuidanceQuestionBuilder.questions(for: currentInput, brief: brief, lang: brief.responseLanguage)

        return ZStack {
            Rectangle()
                .fill(.black.opacity(reduceTransparency ? 0.30 : 0.14))
                .background(.ultraThinMaterial)
                .lippiSystemGlass(
                    in: Rectangle(),
                    tint: DS.accent.opacity(0.04),
                    forceSystemGlass: !reduceTransparency
                )
                .ignoresSafeArea()

            GlassCard(
                padding: 0,
                cornerRadius: 32,
                style: .full,
                forceSystemGlass: !reduceTransparency
            ) {
                VStack(spacing: 0) {
                    roadmapChatHeader(brief)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            chatMessageBubble(
                                text: s("goals.chat.assistant_start"),
                                icon: "sparkles",
                                tone: DS.accent
                            )

                            chatMessageBubble(
                                title: s("goals.chat.user_goal"),
                                text: trimmedGoalText,
                                icon: "flag.checkered",
                                tone: Color(hex: 0x30D158),
                                isUser: true
                            )

                            chatMessageBubble(
                                text: trimmedContextText.isEmpty ? s("goals.chat.context_needed") : s("goals.chat.context_ready"),
                                icon: trimmedContextText.isEmpty ? "questionmark.bubble.fill" : "checkmark.seal.fill",
                                tone: trimmedContextText.isEmpty ? Color(hex: 0x64D2FF) : Color(hex: 0x30D158)
                            )

                            if !isGenerating, roadmap == nil {
                                VStack(spacing: 9) {
                                    ForEach(questions, id: \.self) { question in
                                        chatQuestionBubble(question)
                                    }
                                }

                                chatContextComposer
                            }

                            if isGenerating {
                                chatProcessingPanel
                            } else {
                                if let generationIssue {
                                    chatIssuePanel(generationIssue)
                                }

                                if roadmap != nil {
                                    chatReadyPanel
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .frame(maxHeight: 460)
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .lippiScrollPerformance()

                    roadmapChatActionBar
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(s("goals.chat.title"))
        .accessibilityAddTraits(.isModal)
    }

    private func roadmapChatHeader(_ brief: GoalRequestBrief, showsCloseButton: Bool = true) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(DS.brandSoftGradient).opacity(0.42))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.18), lineWidth: 1))

                Image(safeSystemName: "bubble.left.and.text.bubble.right.fill", fallback: "sparkles")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
            }
            .frame(width: 46, height: 46)
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: DS.accent.opacity(0.12)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(s("goals.chat.title"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                HStack(spacing: 6) {
                    infoPill(title: brief.responseLanguage.title, icon: "globe")
                    infoPill(title: horizon.title(lang: lang), icon: "calendar")
                }
            }

            Spacer(minLength: 8)

            if showsCloseButton && !isGenerating {
                Button {
                    dismiss()
                } label: {
                    Image(safeSystemName: "xmark", fallback: "xmark")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(LippiButtonStyle(kind: .ghost, compact: true))
                .accessibilityLabel(s("common.close"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func chatMessageBubble(
        title: String? = nil,
        text: String,
        icon: String,
        tone: Color,
        isUser: Bool = false
    ) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 34) }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(safeSystemName: icon, fallback: "sparkles")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(tone)

                    Text(title ?? (isUser ? s("goals.chat.user") : "Lippi"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.text(0.70))
                        .singleLine()
                }

                Text(text)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.text(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(isUser ? 0.12 : 0.075))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tone.opacity(isUser ? 0.11 : 0.07)))
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: tone.opacity(0.07)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))

            if !isUser { Spacer(minLength: 34) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func chatQuestionBubble(_ question: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "questionmark.circle.fill", fallback: "questionmark.circle.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x64D2FF))
                .frame(width: 22)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 8) {
                Text(question)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.text(0.86))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    appendGuidanceQuestion(question)
                } label: {
                    Label(s("goals.guidance.add"), systemImage: "plus.circle.fill")
                        .font(.caption.weight(.bold))
                        .labelStyle(TightLabelStyle())
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
            }
        }
        .padding(12)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: Color(hex: 0x64D2FF).opacity(0.07)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private var chatContextComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(s("goals.chat.context_title"), systemImage: "text.alignleft")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.text(0.70))
                .labelStyle(TightLabelStyle())

            TextEditor(text: $contextText)
                .frame(minHeight: 78, maxHeight: 118)
                .scrollContentBackground(.hidden)
                .font(.callout)
                .foregroundStyle(DS.textPrimary)
                .overlay(alignment: .topLeading) {
                    if contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(s("goals.chat.context_placeholder"))
                            .font(.callout)
                            .foregroundStyle(DS.textTertiary)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .goalGlassField(tint: Color(hex: 0x64D2FF))
        }
    }

    private var chatProcessingPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(DS.brandSoftGradient).opacity(0.18))
                .overlay(
                    LippiLiquidSheen(
                        cornerRadius: 22,
                        duration: 3.4,
                        intensity: 0.84
                    )
                )

            VStack(spacing: 14) {
                processingEmblem.scaleEffect(0.78)
                    .lippiFloating(active: isGenerating, amplitude: 1.6, duration: 2.4)

                VStack(spacing: 4) {
                    Text(s("goals.processing.title"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DS.textPrimary)

                    Text(s("goals.processing.subtitle"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                }

                TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 12.0 : 1.0 / 30.0)) { timeline in
                    let activeStep = Int(timeline.date.timeIntervalSinceReferenceDate / 1.15) % processingSteps.count

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(processingSteps.enumerated()), id: \.offset) { index, step in
                            processingStepRow(step, isActive: index == activeStep, isComplete: index < activeStep)
                        }
                    }
                }
            }
            .padding(16)
        }
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: DS.accent.opacity(0.08),
            forceSystemGlass: !reduceTransparency
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.glassStroke(0.13), lineWidth: 1))
        .lippiMagicAppear(delay: 0.02, y: 10, scale: 0.975)
    }

    private var chatReadyPanel: some View {
        chatMessageBubble(
            text: s("goals.chat.ready"),
            icon: "checkmark.seal.fill",
            tone: Color(hex: 0x30D158)
        )
    }

    private func chatAdaptationPanel(_ audit: GoalPlanProgressAudit) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            chatMessageBubble(
                text: audit.chatSummary(lang: lang),
                icon: "arrow.triangle.2.circlepath.circle.fill",
                tone: Color(hex: 0xFF9F0A)
            )

            Button {
                Task { await generateRoadmap(adaptingToProgress: true) }
            } label: {
                Label(s("goals.adapt.chat_action"), systemImage: "wand.and.stars")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canGenerate)
            .buttonStyle(LippiButtonStyle(kind: .secondary))
        }
        .lippiMagicAppear(delay: 0.04, y: 8, scale: 0.98)
    }

    private func chatIssuePanel(_ message: String) -> some View {
        chatMessageBubble(
            text: message,
            icon: "exclamationmark.triangle.fill",
            tone: Color(hex: 0xFF9F0A)
        )
    }

    private var roadmapChatActionBar: some View {
        VStack(spacing: 9) {
            if isGenerating {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DS.accent)

                    Text(s("goals.chat.building"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(DS.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if roadmap != nil {
                Button {
                    dismiss()
                } label: {
                    Label(s("goals.chat.show_roadmap"), systemImage: "map.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))
            } else {
                Button {
                    Task { await generateRoadmap() }
                } label: {
                    Label(s("goals.chat.start_build"), systemImage: "sparkles")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canGenerate)
                .buttonStyle(LippiButtonStyle(kind: .primary))

                if generationIssue != nil {
                    Button {
                        createDraftRoadmap()
                    } label: {
                        Label(s("goals.action.draft"), systemImage: "doc.text.magnifyingglass")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isDrafting)
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(DS.glassFill(0.055))
    }

    private var processingEmblem: some View {
        TimelineView(.animation(minimumInterval: DS.animationFrameInterval(active: isGenerating, reduceMotion: reduceMotion))) { timeline in
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

    private func roadmapChatIntroCard(_ brief: GoalRequestBrief) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.chat.intro_title"),
                    subtitle: s("goals.chat.intro_subtitle"),
                    icon: "bubble.left.and.text.bubble.right.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                HStack(spacing: 8) {
                    infoPill(title: L10n.fmt("goals.brief.language", lang, brief.responseLanguage.title), icon: "globe")
                    infoPill(title: horizon.title(lang: lang), icon: "calendar")
                    infoPill(title: intensity.title(lang: lang), icon: "dial.medium")
                }

                Button {
                    openRoadmapChat()
                } label: {
                    Label(s("goals.chat.open"), systemImage: "sparkles")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }

    private func requestBriefCard(_ brief: GoalRequestBrief) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.brief.title"),
                    subtitle: L10n.fmt("goals.brief.subtitle", lang, brief.responseLanguage.title),
                    icon: "text.magnifyingglass",
                    accent: Color(hex: 0x64D2FF)
                )

                HStack(spacing: 8) {
                    infoPill(title: L10n.fmt("goals.brief.language", lang, brief.responseLanguage.title), icon: "globe")
                    infoPill(title: horizon.title(lang: lang), icon: "calendar")
                    infoPill(title: intensity.title(lang: lang), icon: "dial.medium")
                }

                VStack(spacing: 10) {
                    briefBlock(
                        title: s("goals.brief.objective"),
                        icon: "flag.checkered",
                        tone: DS.accent,
                        items: [brief.objective]
                    )

                    if !brief.quantitiesAndDates.isEmpty {
                        briefBlock(
                            title: s("goals.brief.numbers"),
                            icon: "number.circle.fill",
                            tone: Color(hex: 0xFF9F0A),
                            items: brief.quantitiesAndDates
                        )
                    }

                    if !brief.constraints.isEmpty {
                        briefBlock(
                            title: s("goals.brief.constraints"),
                            icon: "slider.horizontal.3",
                            tone: Color(hex: 0xBF5AF2),
                            items: brief.constraints
                        )
                    }

                    if !brief.contextFacts.isEmpty {
                        briefBlock(
                            title: s("goals.brief.context"),
                            icon: "list.bullet.rectangle.fill",
                            tone: Color(hex: 0x30D158),
                            items: brief.contextFacts
                        )
                    }

                    if !brief.missingContextHints.isEmpty {
                        briefBlock(
                            title: s("goals.brief.missing"),
                            icon: "questionmark.circle.fill",
                            tone: Color(hex: 0x64D2FF),
                            items: brief.missingContextHints,
                            itemIcon: "questionmark.circle.fill"
                        )
                    }
                }
            }
        }
    }

    private func guidanceQuestionsCard(_ brief: GoalRequestBrief) -> some View {
        let questions = GoalGuidanceQuestionBuilder.questions(for: currentInput, brief: brief, lang: brief.responseLanguage)

        return GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.guidance.title"),
                    subtitle: s("goals.guidance.subtitle"),
                    icon: "bubble.left.and.text.bubble.right.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                VStack(spacing: 10) {
                    ForEach(questions, id: \.self) { question in
                        guidanceQuestionRow(question)
                    }
                }
            }
        }
    }

    private func guidanceQuestionRow(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            readableItemRow(
                question,
                icon: "questionmark.circle.fill",
                tone: Color(hex: 0x64D2FF),
                textColor: DS.text(0.84)
            )

            Button {
                appendGuidanceQuestion(question)
            } label: {
                Label(s("goals.guidance.add"), systemImage: "plus.circle.fill")
                    .font(.caption.weight(.bold))
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x64D2FF).opacity(0.07)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: Color(hex: 0x64D2FF).opacity(0.07),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func briefBlock(
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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items.prefix(3), id: \.self) { item in
                    readableItemRow(item, icon: itemIcon, tone: tone, textColor: DS.text(0.82))
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
                Text(roadmap.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(roadmap.summary)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 8) {
                    confidenceBadge(roadmap.confidence)
                    infoPill(title: roadmap.source.title(lang: lang), icon: roadmap.source.icon)
                    infoPill(title: horizon.title(lang: lang), icon: "calendar")
                    infoPill(title: intensity.title(lang: lang), icon: "dial.medium")
                }
            }
        }
    }

    private func adaptationCard(_ audit: GoalPlanProgressAudit) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("goals.adapt.title"),
                    subtitle: L10n.fmt("goals.adapt.subtitle", lang, audit.overdueTasks, audit.activeTasks, audit.completedTasks),
                    icon: "slider.horizontal.3",
                    accent: Color(hex: 0xFF9F0A)
                )

                HStack(spacing: 8) {
                    adaptationMetric(value: audit.overdueTasks, title: s("goals.adapt.metric.overdue"), tone: Color(hex: 0xFF453A))
                    adaptationMetric(value: audit.activeTasks, title: s("goals.adapt.metric.active"), tone: DS.accent)
                    adaptationMetric(value: audit.completedTasks, title: s("goals.adapt.metric.done"), tone: Color(hex: 0x30D158))
                }

                if !audit.missedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(s("goals.adapt.missed_title"), systemImage: "clock.badge.exclamationmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DS.text(0.76))
                            .labelStyle(TightLabelStyle())

                        ForEach(audit.missedTasks.prefixArray(3), id: \.self) { task in
                            missedTaskRow(task)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(audit.suggestions(lang: lang), id: \.self) { suggestion in
                        readableItemRow(
                            suggestion,
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            tone: Color(hex: 0xFF9F0A),
                            textColor: DS.text(0.82)
                        )
                    }
                }

                Button {
                    Task { await generateRoadmap(adaptingToProgress: true) }
                } label: {
                    Label(s("goals.adapt.action"), systemImage: "wand.and.stars")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canGenerate)
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }

    private func missedTaskRow(_ task: GoalMissedTask) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: task.category.symbol, fallback: "clock")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0xFF9F0A))
                .frame(width: 28, height: 28)
                .background(Color(hex: 0xFF9F0A).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    tint: Color(hex: 0xFF9F0A).opacity(0.08)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(task.statusText(lang: lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: Color(hex: 0xFF9F0A).opacity(0.06)
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    private func adaptationMetric(value: Int, title: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tone.opacity(0.08)))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: tone.opacity(0.07)
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
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
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Image(safeSystemName: "arrow.up.right", fallback: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DS.textTertiary)
                }

                Text(source.excerpt)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

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
                        .font(.callout.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(milestone.target)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        infoPill(title: milestone.timeframe, icon: "clock")
                        infoPill(title: milestone.category.title, icon: milestone.category.symbol)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 9) {
                ForEach(milestone.tasks, id: \.self) { task in
                    readableItemRow(
                        task,
                        icon: "checkmark.circle.fill",
                        tone: tone,
                        textColor: DS.text(0.80)
                    )
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
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                    .lineSpacing(3)
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

            VStack(alignment: .leading, spacing: 9) {
                ForEach(items.prefix(4), id: \.self) { item in
                    readableItemRow(item, icon: itemIcon, tone: tone, textColor: DS.text(0.80))
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

    private func readableItemRow(
        _ text: String,
        icon: String,
        tone: Color,
        textColor: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .frame(width: 16)
                .padding(.top, 3)

            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(textColor)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        return HStack(spacing: 5) {
            Text("\(value)%")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.textPrimary)
                .monospacedDigit()
            Text(s("goals.confidence"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .singleLine()
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(DS.glassFill(0.09), in: Capsule())
        .lippiSystemGlass(
            in: Capsule(),
            tint: DS.accent.opacity(0.08)
        )
        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
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

            if roadmap != nil {
                Button {
                    resetGoalChat()
                } label: {
                    Label(s("goals.chat.new_goal"), systemImage: "plus.bubble.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            } else if plannerMode == .manual {
                Button {
                    createManualRoadmap()
                } label: {
                    Label(manualText("Собрать дорожную карту", "Create roadmap"), systemImage: "checkmark.seal.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canCreateManualRoadmap)
                .buttonStyle(LippiButtonStyle(kind: .primary))
                .opacity(canCreateManualRoadmap ? 1 : 0.55)

                HStack(spacing: 10) {
                    Button {
                        addManualMilestone()
                    } label: {
                        Label(manualText("Этап", "Stage"), systemImage: "plus.circle.fill")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(manualMilestones.count >= 6)
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))

                    Button {
                        resetManualPlanner()
                    } label: {
                        Label(manualText("Очистить", "Clear"), systemImage: "eraser.fill")
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            } else {
                chatComposerField

                if hasGoalInput {
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
                            Text(isGenerating ? s("goals.action.generating") : s("goals.chat.start_build"))
                                .singleLine()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canGenerate)
                    .buttonStyle(LippiButtonStyle(kind: .primary))
                    .opacity(canGenerate ? 1 : 0.55)

                    if generationIssue != nil {
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
                }
            }
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

    private var chatComposerField: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(chatComposerPlaceholder, text: $chatDraftText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(DS.textPrimary)
                .submitLabel(.send)
                .onSubmit(sendChatDraft)

            Button {
                sendChatDraft()
            } label: {
                Image(safeSystemName: "arrow.up.circle.fill", fallback: "paperplane.fill")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(canSendChatDraft ? DS.accent : DS.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSendChatDraft)
            .accessibilityLabel(s("goals.chat.send"))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.glassFill(0.09))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DS.glassTint).opacity(0.20))
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            tint: DS.accent.opacity(0.06),
            interactive: true
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private var chatComposerPlaceholder: String {
        let textLang = hasGoalInput ? currentBrief.responseLanguage : lang
        return L10n.tr(hasGoalInput ? "goals.chat.reply_placeholder" : "goals.chat.goal_placeholder", textLang)
    }

    private var canSendChatDraft: Bool {
        !chatDraftText.trimmed.isEmpty && !isGenerating && roadmap == nil
    }

    private func sendChatDraft() {
        let value = chatDraftText.trimmed
        guard !value.isEmpty, !isGenerating, roadmap == nil else { return }

        if hasGoalInput {
            contextText = trimmedContextText.isEmpty ? value : "\(trimmedContextText)\n\(value)"
        } else {
            goalText = value
            generationIssue = nil
        }
        chatDraftText = ""

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func createManualRoadmap() {
        guard canCreateManualRoadmap else { return }

        let title = trimmedManualTitle
        let summary = manualSummary.trimmed.nonEmpty(
            or: manualText(
                "План собран вручную: цель разбита на этапы, критерии и ближайшие действия.",
                "Manually built plan: the goal is split into stages, criteria, and immediate actions."
            )
        )
        let userMilestones = manualMilestones.enumerated().compactMap { index, milestone in
            manualGoalMilestone(from: milestone, index: index, title: title)
        }
        let milestones = userMilestones.ifEmpty(manualFallbackMilestones(title: title))
        let firstActions = manualLines(manualFirstActionsText, limit: 5)
            .ifEmpty(milestones.flatMap(\.tasks).prefixArray(4))
            .ifEmpty(manualDefaultTasks(for: 0, goal: title))
        let criteria = manualLines(manualSuccessText, limit: 5)
            .ifEmpty([
                manualText("Понятно, какой результат должен быть достигнут.", "The desired result is clear."),
                manualText("Дорожная карта разбита на конкретные этапы.", "The roadmap is split into concrete stages."),
                manualText("Первые действия можно выполнить в ближайшие 24-48 часов.", "The first actions can be completed within 24-48 hours.")
            ])
        let habits = manualLines(manualHabitText, limit: 4).map { line in
            GoalHabit(
                title: line,
                detail: manualText("Поддерживай этот ритм и проверяй прогресс на обзоре.", "Keep this cadence and review progress regularly.")
            )
        }.ifEmpty([
            GoalHabit(
                title: manualText("Еженедельный обзор", "Weekly review"),
                detail: manualText("Раз в неделю отмечай выполненное, переносы и следующий самый важный шаг.", "Once a week, review completed work, postponed items, and the next most important step.")
            )
        ])
        let risks = manualLines(manualRiskText, limit: 4).map { line in
            GoalRisk(
                title: line,
                mitigation: manualText("Если риск проявился, уменьши объем ближайшего этапа и оставь только ключевой шаг.", "If this risk appears, reduce the next stage and keep only the key action.")
            )
        }.ifEmpty([
            GoalRisk(
                title: manualText("Слишком большой объем", "Scope too large"),
                mitigation: manualText("Сократи этап до одного результата, который можно проверить за неделю.", "Reduce the stage to one result that can be checked within a week.")
            )
        ])

        let result = GoalRoadmap(
            title: title,
            summary: summary,
            source: .localPlanner,
            confidence: 1.0,
            successCriteria: criteria,
            firstActions: firstActions,
            assumptions: [
                manualText("Дорожная карта составлена вручную пользователем.", "The roadmap was built manually by the user."),
                manualText("Сроки можно корректировать по мере выполнения задач.", "Timeframes can be adjusted as tasks are completed.")
            ],
            clarifyingQuestions: nil,
            evidence: nil,
            milestones: milestones,
            habits: habits,
            risks: risks
        )

        goalText = title
        contextText = manualSummary.trimmed
        generationIssue = nil
        addedTasks = false

        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            roadmap = result
        }
        saveRoadmap(result)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func manualGoalMilestone(from milestone: ManualRoadmapMilestone, index: Int, title: String) -> GoalMilestone? {
        guard milestone.hasContent else { return nil }
        let tasks = manualLines(milestone.tasksText, limit: 8)
            .ifEmpty(manualDefaultTasks(for: index, goal: title))

        return GoalMilestone(
            title: milestone.title.trimmed.nonEmpty(or: manualText("Этап \(index + 1)", "Stage \(index + 1)")),
            timeframe: milestone.timeframe.trimmed.nonEmpty(or: manualDefaultTimeframe(index: index)),
            target: milestone.target.trimmed.nonEmpty(
                or: manualText(
                    "Промежуточный результат для цели: \(title)",
                    "Intermediate result for the goal: \(title)"
                )
            ),
            tasks: tasks,
            category: milestone.category
        )
    }

    private func manualFallbackMilestones(title: String) -> [GoalMilestone] {
        let categories: [TaskCategory] = [.other, .work, .health]
        return (0..<3).map { index in
            GoalMilestone(
                title: manualFallbackMilestoneTitle(index: index),
                timeframe: manualDefaultTimeframe(index: index),
                target: manualFallbackMilestoneTarget(index: index, title: title),
                tasks: manualDefaultTasks(for: index, goal: title),
                category: categories[safe: index] ?? .other
            )
        }
    }

    private func manualFallbackMilestoneTitle(index: Int) -> String {
        let ru = ["Уточнить маршрут", "Собрать рабочий прогресс", "Закрепить результат"]
        let en = ["Clarify the route", "Build working progress", "Lock in the result"]
        return (lang == .ru ? ru : en)[safe: index] ?? manualText("Этап \(index + 1)", "Stage \(index + 1)")
    }

    private func manualFallbackMilestoneTarget(index: Int, title: String) -> String {
        let ru = [
            "Понятна текущая точка, критерии успеха и ближайший шаг для цели: \(title).",
            "Есть заметный практический прогресс, который можно проверить и улучшить.",
            "Результат доведен до устойчивого ритма и понятного следующего уровня."
        ]
        let en = [
            "Current state, success criteria, and the next action are clear for: \(title).",
            "There is visible practical progress that can be tested and improved.",
            "The result is stabilized into a sustainable rhythm and a clear next level."
        ]
        return (lang == .ru ? ru : en)[safe: index] ?? title
    }

    private func manualDefaultTasks(for index: Int, goal: String) -> [String] {
        let ru = [
            [
                "Записать текущую точку по цели: \(goal)",
                "Выбрать 1-2 измеримых критерия успеха",
                "Назначить первый маленький шаг на ближайшие 24 часа"
            ],
            [
                "Сделать первый рабочий результат",
                "Проверить, что мешает двигаться быстрее",
                "Обновить план с учетом фактов"
            ],
            [
                "Закрыть ключевые незавершенные действия",
                "Собрать короткий обзор прогресса",
                "Назначить следующий уровень после завершения этапа"
            ]
        ]
        let en = [
            [
                "Write down the current state for: \(goal)",
                "Choose 1-2 measurable success criteria",
                "Schedule one small action for the next 24 hours"
            ],
            [
                "Create the first working result",
                "Check what slows progress down",
                "Update the plan using real feedback"
            ],
            [
                "Close the key unfinished actions",
                "Make a short progress review",
                "Define the next level after this stage"
            ]
        ]
        return (lang == .ru ? ru : en)[safe: min(index, 2)] ?? []
    }

    private func manualLines(_ text: String, limit: Int) -> [String] {
        text
            .replacingOccurrences(of: "•", with: "\n")
            .replacingOccurrences(of: "·", with: "\n")
            .components(separatedBy: CharacterSet(charactersIn: "\n;"))
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–—"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .prefixArray(limit)
    }

    private func manualDefaultTimeframe(index: Int) -> String {
        let total = max(manualMilestones.count, 1)
        let start = max(1, index * horizon.weeks / total + 1)
        let end = max(start, (index + 1) * horizon.weeks / total)
        return start == end
            ? manualText("Неделя \(start)", "Week \(start)")
            : manualText("Недели \(start)-\(end)", "Weeks \(start)-\(end)")
    }

    private func addManualMilestone() {
        guard manualMilestones.count < 6 else { return }
        let nextIndex = manualMilestones.count
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            manualMilestones.append(
                ManualRoadmapMilestone(
                    category: TaskCategory.allCases[safe: nextIndex % TaskCategory.allCases.count] ?? .other
                )
            )
        }

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func removeManualMilestone(id: UUID) {
        guard manualMilestones.count > 1 else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            manualMilestones.removeAll { $0.id == id }
        }

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func resetManualPlanner() {
        manualTitle = ""
        manualSummary = ""
        manualSuccessText = ""
        manualFirstActionsText = ""
        manualHabitText = ""
        manualRiskText = ""
        manualMilestones = ManualRoadmapMilestone.starter

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func manualMilestoneTone(_ index: Int) -> Color {
        [DS.accent, Color(hex: 0x64D2FF), Color(hex: 0x30D158), Color(hex: 0xBF5AF2), Color(hex: 0xFF9F0A), Color(hex: 0xFF375F)][safe: index] ?? DS.accent
    }

    private func resetGoalChat() {
        goalText = ""
        contextText = ""
        chatDraftText = ""
        roadmap = nil
        generationIssue = nil
        addedTasks = false
        savedRoadmap = ""
        resetManualPlanner()
    }

    @MainActor
    private func generateRoadmap(adaptingToProgress: Bool = false) async {
        guard canGenerate else { return }
        isGenerating = true
        addedTasks = false
        generationIssue = nil
        defer { isGenerating = false }
        let currentAudit = roadmap.flatMap { progressAudit(for: $0) }
        let auditForModel = adaptingToProgress ? currentAudit : currentAudit?.forAutomaticReplan

        let input = currentInput

        await startRoadmapLiveActivity(for: input.goal)

        do {
            let result = try await engine.buildAIRoadmap(input: input, lang: lang, progressAudit: auditForModel) { stage in
                await updateRoadmapLiveActivity(stage)
            }
            roadmap = result
            generationIssue = nil
            saveRoadmap(result)
            await finishRoadmapLiveActivity(.ready)

            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } catch let error as GoalPlannerEngineError {
            handleGenerationFailure(error, input: input, progressAudit: auditForModel)
            await finishRoadmapLiveActivity(error.shouldBuildDraftFallback ? .draftReady : .failed)
        } catch {
            handleGenerationFailure(.generationFailed(error.localizedDescription), input: input, progressAudit: auditForModel)
            await finishRoadmapLiveActivity(.draftReady)
        }
    }

    private func startRoadmapLiveActivity(for goalTitle: String) async {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            await GoalRoadmapLiveActivityManager.start(goalTitle: goalTitle, lang: lang)
        }
        #endif
    }

    private func updateRoadmapLiveActivity(_ stage: GoalRoadmapActivityStage) async {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            await GoalRoadmapLiveActivityManager.update(stage, lang: lang)
        }
        #endif
    }

    private func finishRoadmapLiveActivity(_ outcome: GoalRoadmapActivityOutcome) async {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            await GoalRoadmapLiveActivityManager.finish(outcome, lang: lang)
        }
        #endif
    }

    @MainActor
    private func handleGenerationFailure(_ error: GoalPlannerEngineError, input: GoalPlannerInput, progressAudit: GoalPlanProgressAudit?) {
        generationIssue = error.message(lang: lang)

        if error.shouldBuildDraftFallback {
            let draft = engine.buildDraftRoadmap(input: input, lang: lang, progressAudit: progressAudit)
            roadmap = draft
            saveRoadmap(draft)
        } else {
            roadmap = nil
        }

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    private func openRoadmapChat() {
        guard hasGoalInput else { return }

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func createDraftRoadmap() {
        guard canGenerate || hasGoalInput else { return }
        isDrafting = true
        defer { isDrafting = false }

        let input = currentInput

        let result = engine.buildDraftRoadmap(input: input, lang: lang, progressAudit: roadmap.flatMap { progressAudit(for: $0) })
        roadmap = result
        generationIssue = nil
        saveRoadmap(result)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func appendGuidanceQuestion(_ question: String) {
        guard !contextText.localizedCaseInsensitiveContains(question) else { return }
        let prefix = contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        contextText += prefix + L10n.fmt("goals.guidance.context_line", currentBrief.responseLanguage, question)

        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
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

    private func progressAudit(for roadmap: GoalRoadmap) -> GoalPlanProgressAudit? {
        GoalPlanProgressAudit.make(roadmap: roadmap, tasks: store.tasks)
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

enum GoalPlannerMode: String, CaseIterable, Identifiable {
    case assistant
    case manual

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .assistant: return "sparkles"
        case .manual: return "hand.draw.fill"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .assistant:
            return lang == .ru ? "С ИИ" : "AI"
        case .manual:
            return lang == .ru ? "Вручную" : "Manual"
        }
    }

    func subtitle(lang: AppLang) -> String {
        switch self {
        case .assistant:
            return lang == .ru ? "чат и модель" : "chat and model"
        case .manual:
            return lang == .ru ? "свой маршрут" : "your own route"
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

    func responseLanguage(fallback: AppLang) -> AppLang {
        GoalRequestLanguageDetector.detect(goal: goal, context: context, fallback: fallback)
    }
}

struct GoalRequestBrief: Codable, Hashable {
    var responseLanguage: AppLang
    var objective: String
    var contextFacts: [String]
    var constraints: [String]
    var quantitiesAndDates: [String]
    var missingContextHints: [String]

    static func make(input: GoalPlannerInput, fallbackLang: AppLang) -> GoalRequestBrief {
        let responseLanguage = input.responseLanguage(fallback: fallbackLang)
        let objective = input.goal.trimmed.nonEmpty(or: L10n.tr("goals.brief.empty_goal", responseLanguage))
        let contextSentences = splitMeaningfulLines(input.context)
        let quantities = extractQuantities(from: "\(input.goal) \(input.context)")
        let constraints = contextSentences.filter(isConstraintLine).prefixArray(3)
        let facts = contextSentences
            .filter { line in !constraints.contains(line) }
            .prefixArray(3)
        var missing: [String] = []

        if input.context.trimmed.isEmpty {
            missing.append(L10n.tr("goals.brief.missing.context", responseLanguage))
        }
        if quantities.isEmpty {
            missing.append(L10n.tr("goals.brief.missing.metric", responseLanguage))
        }
        if !input.goal.localizedCaseInsensitiveContains("за ")
            && !input.goal.localizedCaseInsensitiveContains("by ")
            && !input.goal.localizedCaseInsensitiveContains("in ")
            && quantities.filter({ containsTimeWord($0) }).isEmpty {
            missing.append(L10n.tr("goals.brief.missing.deadline", responseLanguage))
        }

        return GoalRequestBrief(
            responseLanguage: responseLanguage,
            objective: objective,
            contextFacts: facts,
            constraints: constraints,
            quantitiesAndDates: quantities.prefixArray(4),
            missingContextHints: missing.prefixArray(3)
        )
    }

    var outputLanguageName: String { responseLanguage.aiOutputLanguage }

    func promptSection() -> String {
        """
        Structured user request:
        - response language: \(outputLanguageName)
        - objective: \(objective)
        - known context facts: \(contextFacts.ifEmpty(["none"]).joined(separator: "; "))
        - constraints and preferences: \(constraints.ifEmpty(["none"]).joined(separator: "; "))
        - numbers, dates, or time limits: \(quantitiesAndDates.ifEmpty(["none"]).joined(separator: "; "))
        - missing context to handle as assumptions/questions: \(missingContextHints.ifEmpty(["none"]).joined(separator: "; "))
        """
    }

    private static func splitMeaningfulLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\n", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".;!?"))
            .map { $0.trimmed }
            .filter { $0.count > 2 }
    }

    private static func isConstraintLine(_ line: String) -> Bool {
        let normalized = line.lowercased()
        return normalized.containsAny([
            "огранич", "без ", "нельзя", "могу", "только", "не хочу", "спокой", "перегруз",
            "constraint", "limit", "only", "without", "can't", "cannot", "calm", "budget",
            "einschr", "nur", "ohne", "begrenz", "solo",
            "limit", "solo", "sin ", "solo ", "presupuesto"
        ])
    }

    private static func extractQuantities(from text: String) -> [String] {
        let pattern = #"(?iu)(?:\d+[,.]?\d*\s*)?(?:кг|килограмм(?:а|ов)?|месяц(?:а|ев)?|недел(?:я|и|ь)|дн(?:я|ей)?|час(?:а|ов)?|минут(?:а|ы)?|руб(?:лей)?|\$|%|kg|kilo(?:gram)?s?|month(?:s)?|week(?:s)?|day(?:s)?|hour(?:s)?|minute(?:s)?|eur|usd|дедлайн|deadline|mvp|a1|a2|b1|b2|c1|c2)|\d+[,.]?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let value = String(text[range]).trimmed
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { return nil }
            return value
        }
    }

    private static func containsTimeWord(_ text: String) -> Bool {
        text.lowercased().containsAny(["меся", "недел", "дн", "час", "минут", "month", "week", "day", "hour", "minute"])
    }
}

enum GoalGuidanceQuestionBuilder {
    static func questions(for input: GoalPlannerInput, brief: GoalRequestBrief, lang: AppLang) -> [String] {
        var candidates: [String] = []
        let fullText = "\(input.goal) \(input.context)"

        if input.context.trimmed.isEmpty {
            candidates.append(L10n.tr("goals.guidance.question.current_state", lang))
            candidates.append(L10n.tr("goals.guidance.question.weekly_capacity", lang))
        }

        if brief.quantitiesAndDates.isEmpty {
            candidates.append(L10n.tr("goals.guidance.question.metric", lang))
        }

        if !hasTimeSignal(fullText) {
            candidates.append(L10n.tr("goals.guidance.question.deadline", lang))
        }

        if brief.constraints.isEmpty {
            candidates.append(L10n.tr("goals.guidance.question.constraints", lang))
        }

        candidates.append(contentsOf: [
            L10n.tr("goals.guidance.question.blockers", lang),
            L10n.tr("goals.guidance.question.first_checkpoint", lang),
            L10n.tr("goals.guidance.question.support_cadence", lang)
        ])

        return unique(candidates).prefixArray(3)
    }

    static func ensuringUsefulQuestions(
        _ questions: [String],
        input: GoalPlannerInput,
        lang: AppLang,
        limit: Int = 3
    ) -> [String] {
        let brief = GoalRequestBrief.make(input: input, fallbackLang: lang)
        let fallback = self.questions(for: input, brief: brief, lang: lang)
        return unique(questions + fallback).prefixArray(limit)
    }

    private static func unique(_ questions: [String]) -> [String] {
        var seen = Set<String>()
        return questions.compactMap { question in
            let value = question.trimmed
            let key = value
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
            guard !value.isEmpty, seen.insert(key).inserted else { return nil }
            return value
        }
    }

    private static func hasTimeSignal(_ text: String) -> Bool {
        text.lowercased().containsAny([
            "сегодня", "завтра", "дедлайн", "срок", "месяц", "недел", "день", "дня", "дней", "час",
            "today", "tomorrow", "deadline", "month", "week", "day", "hour",
            "heute", "morgen", "frist", "monat", "woche", "tag", "stunde",
            "hoy", "manana", "fecha", "mes", "semana", "dia", "hora"
        ])
    }
}

enum GoalRequestLanguageDetector {
    static func detect(goal: String, context: String, fallback: AppLang) -> AppLang {
        let text = "\(goal) \(context)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return fallback }

        if text.unicodeScalars.contains(where: { (0x0400...0x04FF).contains(Int($0.value)) }) {
            return .ru
        }

        let lower = text.lowercased()
        let spanishSignals = ["ñ", "¿", "¡", "para ", "quiero ", "necesito ", "meses", "semanas", "objetivo"]
        if spanishSignals.contains(where: { lower.contains($0) }) { return .es }

        let germanSignals = ["ä", "ö", "ü", "ß", "ich ", "möchte", "wochen", "monate", "ziel", "lernen"]
        if germanSignals.contains(where: { lower.contains($0) }) { return .de }

        if lower.range(of: #"[a-z]"#, options: .regularExpression) != nil {
            return .en
        }

        return fallback
    }
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

struct ManualRoadmapMilestone: Identifiable, Hashable {
    var id = UUID()
    var title: String = ""
    var timeframe: String = ""
    var target: String = ""
    var tasksText: String = ""
    var category: TaskCategory = .other

    var hasContent: Bool {
        !title.trimmed.isEmpty
            || !timeframe.trimmed.isEmpty
            || !target.trimmed.isEmpty
            || !tasksText.trimmed.isEmpty
    }

    static var starter: [ManualRoadmapMilestone] {
        [
            ManualRoadmapMilestone(category: .other),
            ManualRoadmapMilestone(category: .work),
            ManualRoadmapMilestone(category: .health)
        ]
    }
}

struct GoalMissedTask: Codable, Hashable {
    var title: String
    var dueDate: Date
    var daysOverdue: Int
    var createdAgeDays: Int
    var category: TaskCategory

    func statusText(lang: AppLang) -> String {
        let due = dueDate.formatted(.dateTime.locale(Locale(identifier: lang.localeIdentifier)).day().month(.abbreviated).hour().minute())
        let days = max(0, daysOverdue)
        return L10n.fmt("goals.adapt.missed_status", lang, due, days)
    }

    func promptLine(lang: AppLang) -> String {
        let due = dueDate.formatted(.dateTime.locale(Locale(identifier: lang.localeIdentifier)).year().month().day().hour().minute())
        return "\(title) | due: \(due) | overdue days: \(max(0, daysOverdue)) | task age days: \(max(0, createdAgeDays)) | category: \(category.rawValue)"
    }
}

struct GoalPlanProgressAudit: Codable, Hashable {
    var trackedTasks: Int
    var completedTasks: Int
    var activeTasks: Int
    var overdueTasks: Int
    var daysSinceRoadmapCreated: Int
    var oldestActiveTaskAgeDays: Int
    var overdueExamples: [String]
    var missedTasks: [GoalMissedTask]
    var nextActiveTask: String?

    var completionRate: Double {
        guard trackedTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(trackedTasks)
    }

    var isStalledWithoutFirstWin: Bool {
        completedTasks == 0 && activeTasks > 0 && oldestActiveTaskAgeDays >= 2
    }

    var isOverloaded: Bool {
        activeTasks >= 4 && completionRate < 0.35 && daysSinceRoadmapCreated >= 2
    }

    var shouldSuggestAdjustment: Bool {
        overdueTasks > 0 || isStalledWithoutFirstWin || isOverloaded
    }

    var forAutomaticReplan: GoalPlanProgressAudit? {
        shouldSuggestAdjustment ? self : nil
    }

    static func make(roadmap: GoalRoadmap, tasks: [TaskItem], now: Date = .now) -> GoalPlanProgressAudit? {
        let linkedTasks = tasks.filter { task in
            isLinked(task, to: roadmap)
        }
        guard !linkedTasks.isEmpty else { return nil }

        let calendar = Calendar.current
        let completed = linkedTasks.filter(\.isCompleted)
        let active = linkedTasks.filter { !$0.isCompleted }
        let overdue = active.filter { task in
            guard let due = task.dueDate else { return false }
            return due < now
        }
        let missedTasks = overdue
            .sorted(by: dueSort)
            .prefix(4)
            .map { task in
                let due = task.dueDate ?? now
                return GoalMissedTask(
                    title: task.title,
                    dueDate: due,
                    daysOverdue: max(0, calendar.dateComponents([.day], from: due, to: now).day ?? 0),
                    createdAgeDays: max(0, calendar.dateComponents([.day], from: task.createdAt, to: now).day ?? 0),
                    category: task.category
                )
            }
        let oldestActiveAge = active
            .map { max(0, calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 0) }
            .max() ?? 0
        let daysSinceRoadmap = max(0, calendar.dateComponents([.day], from: roadmap.createdAt, to: now).day ?? 0)

        return GoalPlanProgressAudit(
            trackedTasks: linkedTasks.count,
            completedTasks: completed.count,
            activeTasks: active.count,
            overdueTasks: overdue.count,
            daysSinceRoadmapCreated: daysSinceRoadmap,
            oldestActiveTaskAgeDays: oldestActiveAge,
            overdueExamples: overdue.sorted(by: dueSort).map(\.title).prefixArray(3),
            missedTasks: missedTasks,
            nextActiveTask: active.sorted(by: dueSort).first?.title
        )
    }

    func suggestions(lang: AppLang) -> [String] {
        var result: [String] = []

        if overdueTasks > 0 {
            result.append(L10n.tr("goals.adapt.suggestion.reschedule", lang))
        }
        if isStalledWithoutFirstWin {
            result.append(L10n.tr("goals.adapt.suggestion.first_win", lang))
        }
        if isOverloaded {
            result.append(L10n.tr("goals.adapt.suggestion.scope", lang))
        }

        result.append(L10n.tr("goals.adapt.suggestion.review", lang))
        return result.prefixArray(3)
    }

    func chatSummary(lang: AppLang) -> String {
        if overdueTasks > 0 {
            let examples = missedTasks.map(\.title).prefixArray(2).joined(separator: ", ")
            let sample = examples.isEmpty ? L10n.tr("goals.adapt.missed_generic", lang) : examples
            return L10n.fmt("goals.adapt.chat_summary_overdue", lang, overdueTasks, sample)
        }
        if isStalledWithoutFirstWin {
            return L10n.tr("goals.adapt.chat_summary_stalled", lang)
        }
        if isOverloaded {
            return L10n.tr("goals.adapt.chat_summary_overloaded", lang)
        }
        return L10n.tr("goals.adapt.chat_summary_review", lang)
    }

    func promptSection() -> String {
        guard shouldSuggestAdjustment else {
            return "No correction signal from tracked Lippi tasks."
        }

        let examples = overdueExamples.isEmpty ? "none" : overdueExamples.joined(separator: "; ")
        let missed = missedTasks.isEmpty
            ? "none"
            : missedTasks.map { "- \($0.promptLine(lang: .en))" }.joined(separator: "\n")
        let next = nextActiveTask?.trimmed.isEmpty == false ? nextActiveTask! : "not detected"

        return """
        Previous roadmap progress from tracked Lippi tasks:
        - tracked tasks: \(trackedTasks)
        - completed: \(completedTasks)
        - active: \(activeTasks)
        - overdue: \(overdueTasks)
        - days since roadmap was created: \(daysSinceRoadmapCreated)
        - oldest active task age in days: \(oldestActiveTaskAgeDays)
        - overdue examples: \(examples)
        - next active task: \(next)
        - missed task details:
        \(missed)

        Adaptation instruction:
        The user skipped or missed one or more planned Lippi tasks based only on due-date facts. Preserve the goal, name the missed items as factual task-progress signals, reduce the immediate workload, split or reschedule blocked tasks, make the next 48 hours easier to start, and ask whether the skipped items are still relevant if needed. Do not blame the user, infer motivation, or invent reasons for the delay.
        """
    }

    private static func isLinked(_ task: TaskItem, to roadmap: GoalRoadmap) -> Bool {
        let note = normalized(task.notes)
        let roadmapTitle = normalized(roadmap.title)
        if !roadmapTitle.isEmpty, note.contains(roadmapTitle) {
            return true
        }

        let taskTitle = normalized(task.title)
        let roadmapTasks = Set(roadmap.milestones.flatMap(\.tasks).map(normalized) + roadmap.firstActions.map(normalized))
        return !taskTitle.isEmpty && roadmapTasks.contains(taskTitle)
    }

    private static func dueSort(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let left = lhs.dueDate ?? .distantFuture
        let right = rhs.dueDate ?? .distantFuture
        if left == right { return lhs.createdAt < rhs.createdAt }
        return left < right
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
                category: profile.category
            )
        }.filter { !$0.title.isEmpty && !$0.target.isEmpty && !$0.tasks.isEmpty }

        guard !mappedMilestones.isEmpty else { return nil }

        let cleanCriteria = successCriteria.cleanLines(limit: 4)
        let cleanActions = firstActions.cleanLines(limit: 4)
        let cleanAssumptions = assumptions.cleanLines(limit: 3)
        let cleanQuestions = GoalGuidanceQuestionBuilder.ensuringUsefulQuestions(
            clarifyingQuestions.cleanLines(limit: 3),
            input: input,
            lang: lang
        )
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
            clarifyingQuestions: cleanQuestions,
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
    func buildAIRoadmap(
        input: GoalPlannerInput,
        lang: AppLang,
        progressAudit: GoalPlanProgressAudit? = nil,
        onStage: @escaping (GoalRoadmapActivityStage) async -> Void = { _ in }
    ) async throws -> GoalRoadmap {
        await onStage(.research)
        let evidence = await OpenRoadmapRetriever().research(for: input)
        let configuration = OllamaConfiguration.stored
        var macProviderIssue: OllamaProviderError?

        if configuration.isEnabled {
            do {
                await onStage(.planning)
                let roadmap = try await generateOllamaRoadmap(
                    input: input,
                    lang: lang,
                    configuration: configuration,
                    evidence: evidence,
                    progressAudit: progressAudit
                )
                await onStage(.checking)
                return roadmap
            } catch let error as OllamaProviderError {
                macProviderIssue = error
            } catch {
                macProviderIssue = .transport
            }
        }

        do {
            await onStage(.planning)
            let roadmap = try await generateFoundationModelsRoadmap(input: input, lang: lang, evidence: evidence, progressAudit: progressAudit)
            await onStage(.checking)
            return roadmap
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
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?
    ) async throws -> GoalRoadmap {
        let provider = OllamaGoalProvider()
        let brief = GoalRequestBrief.make(input: input, fallbackLang: lang)
        let response = try await provider.generate(
            prompt: ollamaPrompt(for: input, lang: lang, brief: brief, evidence: evidence, progressAudit: progressAudit),
            configuration: configuration
        )

        if let roadmap = qualifiedRoadmap(from: response, source: .ollama, input: input, lang: brief.responseLanguage, evidence: evidence) {
            return roadmap
        }

        let repair = try await provider.generate(
            prompt: ollamaRepairPrompt(
                input: input,
                lang: lang,
                brief: brief,
                evidence: evidence,
                progressAudit: progressAudit,
                qualityFeedback: roadmapQualityFeedback(from: response, source: .ollama, input: input, lang: brief.responseLanguage, evidence: evidence)
            ),
            configuration: configuration
        )
        guard let roadmap = qualifiedRoadmap(from: repair, source: .ollama, input: input, lang: brief.responseLanguage, evidence: evidence) else {
            throw OllamaProviderError.incompleteRoadmap
        }
        return roadmap
    }

    private func ollamaPrompt(
        for input: GoalPlannerInput,
        lang: AppLang,
        brief: GoalRequestBrief,
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?
    ) -> String {
        """
        You are Lippi's grounded roadmap planner. Return JSON only and follow the schema attached by the app.

        Known user goal: \(input.goal)
        Known user context: \(input.context.isEmpty ? L10n.tr("goals.ai.no_context", lang) : input.context)
        Horizon: \(input.horizon.weeks) weeks. Pace: \(input.intensity.rawValue). Output language: \(brief.outputLanguageName).
        Fixed milestone slots: \(milestoneSlotInstructions(totalWeeks: input.horizon.weeks)).

        \(brief.promptSection())

        Progress audit from the previous Lippi plan:
        \(progressAuditPromptSection(progressAudit))

        Relevant open reference excerpts. Use them only when they help; do not claim they support anything beyond their text:
        \(evidencePromptSection(evidence))

        Planning contract:
        - Build the smallest realistic route from the known facts. Preserve stated time, money, dates, constraints, and domain.
        - Use the structured request as the canonical interpretation. If the raw text and structured request conflict, ask a clarifying question instead of inventing.
        - All human-readable JSON string values must be in \(brief.outputLanguageName), matching the user's request language. Keep product names and technical acronyms as written.
        - Make each milestone a different reviewable outcome in its fixed slot. Give every milestone two or three distinct tasks.
        - Each task must start with a clear action and name an artifact, decision, test, or deliverable. Never write vague tasks such as "make progress", "work on the project", or "do research" without a focus.
        - Return exactly two success criteria and two first actions. A success criterion is either a user-supplied metric or an observable deliverable.
        - Return two or three clarifyingQuestions. They must be guiding questions that help refine the roadmap and future Lippi support, not generic placeholders.
        - Unknown information belongs in assumptions or clarifying questions. Do not turn unknown facts into claims.
        - If the progress audit lists missed or overdue Lippi tasks, adapt the roadmap instead of restarting blindly: preserve the goal, reduce the next 48-hour load, split the skipped items into smaller actions, reschedule the closest milestone, and keep the tone supportive.
        - Do not invent why the user skipped tasks. Treat missed task titles and due dates only as task facts, then ask a clarifying question if the cause matters.
        - For a business goal, plan discovery or validation work, not imagined users, downloads, demand, revenue, conversion, or profit. Do not invent any metric, deadline, resource, prerequisite, feedback, or outcome.
        - Keep health, legal, and financial steps non-diagnostic and non-guaranteed. Use reference material as high-level guidance only.
        - Allowed categories: work, study, health, rest, home, other.
        """
    }

    private func ollamaRepairPrompt(
        input: GoalPlannerInput,
        lang: AppLang,
        brief: GoalRequestBrief,
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?,
        qualityFeedback: String
    ) -> String {
        """
        Build a fresh replacement in JSON only using the app schema. Do not copy unsupported claims from an earlier answer.
        Goal: \(input.goal)
        Context: \(input.context.isEmpty ? L10n.tr("goals.ai.no_context", lang) : input.context)
        Horizon: \(input.horizon.weeks) weeks. Fixed milestone slots: \(milestoneSlotInstructions(totalWeeks: input.horizon.weeks)).
        Output language: \(brief.outputLanguageName).
        \(brief.promptSection())
        Progress audit:
        \(progressAuditPromptSection(progressAudit))
        Quality audit to fix: \(qualityFeedback)
        Reference excerpts:
        \(evidencePromptSection(evidence))
        The earlier answer was rejected. Replan from the user brief, the fixed slots, the progress audit, and the quality audit above.
        Return two or three useful clarifyingQuestions in \(brief.outputLanguageName) so the user can refine the roadmap and Lippi can adjust support later.
        """
    }

    private func decodedRoadmap(
        from text: String,
        source: GoalRoadmapSource,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource]
    ) -> GoalRoadmap? {
        guard let payload = parsePayload(text) else { return nil }
        return payload.roadmap(source: source, input: input, lang: lang, evidence: evidence)
    }

    private func qualifiedRoadmap(
        from text: String,
        source: GoalRoadmapSource,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource]
    ) -> GoalRoadmap? {
        guard let roadmap = decodedRoadmap(from: text, source: source, input: input, lang: lang, evidence: evidence) else {
            return nil
        }
        return GoalRoadmapQualityGate.validated(roadmap, input: input, lang: lang)
    }

    private func roadmapQualityFeedback(
        from text: String,
        source: GoalRoadmapSource,
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource]
    ) -> String {
        GoalRoadmapQualityGate.feedback(
            for: decodedRoadmap(from: text, source: source, input: input, lang: lang, evidence: evidence),
            input: input
        )
    }

    private func milestoneSlotInstructions(totalWeeks: Int) -> String {
        let count = totalWeeks == 12 ? 4 : 3
        let base = totalWeeks / count
        return (0..<count).map { index in
            let start = index * base + 1
            let end = index == count - 1 ? totalWeeks : (index + 1) * base
            return start == end ? "week \(start)" : "weeks \(start)-\(end)"
        }.joined(separator: ", ")
    }


    private func generateFoundationModelsRoadmap(
        input: GoalPlannerInput,
        lang: AppLang,
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?
    ) async throws -> GoalRoadmap {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { throw GoalPlannerEngineError.modelUnavailable }
            guard model.supportsLocale(.current) else { throw GoalPlannerEngineError.systemLocaleUnsupported }
            let foundationInput = try await prepareFoundationInput(input)
            let brief = GoalRequestBrief.make(input: input, fallbackLang: lang)

            let session = LanguageModelSession(
                model: model,
                instructions: foundationInstructions
            )

            do {
                let response = try await session.respond(
                    to: prompt(for: foundationInput, original: input, brief: brief, evidence: evidence, progressAudit: progressAudit),
                    options: GenerationOptions(temperature: 0.18, maximumResponseTokens: 2600)
                )
                if let roadmap = qualifiedRoadmap(
                    from: response.content,
                    source: .foundationModels,
                    input: input,
                    lang: brief.responseLanguage,
                    evidence: evidence
                ) {
                    return annotateLanguageBridge(
                        roadmap,
                        lang: brief.responseLanguage,
                        translatedInput: foundationInput.translatedFromUserLanguage,
                        semanticBridge: foundationInput.usedSemanticBridge
                    )
                }

                let repair = try await session.respond(
                    to: repairPrompt(
                        original: response.content,
                        input: foundationInput,
                        originalInput: input,
                        brief: brief,
                        evidence: evidence,
                        progressAudit: progressAudit,
                        qualityFeedback: roadmapQualityFeedback(
                            from: response.content,
                            source: .foundationModels,
                            input: input,
                            lang: brief.responseLanguage,
                            evidence: evidence
                        )
                    ),
                    options: GenerationOptions(temperature: 0.05, maximumResponseTokens: 2200)
                )
                guard let roadmap = qualifiedRoadmap(
                    from: repair.content,
                    source: .foundationModels,
                    input: input,
                    lang: brief.responseLanguage,
                    evidence: evidence
                ) else {
                    throw GoalPlannerEngineError.invalidResponse
                }
                return annotateLanguageBridge(
                    roadmap,
                    lang: brief.responseLanguage,
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
        You are Lippi's grounded goal-roadmap planner inside an iPhone app.
        Work only from stated user facts and supplied reference excerpts. Return strict JSON only.
        First structure the user's request into objective, context facts, constraints, numbers, dates, missing details, and response language. Use that structure as the planning contract.
        Build a small route with distinct, reviewable milestones and concrete tasks. Unknown facts belong in assumptions or clarifying questions.
        Always include two or three helpful clarifying questions for refining the roadmap and future support.
        Write every human-readable JSON value in the detected user request language. Keep names, brands, product terms, and acronyms as written.
        When Lippi supplies a progress audit showing missed, overdue, or stalled plan tasks, adapt the plan: preserve the goal, reduce the immediate workload, split or reschedule skipped next actions, and avoid blaming, psychoanalyzing, or inventing reasons for the delay.
        Never invent metrics, users, downloads, demand, revenue, resources, prerequisites, personal circumstances, or guarantees.
        """
    }

    private func prompt(
        for input: FoundationGoalInput,
        original: GoalPlannerInput,
        brief: GoalRequestBrief,
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?
    ) -> String {
        let sourceNote: String
        if input.usedSemanticBridge {
            sourceNote = "The user wrote in \(brief.outputLanguageName). Apple Translation was unavailable, so Lippi used its offline planning translator before this request. The translated goal and context preserve the planning-relevant intent, domain, dates, quantities, weekly time, and explicit constraints. Use the translated brief for understanding, but write the JSON string values in \(brief.outputLanguageName)."
        } else if input.translatedFromUserLanguage {
            sourceNote = "The user wrote in \(brief.outputLanguageName). Apple Translation converted the goal and context to English before this request. Use the English translation for reasoning, but write the JSON string values in \(brief.outputLanguageName)."
        } else {
            sourceNote = "The user request language is \(brief.outputLanguageName)."
        }

        return """
        Produce a strict JSON roadmap in \(brief.outputLanguageName).
        Original user goal: \(original.goal)
        Original user context: \(original.context.isEmpty ? "No context provided" : original.context)
        Planning goal in English if translated: \(input.goal)
        Planning context in English if translated: \(input.context.isEmpty ? "No context provided" : input.context)
        Horizon: \(original.horizon.weeks) weeks. Pace: \(original.intensity.rawValue).
        Fixed milestone slots: \(milestoneSlotInstructions(totalWeeks: original.horizon.weeks)).
        Source-language handling: \(sourceNote)
        \(brief.promptSection())
        Progress audit from previous Lippi tasks:
        \(progressAuditPromptSection(progressAudit))
        Reference excerpts:
        \(evidencePromptSection(evidence))

        JSON shape: {"title":"string","summary":"string","confidence":0.7,"successCriteria":["string","string"],"firstActions":["string","string"],"assumptions":["string"],"clarifyingQuestions":["guiding question","guiding question"],"milestones":[{"title":"string","timeframe":"string","target":"reviewable output","tasks":["action plus artifact","action plus decision"],"category":"work"}],"habits":[{"title":"string","detail":"cadence"}],"risks":[{"title":"string","mitigation":"specific response"}]}

        Rules: use 3 milestones for 4 or 8 weeks and 4 for 12 weeks; every milestone has two or three different action-plus-artifact tasks; return exactly two success criteria and first actions; return two or three guiding clarifying questions; use assumptions instead of invented facts; if the progress audit lists missed tasks, make the nearest milestone smaller, reschedule the skipped items, and ask what blocked them without inventing a reason; all human-readable JSON strings must be in \(brief.outputLanguageName); no vague tasks, performance predictions, medical/legal/financial instructions, or guarantees. Categories: work, study, health, rest, home, other.
        """
    }

    private func repairPrompt(
        original: String,
        input: FoundationGoalInput,
        originalInput: GoalPlannerInput,
        brief: GoalRequestBrief,
        evidence: [GoalEvidenceSource],
        progressAudit: GoalPlanProgressAudit?,
        qualityFeedback: String
    ) -> String {
        let sourceNote: String
        if input.usedSemanticBridge {
            sourceNote = "The user wrote in \(brief.outputLanguageName). Apple Translation was unavailable, so Lippi created an offline English planning translation before this request. Keep the repaired JSON values in \(brief.outputLanguageName) and preserve the translated intent, dates, quantities, time limits, and constraints."
        } else if input.translatedFromUserLanguage {
            sourceNote = "The user wrote in \(brief.outputLanguageName). Apple Translation converted the goal and context to English before this request. Keep the repaired JSON values in \(brief.outputLanguageName)."
        } else {
            sourceNote = "The user request language is \(brief.outputLanguageName). Keep the repaired JSON values in that language."
        }

        return """
        Repair the previous answer into strict JSON only. Preserve grounded, context-specific ideas and fix the audit findings.

        Original user goal: \(originalInput.goal)
        Original user context: \(originalInput.context.isEmpty ? "No context provided" : originalInput.context)
        Planning goal in English if translated: \(input.goal)
        Planning context in English if translated: \(input.context.isEmpty ? "No context provided" : input.context)
        Planning horizon: \(originalInput.horizon.weeks) weeks
        Desired pace: \(originalInput.intensity.rawValue)
        Output language: \(brief.outputLanguageName)
        Source-language handling: \(sourceNote)
        Fixed milestone slots: \(milestoneSlotInstructions(totalWeeks: originalInput.horizon.weeks)).
        \(brief.promptSection())
        Progress audit:
        \(progressAuditPromptSection(progressAudit))
        Quality audit to fix: \(qualityFeedback)
        Reference excerpts:
        \(evidencePromptSection(evidence))

        Required JSON schema:
        {
          "title": "string",
          "summary": "string",
          "confidence": 0.82,
          "successCriteria": ["string", "string"],
          "firstActions": ["string", "string"],
          "assumptions": ["string"],
          "clarifyingQuestions": ["guiding question", "guiding question"],
          "milestones": [
            {"title": "string", "timeframe": "string", "target": "string", "tasks": ["string", "string", "string"], "category": "work"}
          ],
          "habits": [{"title": "string", "detail": "string"}],
          "risks": [{"title": "string", "mitigation": "string"}]
        }

        Previous answer:
        \(String(original.prefix(5_000)))
        The repaired answer must include two or three useful clarifyingQuestions in \(brief.outputLanguageName).
        """
    }

    private func evidencePromptSection(_ evidence: [GoalEvidenceSource]) -> String {
        guard !evidence.isEmpty else {
            return "No matching reference was available. Build only from the user's input and make uncertainty explicit."
        }

        return evidence.map { source in
            "- \(source.title): \(source.excerpt)"
        }.joined(separator: "\n")
    }

    private func progressAuditPromptSection(_ audit: GoalPlanProgressAudit?) -> String {
        audit?.promptSection() ?? "No previous Lippi task progress is available for this goal."
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

    func buildDraftRoadmap(input: GoalPlannerInput, lang: AppLang, progressAudit: GoalPlanProgressAudit? = nil) -> GoalRoadmap {
        let outputLang = input.responseLanguage(fallback: lang)
        let profile = GoalProfile(goal: input.goal, context: input.context)
        let phaseTitles = localPhaseTitles(for: profile.category, lang: outputLang)
        let tasks = localTaskBank(for: profile.category, lang: outputLang, intensity: input.intensity)
        let weeks = input.horizon.weeks
        let phaseCount = min(4, max(3, weeks / 2))
        let chunk = max(1, weeks / phaseCount)
        let isAdaptive = progressAudit?.shouldSuggestAdjustment == true

        var milestones = (0..<phaseCount).map { index in
            let startWeek = index * chunk + 1
            let endWeek = index == phaseCount - 1 ? weeks : min(weeks, (index + 1) * chunk)
            let title = phaseTitles[safe: index] ?? phaseTitles.last ?? L10n.tr("goals.local.phase", lang)
            let phaseTasks = rotated(tasks, offset: index * 2).prefixArray(3)

            return GoalMilestone(
                title: title,
                timeframe: timeframe(start: startWeek, end: endWeek, lang: outputLang),
                target: targetText(goal: input.goal, index: index, category: profile.category, lang: outputLang),
                tasks: phaseTasks,
                category: profile.category
            )
        }

        if let progressAudit, isAdaptive, !milestones.isEmpty {
            milestones[0].title = L10n.tr("goals.adapt.milestone.title", outputLang)
            milestones[0].target = L10n.tr("goals.adapt.milestone.target", outputLang)
            milestones[0].tasks = progressAudit.suggestions(lang: outputLang).prefixArray(2) + milestones[0].tasks.prefixArray(1)
        }

        var habits = localHabits(for: profile.category, lang: outputLang, intensity: input.intensity)
        var risks = localRisks(for: profile.category, lang: outputLang)
        var assumptions = draftAssumptions(input: input, lang: outputLang)
        let brief = GoalRequestBrief.make(input: input, fallbackLang: outputLang)
        let guidanceQuestions = GoalGuidanceQuestionBuilder.questions(for: input, brief: brief, lang: outputLang)

        if isAdaptive {
            habits.insert(
                GoalHabit(title: L10n.tr("goals.adapt.habit.title", outputLang), detail: L10n.tr("goals.adapt.habit.detail", outputLang)),
                at: 0
            )
            risks.insert(
                GoalRisk(title: L10n.tr("goals.adapt.risk.title", outputLang), mitigation: L10n.tr("goals.adapt.risk.detail", outputLang)),
                at: 0
            )
            assumptions.append(L10n.tr("goals.assumption.progress_audit", outputLang))
        }

        return GoalRoadmap(
            title: input.goal,
            summary: isAdaptive
                ? L10n.fmt("goals.adapt.summary", outputLang, input.goal, progressAudit?.overdueTasks ?? 0, progressAudit?.activeTasks ?? 0)
                : summaryText(goal: input.goal, horizon: input.horizon, intensity: input.intensity, category: profile.category, lang: outputLang),
            source: .localPlanner,
            confidence: isAdaptive ? 0.58 : 0.52,
            successCriteria: draftSuccessCriteria(goal: input.goal, category: profile.category, lang: outputLang),
            firstActions: isAdaptive
                ? (progressAudit?.suggestions(lang: outputLang).prefixArray(2) ?? []) + rotated(tasks, offset: 0).prefixArray(2)
                : rotated(tasks, offset: 0).prefixArray(4),
            assumptions: assumptions,
            clarifyingQuestions: guidanceQuestions,
            milestones: milestones,
            habits: habits.prefixArray(4),
            risks: risks.prefixArray(3)
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
