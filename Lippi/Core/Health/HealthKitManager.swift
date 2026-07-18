import Foundation
import SwiftUI

#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

enum HealthKitConnectionState: Equatable {
    case unavailable
    case notConnected
    case requesting
    case refreshing
    case connected
    case noRecentData
    case failed
}

enum HealthReadinessBand: String, Codable, Hashable {
    case unknown
    case recovery
    case light
    case balanced
    case ready
}

enum HealthWellnessSignal: String, Hashable {
    case sleepBelowBaseline
    case hrvBelowBaseline
    case restingHeartRateAboveBaseline
    case activityStrong
    case personalBaselineStable
    case limitedData
}

struct HealthWellnessSnapshot: Hashable {
    var generatedAt: Date = .now
    var stepsToday: Double?
    var activeEnergyToday: Double?
    var exerciseMinutesToday: Double?
    var recentSleepHours: Double?
    var baselineSleepHours: Double?
    var restingHeartRate: Double?
    var baselineRestingHeartRate: Double?
    var hrvSDNN: Double?
    var baselineHRVSDNN: Double?
    var respiratoryRate: Double?
    var workoutMinutesLast7Days: Double?
    var mindfulMinutesLast7Days: Double?
    var hasAppleWatchData: Bool = false
    var latestAppleWatchSampleDate: Date?

    var hasRecentData: Bool {
        [
            stepsToday,
            activeEnergyToday,
            exerciseMinutesToday,
            recentSleepHours,
            restingHeartRate,
            hrvSDNN,
            respiratoryRate,
            workoutMinutesLast7Days,
            mindfulMinutesLast7Days
        ].contains { $0 != nil }
    }
}

struct HealthWellnessRecommendation: Hashable {
    var band: HealthReadinessBand
    var confidence: Double
    var signals: [HealthWellnessSignal]
    var suggestedFocusMinutes: Int
    var planLoadScale: Double
    var suggestsBreathing: Bool
    var suggestsEyeBreak: Bool

    var suggestsPlanAdjustment: Bool {
        band == .recovery || band == .light
    }
}

enum HealthWellnessRecommendationEngine {
    static func evaluate(_ snapshot: HealthWellnessSnapshot) -> HealthWellnessRecommendation {
        var negativeSignals: [HealthWellnessSignal] = []
        var comparedSignals = 0

        if let recent = snapshot.recentSleepHours,
           let baseline = snapshot.baselineSleepHours,
           baseline > 0 {
            comparedSignals += 1
            if recent < baseline * 0.78 {
                negativeSignals.append(.sleepBelowBaseline)
            }
        }

        if let recent = snapshot.hrvSDNN,
           let baseline = snapshot.baselineHRVSDNN,
           baseline > 0 {
            comparedSignals += 1
            if recent < baseline * 0.72 {
                negativeSignals.append(.hrvBelowBaseline)
            }
        }

        if let recent = snapshot.restingHeartRate,
           let baseline = snapshot.baselineRestingHeartRate,
           baseline > 0 {
            comparedSignals += 1
            if recent > baseline * 1.12 {
                negativeSignals.append(.restingHeartRateAboveBaseline)
            }
        }

        let hasStrongActivity = (snapshot.exerciseMinutesToday ?? 0) >= 20
            || (snapshot.stepsToday ?? 0) >= 6_000

        guard snapshot.hasRecentData else {
            return HealthWellnessRecommendation(
                band: .unknown,
                confidence: 0,
                signals: [.limitedData],
                suggestedFocusMinutes: 25,
                planLoadScale: 1,
                suggestsBreathing: false,
                suggestsEyeBreak: false
            )
        }

        if negativeSignals.count >= 2 {
            return HealthWellnessRecommendation(
                band: .recovery,
                confidence: min(0.92, 0.62 + Double(comparedSignals) * 0.10),
                signals: negativeSignals,
                suggestedFocusMinutes: 15,
                planLoadScale: 0.65,
                suggestsBreathing: true,
                suggestsEyeBreak: true
            )
        }

        if negativeSignals.count == 1 {
            return HealthWellnessRecommendation(
                band: .light,
                confidence: min(0.78, 0.48 + Double(comparedSignals) * 0.10),
                signals: negativeSignals,
                suggestedFocusMinutes: 25,
                planLoadScale: 0.85,
                suggestsBreathing: true,
                suggestsEyeBreak: true
            )
        }

        if hasStrongActivity, comparedSignals >= 2 {
            return HealthWellnessRecommendation(
                band: .ready,
                confidence: min(0.82, 0.48 + Double(comparedSignals) * 0.10),
                signals: [.activityStrong, .personalBaselineStable],
                suggestedFocusMinutes: 50,
                planLoadScale: 1,
                suggestsBreathing: false,
                suggestsEyeBreak: false
            )
        }

        return HealthWellnessRecommendation(
            band: .balanced,
            confidence: comparedSignals > 0 ? min(0.72, 0.42 + Double(comparedSignals) * 0.10) : 0.35,
            signals: comparedSignals > 0 ? [.personalBaselineStable] : [.limitedData],
            suggestedFocusMinutes: 25,
            planLoadScale: 1,
            suggestsBreathing: false,
            suggestsEyeBreak: false
        )
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    static let insightsEnabledKey = "healthkit.insights.enabled"
    static let pairingOnboardingCompletedKey = "healthkit.pairing.onboarding.completed"

    @Published private(set) var state: HealthKitConnectionState
    @Published private(set) var snapshot: HealthWellnessSnapshot?
    @Published private(set) var recommendation: HealthWellnessRecommendation?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isEnabled: Bool
    @Published private(set) var diagnosticReport = HealthKitDiagnosticReport.initial
    @Published private(set) var lastFailure: HealthKitFailure?

    #if canImport(HealthKit) && os(iOS)
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var isRefreshing = false
    #endif

    private init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.insightsEnabledKey)
        isEnabled = enabled

