import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Settings (glass, dark Apple-style backdrop) — polished elements
// =======================================================
struct SettingsView: View {
    private static let privacyPolicyURL = URL(
        string: "https://lippi.lenuma.ru/privacy"
    )!

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var eye: EyeExerciseStore
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var pomo: PomodoroManager
    @EnvironmentObject private var daily: DailyReminderStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.defaultTheme.rawValue
    @AppStorage(PomodoroRingtone.storageKey) private var pomodoroRingtoneRaw: String = PomodoroRingtone.defaultRingtone.rawValue
    @AppStorage(HealthVoicePreferences.isEnabledKey) private var healthVoiceEnabled: Bool = HealthVoicePreferences.defaultEnabled
    @AppStorage(HealthVoicePreferences.autoSpeakKey) private var healthVoiceAutoSpeak: Bool = HealthVoicePreferences.defaultAutoSpeak
    @AppStorage(HealthVoicePlaybackSpeed.storageKey) private var healthVoiceSpeedRaw: String = HealthVoicePlaybackSpeed.defaultSpeed.rawValue
    @AppStorage(GoalCareNotificationScheduler.enabledKey) private var goalCareNotificationsEnabled: Bool = true
    @AppStorage("goal.progress.userState") private var goalUserStateRaw: String = GoalUserState.calm.rawValue
    @State private var selectedScope: SettingsScope = .all
    @State private var confirmClear = false
    @State private var showsLippiOnboarding = false

    // единая сетка для рядов (чтобы всё было ровно)
    private let rowHInset: CGFloat = 14
    private let rowVInset: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var rightColWidthBase: CGFloat = 156

    // фоновая сцена (фиксируем везде, чтобы не “пропадал”)
    private var settingsBackdrop: some View {
        AppBackdrop()
    }

