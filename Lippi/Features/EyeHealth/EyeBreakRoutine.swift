import CoreGraphics
import Foundation

/// A deterministic, camera-free routine shared by the in-app eye break UI.
///
/// The phase is derived from elapsed time instead of being driven by a chain of
/// timers. That keeps the instructions stable after backgrounding the app and
/// mirrors the same schedule rendered by the Live Activity.
enum EyeBreakRoutinePhase: String, CaseIterable, Hashable, Sendable {
    case settle
    case horizontal
    case vertical
    case circle
    case focus
    case blink

    var weight: Double {
        switch self {
        case .settle: 0.10
        case .horizontal: 0.20
        case .vertical: 0.17
        case .circle: 0.20
        case .focus: 0.20
        case .blink: 0.13
        }
    }
}

struct EyeBreakRoutineSnapshot: Equatable, Sendable {
    let phase: EyeBreakRoutinePhase
    let phaseIndex: Int
    let phaseProgress: Double
    let overallProgress: Double
    let elapsed: TimeInterval
    let remaining: TimeInterval
}

enum EyeBreakRoutine {
    static let defaultDuration: TimeInterval = 60

    static func snapshot(
        elapsed proposedElapsed: TimeInterval,
        duration proposedDuration: TimeInterval = defaultDuration
    ) -> EyeBreakRoutineSnapshot {
        let duration = max(proposedDuration, 1)
        let elapsed = min(max(proposedElapsed, 0), duration)
        let overallProgress = elapsed / duration
        let phases = EyeBreakRoutinePhase.allCases

        var lowerBound = 0.0
        for (index, phase) in phases.enumerated() {
            let upperBound = index == phases.count - 1
                ? 1
                : lowerBound + phase.weight
            if overallProgress + 0.000_000_1 < upperBound || index == phases.count - 1 {
                let span = max(upperBound - lowerBound, 0.000_1)
                return EyeBreakRoutineSnapshot(
                    phase: phase,
                    phaseIndex: index,
                    phaseProgress: min(max((overallProgress - lowerBound) / span, 0), 1),
                    overallProgress: overallProgress,
                    elapsed: elapsed,
                    remaining: max(duration - elapsed, 0)
                )
            }
            lowerBound = upperBound
        }

        return EyeBreakRoutineSnapshot(
            phase: .blink,
            phaseIndex: max(phases.count - 1, 0),
            phaseProgress: 1,
            overallProgress: 1,
            elapsed: duration,
            remaining: 0
        )
    }

    static func snapshot(
        at date: Date,
        startDate: Date,
        endDate: Date
    ) -> EyeBreakRoutineSnapshot {
        snapshot(
            elapsed: date.timeIntervalSince(startDate),
            duration: max(endDate.timeIntervalSince(startDate), 1)
        )
    }

    /// Returns a normalized target position inside the exercise canvas.
    /// The point always stays within a comfortable central field of view.
    static func normalizedTarget(
        for phase: EyeBreakRoutinePhase,
        phaseProgress: Double,
        reduceMotion: Bool = false
    ) -> CGPoint {
        let progress = min(max(phaseProgress, 0), 1)
        let amplitude = reduceMotion ? 0.24 : 0.36
        let cycles: Double
        switch phase {
        case .horizontal: cycles = 2.0
        case .vertical: cycles = 1.7
        case .circle: cycles = 1.5
        default: cycles = 1.0
        }
        let angle = progress * cycles * 2 * Double.pi - Double.pi / 2

        switch phase {
        case .settle, .focus, .blink:
            return CGPoint(x: 0.5, y: 0.5)
        case .horizontal:
            return CGPoint(
                x: CGFloat(0.5 + amplitude * sin(angle)),
                y: 0.5
            )
        case .vertical:
            return CGPoint(
                x: 0.5,
                y: CGFloat(0.5 + amplitude * 0.82 * sin(angle))
            )
        case .circle:
            return CGPoint(
                x: CGFloat(0.5 + amplitude * cos(angle)),
                y: CGFloat(0.5 + amplitude * 0.78 * sin(angle))
            )
        }
    }
}
