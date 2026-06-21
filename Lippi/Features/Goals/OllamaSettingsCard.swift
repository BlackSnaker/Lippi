import SwiftUI

struct OllamaSettingsCard: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(OllamaConfiguration.enabledKey) private var isEnabled = false
    @AppStorage(OllamaConfiguration.endpointKey) private var endpoint = ""
    @AppStorage(OllamaConfiguration.modelKey) private var model = OllamaConfiguration.defaultModel
    @State private var state: ConnectionState = .idle

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var configuration: OllamaConfiguration {
        OllamaConfiguration(isEnabled: isEnabled, endpoint: endpoint, model: model)
    }

    var body: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("settings.ollama.title"),
                    subtitle: s("settings.ollama.subtitle"),
                    icon: "desktopcomputer",
                    accent: Color(hex: 0x64D2FF)
                )

                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s("settings.ollama.enabled"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("settings.ollama.enabled_hint"))
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
                .tint(DS.accent)
                .padding(14)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: DS.accent.opacity(0.06), interactive: true)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))

                if isEnabled {
                    field(title: s("settings.ollama.endpoint"), placeholder: "http://192.168.1.42:11434", text: $endpoint, keyboard: .URL)
                    field(title: s("settings.ollama.model"), placeholder: OllamaConfiguration.defaultModel, text: $model, keyboard: .default)

                    Button {
                        Task { await checkConnection() }
                    } label: {
                        HStack(spacing: 8) {
                            if state == .checking {
                                ProgressView().tint(DS.text())
                            } else {
                                Image(safeSystemName: "bolt.horizontal.circle.fill", fallback: "bolt.circle")
                            }
                            Text(state == .checking ? s("settings.ollama.checking") : s("settings.ollama.check"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(state == .checking)
                    .buttonStyle(LippiButtonStyle(kind: .secondary))

                    if state != .idle {
                        connectionState
                    }
                }
            }
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: DS.accent.opacity(0.05), interactive: true)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var connectionState: some View {
        let presentation = state.presentation(lang: lang)
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
    private func checkConnection() async {
        state = .checking
        do {
            let report = try await OllamaGoalProvider().check(configuration: configuration)
            state = report.configuredModelIsAvailable ? .ready : .modelMissing
            DS.hapticSoft()
        } catch let error as OllamaProviderError {
            state = .failed(error.message(lang: lang))
        } catch {
            state = .failed(OllamaProviderError.transport.message(lang: lang))
        }
    }

    private enum ConnectionState: Equatable {
        case idle
        case checking
        case ready
        case modelMissing
        case failed(String)

        func presentation(lang: AppLang) -> (icon: String, color: Color, text: String) {
            switch self {
            case .idle, .checking:
                return ("info.circle.fill", DS.textTertiary, "")
            case .ready:
                return ("checkmark.circle.fill", Color(hex: 0x30D158), L10n.tr("settings.ollama.ready", lang))
            case .modelMissing:
                return ("exclamationmark.triangle.fill", Color(hex: 0xFF9F0A), L10n.tr("settings.ollama.model_missing", lang))
            case .failed(let message):
                return ("wifi.exclamationmark", Color(hex: 0xFF9F0A), message)
            }
        }
    }
}
