import Combine
import Foundation

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity
#endif

enum AppleWatchAvailability: String, Equatable, Sendable {
    case unknown
    case unsupported
    case notPaired
    case paired
    case reachable

    var canOfferSync: Bool {
        self == .paired || self == .reachable
    }
}

enum AppleWatchSyncOfferPolicy {
    static let respondedKey = "watch.sync.offer.responded.v1"

    static func shouldOffer(
        availability: AppleWatchAvailability,
        hasCompletedOnboarding: Bool,
        isAuthenticated: Bool,
        healthInsightsEnabled: Bool,
        hasResponded: Bool
    ) -> Bool {
        availability.canOfferSync
            && hasCompletedOnboarding
            && isAuthenticated
            && !healthInsightsEnabled
            && !hasResponded
    }
}

struct LippiCareWatchActionEvent: Identifiable, Equatable {
    let id: UUID
    let action: LippiCareAction
    let receivedAt: Date
}

/// Watches the relationship already established by iPhone and Apple Watch.
/// watchOS does not expose a general Bluetooth scan to third-party apps, so a
/// paired Watch is the reliable discovery signal; `reachable` additionally
/// confirms that a companion app can currently exchange messages.
@MainActor
final class AppleWatchDiscovery: NSObject, ObservableObject {
    static let shared = AppleWatchDiscovery()

    @Published private(set) var availability: AppleWatchAvailability = .unknown
    @Published private(set) var latestCareAction: LippiCareWatchActionEvent?

    #if canImport(WatchConnectivity) && os(iOS)
    private var hasActivatedSession = false
    private var pendingCareContext: [String: Any]?
    #endif

    private override init() {
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity) && os(iOS)
        guard WCSession.isSupported() else {
            availability = .unsupported
            return
        }

        let session = WCSession.default
        session.delegate = self
        if !hasActivatedSession {
            hasActivatedSession = true
            session.activate()
        }
        apply(
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )
        #else
        availability = .unsupported
        #endif
    }

    func syncCareContext(
        suggestion: LippiCareSuggestion?,
        nextGoalStep: String?,
        paceTitle: String,
        isFocusRunning: Bool,
        focusMinutes: Int,
        stepsToday: Int?,
        lang: AppLang
    ) {
        #if canImport(WatchConnectivity) && os(iOS)
        activate()
        var context: [String: Any] = [
            "schema": 1,
            "updatedAt": Date().timeIntervalSince1970,
            "paceTitle": paceTitle,
            "isFocusRunning": isFocusRunning,
            "focusMinutes": max(0, focusMinutes),
            "lang": lang.rawValue,
            "emptyTitle": L10n.tr("care.watch.empty.title", lang),
            "emptyBody": L10n.tr("care.watch.empty.body", lang),
            "goalLabel": L10n.tr("care.watch.goal", lang),
            "focusLabel": L10n.tr("care.watch.focus", lang),
            "waterLabel": L10n.tr("care.action.logWater", lang),
            "mealLabel": L10n.tr("care.action.logMeal", lang),
            "moveLabel": L10n.tr("care.action.logMovement", lang),
            "restLabel": L10n.tr("care.watch.rest", lang),
            "doneLabel": L10n.tr("care.watch.done", lang)
        ]
        if let suggestion {
            context["suggestionKind"] = suggestion.kind.rawValue
            context["suggestionTitle"] = suggestion.title
            context["suggestionBody"] = suggestion.body
            context["suggestionAction"] = suggestion.action.rawValue
            context["suggestionActionTitle"] = suggestion.actionTitle
        }
        if let nextGoalStep, !nextGoalStep.isEmpty {
            context["nextGoalStep"] = nextGoalStep
        }
        if let stepsToday {
            context["stepsToday"] = max(0, stepsToday)
        }
        pendingCareContext = context
        flushPendingCareContext()
        #endif
    }

    #if canImport(WatchConnectivity) && os(iOS)
    private func apply(isPaired: Bool, isWatchAppInstalled: Bool, isReachable: Bool) {
        guard isPaired else {
            availability = .notPaired
            return
        }
        availability = isWatchAppInstalled && isReachable ? .reachable : .paired
    }

    private func flushPendingCareContext() {
        guard let context = pendingCareContext else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(context)
            pendingCareContext = nil
        } catch {
            // Keep the latest snapshot. It is retried after the next session state change.
        }
    }

    private func receiveCareAction(from payload: [String: Any]) {
        guard let rawValue = payload["careAction"] as? String,
              let action = LippiCareAction(rawValue: rawValue) else { return }
        let timestamp = (payload["timestamp"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .now
        latestCareAction = LippiCareWatchActionEvent(id: UUID(), action: action, receivedAt: timestamp)
    }
    #endif
}

#if canImport(WatchConnectivity) && os(iOS)
extension AppleWatchDiscovery: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        publishSnapshot(from: session)
        Task { @MainActor [weak self] in self?.flushPendingCareContext() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        publishSnapshot(from: session)
        Task { @MainActor [weak self] in self?.flushPendingCareContext() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        publishSnapshot(from: session)
        Task { @MainActor [weak self] in self?.flushPendingCareContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        publishSnapshot(from: session)
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        publishSnapshot(from: session)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.receiveCareAction(from: message) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.receiveCareAction(from: message)
            replyHandler(["accepted": true])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor [weak self] in self?.receiveCareAction(from: userInfo) }
    }

    nonisolated private func publishSnapshot(from session: WCSession) {
        let isPaired = session.isPaired
        let isWatchAppInstalled = session.isWatchAppInstalled
        let isReachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.apply(
                isPaired: isPaired,
                isWatchAppInstalled: isWatchAppInstalled,
                isReachable: isReachable
            )
        }
    }
}
#endif
