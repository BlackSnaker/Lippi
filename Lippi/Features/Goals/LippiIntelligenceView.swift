import SwiftUI

struct LippiIntelligenceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(BonsaiConfiguration.enabledKey) private var isEnabled = BonsaiConfiguration.stored.isEnabled
    @StateObject private var modelStore = BonsaiModelStore.shared
    @State private var checkState: ModelCheckState = .idle

    private let cyan = Color(hex: 0x64D2FF)
    private let green = Color(hex: 0x30D158)
    private let purple = Color(hex: 0xBF5AF2)
    private let orange = Color(hex: 0xFF9F0A)

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var configuration: BonsaiConfiguration { BonsaiConfiguration(isEnabled: isEnabled) }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            ScrollView {
                LazyVStack(spacing: 24) {
                    informationSections
                    Color.clear.frame(height: 64)
                }
                .lippiContentColumn(maxWidth: 700, padding: 18)
            }
            .scrollIndicators(.hidden)
            .lippiScrollPerformance()
        }
        .navigationTitle(s("ai.info.nav_title"))
        .navigationBarTitleDisplayMode(.inline)
        .clearNavBarBackgroundIfAvailable()
        .onAppear { modelStore.refresh() }
        .onChange(of: isEnabled) { _, _ in checkState = .idle }
    }

    /// Small opaque section boundaries keep the physical-device SwiftUI tree
    /// shallow while each card remains lazy inside the scroll view.
    @ViewBuilder
    private var informationSections: some View {
        AnyView(heroCard.lippiMotionScene(0))
        AnyView(capabilitiesCard.lippiMotionScene(1))
        AnyView(localFlowCard.lippiMotionScene(2))
        AnyView(trustCard.lippiMotionScene(3))
        AnyView(controlCard.lippiMotionScene(4))
        AnyView(modelCard.lippiMotionScene(5))
    }

    private var heroCard: some View {
        GlassCard(padding: 0, cornerRadius: 32, style: .lightweight, forceSystemGlass: true) {
            VStack(alignment: .leading, spacing: 20) {
                Text(s("ai.info.eyebrow"))
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(cyan)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(cyan.opacity(0.09), in: Capsule())

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 16) {
                        intelligenceMark
                        heroTitle
                    }
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        intelligenceMark
                        heroTitle
                    }
                }

                Text(s("ai.info.hero_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                modelStatusPill
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [DS.accent.opacity(0.10), cyan.opacity(0.055), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
        }
    }

    private var heroTitle: some View {
        Text(s("ai.info.hero_title"))
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(DS.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var intelligenceMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DS.accent.opacity(0.28), cyan.opacity(0.16), purple.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.52), cyan.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.glassFill(0.14))
                .frame(width: 54, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                )

            Image(safeSystemName: "sparkles", fallback: "cpu.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DS.textPrimary, cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(green)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(DS.solidSurface, lineWidth: 2))
                .offset(x: 31, y: 27)
        }
        .frame(width: 88, height: 88)
        .lippiSystemGlass(in: Circle(), tint: cyan.opacity(0.09), prominent: true, forceSystemGlass: true)
        .accessibilityElement()
        .accessibilityLabel(s("ai.info.mark_accessibility"))
    }

    private var modelStatusPill: some View {
        let status = modelStatus
        return HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(status.color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(status.color.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var modelStatus: (text: String, color: Color) {
        guard isEnabled else { return (s("ai.info.status.disabled"), DS.textTertiary) }
        switch modelStore.state {
        case .missing: return (s("ai.info.status.missing"), DS.textTertiary)
        case .downloading: return (s("ai.info.status.downloading"), DS.accent)
        case .paused: return (s("ai.info.status.paused"), orange)
        case .verifying: return (s("ai.info.status.verifying"), cyan)
        case .ready: return (s("ai.info.status.ready"), green)
        case .failed: return (s("ai.info.status.attention"), orange)
        }
    }

    private var capabilitiesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            LippiSectionHeader(
                title: s("ai.info.capabilities_title"),
                subtitle: s("ai.info.capabilities_subtitle"),
                icon: "wand.and.stars",
                accent: purple
            )
            .padding(.horizontal, 4)

            capabilityRow(
                icon: "flag.checkered",
                title: s("ai.info.capability.goals.title"),
                detail: s("ai.info.capability.goals.detail"),
                tint: DS.accent
            )
            capabilityRow(
                icon: "chart.line.uptrend.xyaxis",
                title: s("ai.info.capability.progress.title"),
                detail: s("ai.info.capability.progress.detail"),
                tint: cyan
            )
            capabilityRow(
                icon: "heart.text.square.fill",
                title: s("ai.info.capability.wellbeing.title"),
                detail: s("ai.info.capability.wellbeing.detail"),
                tint: green
            )
        }
    }

    private func capabilityRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(safeSystemName: icon, fallback: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.08), DS.glassFill(0.055)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 23, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var localFlowCard: some View {
        GlassCard(padding: 22, cornerRadius: 30, style: .lightweight) {
            VStack(alignment: .leading, spacing: 20) {
                LippiSectionHeader(
                    title: s("ai.info.flow_title"),
                    subtitle: s("ai.info.flow_subtitle"),
                    icon: "arrow.triangle.branch",
                    accent: cyan
                )

                VStack(alignment: .leading, spacing: 0) {
                    flowStage(
                        number: "1",
                        title: s("ai.info.flow.context.title"),
                        detail: s("ai.info.flow.context.detail"),
                        tint: DS.accent
                    )
                    flowConnector
                    flowStage(
                        number: "2",
                        title: s("ai.info.flow.local.title"),
                        detail: s("ai.info.flow.local.detail"),
                        tint: cyan
                    )
                    flowConnector
                    flowStage(
                        number: "3",
                        title: s("ai.info.flow.result.title"),
                        detail: s("ai.info.flow.result.detail"),
                        tint: green
                    )
                }

                Text(s("ai.info.flow_friendly_note"))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func flowStage(number: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var flowConnector: some View {
        Rectangle()
            .fill(cyan.opacity(0.20))
            .frame(width: 1, height: 12)
            .padding(.leading, 31)
            .accessibilityHidden(true)
    }

    private var trustCard: some View {
        GlassCard(padding: 22, cornerRadius: 30, style: .lightweight, forceSystemGlass: true) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    Image(safeSystemName: "lock.shield.fill", fallback: "lock.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(green)
                        .frame(width: 46, height: 46)
                        .background(green.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(s("ai.info.privacy_title"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("ai.info.privacy_detail"))
                            .font(.subheadline)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        trustPill(icon: "desktopcomputer", text: s("ai.info.trust.no_mac"))
                        trustPill(icon: "cloud.slash.fill", text: s("ai.info.trust.no_cloud"))
                        trustPill(icon: "wifi.slash", text: s("ai.info.trust.offline"))
                    }
                } else {
                    HStack(spacing: 8) {
                        trustPill(icon: "desktopcomputer", text: s("ai.info.trust.no_mac"))
                        trustPill(icon: "cloud.slash.fill", text: s("ai.info.trust.no_cloud"))
                        trustPill(icon: "wifi.slash", text: s("ai.info.trust.offline"))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(s("ai.info.storage_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text(s("ai.info.storage_subtitle"))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                storageSummary

                Text(s("ai.info.storage_note"))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trustPill(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(green)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(green.opacity(0.09), in: Capsule())
    }

    private var storageSummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    storageValueWide("4,8", label: s("ai.info.storage.runtime"), tint: cyan)
                    storageValueWide("573", label: s("ai.info.storage.model"), tint: purple)
                    storageValueWide("≈577", label: s("ai.info.storage.total"), tint: green)
                }
            } else {
                HStack(spacing: 12) {
                    storageValue("4,8", label: s("ai.info.storage.runtime"), tint: cyan)
                    Rectangle().fill(DS.glassStroke(0.10)).frame(width: 1, height: 36)
                    storageValue("573", label: s("ai.info.storage.model"), tint: purple)
                    Rectangle().fill(DS.glassStroke(0.10)).frame(width: 1, height: 36)
                    storageValue("≈577", label: s("ai.info.storage.total"), tint: green)
                }
            }
        }
        .padding(16)
        .background(DS.glassFill(0.07), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func storageValue(_ value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                Text(s("ai.info.storage.mb"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.textTertiary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func storageValueWide(_ value: String, label: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text("\(value) \(s("ai.info.storage.mb"))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var controlCard: some View {
        GlassCard(padding: 22, cornerRadius: 30, style: .lightweight) {
            VStack(alignment: .leading, spacing: 17) {
                LippiSectionHeader(
                    title: s("ai.info.control_title"),
                    subtitle: s("ai.info.control_subtitle"),
                    icon: "person.crop.circle.badge.checkmark",
                    accent: green
                )

                friendlyRule(icon: "checkmark.circle.fill", text: s("ai.info.boundary.control"), tint: green, showsSurface: true)
                friendlyRule(icon: "heart.circle.fill", text: s("ai.info.boundary.health"), tint: cyan, showsSurface: true)
                friendlyRule(icon: "power.circle.fill", text: s("ai.info.boundary.choice"), tint: purple, showsSurface: true)
            }
        }
    }

    private func friendlyRule(icon: String, text: String, tint: Color, showsSurface: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(showsSurface ? 13 : 0)
        .background(
            tint.opacity(showsSurface ? 0.055 : 0),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var modelCard: some View {
        GlassCard(padding: 22, cornerRadius: 30, style: .lightweight) {
            VStack(alignment: .leading, spacing: 18) {
                modelHeader

                if modelStore.state == .downloading || modelStore.state == .paused {
                    VStack(spacing: 9) {
                        ProgressView(value: modelStore.progress)
                            .tint(DS.accent)
                        HStack {
                            Text(s(modelStore.state == .paused ? "settings.bonsai.paused" : "settings.bonsai.downloading"))
                            Spacer()
                            Text(modelStore.progress.formatted(.percent.precision(.fractionLength(0))))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                    }
                    .padding(14)
                    .background(DS.glassFill(0.06), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                } else if modelStore.state == .verifying {
                    HStack(spacing: 9) {
                        ProgressView().tint(DS.accent)
                        Text(s("settings.bonsai.verifying"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                    }
                } else if case .failed(let error) = modelStore.state {
                    friendlyRule(
                        icon: "exclamationmark.triangle.fill",
                        text: s(error.localizationKey),
                        tint: orange
                    )
                }

                modelActions

                if case .failed(let message) = checkState {
                    friendlyRule(icon: "exclamationmark.circle.fill", text: message, tint: orange)
                } else if checkState == .ready {
                    friendlyRule(icon: "checkmark.circle.fill", text: s("settings.bonsai.ready"), tint: green)
                }

                Link(destination: URL(string: "https://prismml.com")!) {
                    HStack(spacing: 5) {
                        Text(s("settings.bonsai.credit"))
                        Image(safeSystemName: "arrow.up.right", fallback: "arrow.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                }
            }
        }
    }

    private var modelHeader: some View {
        let presentation = modelCardPresentation
        return HStack(alignment: .top, spacing: 15) {
            Image(safeSystemName: presentation.icon, fallback: "cpu.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 48, height: 48)
                .background(presentation.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(presentation.detail)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private var modelCardPresentation: (icon: String, tint: Color, title: String, detail: String) {
        guard isEnabled else {
            return ("power", DS.textTertiary, s("ai.info.setup.disabled.title"), s("ai.info.setup.disabled.detail"))
        }
        switch modelStore.state {
        case .missing:
            return ("arrow.down.circle.fill", DS.accent, s("ai.info.setup.missing.title"), s("ai.info.setup.missing.detail"))
        case .downloading:
            return ("arrow.down.circle.fill", DS.accent, s("ai.info.setup.downloading.title"), s("ai.info.setup.downloading.detail"))
        case .paused:
            return ("pause.circle.fill", orange, s("ai.info.setup.paused.title"), s("ai.info.setup.paused.detail"))
        case .verifying:
            return ("checkmark.shield.fill", cyan, s("ai.info.setup.verifying.title"), s("ai.info.setup.verifying.detail"))
        case .ready:
            return ("checkmark.circle.fill", green, s("ai.info.setup.ready.title"), s("ai.info.setup.ready.detail"))
        case .failed:
            return ("arrow.clockwise.circle.fill", orange, s("ai.info.setup.failed.title"), s("ai.info.setup.failed.detail"))
        }
    }

    @ViewBuilder
    private var modelActions: some View {
        if !isEnabled {
            Button {
                isEnabled = true
            } label: {
                Label(s("ai.info.setup.enable"), systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary))
        } else {
            switch modelStore.state {
            case .missing, .failed:
                Button {
                    checkState = .idle
                    modelStore.startOrResumeDownload()
                } label: {
                    Label(s("settings.bonsai.download"), systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))

            case .downloading:
                HStack(spacing: 10) {
                    Button { modelStore.pauseDownload() } label: {
                        Label(s("settings.bonsai.pause"), systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))

                    cancelDownloadButton
                }

            case .paused:
                HStack(spacing: 10) {
                    Button { modelStore.startOrResumeDownload() } label: {
                        Label(s("settings.bonsai.resume"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary))

                    cancelDownloadButton
                }

            case .verifying:
                EmptyView()

            case .ready:
                Button {
                    Task { await checkModel() }
                } label: {
                    HStack(spacing: 8) {
                        if checkState == .checking {
                            ProgressView().tint(DS.text())
                        } else {
                            Image(safeSystemName: "bolt.horizontal.circle.fill", fallback: "bolt.circle")
                        }
                        Text(checkState == .checking ? s("settings.bonsai.checking") : s("settings.bonsai.check"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(checkState == .checking)
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }

    private var cancelDownloadButton: some View {
        Button {
            modelStore.cancelDownload()
        } label: {
            Image(safeSystemName: "xmark", fallback: "stop.fill")
                .frame(width: 44)
        }
        .buttonStyle(LippiButtonStyle(kind: .secondary))
        .accessibilityLabel(s("settings.bonsai.cancel"))
    }

    @MainActor
    private func checkModel() async {
        checkState = .checking
        do {
            let provider = BonsaiGoalProvider()
            try await provider.check(configuration: configuration)
            checkState = .ready
            DS.hapticSoft()
        } catch let error as BonsaiProviderError {
            checkState = .failed(error.message(lang: lang))
        } catch {
            checkState = .failed(BonsaiProviderError.generationFailed.message(lang: lang))
        }
    }

    private enum ModelCheckState: Equatable {
        case idle
        case checking
        case ready
        case failed(String)
    }
}
