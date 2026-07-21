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

/// Watches the relationship already established by iPhone and Apple Watch.
/// watchOS does not expose a general Bluetooth scan to third-party apps, so a
/// paired Watch is the reliable discovery signal; `reachable` additionally
/// confirms that a companion app can currently exchange messages.
@MainActor
final class AppleWatchDiscovery: NSObject, ObservableObject {
    static let shared = AppleWatchDiscovery()

    @Published private(set) var availability: AppleWatchAvailability = .unknown

    #if canImport(WatchConnectivity) && os(iOS)
    private var hasActivatedSession = false
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

    #if canImport(WatchConnectivity) && os(iOS)
    private func apply(isPaired: Bool, isWatchAppInstalled: Bool, isReachable: Bool) {
        guard isPaired else {
            availability = .notPaired
            return
        }
        availability = isWatchAppInstalled && isReachable ? .reachable : .paired
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
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        publishSnapshot(from: session)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        publishSnapshot(from: session)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        publishSnapshot(from: session)
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        publishSnapshot(from: session)
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