        #if canImport(HealthKit) && os(iOS)
        state = HKHealthStore.isHealthDataAvailable()
            ? (enabled ? .refreshing : .notConnected)
            : .unavailable
        #else
        state = .unavailable
        #endif
    }

    func activateIfEnabled() async {
        guard isEnabled else {
            await runDiagnostics()
            return
        }
        await refresh()
        startBackgroundObservationIfNeeded()
    }

    @discardableResult
    func requestAccess() async -> Bool {
        #if canImport(HealthKit) && os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else {
            lastFailure = HealthKitFailure(kind: .healthDataUnavailable)
            state = .unavailable
            await runDiagnostics()
            return false
        }

        state = .requesting
        lastFailure = nil
        do {
            try await requestAuthorization()
            isEnabled = true
            UserDefaults.standard.set(true, forKey: Self.insightsEnabledKey)
            await refresh()
            startBackgroundObservationIfNeeded()
            return state != .failed
        } catch {
            lastFailure = HealthKitFailure(kind: failureKind(for: error))
            state = .failed
            await runDiagnostics()
            return false
        }
        #else
        state = .unavailable
        return false
        #endif
    }

    func refresh() async {
        #if canImport(HealthKit) && os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else {
            lastFailure = HealthKitFailure(kind: .healthDataUnavailable)
            state = .unavailable
            await runDiagnostics()
            return
        }
        guard isEnabled, !isRefreshing else { return }

        isRefreshing = true
        state = .refreshing
        defer { isRefreshing = false }

        do {
            let newSnapshot = try await fetchSnapshot()
            snapshot = newSnapshot
            recommendation = HealthWellnessRecommendationEngine.evaluate(newSnapshot)
            lastUpdated = newSnapshot.generatedAt
            lastFailure = nil
            state = newSnapshot.hasRecentData ? .connected : .noRecentData
            await runDiagnostics()
        } catch {
            lastFailure = HealthKitFailure(kind: failureKind(for: error))
            state = .failed
            await runDiagnostics()
        }
        #else
        state = .unavailable
        #endif
    }

    func stopUsingInsights() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: Self.insightsEnabledKey)
        snapshot = nil
        recommendation = nil
        lastUpdated = nil
        lastFailure = nil
        diagnosticReport = .initial
        state = .notConnected

        #if canImport(HealthKit) && os(iOS)
        observerQueries.forEach(healthStore.stop)
        observerQueries.removeAll()
        healthStore.disableAllBackgroundDelivery { _, _ in }
        #endif
    }

    func saveMindfulSession(startedAt: Date, endedAt: Date) async {
        #if canImport(HealthKit) && os(iOS)
        guard isEnabled,
              endedAt > startedAt,
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }

        guard healthStore.authorizationStatus(for: type) == .sharingAuthorized else {
            await runDiagnostics()
            return
        }

        let sample = HKCategorySample(
            type: type,
            value: 0,
            start: startedAt,
            end: endedAt,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )

        do {
            try await save(sample)
            await refresh()
        } catch {
            let kind = failureKind(for: error)
            lastFailure = HealthKitFailure(
                kind: kind == .authorizationDenied ? .mindfulWriteDenied : kind
            )
            await runDiagnostics()
            // The local breathing session remains valid even if Apple Health is unavailable.
        }
        #endif
    }

    func runDiagnostics() async {
        #if canImport(HealthKit) && os(iOS)
        let available = HKHealthStore.isHealthDataAvailable()
        guard available else {
            diagnosticReport = HealthKitDiagnosticEngine.makeReport(
                isHealthDataAvailable: false,
                isIntegrationEnabled: isEnabled,
                requestState: .unknown,
                mindfulWriteAccess: .unavailable,
                snapshot: snapshot,
                lastFailure: lastFailure,
                limitedAccessStartDate: nil
            )
            return
        }

        let requestState = await authorizationRequestState()
        let writeAccess = mindfulWriteAccessState()
        diagnosticReport = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: true,
            isIntegrationEnabled: isEnabled,
            requestState: requestState,
            mindfulWriteAccess: writeAccess,
            snapshot: snapshot,
            lastFailure: lastFailure,
            limitedAccessStartDate: nil
        )
        #else
        diagnosticReport = HealthKitDiagnosticEngine.makeReport(
            isHealthDataAvailable: false,
            isIntegrationEnabled: isEnabled,
            requestState: .unknown,
            mindfulWriteAccess: .unavailable,
            snapshot: snapshot,
            lastFailure: lastFailure,
            limitedAccessStartDate: nil
        )
        #endif
    }
}

