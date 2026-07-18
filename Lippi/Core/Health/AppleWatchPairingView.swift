import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AppleWatchPairingView: View {
    @ObservedObject var manager: HealthKitManager
    @Binding var hasCompletedOnboarding: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    @State private var stage: PairingStage = .introduction
    @State private var connectionStep = 0
    @State private var heroDrift = false
    @State private var orbitRotation = false
    @State private var pairingTask: Task<Void, Never>?
    @State private var isOpeningSystemSettings = false
    @State private var showsSettingsNavigationError = false

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                cinematicBackdrop(size: proxy.size)

                if stage == .connecting || stage == .diagnosing {
                    connectionOrbit(size: proxy.size)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, max(10, proxy.safeAreaInsets.top + 4))

                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: max(300, min(410, proxy.size.height * 0.46)))
                                .accessibilityHidden(true)

                            pairingCard
                                .padding(.horizontal, 16)
                                .padding(.bottom, max(14, proxy.safeAreaInsets.bottom + 8))
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startAmbientMotion()
            if manager.isEnabled {
                diagnoseExistingConnection()
            }
        }
        .onDisappear {
            pairingTask?.cancel()
            pairingTask = nil
        }
        .animation(reduceMotion ? nil : DS.motionState, value: stage)
        .interactiveDismissDisabled(stage == .connecting || stage == .diagnosing || isOpeningSystemSettings)
        .onChange(of: scenePhase) { oldValue, newValue in
            guard oldValue != .active,
                  newValue == .active,
                  stage == .needsAttention else { return }
            diagnoseExistingConnection()
        }
        .alert(s("watch.pairing.settings.error.title"), isPresented: $showsSettingsNavigationError) {
            Button(s("watch.pairing.settings.error.ok"), role: .cancel) {}
        } message: {
            Text(s("watch.pairing.settings.error.message"))
        }
    }

    private func cinematicBackdrop(size: CGSize) -> some View {
        ZStack {
            Color(red: 0.005, green: 0.012, blue: 0.035)

            Image("WatchPairingHero")
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(heroDrift ? 1.045 : 1.015)
                .offset(y: heroDrift ? -8 : 4)
                .clipped()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.54),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color(hex: 0x0A84FF).opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 20,
                endRadius: min(size.width, 420)
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(safeSystemName: "heart.fill", fallback: "circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xFF375F), Color(hex: 0xBF5AF2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Text("Lippi")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(safeSystemName: "xmark", fallback: "multiply")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.94, opacity: 0.82))
            .background(Color.white.opacity(reduceTransparency ? 0.14 : 0.07), in: Circle())
            .lippiSystemGlass(in: Circle(), tint: Color.white.opacity(0.04))
            .disabled(stage == .connecting || stage == .diagnosing || isOpeningSystemSettings)
            .opacity(stage == .connecting || stage == .diagnosing || isOpeningSystemSettings ? 0.42 : 1)
            .accessibilityLabel(Text(s("watch.pairing.close")))
        }
        .padding(.horizontal, 18)
    }

    private func connectionOrbit(size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            Circle()
                .trim(from: 0.05, to: 0.34)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: 0x64D2FF).opacity(0.05),
                            Color(hex: 0x64D2FF),
                            Color(hex: 0xBF5AF2),
                            Color.clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .rotationEffect(.degrees(orbitRotation ? 360 : 0))

            Circle()
                .fill(Color(hex: 0x64D2FF))
                .frame(width: 7, height: 7)
                .shadow(color: Color(hex: 0x64D2FF), radius: 8)
                .offset(y: -145)
                .rotationEffect(.degrees(orbitRotation ? 360 : 0))
        }
        .frame(width: min(310, size.width * 0.74), height: min(310, size.width * 0.74))
        .position(x: size.width / 2, y: size.height * 0.40)
        .animation(
            reduceMotion ? nil : .linear(duration: 2.8).repeatForever(autoreverses: false),
            value: orbitRotation
        )
        .accessibilityHidden(true)
    }

    private var pairingCard: some View {
        GlassCard(
            padding: 18,
            cornerRadius: 32,
            style: .full,
            forceSystemGlass: true
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    switch stage {
                    case .introduction:
                        introductionContent
                    case .connecting:
                        connectingContent
                    case .diagnosing:
                        diagnosingContent
                    case .ready:
                        readyContent
                    case .needsAttention:
                        diagnosticsContent
                    case .failed:
                        failedContent
                    }
                }
                .id(stage)
                .transition(
                    reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .bottom))
                )

                primaryButton
            }
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    private var introductionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            pairingEyebrow(
                title: s("watch.pairing.eyebrow"),
                icon: "applewatch",
                tone: Color(hex: 0x64D2FF)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(s("watch.pairing.title"))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(s("watch.pairing.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 9) {
                PairingBenefitRow(
                    icon: "waveform.path.ecg",
                    title: s("watch.pairing.benefit.pace"),
                    tone: Color(hex: 0x64D2FF)
                )
                PairingBenefitRow(
                    icon: "lock.shield.fill",
                    title: s("watch.pairing.benefit.private"),
                    tone: Color(hex: 0x30D158)
                )
                PairingBenefitRow(
                    icon: "hand.raised.fill",
                    title: s("watch.pairing.benefit.control"),
                    tone: Color(hex: 0xBF5AF2)
                )
            }
        }
    }

    private var connectingContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            pairingEyebrow(
                title: s("watch.pairing.connecting.eyebrow"),
                icon: "antenna.radiowaves.left.and.right",
                tone: Color(hex: 0x64D2FF)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(s("watch.pairing.connecting.title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(s("watch.pairing.connecting.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                connectionRow(index: 0, title: s("watch.pairing.step.health"))
                connectionRow(index: 1, title: s("watch.pairing.step.privacy"))
                connectionRow(index: 2, title: s("watch.pairing.step.watch"))
            }
        }
    }

    private var diagnosingContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            pairingEyebrow(
                title: s("watch.pairing.diagnostics.eyebrow"),
                icon: "stethoscope",
                tone: Color(hex: 0x64D2FF)
            )

            Text(s("watch.pairing.diagnostics.checking.title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                ProgressView()
                    .tint(Color(hex: 0x64D2FF))
                Text(s("watch.pairing.diagnostics.checking.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var diagnosticsContent: some View {
        let report = manager.diagnosticReport

        return VStack(alignment: .leading, spacing: 14) {
            pairingEyebrow(
                title: s("watch.pairing.diagnostics.eyebrow"),
                icon: "wrench.and.screwdriver.fill",
                tone: report.status == .unavailable ? Color(hex: 0xFF453A) : Color(hex: 0xFF9F0A)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(s("watch.pairing.diagnostics.\(report.status.rawValue).title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(s("watch.pairing.diagnostics.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(Array(report.issues.prefix(3))) { issue in
                    diagnosticIssueRow(issue)
                }
            }

            if report.availableDataGroups > 0 {
                Label(
                    L10n.fmt(
                        "watch.pairing.diagnostics.coverage",
                        lang,
                        report.availableDataGroups,
                        report.totalDataGroups
                    ),
                    systemImage: "chart.bar.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if report.primaryRecoveryAction == .openSettings {
                Label(s("watch.pairing.settings.route"), systemImage: "arrow.up.forward.app.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if report.primaryRecoveryAction != .refresh {
                Button {
                    diagnoseExistingConnection()
                } label: {
                    Label(s("watch.pairing.diagnostics.recheck"), systemImage: "arrow.clockwise")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
            }
        }
    }

    private func diagnosticIssueRow(_ issue: HealthKitDiagnosticIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(safeSystemName: diagnosticIcon(for: issue), fallback: "exclamationmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(diagnosticTone(for: issue))
                .frame(width: 30, height: 30)
                .background(diagnosticTone(for: issue).opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(s("watch.pairing.diagnostics.issue.\(issue.rawValue)"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func diagnosticIcon(for issue: HealthKitDiagnosticIssue) -> String {
        switch issue {
        case .healthDataUnavailable, .healthDataRestricted: return "lock.trianglebadge.exclamationmark.fill"
        case .deviceLocked: return "lock.fill"
        case .authorizationNeeded, .authorizationCancelled, .authorizationDenied: return "hand.raised.fill"
        case .noReadableData: return "heart.text.square"
        case .watchDataNotFound, .watchDataStale: return "applewatch.slash"
        case .mindfulWriteDenied: return "square.and.pencil"
        case .backgroundRefreshUnavailable: return "arrow.clockwise.icloud"
        case .refreshFailed: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    private func diagnosticTone(for issue: HealthKitDiagnosticIssue) -> Color {
        switch issue {
        case .healthDataUnavailable, .healthDataRestricted: return Color(hex: 0xFF453A)
        case .deviceLocked, .authorizationNeeded, .authorizationCancelled, .authorizationDenied, .refreshFailed:
            return Color(hex: 0xFF9F0A)
        case .noReadableData, .watchDataNotFound, .watchDataStale, .mindfulWriteDenied, .backgroundRefreshUnavailable:
            return Color(hex: 0x64D2FF)
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            pairingEyebrow(
                title: s("watch.pairing.ready.eyebrow"),
                icon: "checkmark.circle.fill",
                tone: Color(hex: 0x30D158)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(s("watch.pairing.ready.title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(s("watch.pairing.ready.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(s("watch.pairing.ready.hint"), systemImage: "heart.text.square.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
    }

    private var failedContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            pairingEyebrow(
                title: s("watch.pairing.failed.eyebrow"),
                icon: "exclamationmark.circle.fill",
                tone: Color(hex: 0xFF9F0A)
            )

            Text(s("watch.pairing.failed.title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(s("watch.pairing.failed.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pairingEyebrow(title: String, icon: String, tone: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(tone)
            .labelStyle(TightLabelStyle())
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tone.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(tone.opacity(0.24), lineWidth: 1))
    }

    private func connectionRow(index: Int, title: String) -> some View {
        let isComplete = connectionStep > index
        let isActive = connectionStep == index

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((isComplete ? Color(hex: 0x30D158) : Color.white).opacity(isComplete ? 0.18 : 0.08))

                if isComplete {
                    Image(safeSystemName: "checkmark", fallback: "circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: 0x30D158))
                } else if isActive {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Color(hex: 0x64D2FF))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(width: 28, height: 28)

            Text(title)
                .font(.footnote.weight(isActive ? .semibold : .medium))
                .foregroundStyle(.white.opacity(isComplete || isActive ? 0.86 : 0.48))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : DS.motionQuick, value: connectionStep)
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            HStack(spacing: 9) {
                if stage == .connecting || stage == .diagnosing || isOpeningSystemSettings {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(safeSystemName: primaryButtonIcon, fallback: "arrow.right")
                }

                Text(primaryButtonTitle)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
        .disabled(stage == .connecting || stage == .diagnosing || isOpeningSystemSettings)
    }

    private var primaryButtonTitle: String {
        if isOpeningSystemSettings {
            return s("watch.pairing.recovery.openingSettings")
        }
        switch stage {
        case .introduction: return s("watch.pairing.continue")
        case .connecting: return s("watch.pairing.connecting.button")
        case .diagnosing: return s("watch.pairing.diagnostics.checking.button")
        case .ready: return s("watch.pairing.done")
        case .needsAttention:
            return s("watch.pairing.recovery.\(manager.diagnosticReport.primaryRecoveryAction.rawValue)")
        case .failed: return s("watch.pairing.retry")
        }
    }

    private var primaryButtonIcon: String {
        switch stage {
        case .introduction: return "arrow.right"
        case .connecting: return "circle"
        case .diagnosing: return "stethoscope"
        case .ready: return "checkmark"
        case .needsAttention:
            switch manager.diagnosticReport.primaryRecoveryAction {
            case .none: return "checkmark"
            case .requestAccess: return "hand.raised.fill"
            case .refresh: return "arrow.clockwise"
            case .openSettings: return "gearshape.fill"
            case .retryAfterUnlock: return "lock.open.fill"
            }
        case .failed: return "arrow.clockwise"
        }
    }

    private func handlePrimaryAction() {
        switch stage {
        case .introduction, .failed:
            beginPairing()
        case .ready:
            dismiss()
        case .needsAttention:
            performRecoveryAction()
        case .connecting, .diagnosing:
            break
        }
    }

    private func beginPairing() {
        pairingTask?.cancel()
        stage = .connecting
        connectionStep = 0
        orbitRotation = false

        pairingTask = Task { @MainActor in
            if !reduceMotion {
                orbitRotation = true
            }

            try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 360_000_000)
            guard !Task.isCancelled else { return }
            connectionStep = 1

            try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 420_000_000)
            guard !Task.isCancelled else { return }
            connectionStep = 2

            try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 420_000_000)
            guard !Task.isCancelled else { return }
            let succeeded = await manager.requestAccess()
            guard !Task.isCancelled else { return }
            await manager.runDiagnostics()

            if succeeded, manager.isEnabled {
                connectionStep = 3
                hasCompletedOnboarding = true
                stage = .ready
            } else {
                stage = manager.diagnosticReport.hasActionableIssue ? .needsAttention : .failed
            }
        }
    }

    private func diagnoseExistingConnection() {
        pairingTask?.cancel()
        stage = .diagnosing
        pairingTask = Task { @MainActor in
            if manager.isEnabled {
                await manager.refresh()
            }
            await manager.runDiagnostics()
            guard !Task.isCancelled else { return }
            if manager.diagnosticReport.hasActionableIssue {
                stage = .needsAttention
            } else {
                hasCompletedOnboarding = true
                stage = .ready
            }
        }
    }

    private func performRecoveryAction() {
        guard !isOpeningSystemSettings else { return }
        switch manager.diagnosticReport.primaryRecoveryAction {
        case .none:
            dismiss()
        case .requestAccess:
            beginPairing()
        case .refresh, .retryAfterUnlock:
            diagnoseExistingConnection()
        case .openSettings:
            openSystemSettings()
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        pairingTask?.cancel()
        isOpeningSystemSettings = true
        pairingTask = Task { @MainActor in
            await manager.runDiagnostics()
            guard !Task.isCancelled else {
                isOpeningSystemSettings = false
                return
            }

            if manager.diagnosticReport.requestState == .shouldRequest {
                stage = .connecting
                connectionStep = 2
                isOpeningSystemSettings = false
                let succeeded = await manager.requestAccess()
                guard !Task.isCancelled else { return }
                await manager.runDiagnostics()
                if succeeded, manager.isEnabled {
                    connectionStep = 3
                    hasCompletedOnboarding = true
                    stage = .ready
                } else {
                    stage = manager.diagnosticReport.hasActionableIssue ? .needsAttention : .failed
                }
                return
            }

            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                isOpeningSystemSettings = false
                showsSettingsNavigationError = true
                return
            }
            let opened = await UIApplication.shared.open(url, options: [:])
            guard !Task.isCancelled else { return }
            isOpeningSystemSettings = false
            if !opened {
                showsSettingsNavigationError = true
            }
        }
        #endif
    }

    private func startAmbientMotion() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
            heroDrift = true
        }
    }
}

private enum PairingStage: Hashable {
    case introduction
    case connecting
    case diagnosing
    case ready
    case needsAttention
    case failed
}

private struct PairingBenefitRow: View {
    let icon: String
    let title: String
    let tone: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(safeSystemName: icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone)
                .frame(width: 30, height: 30)
                .background(tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.80))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
