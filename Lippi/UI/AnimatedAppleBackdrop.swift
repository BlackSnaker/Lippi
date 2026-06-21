import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Animated Apple-like Backdrop (без Canvas/Timeline)
// =======================================================
struct AnimatedAppleBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var animate = false

    private var reducedEffects: Bool { DS.performanceEffectsReduced || reduceMotion || reduceTransparency }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxSide = max(w, h)
            let phase = animate && !reducedEffects

            ZStack {
                // База: глубокий вертикальный градиент
                LinearGradient(
                    colors: [Color(hex: 0x201334), Color(hex: 0x0B3156)],
                    startPoint: .top, endPoint: .bottom
                )

                // Мягкие «световые пятна» (blend .plusLighter), медленно «дышат»
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x8E5CFF), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: maxSide * 1.2, height: maxSide * 1.2)
                    .blur(radius: reducedEffects ? 42 : 72)
                    .offset(x: phase ?  w * 0.25 : -w * 0.15,
                            y: phase ? -h * 0.10 :  h * 0.15)
                    .blendMode(reducedEffects ? .screen : .plusLighter)

                Circle()
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x3D7BFF), .clear],
                                       startPoint: .bottomTrailing, endPoint: .topLeading)
                    )
                    .frame(width: maxSide * 1.4, height: maxSide * 1.4)
                    .blur(radius: reducedEffects ? 46 : 78)
                    .offset(x: phase ? -w * 0.20 :  w * 0.30,
                            y: phase ?  h * 0.20 : -h * 0.10)
                    .blendMode(reducedEffects ? .screen : .plusLighter)

                if !reducedEffects {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(hex: 0xFF6BD6), .clear],
                                           startPoint: .topTrailing, endPoint: .bottomLeading)
                        )
                        .frame(width: maxSide, height: maxSide)
                        .blur(radius: 86)
                        .offset(x: phase ?  w * 0.05 : -w * 0.10,
                                y: phase ?  h * 0.15 : -h * 0.20)
                        .blendMode(.plusLighter)
                }

                // Едва заметная диагональная «волна»
                Rectangle()
                    .fill(
                        LinearGradient(stops: [
                            .init(color: .white.opacity(0.06), location: 0.00),
                            .init(color: .clear,              location: 0.35),
                            .init(color: .white.opacity(0.04), location: 0.70),
                            .init(color: .clear,              location: 1.00)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
            .onAppear {
                guard !reducedEffects else { return }
                withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
}

// =======================================================
// MARK: - Безопасная обёртка для прозрачного навбара
// =======================================================
extension View {
    @ViewBuilder
    func clearNavBarBackgroundIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        } else {
            self
        }
    }
}
