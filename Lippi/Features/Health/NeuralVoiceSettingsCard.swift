import SwiftUI

struct NeuralVoiceSettingsCard: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(NeuralVoiceConfiguration.enabledKey) private var isEnabled = true
    @AppStorage(NeuralVoiceConfiguration.endpointKey) private var endpoint = ""
    @State private var state: ConnectionState = .idle

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var configuration: NeuralVoiceConfiguration {
        NeuralVoiceConfiguration(isEnabled: isEnabled, endpoint: endpoint)
    }

    var body: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                LippiSectionHeader(
                    title: s("settings.neural_voice.title"),
                    subtitle: s("settings.neural_voice.subtitle"),
                    icon: "waveform.and.mic",
                    accent: Color(hex: 0xBF5AF2)
                )

                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s("settings.neural_voice.enabled"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(s("settings.neural_voice.enabled_hint"))
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
                .tint(Color(hex: 0xBF5AF2))
                .padding(14)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: Color(hex: 0xBF5AF2).opacity(0.08), interactive: true)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.glassStroke(0.14), lineWidth: 1))

                if isEnabled {
                    field(
                        title: s("settings.neural_voice.endpoint"),
                        placeholder: "http://Mac.local:8158",
                        text: $endpoint
                    )

                    Button {
                        Task { await checkConnection() }
                    } label: {
                        HStack(spacing: 8) {
                            if state == .checking {
                                ProgressView().tint(DS.textPrimary)
                            } else {
                                Image(safeSystemName: "bolt.horizontal.circle.fill", fallback: "bolt.circle")
                            }
                            Text(state == .checking ? s("settings.neural_voice.checking") : s("settings.neural_voice.check"))
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
        .onAppear {
            guard endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            endpoint = NeuralVoiceConfiguration.suggestedEndpoint
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .lippiSystemGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: Color(hex: 0xBF5AF2).opacity(0.06), interactive: true)
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
            let report = try await MacNeuralVoiceProvider().check(configuration: configuration)
            state = report.isReady ? .ready : .modelUnavailable
            DS.hapticSoft()
        } catch let error as NeuralVoiceProviderError {
            state = .failed(error.message(lang: lang))
        } catch {
            state = .failed(NeuralVoiceProviderError.transport.message(lang: lang))
        }
    }

    private enum ConnectionState: Equatable {
        case idle
        case checking
        case ready
        case modelUnavailable
        case failed(String)

        func presentation(lang: AppLang) -> (icon: String, color: Color, text: String) {
            switch self {
            case .idle, .checking:
                return ("info.circle.fill", DS.textTertiary, "")
            case .ready:
                return ("checkmark.circle.fill", Color(hex: 0x30D158), L10n.tr("settings.neural_voice.ready", lang))
            case .modelUnavailable:
                return ("exclamationmark.triangle.fill", Color(hex: 0xFF9F0A), L10n.tr("settings.neural_voice.model_unavailable", lang))
            case .failed(let message):
                return ("wifi.exclamationmark", Color(hex: 0xFF9F0A), message)
            }
        }
    }
}
