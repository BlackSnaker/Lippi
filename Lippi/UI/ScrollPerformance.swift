import SwiftUI

private struct LippiIsScrollingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var lippiIsScrolling: Bool {
        get { self[LippiIsScrollingKey.self] }
        set { self[LippiIsScrollingKey.self] = newValue }
    }
}

@MainActor
final class ScrollPerformanceCoordinator: ObservableObject {
    @Published private(set) var isScrolling = false
    private var settleTask: Task<Void, Never>?

    func setScrolling(_ value: Bool) {
        settleTask?.cancel()

        if value {
            if !isScrolling { isScrolling = true }
            return
        }

        // Keep the lightweight render path through the final deceleration frames.
        settleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.isScrolling = false
        }
    }

    func stop() {
        settleTask?.cancel()
        settleTask = nil
        isScrolling = false
    }
}

private struct LippiScrollPerformanceModifier: ViewModifier {
    @EnvironmentObject private var coordinator: ScrollPerformanceCoordinator

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                coordinator.setScrolling(phase.isScrolling)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Lets shared glass surfaces switch to their lighter drawing path during scrolling.
    func lippiScrollPerformance() -> some View {
        modifier(LippiScrollPerformanceModifier())
    }
}