    private var tasksActiveCount: Int { store.tasks.filter { !$0.isCompleted }.count }
    private var tasksDoneCount: Int { store.tasks.filter { $0.isCompleted }.count }
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private var rightColWidth: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 120 }
        return horizontalSizeClass == .compact ? min(148, rightColWidthBase) : rightColWidthBase
    }

    private func t(_ key: L10nKey) -> String {
        L10n.tr(key, lang)
    }
    private func s(_ key: String) -> String {
        L10n.tr(key, lang)
    }

    private enum SettingsScope: String, CaseIterable, Identifiable {
        case all
        case account
        case focus
        case ai
        case health
        case data

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .account: return "person.crop.circle.fill"
            case .focus: return "timer"
            case .ai: return "cpu.fill"
            case .health: return "heart.text.square.fill"
            case .data: return "externaldrive.fill"
            }
        }

        func title(_ lang: AppLang) -> String {
            L10n.tr("settings.scope.\(rawValue)", lang)
        }
    }

    private enum SettingsAnchor: String, Hashable {
        case hero
        case account
        case language
        case theme
        case onboarding
        case quick
        case live
        case pomodoro
        case daily
        case ai
        case healthKit
        case eye
        case voice
        case data
    }

    private struct SettingsJumpItem: Identifiable {
        let anchor: SettingsAnchor
        let title: String
        let icon: String

        var id: SettingsAnchor { anchor }
    }

    private var supportsLiveActivitiesCard: Bool {
        #if canImport(ActivityKit)
        return true
        #else
        return false
        #endif
    }

    private func primaryAnchor(for scope: SettingsScope) -> SettingsAnchor {
        switch scope {
        case .all: return .hero
        case .account: return .account
        case .focus: return .quick
        case .ai: return .ai
        case .health: return .healthKit
        case .data: return .data
        }
    }

    private func scopeJumpItems(for scope: SettingsScope) -> [SettingsJumpItem] {
        switch scope {
        case .all:
            return []
        case .account:
            return [
                SettingsJumpItem(anchor: .account, title: t(.settings_account_title), icon: "person.crop.circle.fill"),
                SettingsJumpItem(anchor: .language, title: t(.settings_language_title), icon: "globe"),
                SettingsJumpItem(anchor: .theme, title: t(.settings_theme_title), icon: "swatchpalette.fill"),
                SettingsJumpItem(anchor: .onboarding, title: s("settings.onboarding.title"), icon: "sparkles.rectangle.stack.fill")
            ]
        case .focus:
            var items: [SettingsJumpItem] = [
                SettingsJumpItem(anchor: .quick, title: s("settings.quick.title"), icon: "bolt.circle.fill"),
                SettingsJumpItem(anchor: .pomodoro, title: s("settings.pomodoro.title"), icon: "timer.circle.fill"),
                SettingsJumpItem(anchor: .daily, title: s("settings.daily.title"), icon: "bell.and.waves.left.and.right.fill")
            ]
            if supportsLiveActivitiesCard {
                items.insert(SettingsJumpItem(anchor: .live, title: s("settings.live.title"), icon: "wave.3.right.circle.fill"), at: 1)
            }
            return items
        case .ai:
            return [
                SettingsJumpItem(anchor: .ai, title: s("settings.bonsai.title"), icon: "cpu.fill")
            ]
        case .health:
            return [
                SettingsJumpItem(anchor: .healthKit, title: s("healthkit.title"), icon: "heart.text.square.fill"),
                SettingsJumpItem(anchor: .eye, title: s("settings.eye.title"), icon: "eye.circle.fill"),
                SettingsJumpItem(anchor: .voice, title: s("settings.voice.title"), icon: "speaker.wave.3.fill")
            ]
        case .data:
            return [
                SettingsJumpItem(anchor: .data, title: t(.settings_data_title), icon: "tray.full.fill")
            ]
        }
    }

    private func shouldShowAccountScopeCards() -> Bool {
        selectedScope == .all || selectedScope == .account
    }

    private func shouldShowFocusScopeCards() -> Bool {
        selectedScope == .all || selectedScope == .focus
    }

    private func shouldShowHealthScopeCards() -> Bool {
        selectedScope == .all || selectedScope == .health
    }

    private func shouldShowAIScopeCards() -> Bool {
        selectedScope == .all || selectedScope == .ai
    }

    private func shouldShowDataScopeCards() -> Bool {
        selectedScope == .all || selectedScope == .data
    }

    var body: some View {
        NavigationStack {
            settingsScreen
        }
    }

    /// The settings hierarchy contains many independent cards. Keeping the
    /// navigation shell behind its own opaque boundary avoids a device-only
    /// Swift metadata stack overflow when the screen is first presented.
    private var settingsScreen: some View {
        ZStack {
            settingsBackdrop

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        settingsSections(proxy: proxy)
                    }
                    .lippiContentColumn()
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                .lippiScrollPerformance()
                .onChange(of: selectedScope) { _, newScope in
                    let target = primaryAnchor(for: newScope)
                    DispatchQueue.main.async {
                        withAnimation(reduceMotion ? nil : DS.motionNavigate) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
                .animation(reduceMotion ? nil : DS.motionState, value: selectedScope)
            }
            #if os(iOS)
            .scrollIndicators(.hidden)
            #endif
        }
        .navigationTitle(t(.settings_nav_title))
        .navigationBarTitleDisplayMode(.large)
        .clearNavBarBackgroundIfAvailable()
        .alert(t(.settings_alert_clear_title), isPresented: $confirmClear) {
            Button(t(.common_delete), role: .destructive) { store.clearAll() }
            Button(t(.common_cancel), role: .cancel) { }
        } message: {
            Text(t(.settings_alert_clear_message))
        }
        .fullScreenCover(isPresented: $showsLippiOnboarding) {
            LippiOnboardingView(mode: .replay) {
                showsLippiOnboarding = false
            }
        }
    }

    @ViewBuilder
    private func settingsSections(proxy: ScrollViewProxy) -> some View {
        AnyView(
            heroCard
                .id(SettingsAnchor.hero)
                .lippiMotionScene(0)
        )
        AnyView(
            scopeCard(proxy: proxy)
                .lippiMotionScene(1)
        )

        if shouldShowAccountScopeCards() {
            AnyView(
                accountCard
                    .id(SettingsAnchor.account)
                    .lippiMotionScene(2)
            )
            AnyView(
                languageCard
                    .id(SettingsAnchor.language)
                    .lippiMotionScene(3)
            )
            AnyView(
                themeCard
                    .id(SettingsAnchor.theme)
                    .lippiMotionScene(4)
            )
            AnyView(
                onboardingReplayCard
                    .id(SettingsAnchor.onboarding)
                    .lippiMotionScene(5)
            )
        }

        if shouldShowFocusScopeCards() {
            AnyView(
                quickActionsCard
                    .id(SettingsAnchor.quick)
                    .lippiMotionScene(2)
            )
            AnyView(
                liveActivitiesCard
                    .id(SettingsAnchor.live)
                    .lippiMotionScene(3)
            )
            AnyView(
                pomodoroCard
                    .id(SettingsAnchor.pomodoro)
                    .lippiMotionScene(4)
            )
            AnyView(
                dailyRemindersCard
                    .id(SettingsAnchor.daily)
                    .lippiMotionScene(5)
            )
        }

        if shouldShowAIScopeCards() {
            AnyView(
                BonsaiSettingsCard()
                    .id(SettingsAnchor.ai)
                    .lippiMotionScene(2)
            )
        }

        if shouldShowHealthScopeCards() {
            AnyView(
                HealthKitInsightCard(
                    manager: healthKit,
                    lang: lang,
                    showsManagementActions: true
                )
                .id(SettingsAnchor.healthKit)
                .lippiMotionScene(2)
            )
            AnyView(
                goalCareAdviceCard
                    .lippiMotionScene(3)
            )
            AnyView(
                eyeGymCard
                    .id(SettingsAnchor.eye)
                    .lippiMotionScene(4)
            )
            AnyView(
                healthVoiceCard
                    .id(SettingsAnchor.voice)
                    .lippiMotionScene(5)
            )
            AnyView(
                NeuralVoiceSettingsCard()
                    .lippiMotionScene(6)
            )
        }

        if shouldShowDataScopeCards() {
            AnyView(
                dataCard
                    .id(SettingsAnchor.data)
                    .lippiMotionScene(2)
            )
        }
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: themeRaw) ?? AppTheme.defaultTheme
    }

    private var selectedPomodoroRingtone: PomodoroRingtone {
        PomodoroRingtone.fromStored(pomodoroRingtoneRaw)
    }

    private var selectedHealthVoiceSpeed: HealthVoicePlaybackSpeed {
        HealthVoicePlaybackSpeed(rawValue: healthVoiceSpeedRaw) ?? .defaultSpeed
    }

    // MARK: - Sections (split to help compiler)

    private var heroCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                iconBadge("gearshape.fill", fallback: "gearshape")

                VStack(alignment: .leading, spacing: 4) {
                    Text(t(.settings_hero_title))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DS.text(0.96))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Text(t(.settings_hero_subtitle))
                        .font(.footnote)
                        .foregroundStyle(DS.text(0.66))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }
                .padding(.vertical, 2)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    statChip(t(.settings_stat_active), "\(tasksActiveCount)", icon: "circle.fill")
                    statChip(t(.settings_stat_done), "\(tasksDoneCount)", icon: "checkmark.circle.fill")
                }
            }
        }
    }

    private func scopeCard(proxy: ScrollViewProxy) -> some View {
        let jumpItems = scopeJumpItems(for: selectedScope)
        return GlassCard(style: .flat) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    s("settings.scope.title"),
                    subtitle: s("settings.scope.subtitle"),
                    icon: "line.3.horizontal.decrease.circle.fill",
                    accent: Color(hex: 0x5AC8FA)
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SettingsScope.allCases) { scope in
                            scopeChip(scope, proxy: proxy)
                        }
                    }
                    .padding(.vertical, 1)
                }

                if !jumpItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(jumpItems) { item in
                                scopeJumpChip(item, proxy: proxy)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private var accountCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    t(.settings_account_title),
                    subtitle: t(.settings_account_subtitle),
                    icon: "person.crop.circle.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                HStack(spacing: 10) {
                    Image(safeSystemName: "person.fill", fallback: "person")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.text(0.9))
                        .frame(width: 30, height: 30)
                        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.session?.user.displayName ?? t(.settings_user_fallback))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.text(0.92))
                            .lineLimit(1)

                        Text(providerLabel)
                            .font(.caption)
                            .foregroundStyle(DS.text(0.62))
                            .lineLimit(1)
                    }

                    Spacer()
                }

                Link(destination: Self.privacyPolicyURL) {
                    Label(s("settings.privacy_policy"), systemImage: "lock.shield.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))

                Button {
                    auth.signOut()
                } label: {
                    Label(t(.settings_sign_out), systemImage: "rectangle.portrait.and.arrow.right")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }

    private var providerLabel: String {
        guard let session = auth.session else { return t(.settings_session_inactive) }
        return session.user.email ?? t(.settings_provider_email)
    }

    private func scopeChip(_ scope: SettingsScope, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedScope == scope

        return Button {
            guard selectedScope != scope else { return }
            selectedScope = scope
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif

            let target = primaryAnchor(for: scope)
            DispatchQueue.main.async {
                withAnimation(reduceMotion ? nil : DS.motionNavigate) {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        } label: {
            Label(scope.title(lang), systemImage: scope.icon)
                .labelStyle(TightLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : DS.text(0.88))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.glassFill(0.10)))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? DS.glassStroke(0.24) : DS.glassStroke(0.14), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
        .buttonStyle(PressScaleStyle(scale: 0.988, opacity: 0.96))
    }

    private func scopeJumpChip(_ item: SettingsJumpItem, proxy: ScrollViewProxy) -> some View {
        Button {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            withAnimation(reduceMotion ? nil : DS.motionNavigate) {
                proxy.scrollTo(item.anchor, anchor: .top)
            }
        } label: {
            Label(item.title, systemImage: item.icon)
                .labelStyle(TightLabelStyle())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.text(0.90))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(DS.glassFill(0.10))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
        .buttonStyle(PressScaleStyle(scale: 0.99, opacity: 0.96))
    }

    private var languageCard: some View {
        GlassCard(style: .lightweight) {
            sectionHeader(
                t(.settings_language_title),
                subtitle: t(.settings_language_subtitle),
                icon: "globe",
                accent: Color(hex: 0x5AC8FA)
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 120), spacing: 10),
                    GridItem(.flexible(minimum: 120), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(AppLang.allCases) { option in
                    languageTile(option)
                }
            }

            Text(t(.settings_language_hint))
                .font(.footnote)
                .foregroundStyle(DS.text(0.62))
                .padding(.top, 2)
        }
    }

    private var themeCard: some View {
        GlassCard {
            sectionHeader(
                t(.settings_theme_title),
                subtitle: t(.settings_theme_subtitle),
                icon: "swatchpalette.fill",
                accent: selectedTheme.accentColor
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 130), spacing: 10),
                    GridItem(.flexible(minimum: 130), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(AppTheme.allCases) { theme in
                    themeTile(theme)
                }
            }

            Text(t(.settings_theme_hint))
                .font(.footnote)
                .foregroundStyle(DS.text(0.62))
                .padding(.top, 2)
        }
    }

    private var quickActionsCard: some View {
        GlassCard {
            sectionHeader(
                s("settings.quick.title"),
                subtitle: s("settings.quick.subtitle"),
                icon: "bolt.circle.fill",
                accent: Color(hex: 0x5AC8FA)
            )

            HStack(spacing: 10) {
                quickActionTile(
                    icon: daily.config.enabled ? "bell.badge.fill" : "bell.slash.fill",
                    title: daily.config.enabled ? s("settings.quick.reminders_on") : s("settings.quick.reminders_off"),
                    subtitle: s("settings.quick.reminders_subtitle"),
                    accent: Color(hex: 0xFF9F0A)
                ) {
                    daily.config.enabled.toggle()
                    daily.reschedule()
                }

                quickActionTile(
                    icon: eye.settings.autoSuggestEnabled ? "eye.fill" : "eye.slash.fill",
                    title: eye.settings.autoSuggestEnabled ? s("settings.quick.eyes_on") : s("settings.quick.eyes_off"),
                    subtitle: s("settings.quick.eyes_subtitle"),
                    accent: Color(hex: 0x30D158)
                ) {
                    eye.settings.autoSuggestEnabled.toggle()
                }
            }

            HStack(spacing: 10) {
                quickActionTile(
                    icon: "timer",
                    title: s("settings.quick.preset_title"),
                    subtitle: s("settings.quick.preset_subtitle"),
                    accent: DS.accent
                ) {
                    pomo.config.focusMinutes = 25
                    pomo.config.shortBreakMinutes = 5
                    pomo.config.longBreakMinutes = 15
                    pomo.config.roundsBeforeLongBreak = 4
                }

                quickActionTile(
                    icon: "paperplane.fill",
                    title: s("settings.quick.test_title"),
                    subtitle: s("settings.quick.test_subtitle"),
                    accent: Color(hex: 0x64D2FF)
                ) {
                    daily.testFireIn(3)
                }
            }
        }
    }

    @ViewBuilder
    private var liveActivitiesCard: some View {
        #if canImport(ActivityKit)
        GlassCard {
            sectionHeader(
                s("settings.live.title"),
                subtitle: s("settings.live.subtitle"),
                icon: "wave.3.right.circle.fill",
                accent: Color(hex: 0x5AC8FA)
            )

            if #available(iOS 16.2, *) {
                actionRow(icon: "xmark.circle.fill",
                          title: s("settings.live.end_all_title"),
                          subtitle: s("settings.live.end_all_subtitle")) {
                    Task {
                        await LiveActivityManager.endAllTasks()
                        await PomodoroLiveManager.endAll()
                        await GoalRoadmapLiveActivityManager.endAll()
                    }
                }

                softGap()

                actionRow(icon: "timer",
                          title: s("settings.live.test_title"),
                          subtitle: s("settings.live.test_subtitle")) {
                    let now = Date()
                    Task {
                        await PomodoroLiveManager.start(
                            title: s("settings.live.test_session_title"),
                            phase: .focus,
                            start: now,
                            end: now.addingTimeInterval(15)
                        )
                    }
                }

                #if os(iOS)
                actionRow(icon: "bell.badge.fill",
                          title: s("settings.live.open_notifications_title"),
                          subtitle: s("settings.live.open_notifications_subtitle")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif

                Text(s("settings.live.requirement"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.62))
                    .padding(.top, 4)
            } else {
                Text(s("settings.live.ios_required"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.62))
            }
        }
        #endif
    }

    private var pomodoroCard: some View {
        GlassCard {
            sectionHeader(
                s("settings.pomodoro.title"),
                subtitle: s("settings.pomodoro.subtitle"),
                icon: "timer.circle.fill",
                accent: DS.accent
            )

            stepperRow(
                icon: "bolt.fill",
                title: s("settings.pomodoro.focus_title"),
                subtitle: s("settings.pomodoro.focus_subtitle"),
                valueText: L10n.fmt("settings.unit.minutes", lang, pomo.config.focusMinutes)
            ) {
                Stepper("", value: $pomo.config.focusMinutes, in: 5...120, step: 5).labelsHidden()
            }

            stepperRow(
                icon: "cup.and.saucer.fill",
                title: s("settings.pomodoro.short_break_title"),
                subtitle: s("settings.pomodoro.short_break_subtitle"),
                valueText: L10n.fmt("settings.unit.minutes", lang, pomo.config.shortBreakMinutes)
            ) {
                Stepper("", value: $pomo.config.shortBreakMinutes, in: 3...30, step: 1).labelsHidden()
            }

            stepperRow(
                icon: "sparkles",
                title: s("settings.pomodoro.long_break_title"),
                subtitle: s("settings.pomodoro.long_break_subtitle"),
                valueText: L10n.fmt("settings.unit.minutes", lang, pomo.config.longBreakMinutes)
            ) {
                Stepper("", value: $pomo.config.longBreakMinutes, in: 5...60, step: 5).labelsHidden()
            }

            stepperRow(
                icon: "circle.grid.2x2.fill",
                title: s("settings.pomodoro.rounds_title"),
                subtitle: s("settings.pomodoro.rounds_subtitle"),
                valueText: "\(pomo.config.roundsBeforeLongBreak)"
            ) {
                Stepper("", value: $pomo.config.roundsBeforeLongBreak, in: 2...8).labelsHidden()
            }

            ringtonePickerRow(
                icon: "bell.badge.waveform.fill",
                title: s("settings.pomodoro.ringtone_title"),
                subtitle: s("settings.pomodoro.ringtone_subtitle")
            )
        }
    }

    private var dailyRemindersCard: some View {
        GlassCard {
            sectionHeader(
                s("settings.daily.title"),
                subtitle: s("settings.daily.subtitle"),
                icon: "bell.and.waves.left.and.right.fill",
                accent: Color(hex: 0xFF9F0A)
            )

            toggleRow(icon: "power", title: s("settings.daily.toggle_title"), subtitle: s("settings.daily.toggle_subtitle"), isOn: Binding(
                get: { daily.config.enabled },
                set: { daily.config.enabled = $0 }
            ))

            labeledGlass(s("settings.daily.name_title")) {
                TextField(
                    s("settings.daily.name_placeholder"),
                    text: Binding(get: { daily.config.title }, set: { daily.config.title = $0 })
                )
                .textInputAutocapitalization(.sentences)
                .fieldGlass()
                .tint(DS.text(0.9))
                .foregroundStyle(DS.text(0.95))
            }

            labeledGlass(s("settings.daily.start_time")) {
                DatePicker("", selection: Binding<Date>(
                    get: {
                        let cal = Calendar.current
                        let comps = DateComponents(hour: daily.config.hour, minute: daily.config.minute)
                        return cal.date(from: comps) ?? Date()
                    },
                    set: { newDate in
                        let cal = Calendar.current
                        daily.config.hour = cal.component(.hour, from: newDate)
                        daily.config.minute = cal.component(.minute, from: newDate)
                    }
                ), displayedComponents: [.hourAndMinute])
                .labelsHidden()
            }

            labeledGlass(s("settings.daily.preparation")) {
                HStack(spacing: 10) {
                    Text(L10n.fmt("settings.daily.preparation_value", lang, daily.config.preparationMinutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    Stepper("", value: Binding(
                        get: { daily.config.preparationMinutes },
                        set: { daily.config.preparationMinutes = max(0, min(240, $0)) }
                    ), in: 0...240, step: 5)
                    .labelsHidden()
                }
            }

            HStack(spacing: 12) {
                Button {
                    daily.reschedule()
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                } label: {
                    Label(s("settings.daily.save"), systemImage: "bell.badge.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))

                Button { daily.testFireIn(3) } label: {
                    Label(s("settings.daily.test"), systemImage: "paperplane.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }

            Text(s("settings.daily.info"))
                .font(.footnote)
                .foregroundStyle(DS.text(0.62))
                .padding(.top, 2)
        }
    }

    private var eyeGymCard: some View {
        GlassCard {
            sectionHeader(
                s("settings.eye.title"),
                subtitle: s("settings.eye.subtitle"),
                icon: "eye.circle.fill",
                accent: Color(hex: 0x30D158)
            )

            toggleRow(icon: "sparkles",
                      title: s("settings.eye.toggle_title"),
                      subtitle: s("settings.eye.toggle_subtitle"),
                      isOn: Binding(
                        get: { eye.settings.autoSuggestEnabled },
                        set: { eye.settings.autoSuggestEnabled = $0 }
                      ))

            labeledGlass(s("settings.eye.threshold")) {
                HStack(spacing: 10) {
                    Text(L10n.fmt("settings.eye.threshold_value", lang, eye.settings.suggestThresholdMinutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    Stepper("", value: Binding(
                        get: { eye.settings.suggestThresholdMinutes },
                        set: { eye.settings.suggestThresholdMinutes = max(10, min(120, $0)) }
                    ), in: 10...120, step: 5).labelsHidden()
                }
            }

            labeledGlass(s("settings.eye.targets")) {
                HStack(spacing: 10) {
                    Text("\(eye.settings.targetsPerSession)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    Stepper("", value: Binding(
                        get: { eye.settings.targetsPerSession },
                        set: { eye.settings.targetsPerSession = max(8, min(40, $0)) }
                    ), in: 8...40, step: 2).labelsHidden()
                }
            }

            labeledGlass(s("settings.eye.limit")) {
                HStack(spacing: 10) {
                    Text(L10n.fmt("settings.unit.seconds", lang, Int(eye.settings.maxTimePerTarget)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    Stepper("", value: Binding(
                        get: { Int(eye.settings.maxTimePerTarget) },
                        set: { eye.settings.maxTimePerTarget = Double(max(1, min(5, $0))) }
                    ), in: 1...5).labelsHidden()
                }
            }

            labeledGlass(s("settings.eye.cooldown")) {
                HStack(spacing: 10) {
                    Text(L10n.fmt("settings.unit.minutes", lang, eye.settings.cooldownMinutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                        .lineLimit(1)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    Stepper("", value: Binding(
                        get: { eye.settings.cooldownMinutes },
                        set: { eye.settings.cooldownMinutes = max(15, min(180, $0)) }
                    ), in: 15...180, step: 15).labelsHidden()
                }
            }

            Button {
                NotificationCenter.default.post(name: .suggestEyeExercise, object: nil)
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
            } label: {
                Label(s("settings.eye.open_now"), systemImage: "eye.fill")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary))
        }
    }

    private var goalCareAdviceCard: some View {
        GlassCard {
            sectionHeader(
                s("goalcare.settings.title"),
                subtitle: s("goalcare.settings.subtitle"),
                icon: "bell.badge.fill",
                accent: Color(hex: 0x64D2FF)
            )

            toggleRow(
                icon: "heart.fill",
                title: s("goalcare.settings.toggle.title"),
                subtitle: s("goalcare.settings.toggle.subtitle"),
                isOn: $goalCareNotificationsEnabled
            )

            Label(s("goalcare.settings.policy"), systemImage: "moon.stars.fill")
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .onChange(of: goalCareNotificationsEnabled) { _, enabled in
            if enabled {
                NotificationCenter.default.post(name: .lippiCareDidChange, object: nil)
            } else {
                LippiCareNotificationScheduler.cancel()
            }
        }
    }

    private func refreshGoalCareAdvice() {
        let roadmap: GoalRoadmap?
        if let raw = UserDefaults.standard.string(forKey: GoalProgressNotificationScheduler.roadmapStorageKey),
           let data = raw.data(using: .utf8) {
            roadmap = try? JSONDecoder().decode(GoalRoadmap.self, from: data)
        } else {
            roadmap = nil
        }

        GoalCareNotificationScheduler.refresh(
            roadmap: roadmap,
            tasks: store.tasks,
            health: healthKit.isEnabled ? healthKit.recommendation : nil,
            userState: GoalUserState(rawValue: goalUserStateRaw) ?? .calm,
            lang: lang
        )
    }

    private var healthVoiceCard: some View {
        GlassCard(style: .lightweight) {
            sectionHeader(
                s("settings.voice.title"),
                subtitle: s("settings.voice.subtitle"),
                icon: "speaker.wave.3.fill",
                accent: Color(hex: 0x5AC8FA)
            )

            toggleRow(
                icon: "mic.fill",
                title: s("settings.voice.enabled_title"),
                subtitle: s("settings.voice.enabled_subtitle"),
                isOn: $healthVoiceEnabled
            )

            toggleRow(
                icon: "waveform.badge.magnifyingglass",
                title: s("settings.voice.auto_title"),
                subtitle: s("settings.voice.auto_subtitle"),
                isOn: $healthVoiceAutoSpeak
            )
            .disabled(!healthVoiceEnabled)
            .opacity(healthVoiceEnabled ? 1 : 0.62)

            HStack(alignment: .center, spacing: 10) {
                Image(safeSystemName: "dial.medium.fill", fallback: "slider.horizontal.3")
                    .foregroundStyle(DS.text(0.86))
                    .frame(width: 22, height: 22, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(s("settings.voice.speed_title"))
                        .foregroundStyle(DS.text(0.94))
                        .lineLimit(1)

                    Text(s("settings.voice.speed_subtitle"))
                        .font(.caption2)
                        .foregroundStyle(DS.text(0.55))
                        .lineLimit(2)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Menu {
                    ForEach(HealthVoicePlaybackSpeed.allCases) { speed in
                        Button {
                            guard selectedHealthVoiceSpeed != speed else { return }
                            healthVoiceSpeedRaw = speed.rawValue
                            #if os(iOS)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        } label: {
                            HStack {
                                Text(speed.title(lang))
                                if selectedHealthVoiceSpeed == speed {
                                    Spacer()
                                    Image(safeSystemName: "checkmark", fallback: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedHealthVoiceSpeed.title(lang))
                            .font(.caption.weight(.semibold))
                        Image(safeSystemName: "chevron.up.chevron.down", fallback: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(DS.text(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.glassFill(0.10), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .disabled(!healthVoiceEnabled)
            }
            .padding(.horizontal, rowHInset)
            .padding(.vertical, rowVInset)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DS.glassStroke(0.14))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.06), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .opacity(healthVoiceEnabled ? 1 : 0.62)

            if !healthVoiceEnabled {
                Text(s("settings.voice.disabled_hint"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.62))
                    .padding(.top, 2)
            }
        }
    }

    private var dataCard: some View {
        GlassCard {
            sectionHeader(
                t(.settings_data_title),
                subtitle: t(.settings_data_subtitle),
                icon: "tray.full.fill",
                accent: Color(hex: 0xFF453A)
            )

            Button(role: .destructive) { confirmClear = true } label: {
                Label(t(.settings_clear_tasks), systemImage: "trash.fill")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .destructive))
        }
    }

    private var onboardingReplayCard: some View {
        GlassCard(style: .lightweight, forceSystemGlass: !DS.runtimeConstrained) {
            sectionHeader(
                s("settings.onboarding.title"),
                subtitle: s("settings.onboarding.subtitle"),
                icon: "sparkles.rectangle.stack.fill",
                accent: Color(hex: 0x64D2FF)
            )

            Button {
                showsLippiOnboarding = true
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
                #endif
            } label: {
                Label(s("settings.onboarding.button"), systemImage: "play.fill")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                LippiButtonStyle(
                    kind: .primary,
                    forceSystemGlass: !DS.runtimeConstrained
                )
            )
            .accessibilityHint(s("settings.onboarding.hint"))
        }
    }

    // MARK: - UI helpers (polished elements)

    private func softGap() -> some View {
        Color.clear
            .frame(height: 6)
    }

    private func iconBadge(_ name: String, fallback: String) -> some View {
        Image(safeSystemName: name, fallback: fallback)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.text(0.92))
            .frame(width: 46, height: 46)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.16), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.10), .white.opacity(0.00)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            )
    }

    private func sectionHeader(
        _ title: String,
        subtitle: String,
        icon: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(DS.glassFill(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(accent.opacity(0.24))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        )

                    Image(safeSystemName: icon, fallback: "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.text(0.96))
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.text(0.94))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.text(0.62))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.46), accent.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.2)
        }
        .padding(.bottom, 4)
    }

    private func quickActionTile(
        icon: String,
        title: String,
        subtitle: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        } label: {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.glassFill(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accent.opacity(0.24))
                                .allowsHitTesting(false)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                                .allowsHitTesting(false)
                        )

                    Image(safeSystemName: icon, fallback: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.text(0.96))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.94))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DS.text(0.60))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DS.glassStroke(0.14))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.18), accent.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.95))
    }

    private func themeTile(_ theme: AppTheme) -> some View {
        let isSelected = selectedTheme == theme

        return Button {
            guard selectedTheme != theme else { return }
            themeRaw = theme.rawValue
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                themeAppearancePreview(theme)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(theme.name(lang: lang))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.text(0.94))
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        if isSelected {
                            Image(safeSystemName: "checkmark.circle.fill", fallback: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.accentColor)
                        }
                    }

                    Text(theme.subtitle(lang: lang))
                        .font(.caption2)
                        .foregroundStyle(DS.text(0.60))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.glassFill(isSelected ? 0.14 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? theme.accentColor.opacity(0.60) : DS.glassStroke(0.14), lineWidth: isSelected ? 1.2 : 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accentColor.opacity(isSelected ? 0.16 : 0.09), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .shadow(color: isSelected ? theme.accentColor.opacity(0.22) : .clear, radius: isSelected ? 6 : 0, x: 0, y: 3)
        }
        .buttonStyle(PressScaleStyle(scale: 0.988, opacity: 0.96))
    }

    private func themeAppearancePreview(_ theme: AppTheme) -> some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        return HStack(spacing: 1) {
            ZStack {
                Rectangle()
                    .fill(theme.previewLightGradient)

                Circle()
                    .fill(Color(hex: palette.glowA.lightHex, alpha: 0.24))
                    .frame(width: 58, height: 58)
                    .blur(radius: 9)
                    .offset(x: -18, y: -14)

                previewGlassCapsule(
                    theme: theme,
                    isDark: false,
                    icon: "sun.max.fill"
                )
            }

            ZStack {
                Rectangle()
                    .fill(theme.previewDarkGradient)

                Circle()
                    .fill(Color(hex: palette.glowB.darkHex, alpha: 0.18))
                    .frame(width: 62, height: 62)
                    .blur(radius: 11)
                    .offset(x: 20, y: 16)

                previewGlassCapsule(
                    theme: theme,
                    isDark: true,
                    icon: "moon.stars.fill"
                )
            }
        }
        .frame(height: 62)
        .clipShape(shape)
        .overlay(
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.72),
                            .white.opacity(0.16),
                            Color.black.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        )
        .accessibilityHidden(true)
    }

    private func previewGlassCapsule(
        theme: AppTheme,
        isDark: Bool,
        icon: String
    ) -> some View {
        Capsule(style: .continuous)
            .fill(
                Color(
                    hex: isDark ? 0xFFFFFF : 0xFFFFFF,
                    alpha: isDark ? 0.13 : 0.66
                )
            )
            .frame(width: 40, height: 27)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        Color.white.opacity(isDark ? 0.28 : 0.88),
                        lineWidth: 0.8
                    )
            )
            .overlay {
                Image(safeSystemName: icon, fallback: "circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        isDark
                            ? Color.white.opacity(0.88)
                            : Color(hex: theme.palette.accent)
                    )
            }
            .shadow(
                color: Color.black.opacity(isDark ? 0.24 : 0.10),
                radius: 5,
                x: 0,
                y: 3
            )
    }

    private func languageTile(_ option: AppLang) -> some View {
        let isSelected = lang == option

        return Button {
            guard lang != option else { return }
            langRaw = option.rawValue
            #if os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        } label: {
            HStack(spacing: 8) {
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(1)

                Spacer(minLength: 6)

                if isSelected {
                    Image(safeSystemName: "checkmark.circle.fill", fallback: "checkmark.circle")
                        .foregroundStyle(DS.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(DS.glassFill(isSelected ? 0.14 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DS.accent.opacity(0.56) : DS.glassStroke(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.988, opacity: 0.96))
    }

    private func statChip(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(safeSystemName: icon, fallback: "circle")
                .foregroundStyle(DS.text(0.86))
                .frame(width: 18, height: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.text(0.58))
                    .lineLimit(1)

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.top, 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.16), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
        )
    }

    private func actionRow(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(safeSystemName: icon, fallback: icon)
                    .foregroundStyle(DS.text(0.86))
                    .frame(width: 22, height: 22, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(DS.text(0.94))
                        .lineLimit(1)
                        .layoutPriority(2)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(DS.text(0.58))
                            .lineLimit(2)
                            .layoutPriority(1)
                    }
                }
                .padding(.vertical, 1)

                Spacer(minLength: 8)

                Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.32))
                    .baselineOffset(0.5)
            }
            .padding(.horizontal, rowHInset)
            .padding(.vertical, rowVInset)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DS.glassStroke(0.14))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.07), .white.opacity(0.00)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.95))
    }

    @ViewBuilder
    private func stepperRow(
        icon: String,
        title: String,
        subtitle: String,
        valueText: String,
        control: () -> some View
    ) -> some View {
        let rowLabel = HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.86))
                .frame(width: 22, height: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(2)
                    .layoutPriority(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.text(0.55))
                    .lineLimit(2)
                    .layoutPriority(1)
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        let trailingControl = VStack(alignment: .trailing, spacing: 6) {
            Text(valueText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.78))
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)

            control()
        }

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rowLabel
                    trailingControl
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    rowLabel
                    Spacer(minLength: 8)
                    trailingControl
                        .frame(width: rightColWidth, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, rowHInset)
        .padding(.vertical, rowVInset)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.glassStroke(0.14))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func ringtonePickerRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        let rowLabel = HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.86))
                .frame(width: 22, height: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(2)
                    .layoutPriority(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.text(0.55))
                    .lineLimit(2)
                    .layoutPriority(1)
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        let trailingControl = VStack(alignment: .trailing, spacing: 7) {
                Menu {
                    ForEach(PomodoroRingtone.allCases) { tone in
                        Button {
                            guard selectedPomodoroRingtone != tone else { return }
                            pomodoroRingtoneRaw = tone.rawValue
                            PomodoroRingtonePlayer.play(tone)
                            #if os(iOS)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        } label: {
                            HStack {
                                Text(tone.title(lang))
                                if selectedPomodoroRingtone == tone {
                                    Spacer()
                                    Image(safeSystemName: "checkmark", fallback: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedPomodoroRingtone.title(lang))
                            .font(.caption.weight(.semibold))
                        Image(safeSystemName: "chevron.up.chevron.down", fallback: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(DS.text(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 44)
                    .background(DS.glassFill(0.10), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

                Button {
                    PomodoroRingtonePlayer.play(selectedPomodoroRingtone)
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.58)
                    #endif
                } label: {
                    Label(s("settings.pomodoro.ringtone_preview"), systemImage: "play.fill")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .foregroundStyle(DS.text(0.84))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .background(DS.glassFill(0.10), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                                .allowsHitTesting(false)
                        )
                }
                .buttonStyle(PressScaleStyle(scale: 0.99, opacity: 0.96))
        }

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    rowLabel
                    trailingControl
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    rowLabel
                    Spacer(minLength: 8)
                    trailingControl
                        .frame(minWidth: rightColWidth, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, rowHInset)
        .padding(.vertical, rowVInset)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.glassStroke(0.14))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func toggleRow(icon: String, title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.86))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(1)
                    .layoutPriority(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DS.text(0.58))
                        .lineLimit(2)
                        .layoutPriority(1)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn).labelsHidden()
                .scaleEffect(0.95)
        }
        .padding(.horizontal, rowHInset)
        .padding(.vertical, rowVInset)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DS.glassStroke(0.14))
                .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func labeledGlass(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.68))
                .textCase(.uppercase)
                .tracking(0.6)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 10) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DS.glassStroke(0.14))
                        .allowsHitTesting(false)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.00)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                )
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Press scale button style (micro Apple-like feedback)
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.985
    var opacity: Double = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? opacity : 1)
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(
                reduceMotion ? nil : DS.motionPress,
                value: configuration.isPressed
            )
    }
}

