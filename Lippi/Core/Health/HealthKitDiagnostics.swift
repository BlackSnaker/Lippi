import Foundation

enum HealthKitAuthorizationRequestState: String, Hashable {
    case unknown
    case shouldRequest
    case reviewed
}

enum HealthKitWriteAccessState: String, Hashable {
    case unavailable
    case notDetermined
    case denied
    case allowed
}

enum HealthKitFailureKind: String, Hashable {
    case healthDataUnavailable
    case healthDataRestricted
    case deviceLocked
    case authorizationCancelled
    case authorizationNotDetermined
    case authorizationDenied
    case mindfulWriteDenied
    case invalidConfiguration
    case backgroundDeliveryFailed
    case queryFailed
    case unknown
}

struct HealthKitFailure: Hashable {
    var kind: HealthKitFailureKind
    var occurredAt: Date = .now
}

enum HealthKitDiagnosticIssue: String, Hashable, Identifiable {
    case healthDataUnavailable
    case healthDataRestricted
    case deviceLocked
    case authorizationNeeded
    case authorizationCancelled
    case authorizationDenied
    case noReadableData
    case watchDataNotFound
    case watchDataStale
    case mindfulWriteDenied
    case backgroundRefreshUnavailable
    case refreshFailed

    var id: String { rawValue }
}

enum HealthKitDiagnosticStatus: String, Hashable {
    case healthy
    case partial
    case needsAttention
    case unavailable
}

enum HealthKitRecoveryAction: String, Hashable {
    case none
    case requestAccess
    case refresh
    case openSettings
    case retryAfterUnlock
}

struct HealthKitDiagnosticReport: Hashable {
    var checkedAt: Date
    var status: HealthKitDiagnosticStatus
    var issues: [HealthKitDiagnosticIssue]
    var requestState: HealthKitAuthorizationRequestState
    var mindfulWriteAccess: HealthKitWriteAccessState
    var availableDataGroups: Int
    var totalDataGroups: Int
    var latestAppleWatchSampleDate: Date?
    var limitedAccessStartDate: Date?
    var primaryRecoveryAction: HealthKitRecoveryAction

    static let initial = HealthKitDiagnosticReport(
        checkedAt: .distantPast,
        status: .partial,
        issues: [],
        requestState: .unknown,
        mindfulWriteAccess: .unavailable,
        availableDataGroups: 0,
        totalDataGroups: 6,
        latestAppleWatchSampleDate: nil,
        limitedAccessStartDate: nil,
        primaryRecoveryAction: .none
    )

    var isHealthy: Bool { status == .healthy }
    var hasActionableIssue: Bool { status == .needsAttention || status == .unavailable }
}

