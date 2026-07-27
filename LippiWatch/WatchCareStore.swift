import Foundation
import WatchConnectivity

struct WatchCareSnapshot: Codable, Hashable {
    var updatedAt: Date = .distantPast
    var suggestionKind = "steady"
    var suggestionTitle = "Lippi"
    var suggestionBody = "Open Lippi on iPhone to refresh your day."
    var suggestionAction = "none"
    var suggestionActionTitle = ""
    var nextGoalStep: String?
    var paceTitle = ""
    var isFocusRunning = false
    var focusMinutes = 0
    var stepsToday: Int?
    var goalLabel = "Goal"
    var focusLabel = "Focus"
    var waterLabel = "Water"
    var mealLabel = "Meal"
    var moveLabel = "Move"
    var restLabel = "Rest"
    var doneLabel = "Logged"

    init() {}

    init(context: [String: Any]) {
        updatedAt = (context["updatedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? .now
        suggestionKind = context["suggestionKind"] as? String ?? "steady"
        suggestionTitle = context["suggestionTitle"] as? String
            ?? context["emptyTitle"] as? String
            ?? "Lippi"
        suggestionBody = context["suggestionBody"] as? String
            ?? context["emptyBody"] as? String
            ?? ""
        suggestionAction = context["suggestionAction"] as? String ?? "none"
        suggestionActionTitle = context["suggestionActionTitle"] as? String ?? ""
        nextGoalStep = context["nextGoalStep"] as? String
        paceTitle = context["paceTitle"] as? String ?? ""
        isFocusRunning = context["isFocusRunning"] as? Bool ?? false
        focusMinutes = context["focusMinutes"] as? Int ?? 0
        stepsToday = context["stepsToday"] as? Int
        goalLabel = context["goalLabel"] as? String ?? "Goal"
        focusLabel = context["focusLabel"] as? String ?? "Focus"
        waterLabel = context["waterLabel"] as? String ?? "Water"
        mealLabel = context["mealLabel"] as? String ?? "Meal"
        moveLabel = context["moveLabel"] as? String ?? "Move"
        restLabel = context["restLabel"] as? String ?? "Rest"
        doneLabel = context["doneLabel"] as? String ?? "Logged"
    }
}

@MainActor
final class WatchCareStore: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchCareSnapshot
    @Published private(set) var confirmation: String?

    private static let snapshotKey = "lippi.watch.care.snapshot.v1"
    private var confirmationTask: Task<Void, Never>?

    override init() {
        if let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
           let stored = try? JSONDecoder().decode(WatchCareSnapshot.self, from: data) {
            snapshot = stored
        } else {
            snapshot = WatchCareSnapshot()
        }
        super.init()
        activate()
    }

    func send(action: String) {
        guard action != "none" else { return }
        let payload: [String: Any] = [
            "careAction": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
        showConfirmation()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        if !session.receivedApplicationContext.isEmpty {
            apply(session.receivedApplicationContext)
        }
    }

    private func apply(_ context: [String: Any]) {
        let value = WatchCareSnapshot(context: context)
        snapshot = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    private func showConfirmation() {
        confirmationTask?.cancel()
        confirmation = snapshot.doneLabel
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            self?.confirmation = nil
        }
    }
}

extension WatchCareStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard !session.receivedApplicationContext.isEmpty else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in self?.apply(context) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let context = message["careContext"] as? [String: Any] {
            Task { @MainActor [weak self] in self?.apply(context) }
        }
    }
}
