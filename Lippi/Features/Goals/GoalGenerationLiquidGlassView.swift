import SwiftUI

/// A deliberately small, energy-aware animation for the short period while
/// Bonsai turns a request into a roadmap. The visual keeps its optical depth
/// inside a compact canvas so it does not compete with model inference.
struct GoalGenerationLiquidGlassView: View {
    let stage: GoalRoadmapActivityStage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @State private var thermalState = ProcessInfo.processInfo.thermalState
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var pausesContinuousMotion: Bool {
        reduceMotion
            || isLowPowerModeEnabled
            || thermalState == .serious
            || thermalState == .critical
    }

    private var frameInterval: TimeInterval {
        thermalState == .fair ? 1.0 / 8.0 : 1.0 / 18.0
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: frameInterval,
                paused: pausesContinuousMotion
            )
        ) { timeline in
            let time = pausesContinuousMotion
                ? stage.staticPhase
                : timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { proxy in
                liquidOrb(time: time, size: min(proxy.size.width, proxy.size.height))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : DS.motionState, value: stage)
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            thermalState = ProcessInfo.processInfo.thermalState
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }

    private func liquidOrb(time: TimeInterval, size: CGFloat) -> some View {
        let palette = stage.generationPalette
        let pulse = pausesContinuousMotion ? 0 : CGFloat(sin(time * stage.pulseRate))
        let drift = pausesContinuousMotion ? 0 : CGFloat(sin(time * 0.62))
        let phase = CGFloat(time * stage.ribbonRate)
        let coreSize = size * 0.68

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette[0].opacity(reduceTransparency ? 0.13 : 0.24),
                            palette[1].opacity(reduceTransparency ? 0.04 : 0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.50
                    )
                )
                .frame(width: size * 0.96, height: size * 0.96)
                .scaleEffect(1 + pulse * 0.026)

            orbit(
                size: size * 0.88,
                lineWidth: max(1, size * 0.011),
                trim: 0.68,
                rotation: time * 10.0,
                colors: palette
            )

            orbit(
                size: size * 0.77,
                lineWidth: max(0.8, size * 0.008),
                trim: 0.54,
                rotation: -time * 7.0 + 122,
                colors: Array(palette.reversed())
            )
            .opacity(0.76)

            orbitDot(
                diameter: max(5, size * 0.052),
                radius: size * 0.415,
                angle: time * 10.0 + 22,
                color: palette[1]
            )

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.glassFill(reduceTransparency ? 0.22 : 0.10),
                                DS.glassFill(reduceTransparency ? 0.14 : 0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                liquidColorField(
                    time: time,
                    pulse: pulse,
                    drift: drift,
                    size: coreSize,
                    palette: palette
                )
                .clipShape(Circle())

                GoalGenerationRibbon(phase: phase, amplitude: coreSize * 0.038)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette[0].opacity(0.15),
                                Color.white.opacity(reduceTransparency ? 0.74 : 0.96),
                                palette[2].opacity(0.72),
                                palette[3].opacity(0.14)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: coreSize * 0.91, height: coreSize * 0.27)
                    .blendMode(reduceTransparency ? .normal : .plusLighter)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.24 : 0.58),
                                Color.white.opacity(0.04),
                                .clear
                            ],
                            center: UnitPoint(x: 0.31, y: 0.22),
                            startRadius: 1,
                            endRadius: coreSize * 0.56
                        )
                    )

                Image(safeSystemName: stage.symbol, fallback: "sparkles")
                    .font(.system(size: size * 0.115, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: palette[0].opacity(0.42), radius: 8)
                    .offset(y: coreSize * 0.235)
            }
            .frame(width: coreSize, height: coreSize)
            .lippiSystemGlass(
                in: Circle(),
                tint: palette[0].opacity(0.10),
                prominent: true,
                forceSystemGlass: true
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.42 : 0.82),
                                palette[1].opacity(0.28),
                                palette[3].opacity(0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: palette[0].opacity(reduceTransparency ? 0.12 : 0.28), radius: 18, y: 8)
            .scaleEffect(1 + pulse * 0.012 + drift * 0.006)
        }
    }

    private func liquidColorField(
        time: TimeInterval,
        pulse: CGFloat,
        drift: CGFloat,
        size: CGFloat,
        palette: [Color]
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[0].opacity(0.74), palette[0].opacity(0.02)],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.34
                    )
                )
                .frame(width: size * 0.70, height: size * 0.70)
                .offset(x: size * (-0.15 + drift * 0.07), y: size * (0.12 - pulse * 0.04))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[1].opacity(0.78), palette[1].opacity(0.01)],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.32
                    )
                )
                .frame(width: size * 0.66, height: size * 0.66)
                .offset(
                    x: size * (0.16 + CGFloat(cos(time * 0.53)) * 0.055),
                    y: size * (-0.13 + drift * 0.045)
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[2].opacity(0.68), palette[2].opacity(0.01)],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.27
                    )
                )
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(
                    x: size * CGFloat(sin(time * 0.44)) * 0.07,
                    y: size * (0.18 + CGFloat(cos(time * 0.48)) * 0.045)
                )
        }
        .blur(radius: reduceTransparency ? 0 : 5)
    }

    private func orbit(
        size: CGFloat,
        lineWidth: CGFloat,
        trim: CGFloat,
        rotation: Double,
        colors: [Color]
    ) -> some View {
        Circle()
            .trim(from: 0.02, to: trim)
            .stroke(
                AngularGradient(colors: colors + [colors[0]], center: .center),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
    }

    private func orbitDot(
        diameter: CGFloat,
        radius: CGFloat,
        angle: Double,
        color: Color
    ) -> some View {
        let radians = angle * .pi / 180
        return Circle()
            .fill(color)
            .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 0.8))
            .frame(width: diameter, height: diameter)
            .shadow(color: color.opacity(0.54), radius: 5)
            .offset(
                x: CGFloat(cos(radians)) * radius,
                y: CGFloat(sin(radians)) * radius
            )
    }
}