enum HealthKitDiagnosticEngine {
    static func makeReport(
        isHealthDataAvailable: Bool,
        isIntegrationEnabled: Bool,
        requestState: HealthKitAuthorizationRequestState,
        mindfulWriteAccess: HealthKitWriteAccessState,
        snapshot: HealthWellnessSnapshot?,
        lastFailure: HealthKitFailure?,
        limitedAccessStartDate: Date?,
        now: Date = .now
    ) -> HealthKitDiagnosticReport {
        let totalGroups = 6
        let availableGroups = availableGroupCount(in: snapshot)
        var issues: [HealthKitDiagnosticIssue] = []

        guard isHealthDataAvailable else {
            return HealthKitDiagnosticReport(
                checkedAt: now,
                status: .unavailable,
                issues: [.healthDataUnavailable],
                requestState: requestState,
                mindfulWriteAccess: mindfulWriteAccess,
                availableDataGroups: availableGroups,
                totalDataGroups: totalGroups,
                latestAppleWatchSampleDate: snapshot?.latestAppleWatchSampleDate,
                limitedAccessStartDate: limitedAccessStartDate,
                primaryRecoveryAction: .none
            )
        }

        if let failure = lastFailure {
            switch failure.kind {
            case .healthDataUnavailable:
                issues.append(.healthDataUnavailable)
            case .healthDataRestricted:
                issues.append(.healthDataRestricted)
            case .deviceLocked:
                issues.append(.deviceLocked)
            case .authorizationCancelled:
                issues.append(.authorizationCancelled)
            case .authorizationNotDetermined:
                issues.append(.authorizationNeeded)
            case .authorizationDenied:
                issues.append(.authorizationDenied)
            case .mindfulWriteDenied:
                issues.append(.mindfulWriteDenied)
            case .backgroundDeliveryFailed:
                issues.append(.backgroundRefreshUnavailable)
            case .invalidConfiguration, .queryFailed, .unknown:
                issues.append(.refreshFailed)
            }
        }

        if requestState == .shouldRequest {
            issues.append(.authorizationNeeded)
        }

        if isIntegrationEnabled {
            if snapshot?.hasRecentData != true {
                issues.append(.noReadableData)
            } else if snapshot?.hasAppleWatchData != true {
                issues.append(.watchDataNotFound)
            }

            if let watchDate = snapshot?.latestAppleWatchSampleDate,
               now.timeIntervalSince(watchDate) > 72 * 60 * 60 {
                issues.append(.watchDataStale)
            }
        }

        if mindfulWriteAccess == .denied {
            issues.append(.mindfulWriteDenied)
        }

        issues = deduplicated(issues)
        let status = status(for: issues)

        return HealthKitDiagnosticReport(
            checkedAt: now,
            status: status,
            issues: issues,
            requestState: requestState,
            mindfulWriteAccess: mindfulWriteAccess,
            availableDataGroups: availableGroups,
            totalDataGroups: totalGroups,
            latestAppleWatchSampleDate: snapshot?.latestAppleWatchSampleDate,
            limitedAccessStartDate: limitedAccessStartDate,
            primaryRecoveryAction: recoveryAction(for: issues)
        )
    }

    private static func availableGroupCount(in snapshot: HealthWellnessSnapshot?) -> Int {
        guard let snapshot else { return 0 }
        var count = 0
        if snapshot.stepsToday != nil || snapshot.activeEnergyToday != nil || snapshot.exerciseMinutesToday != nil {
            count += 1
        }
        if snapshot.recentSleepHours != nil { count += 1 }
        if snapshot.restingHeartRate != nil || snapshot.hrvSDNN != nil { count += 1 }
        if snapshot.respiratoryRate != nil { count += 1 }
        if snapshot.workoutMinutesLast7Days != nil { count += 1 }
        if snapshot.mindfulMinutesLast7Days != nil { count += 1 }
        return count
    }

    private static func deduplicated(_ issues: [HealthKitDiagnosticIssue]) -> [HealthKitDiagnosticIssue] {
        var seen: Set<HealthKitDiagnosticIssue> = []
        return issues.filter { seen.insert($0).inserted }
    }

    private static func status(for issues: [HealthKitDiagnosticIssue]) -> HealthKitDiagnosticStatus {
        if issues.contains(.healthDataUnavailable) || issues.contains(.healthDataRestricted) {
            return .unavailable
        }
        if issues.contains(.deviceLocked)
            || issues.contains(.authorizationNeeded)
            || issues.contains(.authorizationCancelled)
            || issues.contains(.authorizationDenied)
            || issues.contains(.refreshFailed) {
            return .needsAttention
        }
        return issues.isEmpty ? .healthy : .partial
    }

    private static func recoveryAction(for issues: [HealthKitDiagnosticIssue]) -> HealthKitRecoveryAction {
        if issues.contains(.healthDataUnavailable) || issues.contains(.healthDataRestricted) {
            return .none
        }
        if issues.contains(.deviceLocked) { return .retryAfterUnlock }
        if issues.contains(.authorizationNeeded) || issues.contains(.authorizationCancelled) {
            return .requestAccess
        }
        if issues.contains(.authorizationDenied)
            || issues.contains(.noReadableData)
            || issues.contains(.watchDataNotFound)
            || issues.contains(.mindfulWriteDenied) {
            return .openSettings
        }
        if issues.contains(.watchDataStale)
            || issues.contains(.backgroundRefreshUnavailable)
            || issues.contains(.refreshFailed) {
            return .refresh
        }
        return .none
    }
}
