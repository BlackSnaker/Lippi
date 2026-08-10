import AVFoundation
import SwiftUI

struct NeuralVoiceSettingsCard: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(NeuralVoiceConfiguration.enabledKey) private var isEnabled = true
    @AppStorage(LocalNeuralVoiceProfile.storageKey) private var profileRaw =
        LocalNeuralVoiceProfile.defaultProfile.rawValue
    @AppStorage(HealthVoicePlaybackSpeed.storageKey) private var healthVoiceSpeedRaw =
        HealthVoicePlaybackSpeed.defaultSpeed.rawValue
    @StateObject private var modelStore = LocalVoiceModelStore.shared
    @State private var previewTask: Task<Void, Never>?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isGeneratingPreview = false
    @State private var isPlayingPreview = false
    @State private var previewErrorKey: String?
    @State private var previewRequestID = UUID()
    @State private var showsInstallationSuccess = false
    @State private var selectedIntonation: PhysiologicalVoiceState = .neutral

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var selectedProfile: LocalNeuralVoiceProfile {
        LocalNeuralVoiceProfile(rawValue: profileRaw) ?? .defaultProfile
    }
    private var selectedBaseSpeed: HealthVoicePlaybackSpeed {
        HealthVoicePlaybackSpeed(rawValue: healthVoiceSpeedRaw) ?? .defaultSpeed
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
                .background(
                    DS.glassFill(0.10),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .lippiSystemGlass(
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                    tint: Color(hex: 0xBF5AF2).opacity(0.08),
                    interactive: true
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.glassStroke(0.14), lineWidth: 1)
                )

                if isEnabled {
                    voicePicker
                    modelState

                    if showsInstallationSuccess {
                        installationSuccessBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    actionButtons

                    if modelStore.isReady {
                        intonationTester
                    }

                    if isPlayingPreview {
                        previewStatus(
                            icon: "waveform",
                            color: Color(hex: 0x30D158),
                            message: s("settings.neural_voice.preview_playing")
                        )
                    } else if let previewErrorKey {
                        previewStatus(
                            icon: "exclamationmark.triangle.fill",
                            color: Color(hex: 0xFF9F0A),
                            message: s(previewErrorKey)
                        )
                    }

                    Text(s("settings.neural_voice.thermal_hint"))
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            modelStore.refresh()
            handleInstallationReceipt(modelStore.installationReceipt)
        }
        .onChange(of: modelStore.installationReceipt) { _, receipt in
            handleInstallationReceipt(receipt)
        }
        .onChange(of: profileRaw) { _, _ in
            stopPreview()
        }
        .onChange(of: selectedIntonation) { _, _ in
            stopPreview()
        }
        .onDisappear {
            stopPreview()
        }
    }

    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s("settings.neural_voice.voice"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)

            Picker(
                s("settings.neural_voice.voice"),
                selection: $profileRaw
            ) {
                ForEach(LocalNeuralVoiceProfile.allCases) { profile in
                    Text(profile.title(lang)).tag(profile.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var intonationTester: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text(s("settings.neural_voice.intonation_title"))
                        .font(.subheadline.weight(.semibold))
                } icon: {
                    Image(safeSystemName: "waveform.path", fallback: "waveform")
                        .foregroundStyle(Color(hex: 0x5AC8FA))
                }

                Text(s("settings.neural_voice.intonation_subtitle"))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhysiologicalVoiceState.allCases, id: \.self) { state in
                        Button {
                            selectedIntonation = state
                            DS.hapticSoft()
                        } label: {
                            Text(intonationTitle(state))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(
                                    selectedIntonation == state
                                        ? Color.white
                                        : DS.text(0.78)
                                )
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    selectedIntonation == state
                                        ? Color(hex: 0x0A84FF).opacity(0.82)
                                        : DS.glassFill(0.10),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedIntonation == state
                                                ? Color(hex: 0x5AC8FA).opacity(0.72)
                                                : DS.glassStroke(0.14),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            selectedIntonation == state ? .isSelected : []
                        )
                    }
                }
            }

            primaryButton(
                title: intonationPreviewButtonTitle,
                icon: isGeneratingPreview || isPlayingPreview
                    ? "waveform"
                    : "play.circle.fill"
            ) {
                playIntonationPreview()
            }
            .disabled(isGeneratingPreview || isPlayingPreview)
        }
        .padding(14)
        .background(
            Color(hex: 0x0A84FF).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0x5AC8FA).opacity(0.20), lineWidth: 1)
        )
    }

    private func intonationTitle(_ state: PhysiologicalVoiceState) -> String {
        s("settings.neural_voice.intonation.\(state.rawValue)")
    }

    private var modelState: some View {
        let presentation = statePresentation
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(safeSystemName: presentation.icon, fallback: "info.circle")
                    .foregroundStyle(presentation.color)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(presentation.detail)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if case .downloading = modelStore.state {
                activeInstallationProgress
            } else if isInstallationActive {
                activeInstallationProgress
            }
        }
        .padding(12)
        .background(
            presentation.color.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(presentation.color.opacity(0.22), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch modelStore.state {
        case .missing, .failed:
            primaryButton(
                title: s("settings.neural_voice.download"),
                icon: "arrow.down.circle.fill"
            ) {
                modelStore.startOrResumeDownload()
            }

        case .downloading:
            primaryButton(
                title: s("settings.neural_voice.pause"),
                icon: "pause.circle.fill"
            ) {
                modelStore.pauseDownload()
            }

        case .retrying:
            primaryButton(
                title: s("settings.neural_voice.retry_now"),
                icon: "arrow.clockwise.circle.fill"
            ) {
                modelStore.startOrResumeDownload()
            }

        case .paused:
            primaryButton(
                title: s("settings.neural_voice.resume"),
                icon: "arrow.clockwise.circle.fill"
            ) {
                modelStore.startOrResumeDownload()
            }

        case .verifying, .decompressing, .installing:
            EmptyView()

        case .ready:
            HStack(spacing: 10) {
                primaryButton(
                    title: previewButtonTitle,
                    icon: isGeneratingPreview || isPlayingPreview
                        ? "waveform"
                        : "play.circle.fill"
                ) {
                    playPreview()
                }
                .disabled(isGeneratingPreview || isPlayingPreview)

                Button(role: .destructive) {
                    stopPreview()
                    modelStore.deleteModel()
                } label: {
                    Image(safeSystemName: "trash", fallback: "xmark.circle")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
                .accessibilityLabel(s("settings.neural_voice.delete"))
            }
        }
    }

    private func primaryButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isGeneratingPreview && title == s("settings.neural_voice.previewing") {
                    ProgressView().tint(DS.textPrimary)
                } else {
                    Image(safeSystemName: icon, fallback: "circle.fill")
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LippiButtonStyle(kind: .secondary))
    }

    private var previewButtonTitle: String {
        if isGeneratingPreview {
            return s("settings.neural_voice.previewing")
        }
        if isPlayingPreview {
            return s("settings.neural_voice.preview_playing")
        }
        return s("settings.neural_voice.preview")
    }

    private var intonationPreviewButtonTitle: String {
        if isGeneratingPreview {
            return s("settings.neural_voice.previewing")
        }
        if isPlayingPreview {
            return s("settings.neural_voice.preview_playing")
        }
        return s("settings.neural_voice.intonation_play")
    }

    private var isInstallationActive: Bool {
        switch modelStore.state {
        case .downloading, .retrying, .paused, .verifying, .decompressing,
             .installing:
            return true
        case .missing, .ready, .failed:
            return false
        }
    }

    private var activeInstallationProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            installationStageRail

            switch modelStore.state {
            case .downloading, .paused, .retrying:
                ProgressView(value: modelStore.progress)
                    .tint(Color(hex: 0x0A84FF))

                HStack(spacing: 8) {
                    Text(downloadAmountText)
                    Spacer(minLength: 8)
                    Text("\(Int(modelStore.progress * 100))%")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DS.textTertiary)

                if modelStore.downloadBytesPerSecond > 0 {
                    HStack(spacing: 8) {
                        Text(
                            L10n.fmt(
                                "settings.neural_voice.download_speed",
                                lang,
                                formattedBytes(Int64(modelStore.downloadBytesPerSecond))
                            )
                        )
                        Spacer(minLength: 8)
                        if let remaining = modelStore.estimatedTimeRemaining {
                            Text(
                                L10n.fmt(
                                    "settings.neural_voice.time_remaining",
                                    lang,
                                    formattedDuration(remaining)
                                )
                            )
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.textTertiary)
                }

            case .verifying, .decompressing:
                ProgressView()
                    .tint(Color(hex: 0x0A84FF))
                    .frame(maxWidth: .infinity, alignment: .leading)
                elapsedPhaseLabel

            case .installing:
                ProgressView(value: modelStore.progress)
                    .tint(Color(hex: 0x30D158))
                HStack(spacing: 8) {
                    Text(
                        L10n.fmt(
                            "settings.neural_voice.install_progress",
                            lang,
                            Int(modelStore.progress * 100)
                        )
                    )
                    Spacer(minLength: 8)
                    elapsedPhaseLabel
                }

            case .missing, .ready, .failed:
                EmptyView()
            }
        }
    }

    private var installationStageRail: some View {
        let current = currentInstallationStage
        let stages = [
            ("arrow.down.circle.fill", "settings.neural_voice.phase.download"),
            ("checkmark.shield.fill", "settings.neural_voice.phase.verify"),
            ("archivebox.fill", "settings.neural_voice.phase.unpack"),
            ("shippingbox.fill", "settings.neural_voice.phase.install")
        ]

        return HStack(spacing: 5) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                VStack(spacing: 5) {
                    Image(
                        safeSystemName: index < current
                            ? "checkmark.circle.fill"
                            : stage.0,
                        fallback: index < current ? "checkmark.circle.fill" : "circle.fill"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        index <= current
                            ? Color(hex: index < current ? 0x30D158 : 0x0A84FF)
                            : DS.textTertiary
                    )

                    Text(s(stage.1))
                        .font(.system(size: 9, weight: index == current ? .bold : .medium))
                        .foregroundStyle(index <= current ? DS.textSecondary : DS.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var currentInstallationStage: Int {
        switch modelStore.state {
        case .missing, .downloading, .retrying, .paused, .failed:
            return 0
        case .verifying:
            return 1
        case .decompressing:
            return 2
        case .installing:
            return 3
        case .ready:
            return 4
        }
    }

    private var downloadAmountText: String {
        "\(formattedBytes(modelStore.downloadedBytes)) / \(formattedBytes(modelStore.totalDownloadBytes))"
    }

    private var elapsedPhaseLabel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(
                L10n.fmt(
                    "settings.neural_voice.elapsed",
                    lang,
                    formattedDuration(
                        context.date.timeIntervalSince(modelStore.phaseStartedAt)
                    )
                )
            )
            .font(.caption2.monospacedDigit())
            .foregroundStyle(DS.textTertiary)
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(bytes, 0), countStyle: .file)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let seconds = max(Int(duration.rounded()), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var installationSuccessBanner: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(safeSystemName: "checkmark.seal.fill", fallback: "checkmark.circle.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color(hex: 0x30D158))

            VStack(alignment: .leading, spacing: 3) {
                Text(s("settings.neural_voice.installation_complete"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                Text(s("settings.neural_voice.installation_complete_hint"))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showsInstallationSuccess = false
                }
            } label: {
                Image(safeSystemName: "xmark", fallback: "xmark.circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(s("common.close"))
        }
        .padding(13)
        .background(
            Color(hex: 0x30D158).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color(hex: 0x30D158).opacity(0.30), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func previewStatus(
        icon: String,
        color: Color,
        message: String
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(safeSystemName: icon, fallback: "info.circle.fill")
                .foregroundStyle(color)
            Text(message)
                .font(.caption)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private var statePresentation: (
        icon: String,
        color: Color,
        title: String,
        detail: String
    ) {
        let size = LocalVoiceModelDescriptor.recommended.formattedDownloadSize
        switch modelStore.state {
        case .missing:
            return (
                "arrow.down.circle.fill",
                Color(hex: 0xBF5AF2),
                s("settings.neural_voice.model_missing"),
                L10n.fmt("settings.neural_voice.model_missing_hint", lang, size)
            )
        case .downloading:
            return (
                "arrow.down.circle.fill",
                Color(hex: 0x0A84FF),
                s("settings.neural_voice.downloading"),
                s("settings.neural_voice.downloading_hint")
            )
        case .retrying(let attempt, let seconds):
            return (
                "arrow.clockwise.circle.fill",
                Color(hex: 0xFF9F0A),
                s("settings.neural_voice.retrying"),
                L10n.fmt(
                    "settings.neural_voice.retrying_hint",
                    lang,
                    attempt,
                    seconds
                )
            )
        case .paused:
            return (
                "pause.circle.fill",
                Color(hex: 0xFF9F0A),
                s("settings.neural_voice.paused"),
                s("settings.neural_voice.paused_hint")
            )
        case .verifying:
            return (
                "checkmark.shield.fill",
                Color(hex: 0x0A84FF),
                s("settings.neural_voice.verifying"),
                s("settings.neural_voice.verifying_hint")
            )
        case .decompressing:
            return (
                "archivebox.fill",
                Color(hex: 0x0A84FF),
                s("settings.neural_voice.decompressing"),
                s("settings.neural_voice.decompressing_hint")
            )
        case .installing:
            return (
                "shippingbox.fill",
                Color(hex: 0x0A84FF),
                s("settings.neural_voice.installing"),
                s("settings.neural_voice.installing_hint")
            )
        case .ready:
            return (
                "checkmark.circle.fill",
                Color(hex: 0x30D158),
                s("settings.neural_voice.ready"),
                s("settings.neural_voice.ready_hint")
            )
        case .failed(let error):
            return (
                "exclamationmark.triangle.fill",
                Color(hex: 0xFF9F0A),
                s("settings.neural_voice.failed"),
                s(error.localizationKey)
            )
        }
    }

    private func playPreview(
        phraseKey: String = "settings.neural_voice.preview_phrase",
        prosody: VoiceProsodyProfile = .neutral
    ) {
        stopPreview()
        isGeneratingPreview = true
        previewErrorKey = nil
        let profile = selectedProfile
        let phrase = s(phraseKey)
        let speed = selectedBaseSpeed.neuralSpeed
        let requestID = UUID()
        previewRequestID = requestID

        previewTask = Task {
            do {
                let audio = try await LocalNeuralVoiceProvider.shared.synthesize(
                    phrase,
                    language: lang,
                    speed: speed,
                    profile: profile,
                    prosody: prosody,
                    quality: .maximum
                )
                guard !Task.isCancelled, previewRequestID == requestID else { return }
                #if os(iOS)
                let session = AVAudioSession.sharedInstance()
                // Do not discard a valid generated WAV when Simulator is
                // temporarily rebuilding its host CoreAudio route.
                try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try? session.setActive(true)
                #endif
                let player = try AVAudioPlayer(data: audio)
                player.volume = 1
                guard player.prepareToPlay(), player.play() else {
                    throw NeuralVoicePreviewError.playback
                }
                previewPlayer = player
                isGeneratingPreview = false
                isPlayingPreview = true
                DS.hapticSoft()

                let playbackNanoseconds = UInt64(
                    max(player.duration + 0.2, 0.2) * 1_000_000_000
                )
                try await Task.sleep(nanoseconds: playbackNanoseconds)
                guard previewRequestID == requestID else { return }
                isPlayingPreview = false
                previewPlayer = nil
                #if os(iOS)
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
                #endif
            } catch is CancellationError {
                return
            } catch let error as NeuralVoiceProviderError {
                guard !Task.isCancelled, previewRequestID == requestID else { return }
                isGeneratingPreview = false
                isPlayingPreview = false
                previewErrorKey = error.localizationKey
            } catch {
                guard !Task.isCancelled, previewRequestID == requestID else { return }
                isGeneratingPreview = false
                isPlayingPreview = false
                previewErrorKey = "settings.neural_voice.preview_error"
            }
        }
    }

    private func playIntonationPreview() {
        let decision = VoicePolicy.previewDecision(for: selectedIntonation)
        playPreview(
            phraseKey: "settings.neural_voice.intonation_phrase",
            prosody: decision.prosody
        )
    }

    private func stopPreview() {
        previewRequestID = UUID()
        previewTask?.cancel()
        previewTask = nil
        previewPlayer?.stop()
        previewPlayer = nil
        isGeneratingPreview = false
        isPlayingPreview = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        #endif
    }

    private func handleInstallationReceipt(_ receipt: UUID?) {
        guard let receipt else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showsInstallationSuccess = true
        }
        DS.hapticSoft()
        modelStore.consumeInstallationReceipt(receipt)
    }
}

private enum NeuralVoicePreviewError: Error {
    case playback
}