#if canImport(HealthKit) && os(iOS)
private struct HealthKitQueryOutcome<Value> {
    let value: Value?
    let error: Error?
}

private extension HealthKitManager {
    var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate
        ]

        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    var shareTypes: Set<HKSampleType> {
        guard let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return [] }
        return [mindful]
    }

    func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitManagerError.authorizationNotCompleted)
                }
            }
        }
    }

    func authorizationRequestState() async -> HealthKitAuthorizationRequestState {
        await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { status, _ in
                switch status {
                case .shouldRequest:
                    continuation.resume(returning: .shouldRequest)
                case .unnecessary:
                    continuation.resume(returning: .reviewed)
                case .unknown:
                    continuation.resume(returning: .unknown)
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    func mindfulWriteAccessState() -> HealthKitWriteAccessState {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return .unavailable
        }
        switch healthStore.authorizationStatus(for: type) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        case .sharingAuthorized: return .allowed
        @unknown default: return .unavailable
        }
    }

    func failureKind(for error: Error) -> HealthKitFailureKind {
        let nsError = error as NSError
        guard nsError.domain == HKErrorDomain,
              let code = HKError.Code(rawValue: nsError.code) else {
            if let managerError = error as? HealthKitManagerError {
                switch managerError {
                case .authorizationNotCompleted: return .authorizationCancelled
                case .saveNotCompleted: return .queryFailed
                }
            }
            return .unknown
        }

        switch code {
        case .errorHealthDataUnavailable: return .healthDataUnavailable
        case .errorHealthDataRestricted, .errorNotPermissibleForGuestUserMode: return .healthDataRestricted
        case .errorDatabaseInaccessible: return .deviceLocked
        case .errorUserCanceled: return .authorizationCancelled
        case .errorAuthorizationNotDetermined: return .authorizationNotDetermined
        case .errorAuthorizationDenied, .errorRequiredAuthorizationDenied: return .authorizationDenied
        case .errorInvalidArgument: return .invalidConfiguration
        default: return .queryFailed
        }
    }

    func fetchSnapshot(reference: Date = .now) async throws -> HealthWellnessSnapshot {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: reference)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: reference) ?? reference.addingTimeInterval(-604_800)
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: reference) ?? reference.addingTimeInterval(-2_419_200)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: reference) ?? reference.addingTimeInterval(-172_800)
        let recentSleepStart = calendar.date(byAdding: .hour, value: -36, to: reference) ?? reference.addingTimeInterval(-129_600)

        // Read each group independently. HealthKit intentionally represents a
        // denied or unavailable read as missing data, and one optional metric
        // must not invalidate every other authorized signal.
        let stepsQuery = await healthQuery {
            try await sum(.stepCount, unit: .count(), start: startOfDay, end: reference)
        }
        let activeEnergyQuery = await healthQuery {
            try await sum(.activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: reference)
        }
        let exerciseQuery = await healthQuery {
            try await sum(.appleExerciseTime, unit: .minute(), start: startOfDay, end: reference)
        }
        let recentRHRQuery = await healthQuery {
            try await average(
                .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                start: twoDaysAgo,
                end: reference
            )
        }
        let baselineRHRQuery = await healthQuery {
            try await average(
                .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                start: twentyEightDaysAgo,
                end: reference
            )
        }
        let recentHRVQuery = await healthQuery {
            try await average(
                .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                start: twoDaysAgo,
                end: reference
            )
        }
        let baselineHRVQuery = await healthQuery {
            try await average(
                .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                start: twentyEightDaysAgo,
                end: reference
            )
        }
        let respiratoryRateQuery = await healthQuery {
            try await average(
                .respiratoryRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                start: twoDaysAgo,
                end: reference
            )
        }
        let recentSleepQuery = await healthQuery {
            try await categorySamples(.sleepAnalysis, start: recentSleepStart, end: reference)
        }
        let baselineSleepQuery = await healthQuery {
            try await categorySamples(.sleepAnalysis, start: twentyEightDaysAgo, end: reference)
        }
        let workoutsQuery = await healthQuery {
            try await samples(
                type: HKObjectType.workoutType(),
                start: sevenDaysAgo,
                end: reference,
                limit: HKObjectQueryNoLimit
            )
        }
        let mindfulQuery = await healthQuery {
            try await categorySamples(.mindfulSession, start: sevenDaysAgo, end: reference)
        }

        let queryErrors = [
            stepsQuery.error,
            activeEnergyQuery.error,
            exerciseQuery.error,
            recentRHRQuery.error,
            baselineRHRQuery.error,
            recentHRVQuery.error,
            baselineHRVQuery.error,
            respiratoryRateQuery.error,
            recentSleepQuery.error,
            baselineSleepQuery.error,
            workoutsQuery.error,
            mindfulQuery.error
        ].compactMap { $0 }

        if let blockingError = queryErrors.first(where: isBlockingHealthStoreError) {
            throw blockingError
        }

        let steps = stepsQuery.value ?? nil
        let activeEnergy = activeEnergyQuery.value ?? nil
        let exercise = exerciseQuery.value ?? nil
        let recentRHR = recentRHRQuery.value ?? nil
        let baselineRHR = baselineRHRQuery.value ?? nil
        let recentHRV = recentHRVQuery.value ?? nil
        let baselineHRV = baselineHRVQuery.value ?? nil
        let respiratoryRate = respiratoryRateQuery.value ?? nil
        let recentSleepSamples = recentSleepQuery.value ?? []
        let baselineSleepSamples = baselineSleepQuery.value ?? []
        let recentSleep = sleepHours(in: recentSleepSamples)
        let baselineSleep = averageSleepHoursPerObservedDay(in: baselineSleepSamples)

        let workouts = workoutsQuery.value ?? []
        let workoutMinutes = workouts
            .compactMap { $0 as? HKWorkout }
            .reduce(0) { $0 + $1.duration / 60 }

        let mindfulSamples = mindfulQuery.value ?? []
        let mindfulMinutes = mindfulSamples.reduce(0) { total, sample in
            total + max(0, sample.endDate.timeIntervalSince(sample.startDate)) / 60
        }

        let watchProbeTypes: [HKQuantityTypeIdentifier] = [
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate
        ]
        var watchSamples: [HKSample] = []
        for identifier in watchProbeTypes {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { continue }
            let watchQuery = await healthQuery {
                try await samples(type: type, start: twentyEightDaysAgo, end: reference, limit: 30)
            }
            if let error = watchQuery.error {
                if isBlockingHealthStoreError(error) { throw error }
            }
            watchSamples.append(contentsOf: watchQuery.value ?? [])
        }
        let watchOnlySamples = watchSamples.filter(isAppleWatchSample)

        return HealthWellnessSnapshot(
            generatedAt: reference,
            stepsToday: steps,
            activeEnergyToday: activeEnergy,
            exerciseMinutesToday: exercise,
            recentSleepHours: recentSleep,
            baselineSleepHours: baselineSleep,
            restingHeartRate: recentRHR,
            baselineRestingHeartRate: baselineRHR,
            hrvSDNN: recentHRV,
            baselineHRVSDNN: baselineHRV,
            respiratoryRate: respiratoryRate,
            workoutMinutesLast7Days: workouts.isEmpty ? nil : workoutMinutes,
            mindfulMinutesLast7Days: mindfulSamples.isEmpty ? nil : mindfulMinutes,
            hasAppleWatchData: !watchOnlySamples.isEmpty,
            latestAppleWatchSampleDate: watchOnlySamples.map(\.endDate).max()
        )
    }

    func healthQuery<Value>(
        _ operation: () async throws -> Value
    ) async -> HealthKitQueryOutcome<Value> {
        do {
            return HealthKitQueryOutcome(value: try await operation(), error: nil)
        } catch {
            return HealthKitQueryOutcome(value: nil, error: error)
        }
    }

    func isBlockingHealthStoreError(_ error: Error) -> Bool {
        switch failureKind(for: error) {
        case .healthDataUnavailable, .healthDataRestricted, .deviceLocked:
            return true
        case .authorizationCancelled,
             .authorizationNotDetermined,
             .authorizationDenied,
             .mindfulWriteDenied,
             .invalidConfiguration,
             .backgroundDeliveryFailed,
             .queryFailed,
             .unknown:
            return false
        }
    }

    func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let result = try await statistics(type: type, start: start, end: end, options: .cumulativeSum)
        return result?.sumQuantity()?.doubleValue(for: unit)
    }

    func average(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let result = try await statistics(type: type, start: start, end: end, options: .discreteAverage)
        return result?.averageQuantity()?.doubleValue(for: unit)
    }

    func statistics(
        type: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
            healthStore.execute(query)
        }
    }

    func categorySamples(
        _ identifier: HKCategoryTypeIdentifier,
        start: Date,
        end: Date
    ) async throws -> [HKCategorySample] {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else { return [] }
        return try await samples(type: type, start: start, end: end, limit: HKObjectQueryNoLimit)
            .compactMap { $0 as? HKCategorySample }
    }

    func samples(
        type: HKSampleType,
        start: Date,
        end: Date,
        limit: Int
    ) async throws -> [HKSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitManagerError.saveNotCompleted)
                }
            }
        }
    }

    func sleepHours(in samples: [HKCategorySample]) -> Double? {
        let intervals = sleepingIntervals(in: samples)
        guard !intervals.isEmpty else { return nil }
        return mergedDuration(of: intervals) / 3_600
    }

    func averageSleepHoursPerObservedDay(in samples: [HKCategorySample]) -> Double? {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sleepingIntervals(in: samples)) { interval in
            calendar.startOfDay(for: interval.end)
        }
        let dailyHours = grouped.values
            .map { mergedDuration(of: Array($0)) / 3_600 }
            .filter { $0 >= 1 }
        guard !dailyHours.isEmpty else { return nil }
        return dailyHours.reduce(0, +) / Double(dailyHours.count)
    }

    func sleepingIntervals(in samples: [HKCategorySample]) -> [DateInterval] {
        samples.compactMap { sample in
            let awake = HKCategoryValueSleepAnalysis.awake.rawValue
            let inBed = HKCategoryValueSleepAnalysis.inBed.rawValue
            guard sample.value != awake, sample.value != inBed, sample.endDate > sample.startDate else {
                return nil
            }
            return DateInterval(start: sample.startDate, end: sample.endDate)
        }
    }

    func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var duration: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                duration += current.duration
                current = interval
            }
        }
        return duration + current.duration
    }

    func isAppleWatchSample(_ sample: HKSample) -> Bool {
        let sourceName = sample.sourceRevision.source.name.lowercased()
        let model = sample.device?.model?.lowercased() ?? ""
        let name = sample.device?.name?.lowercased() ?? ""
        return sourceName.contains("watch") || model.contains("watch") || name.contains("watch")
    }

    func startBackgroundObservationIfNeeded() {
        guard isEnabled, observerQueries.isEmpty else { return }

        let identifiers: [HKObjectType] = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ].compactMap { $0 }

        for objectType in identifiers {
            guard let sampleType = objectType as? HKSampleType else { continue }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
                if let error {
                    Task { @MainActor [weak self] in
                        guard let self else {
                            completion()
                            return
                        }
                        self.lastFailure = HealthKitFailure(kind: self.backgroundFailureKind(for: error))
                        await self.runDiagnostics()
                        completion()
                    }
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.refresh()
                    completion()
                }
            }
            observerQueries.append(query)
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { [weak self] success, error in
                guard !success else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.lastFailure = HealthKitFailure(
                        kind: error.map(self.backgroundFailureKind(for:)) ?? .backgroundDeliveryFailed
                    )
                    await self.runDiagnostics()
                }
            }
        }
    }

    func backgroundFailureKind(for error: Error) -> HealthKitFailureKind {
        switch failureKind(for: error) {
        case .healthDataUnavailable: return .healthDataUnavailable
        case .healthDataRestricted: return .healthDataRestricted
        case .deviceLocked: return .deviceLocked
        default: return .backgroundDeliveryFailed
        }
    }
}

private enum HealthKitManagerError: Error {
    case authorizationNotCompleted
    case saveNotCompleted
}
#endif
