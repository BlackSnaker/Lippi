import Testing
@testable import Lippi

struct AdaptivePomodoroCoachTests {
    @Test("Recovery context limits focus and protects breaks")
    func recoveryContextUsesProtectiveRhythm() {
        let recommendation = HealthWellnessRecommendation(
            band: .recovery,
            confidence: 0.82,
            signals: [.sleepBelowBaseline, .hrvBelowBaseline],
            suggestedFocusMinutes: 15,
            planLoadScale: 0.65,
            suggestsBreathing: true,
            suggestsEyeBreak: true
        )
        let context = AdaptivePomodoroContext(
            healthSnapshot: nil,
            healthRecommendation: recommendation,
            goalTitle: "Prepare the portfolio",
            goalAudit: nil,
            fallbackGoalStep: "Choose three strongest projects",
            userState: .overloaded,
            rhythmHistory: PomodoroRhythmHistory(),
            lang: .en
        )

        let result = AdaptivePomodoroPolicy.fallback(for: context)

        #expect(result.focusMinutes <= 15)
        #expect(result.shortBreakMinutes >= 7)
        #expect(result.longBreakMinutes >= 20)
        #expect(result.roundsBeforeLongBreak == 2)
        #expect(result.nextGoalStep == "Choose three strongest projects")
    }

    @Test("Interrupted focus and skipped breaks adapt the next cycle")
    func historyChangesTheRhythm() {
        var history = PomodoroRhythmHistory()
        history.append(PomodoroSessionRecord(
            phase: .focus,
            plannedSeconds: 25 * 60,
            activeSeconds: 6 * 60,
            transitionReason: .skipped
        ))
        history.append(PomodoroSessionRecord(
            phase: .focus,
            plannedSeconds: 25 * 60,
            activeSeconds: 9 * 60,
            transitionReason: .stopped
        ))
        history.append(PomodoroSessionRecord(
            phase: .shortBreak,
            plannedSeconds: 5 * 60,
            activeSeconds: 30,
            transitionReason: .skipped
        ))
        history.append(PomodoroSessionRecord(
            phase: .shortBreak,
            plannedSeconds: 5 * 60,
            activeSeconds: 60,
            transitionReason: .skipped
        ))

        let context = AdaptivePomodoroContext(
            healthSnapshot: nil,
            healthRecommendation: nil,
            goalTitle: nil,
            goalAudit: nil,
            fallbackGoalStep: nil,
            userState: .calm,
            rhythmHistory: history,
            lang: .en
        )
        let result = AdaptivePomodoroPolicy.fallback(for: context)

        #expect(result.focusMinutes == 15)
        #expect(result.shortBreakMinutes == 7)
        #expect(result.longBreakMinutes == 18)
        #expect(result.roundsBeforeLongBreak == 3)
        #expect(result.reasons.contains { $0.localizedCaseInsensitiveContains("focus") })
        #expect(result.reasons.contains { $0.localizedCaseInsensitiveContains("break") })
    }

    @Test("Bonsai cannot exceed the local safety ceiling or rewrite the goal step")
    func modelOutputIsSafetyBounded() {
        let context = AdaptivePomodoroContext(
            healthSnapshot: nil,
            healthRecommendation: HealthWellnessRecommendation(
                band: .light,
                confidence: 0.7,
                signals: [.sleepBelowBaseline],
                suggestedFocusMinutes: 20,
                planLoadScale: 0.8,
                suggestsBreathing: true,
                suggestsEyeBreak: true
            ),
            goalTitle: "Publish an article",
            goalAudit: nil,
            fallbackGoalStep: "Draft the opening paragraph",
            userState: .tired,
            rhythmHistory: PomodoroRhythmHistory(),
            lang: .en
        )
        let fallback = AdaptivePomodoroPolicy.fallback(for: context)
        let payload = BonsaiPomodoroPayload(
            title: "A focused writing block",
            summary: "Start with a concrete piece of the article.",
            focusMinutes: 90,
            shortBreakMinutes: 1,
            longBreakMinutes: 4,
            roundsBeforeLongBreak: 8,
            recoveryKind: "reset",
            recoveryAction: "Skip the break",
            confidence: 4
        )

        let result = AdaptivePomodoroPolicy.validated(payload, fallback: fallback, context: context)

        #expect(result.source == .bonsai)
        #expect(result.focusMinutes <= fallback.focusMinutes)
        #expect(result.shortBreakMinutes >= fallback.shortBreakMinutes)
        #expect(result.longBreakMinutes >= fallback.longBreakMinutes)
        #expect(result.roundsBeforeLongBreak <= fallback.roundsBeforeLongBreak)
        #expect(result.nextGoalStep == "Draft the opening paragraph")
        #expect(result.recoveryAction == fallback.recoveryAction)
        #expect(result.confidence == 1)
    }
}