private struct GoalGenerationRibbon: Shape {
    let phase: CGFloat
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let samples = 32
        let centerY = rect.midY
        let topAmplitude = max(2, amplitude)
        let bottomAmplitude = topAmplitude * 0.72

        for index in 0...samples {
            let progress = CGFloat(index) / CGFloat(samples)
            let x = rect.minX + rect.width * progress
            let y = centerY
                + sin(progress * .pi * 3.2 + phase) * topAmplitude
                - rect.height * 0.055
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        for index in stride(from: samples, through: 0, by: -1) {
            let progress = CGFloat(index) / CGFloat(samples)
            let x = rect.minX + rect.width * progress
            let y = centerY
                + sin(progress * .pi * 2.7 + phase + 1.18) * bottomAmplitude
                + rect.height * 0.09
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }
}

private extension GoalRoadmapActivityStage {
    var generationPalette: [Color] {
        switch self {
        case .preparing:
            return [Color(hex: 0x0A84FF), Color(hex: 0x64D2FF), Color(hex: 0x5E5CE6), Color(hex: 0x30D158)]
        case .research:
            return [Color(hex: 0x00C7BE), Color(hex: 0x64D2FF), Color(hex: 0x30D158), Color(hex: 0x0A84FF)]
        case .planning:
            return [Color(hex: 0x0A84FF), Color(hex: 0xBF5AF2), Color(hex: 0x64D2FF), Color(hex: 0x5E5CE6)]
        case .checking:
            return [Color(hex: 0x30D158), Color(hex: 0x64D2FF), Color(hex: 0x0A84FF), Color(hex: 0xFFD60A)]
        case .refining:
            return [Color(hex: 0xBF5AF2), Color(hex: 0xFF375F), Color(hex: 0x64D2FF), Color(hex: 0x5E5CE6)]
        case .finalizing:
            return [Color(hex: 0x30D158), Color(hex: 0x64D2FF), Color(hex: 0x0A84FF), Color(hex: 0x00C7BE)]
        }
    }

    var ribbonRate: CGFloat {
        switch self {
        case .preparing, .finalizing: return 1.15
        case .research, .checking: return 1.42
        case .planning, .refining: return 1.65
        }
    }

    var pulseRate: Double {
        switch self {
        case .preparing, .finalizing: return 1.28
        case .research, .checking: return 1.52
        case .planning, .refining: return 1.72
        }
    }

    var staticPhase: TimeInterval {
        switch self {
        case .preparing: return 0.2
        case .research: return 0.8
        case .planning: return 1.4
        case .checking: return 2.0
        case .refining: return 2.6
        case .finalizing: return 3.2
        }
    }
}
