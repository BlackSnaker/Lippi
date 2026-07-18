import Foundation
import Testing
@testable import Lippi

struct HealthWellnessRecommendationTests {
    @Test("Uses personal baselines to choose a recovery routine")
    func recoveryRoutine() {
        let snapshot = HealthWellnessSnapshot(
            stepsToday: 1_800,
            recentSleepHours: 5.1,
            baselineSleepHours: 7.6,
            restingHeartRate: 72,
            baselineRestingHeartRate: 61,
            hrvSDNN: 28,
            baselineHRVSDNN: 48
        )

        let recommendation = HealthWellnessRecommendationEngine.evaluate(snapshot)

        #expect(recommendation.band == .recovery)
        #expect(recommendation.suggestedFocusMinutes == 15)
        #expect(recommendation.suggestsPlanAdjustment)
        #expect(recommendation.suggestsBreathing)
        #expect(recommendation.suggestsEyeBreak)
    }

    @Test("Keeps a regular routine when the personal baseline is steady")
    func balancedRoutine() {
        let snapshot = HealthWellnessSnapshot(
            stepsToday: 3_500,
            recentSleepHours: 7.2,
            baselineSleepHours: 7.4,
            restingHeartRate: 61,
            baselineRestingHeartRate: 60,
            hrvSDNN: 47,
            baselineHRVSDNN: 46
        )

        let recommendation = HealthWellnessRecommendationEngine.evaluate(snapshot)

        #expect(recommendation.band == .balanced)
        #expect(recommendation.suggestedFocusMinutes == 25)
        #expect(!recommendation.suggestsPlanAdjustment)
    }

    @Test("Suggests a longer focus block only with steady signals and activity")
    func readyRoutine() {
        let snapshot = HealthWellnessSnapshot(
            stepsToday: 7_200,
            exerciseMinutesToday: 28,
            recentSleepHours: 7.6,
            baselineSleepHours: 7.4,
            restingHeartRate: 59,
            baselineRestingHeartRate: 61,
            hrvSDNN: 51,
            baselineHRVSDNN: 48
        )

        let recommendation = HealthWellnessRecommendationEngine.evaluate(snapshot)

        #expect(recommendation.band == .ready)
        #expect(recommendation.suggestedFocusMinutes == 50)
        #expect(!recommendation.suggestsPlanAdjustment)
    }

    @Test("Plan adjustment is explicit, additive, and idempotent")
    func additivePlanAdjustment() {
        let roadmap = GoalRoadmap(
            title: "Ship a release",
            summary: "Prepare and ship the next version.",
            source: .localPlanner,
            confidence: 0.7,
            successCriteria: ["A reviewable build is ready."],
            firstActions: ["Review the release scope."],
            assumptions: [],
            milestones: [
                GoalMilestone(
                    title: "Prepare",
                    timeframe: "Week 1",
                    target: "A tested build",
                    tasks: ["Run the release checklist."],
                    category: .work
                )
            ],
            habits: [],
            risks: []
        )
        let pace = AdaptiveGoalPace(
            level: .recovery,
            dailyStepLimit: 1,
            focusMinutes: 15,
            spacingDays: 3,
            reasons: [.recoverySignals],
            shouldRedistributeOverdueSteps: true
        )

        let once = AdaptiveGoalPlanEngine.applying(to: roadmap, pace: pace, lang: .en)
        let twice = AdaptiveGoalPlanEngine.applying(to: once, pace: pace, lang: .en)

        #expect(once.milestones == roadmap.milestones)
        #expect(once.firstActions.count == roadmap.firstActions.count + 1)
        #expect(once.habits.count == 1)
        #expect(twice.firstActions == once.firstActions)
        #expect(twice.habits == once.habits)
    }

