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
    private let settleDelay: UInt64 = 420_000_000
    private var activeGestures = 0

    func setScrolling(_ value: Bool) {
        settleTask?.cancel()

        if value {
            updateScrolling(true)
            return
        }

        // Keep animation throttling through the final deceleration frames without
        // changing the visual hierarchy or material quality.
        settleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.settleDelay ?? 360_000_000)
            guard !Task.isCancelled else { return }
            self?.updateScrolling(false)
        }
    }

    func beginGesture() {
        activeGestures = 1
        setScrolling(true)
    }

    func endGesture() {
        activeGestures = max(0, activeGestures - 1)
        guard activeGestures == 0 else { return }
        setScrolling(false)
    }

    func stop() {
        settleTask?.cancel()
        settleTask = nil
        activeGestures = 0
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        coordinator?.beginGesture()
                    }
                    .onEnded { _ in
                        coordinator?.endGesture()
                    }
            )

        if #available(iOS 18.0, *), let coordinator {
            tunedContent
                .onScrollPhaseChange { _, phase in
                    if phase.isScrolling {
                        coordinator.setScrolling(true)
                    } else {
                        coordinator.endGesture()
                    }
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
    /// Reports active scrolling so expensive continuous motion can lower its frame rate.
    /// Static surfaces must keep the same visual representation while this flag changes.
    func lippiScrollPerformance() -> some View {
        modifier(LippiScrollPerformanceModifier())
    }

    /// Disables implicit work while a shared scroll view is actively moving.
    func lippiPerformanceResponsive() -> some View {
        modifier(LippiPerformanceModeModifier())
    }
}
