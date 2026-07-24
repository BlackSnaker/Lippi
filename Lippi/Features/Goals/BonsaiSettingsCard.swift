import SwiftUI

struct BonsaiSettingsCard: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(BonsaiConfiguration.enabledKey) private var isEnabled = BonsaiConfiguration.stored.isEnabled
    @StateObject private var modelStore = BonsaiModelStore.shared
    @State private var checkState: CheckState = .idle
    @State private var confirmsDeletion = false

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var configuration: BonsaiConfiguration { BonsaiConfiguration(isEnabled: isEnabled) }

    var body: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("settings.bonsai.title"),
                    subtitle: s("settings.bonsai.subtitle"),
                    icon: "cpu.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                informationLink

                privacyStrip
                providerToggle

                if isEnabled {
                    modelPanel
                    actionArea

                    if checkState != .idle {
                        checkPresentation
                    }
                }

                Link(destination: URL(string: "https://prismml.com")!) {
                    HStack(spacing: 6) {
                        Text(s("settings.bonsai.credit"))
                        Image(safeSystemName: "arrow.up.right", fallback: "arrow.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                }
            }
        }
        .onAppear { modelStore.refresh() }
        .onChange(of: isEnabled) { _, _ in checkState = .idle }
        .alert(s("settings.bonsai.delete_title"), isPresented: $confirmsDeletion) {
            Button(s("settings.bonsai.delete"), role: .destructive) {
                modelStore.deleteModel()
                checkState = .idle
            }
            Button(L10n.tr(.common_cancel, lang), role: .cancel) { }
        } message: {
            Text(s("settings.bonsai.delete_message"))
        }
    }

    private var informationLink: some View {
        NavigationLink {
            LippiIntelligenceView()
        } label: {
            HStack(spacing: 12) {
                Image(safeSystemName: "sparkles", fallback: "info.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x64D2FF))
                    .frame(width: 38, height: 38)
                    .background(Color(hex: 0x64D2FF).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(s("ai.info.entry_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(s("ai.info.entry_subtitle"))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(safeSystemName: "chevron.right", fallback: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(13)
            .background(DS.glassFill(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                tint: Color(hex: 0x64D2FF).opacity(0.07),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: 0x64D2FF).opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(s("ai.info.entry_hint"))
    }

    private var privacyStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: "lock.shield.fill", fallback: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0x30D158))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(s("settings.bonsai.private_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(s("settings.bonsai.private_hint"))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(hex: 0x30D158).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: 0x30D158).opacity(0.18), lineWidth: 1))
    }

    private var providerToggle: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s("settings.bonsai.enabled"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(s("settings.bonsai.enabled_hint"))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(DS.accent)
        .padding(14)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: DS.accent.opacity(0.06), interactive: true)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
    }

    private var modelPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(safeSystemName: "leaf.fill", fallback: "cpu.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 38, height: 38)
                    .background(DS.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(BonsaiModelDescriptor.recommended.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(s("settings.bonsai.model_detail"))
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                statusCapsule
            }

            if modelStore.state == .downloading || modelStore.state == .paused {
                VStack(spacing: 7) {
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
                .accessibilityElement(children: .combine)
                .accessibilityValue(modelStore.progress.formatted(.percent))
            } else if modelStore.state == .verifying {
                HStack(spacing: 9) {
                    ProgressView().tint(DS.accent)
                    Text(s("settings.bonsai.verifying"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                }
            } else if case .failed(let error) = modelStore.state {
                HStack(alignment: .top, spacing: 9) {
                    Image(safeSystemName: "exclamationmark.triangle.fill", fallback: "exclamationmark.circle.fill")
                        .foregroundStyle(Color(hex: 0xFF9F0A))
                    Text(s(error.localizationKey))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.glassStroke(0.12), lineWidth: 1))
    }

    @ViewBuilder
    private var actionArea: some View {
        switch modelStore.state {
        case .missing, .failed(_):
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

                Button { modelStore.cancelDownload() } label: {
                    Image(safeSystemName: "xmark", fallback: "stop.fill")
                        .frame(width: 44)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
                .accessibilityLabel(s("settings.bonsai.cancel"))
            }

        case .paused:
            HStack(spacing: 10) {
                Button { modelStore.startOrResumeDownload() } label: {
                    Label(s("settings.bonsai.resume"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))

                Button { modelStore.cancelDownload() } label: {
                    Image(safeSystemName: "xmark", fallback: "stop.fill")
                        .frame(width: 44)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
                .accessibilityLabel(s("settings.bonsai.cancel"))
            }

        case .verifying:
            EmptyView()

        case .ready:
            HStack(spacing: 10) {
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

                Button { confirmsDeletion = true } label: {
                    Image(safeSystemName: "trash", fallback: "xmark")
                        .frame(width: 44)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
                .accessibilityLabel(s("settings.bonsai.delete"))
            }
        }
    }

    private var statusCapsule: some View {
        let presentation = modelStatusPresentation
        return Text(presentation.text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(presentation.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(presentation.color.opacity(0.10), in: Capsule())
    }

    private var modelStatusPresentation: (text: String, color: Color) {
        switch modelStore.state {
        case .missing: return (s("settings.bonsai.not_installed"), DS.textTertiary)
        case .downloading: return (s("settings.bonsai.loading_short"), DS.accent)
        case .paused: return (s("settings.bonsai.paused_short"), Color(hex: 0xFF9F0A))
        case .verifying: return (s("settings.bonsai.verifying_short"), DS.accent)
        case .ready: return (s("settings.bonsai.ready_short"), Color(hex: 0x30D158))
        case .failed: return (s("settings.bonsai.error_short"), Color(hex: 0xFF9F0A))
        }
    }

    @ViewBuilder
    private var checkPresentation: some View {
        let presentation = checkState.presentation(lang: lang)
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: presentation.icon, fallback: "info.circle")
                .foregroundStyle(presentation.color)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 20)
            Text(presentation.text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(presentation.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(presentation.color.opacity(0.22), lineWidth: 1))
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

    private enum CheckState: Equatable {
        case idle
        case checking
        case ready
        case failed(String)

        func presentation(lang: AppLang) -> (icon: String, color: Color, text: String) {
            switch self {
            case .idle, .checking:
                return ("info.circle.fill", DS.textTertiary, "")
            case .ready:
                return ("checkmark.circle.fill", Color(hex: 0x30D158), L10n.tr("settings.bonsai.ready", lang))
            case .failed(let message):
                return ("exclamationmark.triangle.fill", Color(hex: 0xFF9F0A), message)
            }
        }
    }
}
