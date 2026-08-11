import XCTest
@testable import Lippi

final class EyeBreakRoutineTests: XCTestCase {
    func testMinuteRoutineMovesThroughEveryPhaseAtExpectedBoundary() {
        let checkpoints: [(TimeInterval, EyeBreakRoutinePhase)] = [
            (0, .settle),
            (6, .horizontal),
            (18, .vertical),
            (28.2, .circle),
            (40.2, .focus),
            (52.2, .blink),
            (60, .blink)
        ]

        for (elapsed, expected) in checkpoints {
            XCTAssertEqual(
                EyeBreakRoutine.snapshot(elapsed: elapsed).phase,
                expected,
                "Unexpected phase at \(elapsed) seconds"
            )
        }
    }

    func testSnapshotClampsElapsedAndProgress() {
        let beforeStart = EyeBreakRoutine.snapshot(elapsed: -50)
        XCTAssertEqual(beforeStart.phase, .settle)
        XCTAssertEqual(beforeStart.elapsed, 0)
        XCTAssertEqual(beforeStart.overallProgress, 0)

        let afterEnd = EyeBreakRoutine.snapshot(elapsed: 500)
        XCTAssertEqual(afterEnd.phase, .blink)
        XCTAssertEqual(afterEnd.elapsed, EyeBreakRoutine.defaultDuration)
        XCTAssertEqual(afterEnd.remaining, 0)
        XCTAssertEqual(afterEnd.overallProgress, 1)
        XCTAssertEqual(afterEnd.phaseProgress, 1, accuracy: 0.000_1)
    }

    func testDateBasedSnapshotUsesActivityInterval() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(120)
        let snapshot = EyeBreakRoutine.snapshot(
            at: start.addingTimeInterval(36),
            startDate: start,
            endDate: end
        )

        XCTAssertEqual(snapshot.phase, .vertical)
        XCTAssertEqual(snapshot.overallProgress, 0.3, accuracy: 0.000_1)
        XCTAssertEqual(snapshot.remaining, 84, accuracy: 0.000_1)
    }

    func testAnimatedTargetsRemainInsideComfortableFieldOfView() {
        for phase in EyeBreakRoutinePhase.allCases {
            for step in 0...100 {
                let point = EyeBreakRoutine.normalizedTarget(
                    for: phase,
                    phaseProgress: Double(step) / 100
                )
                XCTAssertTrue((0.12...0.88).contains(point.x), "x out of range for \(phase)")
                XCTAssertTrue((0.20...0.80).contains(point.y), "y out of range for \(phase)")
            }
        }
    }

    func testRoutineCopyExistsInEverySupportedLanguage() {
        let sharedKeys = [
            "eye.camera.start_without_camera",
            "eye.camera.continue_without_camera",
            "eye.routine.intro_title",
            "eye.routine.intro_subtitle",
            "eye.routine.safety",
            "eye.routine.complete_title"
        ]

        for language in AppLang.allCases {
            for key in sharedKeys {
                XCTAssertNotEqual(L10n.tr(key, language), key, "Missing \(key) for \(language)")
            }
            for phase in EyeBreakRoutinePhase.allCases {
                for suffix in ["title", "instruction", "hint"] {
                    let key = "eye.routine.phase.\(phase.rawValue).\(suffix)"
                    XCTAssertNotEqual(L10n.tr(key, language), key, "Missing \(key) for \(language)")
                }
            }
        }
    }
}
