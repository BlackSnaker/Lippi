import SwiftUI

enum LippiOnboarding {
    static let completedKey = "onboarding.lippi.completed.v1"
}

enum LippiOnboardingLaunchMode {
    case firstActivation
    case replay
}

private enum LippiOnboardingFeature: String, CaseIterable, Identifiable {
    case plan
    case focus
    case care

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .plan: return "point.topleft.down.curvedto.point.bottomright.up"
        case .focus: return "timer"
        case .care: return "heart.text.square.fill"
        }
    }

    var tone: Color {
        switch self {
        case .plan: return Color(hex: 0x0A84FF)
        case .focus: return Color(hex: 0x64D2FF)
        case .care: return Color(hex: 0x30D158)
        }
    }
}

struct LippiOnboardingView: View {
    let mode: LippiOnboardingLaunchMode
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage("goal.progress.userState") private var userStateRaw: String = GoalUserState.calm.rawValue
    @ObservedObject private var modelStore = BonsaiModelStore.shared

    @State private var step = 0
    @State private var selectedFeature: LippiOnboardingFeature = .plan
    @State private var navigationDirection: CGFloat = 1
    @GestureState private var pageDragOffset: CGFloat = 0

    private let stepCount = 4
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private var isLastStep: Bool { step == stepCount - 1 }
    private var allowsFullGlass: Bool { !DS.runtimeConstrained }
    private var selectedState: GoalUserState {
        GoalUserState(rawValue: userStateRaw) ?? .calm
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .offset(x: 46 * navigationDirection, y: 0))
                .combined(with: .scale(scale: 0.988)),
            removal: .opacity
                .combined(with: .offset(x: -30 * navigationDirection, y: 0))
                .combined(with: .scale(scale: 0.994))
        )
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($pageDragOffset) { value, state, transaction in
                guard !reduceMotion else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                transaction.animation = nil
                state = min(max(horizontal * 0.16, -42), 42)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 64, abs(horizontal) > abs(vertical) * 1.15 else { return }
                if horizontal < 0, !isLastStep {
                    nextStep()
                } else if horizontal > 0, step > 0 {
                    previousStep()
                }
            }
    }

    private var pageAccent: Color {
        switch step {
        case 0: return Color(hex: 0x0A84FF)
        case 1: return selectedState.tone
        case 2: return selectedFeature.tone
        default: return Color(hex: 0x30D158)
        }
    }

    private func s(_ key: String) -> String {
        L10n.tr(key, lang)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppBackdrop(renderMode: .force)

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, max(proxy.safeAreaInsets.top, 52) + 4)
                        .padding(.horizontal, 20)

                    page
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14) + 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .preferredColorScheme(nil)
        .accessibilityElement(children: .contain)
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            LippiGlassEffectGroup(spacing: 10) {
                HStack(spacing: 12) {
                    HStack(spacing: 9) {
                        Image(safeSystemName: "sparkles", fallback: "star.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(pageAccent)
                            .frame(width: 28, height: 28)

                        Text("Lippi")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.text(0.96))
                    }
                    .padding(.horizontal, 9)
                    .frame(minHeight: 38)
                    .background(DS.glassFill(0.055), in: Capsule())
                    .overlay(Capsule().stroke(DS.glassStroke(0.11), lineWidth: 1))
                    .lippiSystemGlass(
                        in: Capsule(style: .continuous),
                        tint: pageAccent.opacity(0.08),
                        prominent: true,
                        forceSystemGlass: allowsFullGlass
                    )

                    Spacer(minLength: 12)

                    Button(action: finish) {
                        Text(mode == .firstActivation ? s("onboarding.skip") : s("onboarding.close"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DS.text(0.76))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 44)
                            .background(DS.glassFill(0.055), in: Capsule())
                            .overlay(Capsule().stroke(DS.glassStroke(0.11), lineWidth: 1))
                            .lippiSystemGlass(
                                in: Capsule(style: .continuous),
                                tint: pageAccent.opacity(0.055),
                                interactive: true,
                                forceSystemGlass: allowsFullGlass
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(s("onboarding.close.hint"))
                }
            }

            LippiGlassEffectGroup(spacing: 7) {
                HStack(spacing: 7) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index <= step ? pageAccent.opacity(0.88) : DS.glassFill(0.10))
                            .frame(width: index == step ? 38 : 18, height: 6)
                            .lippiSystemGlass(
                                in: Capsule(style: .continuous),
                                tint: index <= step ? pageAccent.opacity(0.12) : nil,
                                prominent: index == step,
                                forceSystemGlass: allowsFullGlass
                            )
                    }
                }
            }
            .animation(reduceMotion ? nil : DS.motionState, value: step)
            .animation(reduceMotion ? nil : DS.motionState, value: pageAccent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(s("onboarding.progress"))
            .accessibilityValue("\(step + 1) / \(stepCount)")
        }
        .padding(12)
        .background(
            DS.glassFill(0.065),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DS.glassStroke(0.13), lineWidth: 1)
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 22, style: .continuous),
            tint: pageAccent.opacity(0.07),
            prominent: true,
            forceSystemGlass: allowsFullGlass
        )
    }

    @ViewBuilder
    private var page: some View {
        ScrollView {
            Group {
                switch step {
                case 0:
                    welcomePage
                case 1:
                    checkInPage
                case 2:
                    featuresPage
                default:
                    readyPage
                }
            }
            .id(step)
            .transition(pageTransition)
            .padding(.horizontal, 20)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 14 : 22)
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .offset(x: reduceMotion ? 0 : pageDragOffset)
        .scaleEffect(reduceMotion ? 1 : 1 - min(abs(pageDragOffset) / 3_600, 0.012))
        .simultaneousGesture(pageSwipeGesture)
        .animation(reduceMotion ? nil : DS.motionNavigate, value: step)
    }

    private var welcomePage: some View {
        VStack(spacing: 26) {
            onboardingMark(
                icon: "sparkles",
                accent: Color(hex: 0x0A84FF)
            )
            .lippiMotionScene(0, y: 7)

            titleBlock(
                eyebrow: s("onboarding.welcome.eyebrow"),
                title: s("onboarding.welcome.title"),
                subtitle: s("onboarding.welcome.subtitle")
            )
            .lippiMotionScene(1, y: 7)

            LippiGlassEffectGroup(spacing: 10) {
                HStack(spacing: 12) {
                    promise(icon: "checkmark", title: s("onboarding.welcome.promise.clear"))
                    promise(icon: "leaf.fill", title: s("onboarding.welcome.promise.calm"))
                    promise(icon: "lock.fill", title: s("onboarding.welcome.promise.private"))
                }
            }
            .lippiMotionScene(2, y: 7)
        }
    }

    private var checkInPage: some View {
        VStack(spacing: 20) {
            onboardingMark(
                icon: selectedState.icon,
                accent: selectedState.tone,
                compact: true
            )
            .lippiMotionScene(0, y: 7)

            titleBlock(
                eyebrow: s("onboarding.checkin.eyebrow"),
                title: s("onboarding.checkin.title"),
                subtitle: s("onboarding.checkin.subtitle")
            )
            .lippiMotionScene(1, y: 7)

            LippiGlassEffectGroup(spacing: 10) {
                VStack(spacing: 10) {
                    checkInChoice(
                        state: .overloaded,
                        title: s("onboarding.checkin.gentle.title"),
                        subtitle: s("onboarding.checkin.gentle.subtitle")
                    )
                    checkInChoice(
                        state: .calm,
                        title: s("onboarding.checkin.steady.title"),
                        subtitle: s("onboarding.checkin.steady.subtitle")
                    )
                    checkInChoice(
                        state: .energetic,
                        title: s("onboarding.checkin.energy.title"),
                        subtitle: s("onboarding.checkin.energy.subtitle")
                    )
                }
            }
            .lippiMotionScene(2, y: 7)

            Text(s("onboarding.checkin.footnote"))
                .font(.caption)
                .foregroundStyle(DS.text(0.58))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DS.glassFill(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DS.glassStroke(0.09), lineWidth: 1)
                )
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                    tint: selectedState.tone.opacity(0.045),
                    forceSystemGlass: allowsFullGlass
                )
                .lippiMotionScene(3, y: 7)
        }
    }

    private var featuresPage: some View {
        VStack(spacing: 20) {
            titleBlock(
                eyebrow: s("onboarding.features.eyebrow"),
                title: s("onboarding.features.title"),
                subtitle: s("onboarding.features.subtitle")
            )
            .lippiMotionScene(0, y: 7)

            LippiGlassEffectGroup(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(LippiOnboardingFeature.allCases) { feature in
                        featureButton(feature)
                    }
                }
            }
            .lippiMotionScene(1, y: 7)

            GlassCard(
                padding: 20,
                cornerRadius: 26,
                style: .lightweight,
                forceSystemGlass: allowsFullGlass
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(safeSystemName: selectedFeature.icon, fallback: "sparkles")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedFeature.tone)
                        .frame(width: 54, height: 54)
                        .background(selectedFeature.tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(selectedFeature.tone.opacity(0.18), lineWidth: 1)
                        )
                        .lippiSystemGlass(
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                            tint: selectedFeature.tone.opacity(0.10),
                            prominent: true,
                            forceSystemGlass: allowsFullGlass
                        )
                        .contentTransition(.symbolEffect(.replace))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(featureTitle(selectedFeature))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DS.text(0.96))
                        Text(featureDescription(selectedFeature))
                            .font(.body)
                            .foregroundStyle(DS.text(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label(s("onboarding.features.tap_hint"), systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.text(0.58))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(DS.glassFill(0.045), in: Capsule())
                        .overlay(Capsule().stroke(DS.glassStroke(0.08), lineWidth: 1))
                        .lippiSystemGlass(
                            in: Capsule(style: .continuous),
                            tint: selectedFeature.tone.opacity(0.045),
                            forceSystemGlass: allowsFullGlass
                        )
                }
                .id(selectedFeature)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
            }
            .animation(reduceMotion ? nil : DS.motionState, value: selectedFeature)
            .lippiMotionScene(2, y: 7)
        }
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            onboardingMark(
                icon: "checkmark",
                accent: Color(hex: 0x30D158)
            )
            .lippiMotionScene(0, y: 7)

            titleBlock(
                eyebrow: s("onboarding.ready.eyebrow"),
                title: s("onboarding.ready.title"),
                subtitle: s("onboarding.ready.subtitle")
            )
            .lippiMotionScene(1, y: 7)

            LippiGlassEffectGroup(spacing: 10) {
                VStack(spacing: 10) {
                    trustRow(icon: modelStatusIcon, text: modelStatusText, tone: modelStatusTone)
                    trustRow(icon: "slider.horizontal.3", text: s("onboarding.ready.control"), tone: Color(hex: 0x64D2FF))
                    trustRow(icon: "heart.fill", text: s("onboarding.ready.kind"), tone: Color(hex: 0x30D158))
                }
            }
            .lippiMotionScene(2, y: 7)
        }
    }

    private var modelStatusText: String {
        switch modelStore.state {
        case .ready:
            return s("onboarding.ready.model.ready")
        case .downloading:
            return L10n.fmt(
                "onboarding.ready.model.downloading",
                lang,
                Int((modelStore.progress * 100).rounded())
            )
        case .verifying:
            return s("onboarding.ready.model.verifying")
        case .failed:
            return s("onboarding.ready.model.attention")
        case .missing, .paused:
            return s("onboarding.ready.model.preparing")
        }
    }

    private var modelStatusIcon: String {
        switch modelStore.state {
        case .ready: return "checkmark.circle.fill"
        case .downloading: return "arrow.down.circle.fill"
        case .verifying: return "checkmark.shield.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .missing, .paused: return "sparkles"
        }
    }

    private var modelStatusTone: Color {
        switch modelStore.state {
        case .ready: return Color(hex: 0x30D158)
        case .failed: return Color(hex: 0xFF9F0A)
        default: return Color(hex: 0x0A84FF)
        }
    }

    private var footer: some View {
        LippiGlassEffectGroup(spacing: 10) {
            HStack(spacing: 10) {
                if step > 0 {
                    Button(action: previousStep) {
                        Image(safeSystemName: "chevron.left", fallback: "arrow.left")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 20, height: 20)
                            .accessibilityLabel(s("onboarding.back"))
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, forceSystemGlass: allowsFullGlass))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Button(action: nextStep) {
                    HStack(spacing: 8) {
                        Text(isLastStep ? s("onboarding.start") : s("onboarding.continue"))
                            .contentTransition(.opacity)
                        Image(safeSystemName: isLastStep ? "checkmark" : "arrow.right", fallback: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, forceSystemGlass: allowsFullGlass))
            }
        }
        .padding(.top, 10)
    }

    private func titleBlock(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(pageAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.glassFill(0.04), in: Capsule())
                .overlay(Capsule().stroke(DS.glassStroke(0.08), lineWidth: 1))
                .lippiSystemGlass(
                    in: Capsule(style: .continuous),
                    tint: pageAccent.opacity(0.045),
                    forceSystemGlass: allowsFullGlass
                )

            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(DS.text(0.97))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(DS.text(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func onboardingMark(
        icon: String,
        accent: Color,
        compact: Bool = false
    ) -> some View {
        Image(safeSystemName: icon, fallback: "sparkles")
            .font(.system(size: compact ? 30 : 36, weight: .semibold, design: .rounded))
            .foregroundStyle(accent)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: compact ? 74 : 88, height: compact ? 74 : 88)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 1)
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous),
                tint: accent.opacity(0.13),
                prominent: true,
                forceSystemGlass: allowsFullGlass
            )
            .accessibilityHidden(true)
    }

    private func promise(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(safeSystemName: icon, fallback: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: 0x0A84FF))
                .frame(width: 30, height: 30)
                .background(
                    Color(hex: 0x0A84FF).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(hex: 0x0A84FF).opacity(0.14), lineWidth: 1)
                )
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous),
                    tint: Color(hex: 0x0A84FF).opacity(0.08),
                    forceSystemGlass: allowsFullGlass
                )
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            tint: Color(hex: 0x0A84FF).opacity(0.055),
            prominent: true,
            forceSystemGlass: allowsFullGlass
        )
    }

    private func checkInChoice(state: GoalUserState, title: String, subtitle: String) -> some View {
        let isSelected = selectedState == state
        return Button {
            withAnimation(reduceMotion ? nil : DS.motionState) {
                userStateRaw = state.rawValue
            }
            DS.hapticSoft()
        } label: {
            HStack(spacing: 13) {
                Image(safeSystemName: state.icon, fallback: "square.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(state.tone)
                    .frame(width: 42, height: 42)
                    .background(state.tone.opacity(isSelected ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(state.tone.opacity(0.16), lineWidth: 1)
                    )
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                        tint: state.tone.opacity(0.08),
                        forceSystemGlass: allowsFullGlass
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DS.text(0.94))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.text(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(safeSystemName: "checkmark", fallback: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(state.tone)
                    .frame(width: 24, height: 24)
                    .opacity(isSelected ? 1 : 0)
                    .background(DS.glassFill(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DS.glassStroke(0.08), lineWidth: 1)
                    )
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous),
                        tint: state.tone.opacity(isSelected ? 0.08 : 0.025),
                        forceSystemGlass: allowsFullGlass
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.glassFill(isSelected ? 0.13 : 0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? state.tone.opacity(0.44) : DS.glassStroke(0.11), lineWidth: isSelected ? 1.4 : 1)
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                tint: state.tone.opacity(0.11),
                interactive: true,
                forceSystemGlass: allowsFullGlass
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : DS.motionState, value: isSelected)
    }

    private func featureButton(_ feature: LippiOnboardingFeature) -> some View {
        let isSelected = selectedFeature == feature
        return Button {
            withAnimation(reduceMotion ? nil : DS.motionState) {
                selectedFeature = feature
            }
            DS.hapticSoft()
        } label: {
            VStack(spacing: 8) {
                Image(safeSystemName: feature.icon, fallback: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(
                        feature.tone.opacity(isSelected ? 0.12 : 0.055),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(feature.tone.opacity(isSelected ? 0.16 : 0.08), lineWidth: 1)
                    )
                    .lippiSystemGlass(
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous),
                        tint: feature.tone.opacity(isSelected ? 0.08 : 0.035),
                        forceSystemGlass: allowsFullGlass
                    )
                Text(featureShortTitle(feature))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? feature.tone : DS.text(0.64))
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? feature.tone.opacity(0.13) : DS.glassFill(0.06), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(isSelected ? feature.tone.opacity(0.42) : DS.glassStroke(0.10), lineWidth: 1)
            )
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 19, style: .continuous),
                tint: feature.tone.opacity(0.11),
                interactive: true,
                forceSystemGlass: allowsFullGlass
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : DS.motionState, value: isSelected)
    }

    private func trustRow(icon: String, text: String, tone: Color) -> some View {
        HStack(spacing: 13) {
            Image(safeSystemName: icon, fallback: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 36, height: 36)
                .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tone.opacity(0.15), lineWidth: 1)
                )
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    tint: tone.opacity(0.08),
                    forceSystemGlass: allowsFullGlass
                )
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.text(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(DS.glassStroke(0.10), lineWidth: 1)
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 19, style: .continuous),
            tint: tone.opacity(0.05),
            prominent: true,
            forceSystemGlass: allowsFullGlass
        )
    }

    private func featureTitle(_ feature: LippiOnboardingFeature) -> String {
        s("onboarding.features.\(feature.rawValue).title")
    }

    private func featureShortTitle(_ feature: LippiOnboardingFeature) -> String {
        s("onboarding.features.\(feature.rawValue).short")
    }

    private func featureDescription(_ feature: LippiOnboardingFeature) -> String {
        s("onboarding.features.\(feature.rawValue).description")
    }

    private func nextStep() {
        guard !isLastStep else {
            finish()
            return
        }
        navigationDirection = 1
        withAnimation(reduceMotion ? nil : DS.motionNavigate) {
            step += 1
        }
        DS.hapticSoft()
    }

    private func previousStep() {
        guard step > 0 else { return }
        navigationDirection = -1
        withAnimation(reduceMotion ? nil : DS.motionNavigate) {
            step -= 1
        }
        DS.hapticSoft()
    }

    private func finish() {
        DS.hapticSoft()
        onFinish()
    }
}