    @Test("Adaptive pace keeps the outcome while reducing immediate overload")
    func adaptivePaceForOverload() {
        let audit = GoalPlanProgressAudit(
            trackedTasks: 5,
            completedTasks: 1,
            activeTasks: 4,
            overdueTasks: 2,
            daysSinceRoadmapCreated: 5,
            oldestActiveTaskAgeDays: 4,
            overdueExamples: ["First", "Second"],
            missedTasks: [],
            nextActiveTask: "First"
        )
        let health = HealthWellnessRecommendation(
            band: .light,
            confidence: 0.7,
            signals: [.sleepBelowBaseline],
            suggestedFocusMinutes: 25,
            planLoadScale: 0.85,
            suggestsBreathing: true,
            suggestsEyeBreak: true
        )

        let pace = AdaptiveGoalPaceEngine.evaluate(
            health: health,
            audit: audit,
            userState: .overloaded
        )

        #expect(pace.level == .recovery)
        #expect(pace.dailyStepLimit == 1)
        #expect(pace.shouldRedistributeOverdueSteps)
        #expect(pace.keepsGoalIntact)
    }

    @Test("Explains when Apple Health is unavailable")
    func healthDiagnosticsUnavailable() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: false,
            isIntegrationEnabled: false,
            requestState: .unknown,
            mindfulWriteAccess: .unavailable,
            snapshot: nil,
            lastFailure: nil,
            limitedAccessStartDate: nil
        )

        #expect(report.status == .unavailable)
        #expect(report.issues == [.healthDataUnavailable])
        #expect(report.primaryRecoveryAction == .none)
    }

    @Test("Directs the user to unlock the device before retrying")
    func healthDiagnosticsLockedDevice() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: true,
            requestState: .reviewed,
            mindfulWriteAccess: .allowed,
            snapshot: HealthWellnessSnapshot(stepsToday: 2_000),
            lastFailure: HealthKitFailure(kind: .deviceLocked),
            limitedAccessStartDate: nil
        )

        #expect(report.status == .needsAttention)
        #expect(report.issues.contains(.deviceLocked))
        #expect(report.primaryRecoveryAction == .retryAfterUnlock)
    }

    @Test("Offers the Apple permission sheet when access was not reviewed")
    func healthDiagnosticsNeedsAuthorization() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: false,
            requestState: .shouldRequest,
            mindfulWriteAccess: .notDetermined,
            snapshot: nil,
            lastFailure: nil,
            limitedAccessStartDate: nil
        )

        #expect(report.status == .needsAttention)
        #expect(report.issues == [.authorizationNeeded])
        #expect(report.primaryRecoveryAction == .requestAccess)
    }

    @Test("Uses Settings after a required permission is denied")
    func healthDiagnosticsDeniedAuthorization() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: false,
            requestState: .reviewed,
            mindfulWriteAccess: .notDetermined,
            snapshot: nil,
            lastFailure: HealthKitFailure(kind: .authorizationDenied),
            limitedAccessStartDate: nil
        )

        #expect(report.status == .needsAttention)
        #expect(report.issues == [.authorizationDenied])
        #expect(report.primaryRecoveryAction == .openSettings)
    }

    @Test("Opens Settings when an enabled connection exposes no readable data")
    func healthDiagnosticsNoReadableData() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: true,
            requestState: .reviewed,
            mindfulWriteAccess: .allowed,
            snapshot: HealthWellnessSnapshot(),
            lastFailure: nil,
            limitedAccessStartDate: nil
        )

        #expect(report.status == .partial)
        #expect(report.issues == [.noReadableData])
        #expect(report.primaryRecoveryAction == .openSettings)
        #expect(!report.hasActionableIssue)
    }

    @Test("Missing Watch samples do not invalidate an active Health connection")
    func healthDiagnosticsWithoutRecentWatchSamples() {
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: true,
            requestState: .reviewed,
            mindfulWriteAccess: .allowed,
            snapshot: HealthWellnessSnapshot(stepsToday: 3_200),
            lastFailure: nil,
            limitedAccessStartDate: nil
        )

        #expect(report.status == .partial)
        #expect(report.issues == [.watchDataNotFound])
        #expect(!report.hasActionableIssue)
    }

    @Test("Refreshes a connection when recent Apple Watch data becomes stale")
    func healthDiagnosticsStaleWatchData() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let watchDate = now.addingTimeInterval(-80 * 60 * 60)
        let snapshot = HealthWellnessSnapshot(
            stepsToday: 4_000,
            hasAppleWatchData: true,
            latestAppleWatchSampleDate: watchDate
        )
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: true,
            requestState: .reviewed,
            mindfulWriteAccess: .allowed,
            snapshot: snapshot,
            lastFailure: nil,
            limitedAccessStartDate: nil,
            now: now
        )

        #expect(report.status == .partial)
        #expect(report.issues == [.watchDataStale])
        #expect(report.primaryRecoveryAction == .refresh)
    }

    @Test("Keeps readable insights while guiding denied mindful writes to Settings")
    func healthDiagnosticsDeniedMindfulWrite() {
        let snapshot = HealthWellnessSnapshot(
            stepsToday: 4_000,
            hasAppleWatchData: true,
            latestAppleWatchSampleDate: .now
        )
        let report = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: true,
            requestState: .reviewed,
            mindfulWriteAccess: .denied,
            snapshot: snapshot,
            lastFailure: nil,
            limitedAccessStartDate: nil
        )

        #expect(report.status == .partial)
        #expect(report.issues == [.mindfulWriteDenied])
        #expect(report.primaryRecoveryAction == .openSettings)
    }

    @Test("Replacing a health adaptation does not accumulate generated plan steps")
    func replacesPreviousHealthAdaptation() {
        let roadmap = GoalRoadmap(
            title: "Finish a course",
            summary: "Complete the lessons without overload.",
            source: .localPlanner,
            confidence: 0.8,
            successCriteria: ["All lessons are complete."],
            firstActions: ["Open the next lesson."],
            assumptions: [],
            milestones: [],
            habits: [],
            risks: []
        )
        let recovery = AdaptiveGoalPace(
            level: .recovery,
            dailyStepLimit: 1,
            focusMinutes: 15,
            spacingDays: 3,
            reasons: [.recoverySignals],
            shouldRedistributeOverdueSteps: false
        )
        let first = AdaptiveGoalPlanEngine.applying(to: roadmap, pace: recovery, lang: .en)
        let record = AdaptiveGoalPlanRecord(
            roadmapID: roadmap.id,
            appliedAt: .now,
            pace: recovery,
            userState: .tired,
            healthBand: .recovery,
            activeTaskCount: 0,
            completedTaskCount: 0,
            overdueTaskCount: 0,
            redistributedTaskCount: 0,
            firstAction: AdaptiveGoalPlanEngine.firstAction(for: recovery, lang: .en),
            habitTitle: AdaptiveGoalPlanEngine.habitTitle(lang: .en),
            habitDetail: AdaptiveGoalPlanEngine.habitDetail(for: recovery, lang: .en)
        )
        let balanced = AdaptiveGoalPace(
            level: .balanced,
            dailyStepLimit: 2,
            focusMinutes: 25,
            spacingDays: 2,
            reasons: [.steadyProgress],
            shouldRedistributeOverdueSteps: false
        )

        let replaced = AdaptiveGoalPlanEngine.applying(
            to: first,
            pace: balanced,
            lang: .en,
            replacing: record
        )

        #expect(!replaced.firstActions.contains(record.firstAction))
        #expect(replaced.firstActions.first == AdaptiveGoalPlanEngine.firstAction(for: balanced, lang: .en))
        #expect(replaced.habits.count == 1)
        #expect(AdaptiveGoalPlanEngine.isApplied(to: replaced, pace: balanced, lang: .en))
        #expect(record.matchesCurrentContext(healthBand: .recovery, userState: .tired, audit: nil))
    }

    @Test("A wellbeing check-in keeps one current state per calendar day")
    @MainActor
    func wellbeingCheckInReplacesSameDayEntry() {
        let suite = "WellbeingCheckInStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = WellbeingCheckInStore(defaults: defaults, calendar: calendar)
        let morning = Date(timeIntervalSince1970: 1_800_000_000)

        store.record(.energetic, at: morning)
        store.record(.tired, at: morning.addingTimeInterval(3_600))

        #expect(store.entries.count == 1)
        #expect(store.entry(on: morning)?.state == .tired)
        #expect(store.datesForRecentWeek(reference: morning).count == 7)
    }
}
