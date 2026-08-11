import SwiftUI

/// A guided eye-rest routine that never asks for camera permission.
/// It deliberately avoids scores and reaction targets: the goal is smooth,
/// unhurried eye movement rather than another attention game.
struct CameraFreeEyeExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(L10n.storageKey) private var langRaw = AppLang.fallback.rawValue

    private let autoStart: Bool
    private let onClose: (() -> Void)?
    private let duration: TimeInterval

    @State private var now = Date.now
    @State private var startedAt: Date?
    @State private var accumulatedElapsed: TimeInterval = 0
    @State private var isComplete = false
    @State private var didBootstrap = false
    @State private var lastPhase: EyeBreakRoutinePhase = .settle
    @State private var resumeAfterInactive = false

    init(
        autoStart: Bool = false,
        duration: TimeInterval = EyeBreakRoutine.defaultDuration,
        onClose: (() -> Void)? = nil
    ) {
        self.autoStart = autoStart
        self.duration = max(duration, 1)
        self.onClose = onClose
    }

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var elapsed: TimeInterval {
        min(
            accumulatedElapsed + max(now.timeIntervalSince(startedAt ?? now), 0),
            duration
        )
    }

    private var isRunning: Bool {
        startedAt != nil && !isComplete && scenePhase == .active
    }

    var body: some View {
        let snapshot = EyeBreakRoutine.snapshot(elapsed: elapsed, duration: duration)

        NavigationStack {
            ZStack {
                AppBackdrop(renderMode: .force)

                ambientBackground(snapshot: snapshot)

                Group {
                    if isComplete {
                        completionView
                    } else if startedAt == nil && accumulatedElapsed == 0 {
                        introView
                    } else {
                        routineView(snapshot: snapshot)
                    }
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            }
            .navigationTitle(s("eye.routine.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(s("eye.routine.close")) { close() }
                }
            }
        }
        .onAppear {
            guard !didBootstrap else { return }
            didBootstrap = true
            if autoStart { start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = .now
                if resumeAfterInactive && !isComplete {
                    startedAt = now
                }
                resumeAfterInactive = false
            } else {
                resumeAfterInactive = startedAt != nil
                pauseClock()
            }
        }
        .onChange(of: snapshot.phase) { _, phase in
            guard phase != lastPhase, !isComplete else { return }
            lastPhase = phase
            DS.hapticSoft()
        }
        .task(id: isRunning) {
            guard isRunning else { return }
            let interval: UInt64 = reduceMotion ? 66_000_000 : 33_000_000
            while !Task.isCancelled {
                now = .now
                if elapsed >= duration {
                    complete()
                    return
                }
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    private func ambientBackground(snapshot: EyeBreakRoutineSnapshot) -> some View {
        GeometryReader { proxy in
            let point = EyeBreakRoutine.normalizedTarget(
                for: snapshot.phase,
                phaseProgress: snapshot.phaseProgress,
                reduceMotion: reduceMotion
            )
            ZStack {
                Circle()
                    .fill(Color(hex: 0x5AC8FA).opacity(0.13))
                    .frame(width: 280, height: 280)
                    .blur(radius: 54)
                    .position(
                        x: proxy.size.width * point.x,
                        y: proxy.size.height * (0.22 + point.y * 0.40)
                    )

                Circle()
                    .fill(Color(hex: 0x9A7CFF).opacity(0.09))
                    .frame(width: 220, height: 220)
                    .blur(radius: 48)
                    .position(x: proxy.size.width * 0.16, y: proxy.size.height * 0.82)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var introView: some View {
        ScrollView {
            VStack(spacing: 18) {
                GlassCard(padding: 22, cornerRadius: 32, style: .full, forceSystemGlass: false) {
                    VStack(spacing: 18) {
                        cameraFreeHero

                        VStack(spacing: 8) {
                            Text(s("eye.routine.intro_title"))
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(DS.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(s("eye.routine.intro_subtitle"))
                                .font(.body)
                                .foregroundStyle(DS.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 8) {
                            introFact("timer", s("eye.routine.fact_minute"))
                            introFact("camera.fill.badge.xmark", s("eye.routine.fact_no_camera"))
                            introFact("hand.tap.fill", s("eye.routine.fact_hands_free"))
                        }

                        Button { start() } label: {
                            Label(s("eye.routine.start"), systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LippiButtonStyle(kind: .primary, forceSystemGlass: true))
                    }
                }

                safetyCard
            }
            .lippiContentColumn()
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var cameraFreeHero: some View {
        ZStack {
            Circle()
                .fill(DS.brandSoftGradient)
                .frame(width: 144, height: 144)
                .blur(radius: 8)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(DS.accent.opacity(0.22 - Double(index) * 0.045), lineWidth: 2)
                    .frame(
                        width: 76 + CGFloat(index * 24),
                        height: 76 + CGFloat(index * 24)
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(hex: 0x64D2FF), Color(hex: 0x3D8CFF)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: Color(hex: 0x64D2FF).opacity(0.8), radius: 16)
        }
        .accessibilityHidden(true)
    }

    private func introFact(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(safeSystemName: icon, fallback: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.accent)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .padding(.horizontal, 4)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(DS.glassStroke(0.10), lineWidth: 1))
    }

    private func routineView(snapshot: EyeBreakRoutineSnapshot) -> some View {
        VStack(spacing: 14) {
            phaseHeader(snapshot: snapshot)

            GlassCard(padding: 0, cornerRadius: 34, style: .full, forceSystemGlass: false) {
                routineCanvas(snapshot: snapshot)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 390)
            }

            instructionCard(snapshot: snapshot)
            routineControls
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func phaseHeader(snapshot: EyeBreakRoutineSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label(s("eye.routine.no_camera_badge"), systemImage: "camera.fill.badge.xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x55E0B5))

                Spacer()

                Text(timeLabel(snapshot.remaining))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach(EyeBreakRoutinePhase.allCases.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < snapshot.phaseIndex
                            ? Color(hex: 0x55E0B5)
                            : index == snapshot.phaseIndex
                                ? DS.accent
                                : DS.glassFill(0.10))
                        .frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.fmt(
                "eye.routine.phase_progress",
                lang,
                snapshot.phaseIndex + 1,
                EyeBreakRoutinePhase.allCases.count
            )))
        }
    }

    private func routineCanvas(snapshot: EyeBreakRoutineSnapshot) -> some View {
        GeometryReader { proxy in
            let target = EyeBreakRoutine.normalizedTarget(
                for: snapshot.phase,
                phaseProgress: snapshot.phaseProgress,
                reduceMotion: reduceMotion
            )
            let x = proxy.size.width * target.x
            let y = proxy.size.height * target.y

            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x07111F).opacity(0.94),
                        Color(hex: 0x101B34).opacity(0.86),
                        Color(hex: 0x07111F).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                EyeRoutineGuidePath(phase: snapshot.phase)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x64D2FF).opacity(0.12),
                                Color(hex: 0x64D2FF).opacity(0.55),
                                Color(hex: 0x9A7CFF).opacity(0.20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 8])
                    )
                    .padding(34)
                    .opacity(guideOpacity(for: snapshot.phase))

                if snapshot.phase == .focus {
                    focusRings(progress: snapshot.phaseProgress)
                        .position(x: x, y: y)
                } else if snapshot.phase == .blink {
                    blinkTarget(progress: snapshot.phaseProgress)
                        .position(x: x, y: y)
                } else {
                    lightTarget(progress: snapshot.phaseProgress, phase: snapshot.phase)
                        .position(x: x, y: y)
                }

                VStack {
                    Spacer()
                    Text(phaseHint(snapshot.phase))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.50))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(phaseTitle(snapshot.phase)))
        .accessibilityValue(Text(phaseInstruction(snapshot.phase)))
    }

    private func lightTarget(
        progress: Double,
        phase: EyeBreakRoutinePhase
    ) -> some View {
        let pulse = reduceMotion ? 1 : 1 + CGFloat((sin(progress * .pi * 10) + 1) * 0.055)
        return ZStack {
            Circle()
                .fill(Color(hex: 0x64D2FF).opacity(0.18))
                .frame(width: 74, height: 74)
                .blur(radius: 12)
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                .frame(width: 46, height: 46)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(hex: 0x64D2FF), Color(hex: 0x3D8CFF)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: phase == .settle ? 26 : 22, height: phase == .settle ? 26 : 22)
                .overlay(Circle().stroke(.white.opacity(0.82), lineWidth: 1))
                .shadow(color: Color(hex: 0x64D2FF).opacity(0.95), radius: 14)
        }
        .scaleEffect(pulse)
    }

    private func focusRings(progress: Double) -> some View {
        let wave = (sin(progress * .pi * 4 - .pi / 2) + 1) / 2
        let scale = reduceMotion ? 1 : 0.74 + CGFloat(wave) * 0.58
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color(hex: index == 2 ? 0x9A7CFF : 0x64D2FF).opacity(0.34 - Double(index) * 0.06), lineWidth: 1.5)
                    .frame(width: 56 + CGFloat(index * 44), height: 56 + CGFloat(index * 44))
            }
            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: Color(hex: 0x64D2FF), radius: 13)
        }
        .scaleEffect(scale)
        .opacity(0.62 + wave * 0.38)
    }

    private func blinkTarget(progress: Double) -> some View {
        let blinkWave = pow(abs(sin(progress * .pi * 7)), 8)
        return ZStack {
            Ellipse()
                .fill(Color(hex: 0x64D2FF).opacity(0.18))
                .frame(width: 132, height: 76)
                .blur(radius: 11)
            Image(systemName: "eye.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(x: 1, y: reduceMotion ? 1 : max(0.12, 1 - blinkWave))
        }
    }

    private func instructionCard(snapshot: EyeBreakRoutineSnapshot) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .lightweight, forceSystemGlass: false) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: phaseIcon(snapshot.phase))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.accent)
                    .frame(width: 44, height: 44)
                    .background(DS.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(phaseTitle(snapshot.phase))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                    Text(phaseInstruction(snapshot.phase))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var routineControls: some View {
        HStack(spacing: 12) {
            Button { togglePause() } label: {
                Label(
                    startedAt == nil ? s("eye.routine.resume") : s("eye.routine.pause"),
                    systemImage: startedAt == nil ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, forceSystemGlass: true))

            Button(role: .destructive) { close() } label: {
                Text(s("eye.routine.finish"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .destructive, forceSystemGlass: true))
        }
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color(hex: 0xFF9F0A))
            Text(s("eye.routine.safety"))
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: 0x55E0B5).opacity(0.14))
                    .frame(width: 132, height: 132)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 68, weight: .medium))
                    .foregroundStyle(Color(hex: 0x55E0B5))
            }

            VStack(spacing: 8) {
                Text(s("eye.routine.complete_title"))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(s("eye.routine.complete_subtitle"))
                    .font(.body)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button { close() } label: {
                Text(s("eye.routine.done"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, forceSystemGlass: true))
            .frame(maxWidth: 360)

            Spacer()
        }
        .padding(24)
    }

    private func start() {
        accumulatedElapsed = 0
        now = .now
        startedAt = now
        resumeAfterInactive = false
        lastPhase = .settle
        isComplete = false
    }

    private func pauseClock() {
        guard let startedAt else { return }
        accumulatedElapsed = min(
            accumulatedElapsed + max(Date.now.timeIntervalSince(startedAt), 0),
            duration
        )
        self.startedAt = nil
        now = .now
    }

    private func togglePause() {
        if startedAt == nil {
            now = .now
            startedAt = now
        } else {
            pauseClock()
        }
        resumeAfterInactive = false
    }

    private func complete() {
        accumulatedElapsed = duration
        startedAt = nil
        now = .now
        isComplete = true
        resumeAfterInactive = false
        DS.hapticSoft()
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func timeLabel(_ remaining: TimeInterval) -> String {
        let seconds = max(Int(ceil(remaining)), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func phaseTitle(_ phase: EyeBreakRoutinePhase) -> String {
        s("eye.routine.phase.\(phase.rawValue).title")
    }

    private func phaseInstruction(_ phase: EyeBreakRoutinePhase) -> String {
        s("eye.routine.phase.\(phase.rawValue).instruction")
    }

    private func phaseHint(_ phase: EyeBreakRoutinePhase) -> String {
        s("eye.routine.phase.\(phase.rawValue).hint")
    }

    private func phaseIcon(_ phase: EyeBreakRoutinePhase) -> String {
        switch phase {
        case .settle: "wind"
        case .horizontal: "arrow.left.and.right"
        case .vertical: "arrow.up.and.down"
        case .circle: "arrow.triangle.2.circlepath"
        case .focus: "scope"
        case .blink: "eye.fill"
        }
    }

    private func guideOpacity(for phase: EyeBreakRoutinePhase) -> Double {
        switch phase {
        case .horizontal, .vertical, .circle: 1
        case .settle, .focus, .blink: 0
        }
    }
}

private struct EyeRoutineGuidePath: Shape {
    let phase: EyeBreakRoutinePhase

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch phase {
        case .horizontal:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        case .vertical:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        case .circle:
            path.addEllipse(in: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.10))
        case .settle, .focus, .blink:
            break
        }
        return path
    }
}