// =======================================================
// MARK: - Countdown Settings Section (glass inputs)
// =======================================================
struct CountdownSettingsSection: View {
    @EnvironmentObject private var countdown: CountdownStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var title: String = ""
    @State private var date: Date = .now.addingTimeInterval(3600)

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(safeSystemName: "calendar.badge.clock", fallback: "calendar")
                    .foregroundStyle(DS.text(0.86))
                Text(s("settings.countdown.hint"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField(s("settings.countdown.name_placeholder"), text: $title)
                .textInputAutocapitalization(.sentences)
                .fieldGlass()
                .tint(DS.text(0.9))
                .foregroundStyle(DS.text(0.95))

            labeledGlass(s("settings.countdown.date_time")) {
                Image(safeSystemName: "clock.badge.checkmark", fallback: "clock")
                    .foregroundStyle(DS.text(0.78))

                DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(DS.text(0.9))
            }

            HStack(spacing: 10) {
                Button {
                    countdown.setEvent(title: title.isEmpty ? s("settings.countdown.default_event_title") : title, date: date)
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                } label: {
                    Label(s("settings.countdown.save"), systemImage: "checkmark.seal.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))

                Button(role: .destructive) { countdown.clear() } label: {
                    Label(s("settings.countdown.reset"), systemImage: "trash")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .destructive))
            }

            if let ev = countdown.event {
                HStack(alignment: .center, spacing: 10) {
                    Image(safeSystemName: "checkmark.circle.fill", fallback: "checkmark.circle")
                        .foregroundStyle(Color(hex: 0x30D158))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(s("settings.countdown.current"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.text(0.66))
                        Text(L10n.fmt("settings.countdown.current_value", lang, ev.title, ev.date.formatted(date: .abbreviated, time: .shortened)))
                            .font(.footnote)
                            .foregroundStyle(DS.text(0.92))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.glassStroke(0.14)))
            } else {
                HStack(spacing: 8) {
                    Image(safeSystemName: "exclamationmark.circle", fallback: "exclamationmark.circle")
                        .foregroundStyle(DS.text(0.62))
                    Text(s("settings.countdown.empty"))
                        .font(.footnote)
                        .foregroundStyle(DS.text(0.62))
                }
            }
        }
        .onAppear {
            if let ev = countdown.event { title = ev.title; date = ev.date }
        }
    }

    @ViewBuilder
    private func labeledGlass(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.68))
                .textCase(.uppercase)
                .tracking(0.5)
            HStack(spacing: 10) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.glassStroke(0.12)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.06), .white.opacity(0.00)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
        }
    }
}

// =======================================================
// MARK: - View Modifier for glass text fields
// =======================================================
extension View {
    func fieldGlass() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.glassTint)
                            .opacity(0.30)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.brandIridescent)
                            .blendMode(.screen)
                            .opacity(0.20)
                    )
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                tint: DS.accent.opacity(0.08),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(DS.glassStroke(0.08), lineWidth: 1)
                            .padding(1)
                            .allowsHitTesting(false)
                    )
            )
    }
}


// =======================================================
