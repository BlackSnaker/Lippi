import SwiftUI

private struct LippiIsScrollingKey: EnvironmentKey {
    static let defaultValue = false
}

private struct LippiScrollPerformanceCoordinatorKey: EnvironmentKey {
    static let defaultValue: ScrollPerformanceCoordinator? = nil
}

extension EnvironmentValues {
    var lippiIsScrolling: Bool {
        get { self[LippiIsScrollingKey.self] }
        set { self[LippiIsScrollingKey.self] = newValue }
    }

    var lippiScrollPerformanceCoordinator: ScrollPerformanceCoordinator? {
        get { self[LippiScrollPerformanceCoordinatorKey.self] }
        set { self[LippiScrollPerformanceCoordinatorKey.self] = newValue }
    }
}

@MainActor
final class ScrollPerformanceCoordinator: ObservableObject {
    @Published private(set) var isScrolling = false
    private var settleTask: Task<Void, Never>?
    private let settleDelay: UInt64 = 360_000_000

    func setScrolling(_ value: Bool) {
        settleTask?.cancel()

        if value {
            updateScrolling(true)
            return
        }

        // Keep the lightweight render path through the final deceleration frames
        // so glass, shadows, and implicit animations do not come back mid-scroll.
        settleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.settleDelay ?? 360_000_000)
            guard !Task.isCancelled else { return }
            self?.updateScrolling(false)
        }
    }

    func stop() {
        settleTask?.cancel()
        settleTask = nil
        updateScrolling(false)
    }

    private func updateScrolling(_ value: Bool) {
        guard isScrolling != value else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isScrolling = value
        }
    }
}

private struct LippiScrollPerformanceModifier: ViewModifier {
    @Environment(\.lippiScrollPerformanceCoordinator) private var coordinator
    @Environment(\.lippiIsScrolling) private var isScrolling

    @ViewBuilder
    func body(content: Content) -> some View {
        let tunedContent = content
            .transaction { transaction in
                if isScrolling {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }

        if #available(iOS 18.0, *), let coordinator {
            tunedContent
                .onScrollPhaseChange { _, phase in
                    coordinator.setScrolling(phase.isScrolling)
                }
                .scrollBounceBehavior(.basedOnSize)
        } else {
            tunedContent
                .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct LippiPerformanceModeModifier: ViewModifier {
    @Environment(\.lippiIsScrolling) private var isScrolling

    func body(content: Content) -> some View {
        content.transaction { transaction in
            if isScrolling {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}

extension View {
    /// Lets shared glass surfaces switch to their lighter drawing path during scrolling.
    func lippiScrollPerformance() -> some View {
        modifier(LippiScrollPerformanceModifier())
    }

    /// Disables implicit work while a shared scroll view is actively moving.
    func lippiPerformanceResponsive() -> some View {
        modifier(LippiPerformanceModeModifier())
    }
}
