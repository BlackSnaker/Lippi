import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Break Section (mini platformer)
// =======================================================
struct BreakView: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var showGame = false
    @State private var bestScore = UserDefaults.standard.integer(forKey: BreakGameModel.bestScoreKey)
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroCard
                        launchCard
                        hintsCard
                        Color.clear.frame(height: 84)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(s("break.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 92) }
        }
        .fullScreenCover(isPresented: $showGame) {
            BreakGameFullscreenView()
        }
        .onAppear {
            bestScore = UserDefaults.standard.integer(forKey: BreakGameModel.bestScoreKey)
        }
        .onChange(of: showGame) { _, opened in
            if !opened {
                bestScore = UserDefaults.standard.integer(forKey: BreakGameModel.bestScoreKey)
            }
        }
    }

    private var heroCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: s("break.hero.title"),
                    subtitle: s("break.hero.subtitle"),
                    icon: "gamecontroller.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                Text(s("break.hero.description"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    BreakHUDChip(
                        icon: "star.fill",
                        title: s("break.hud.record"),
                        value: "\(bestScore)"
                    )
                    BreakHUDChip(
                        icon: "target",
                        title: s("break.hud.goal"),
                        value: s("break.hud.goal_value")
                    )
                    BreakHUDChip(
                        icon: "flag.fill",
                        title: s("break.hud.distance"),
                        value: s("break.hud.distance_value")
                    )
                }
            }
        }
    }

    private var launchCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    LippiSectionHeader(
                        title: s("break.launch.title"),
                        subtitle: s("break.launch.subtitle"),
                        icon: "figure.run",
                        accent: Color(hex: 0x30D158)
                    )
                    Spacer()
                }

                BreakLaunchPreview()
                .frame(height: 260)

                Text(s("break.launch.description"))
                .font(.footnote)
                .foregroundStyle(DS.text(0.68))
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    BreakHaptics.tap()
                    showGame = true
                } label: {
                    Label(s("break.launch.button"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))
                .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.95))
            }
        }
    }

    private var hintsCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 8) {
                LippiSectionHeader(
                    title: s("break.hints.title"),
                    subtitle: s("break.hints.subtitle"),
                    icon: "lightbulb.fill",
                    accent: Color(hex: 0xFFD60A)
                )

                Text(s("break.hints.step1"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
                Text(s("break.hints.step2"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
                Text(s("break.hints.step3"))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.70))
            }
        }
    }
}

// MARK: - Fullscreen Game
// =======================================================
private struct BreakGameFullscreenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    @StateObject private var game = BreakGameModel()
    @State private var lastTick: Date = .now
    @State private var viewportWidth: CGFloat = 320

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            VStack(spacing: 10) {
                topBar

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DS.glassFill(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        )

                    GeometryReader { geo in
                        BreakGameScene(game: game)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onAppear {
                                viewportWidth = max(220, geo.size.width)
                                game.updateCamera(viewportWidth: viewportWidth)
                            }
                            .onChange(of: geo.size.width) { _, newWidth in
                                viewportWidth = max(220, newWidth)
                                game.updateCamera(viewportWidth: viewportWidth)
                            }
                    }

                    if game.phase != .running {
                        gameOverlay
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomMetrics
                controlsRow
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            lastTick = .now
            game.start()
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { now in
            guard scenePhase == .active else { return }
            let maxDt: TimeInterval = reduceMotion ? (1.0 / 20.0) : (1.0 / 35.0)
            let dt = min(max(now.timeIntervalSince(lastTick), 0), maxDt)
            lastTick = now
            game.tick(dt: CGFloat(dt), viewportWidth: viewportWidth)
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active {
                game.pauseIfRunning()
                lastTick = .now
            }
        }
        .onDisappear {
            game.stopMovement()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                BreakHaptics.tap()
                dismiss()
            } label: {
                Label(s("break.close"), systemImage: "xmark.circle.fill")
                    .labelStyle(TightLabelStyle())
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))

            Spacer(minLength: 8)

            BreakHUDChip(icon: "star.fill", title: s("break.hud.coins"), value: "\(game.score)/\(game.totalCoins)")
            BreakHUDChip(icon: "heart.fill", title: s("break.hud.lives"), value: "\(max(game.lives, 0))")
            BreakHUDChip(icon: "timer", title: s("break.hud.time"), value: game.timeLabel)
        }
    }

    private var bottomMetrics: some View {
        HStack(spacing: 10) {
            BreakHUDChip(icon: "flag.fill", title: s("break.hud.progress"), value: "\(Int((game.progress * 100).rounded()))%")
            BreakHUDChip(icon: "star.fill", title: s("break.hud.record"), value: "\(game.bestScore)")
        }
    }

    @ViewBuilder
    private var gameOverlay: some View {
        VStack(spacing: 12) {
            Text(overlayTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.text(0.95))
                .singleLine()

            Text(overlaySubtitle)
                .font(.footnote)
                .foregroundStyle(DS.text(0.70))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(primaryButtonTitle) { primaryAction() }
                    .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))

                if game.phase == .paused {
                    Button(s("break.reset")) { game.start() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            }
        }
        .padding(16)
        .background(DS.glassFill(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DS.glassStroke(0.18), lineWidth: 1)
        )
        .padding(18)
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            HoldMoveButton(icon: "arrow.left", title: s("break.controls.left")) { pressed in
                guard game.phase == .running else { return }
                game.setMovingLeft(pressed)
            }

            HoldMoveButton(icon: "arrow.right", title: s("break.controls.right")) { pressed in
                guard game.phase == .running else { return }
                game.setMovingRight(pressed)
            }

            Spacer(minLength: 6)

            ActionControlButton(icon: "arrow.up.circle.fill", title: s("break.controls.jump")) {
                game.jump()
            }

            ActionControlButton(
                icon: game.phase == .paused ? "play.fill" : "pause.fill",
                title: game.phase == .paused ? s("break.controls.play") : s("break.controls.pause")
            ) {
                game.togglePause()
            }
        }
    }

    private var overlayTitle: String {
        switch game.phase {
        case .ready: return s("break.overlay.ready_title")
        case .paused: return s("break.overlay.paused_title")
        case .won: return s("break.overlay.won_title")
        case .lost: return s("break.overlay.lost_title")
        case .running: return ""
        }
    }

    private var overlaySubtitle: String {
        switch game.phase {
        case .ready:
            return s("break.overlay.ready_subtitle")
        case .paused:
            return s("break.overlay.paused_subtitle")
        case .won:
            return L10n.fmt("break.overlay.won_subtitle", lang, game.score, game.totalCoins, game.timeLabel)
        case .lost:
            return L10n.fmt("break.overlay.lost_subtitle", lang, game.score, game.totalCoins)
        case .running:
            return ""
        }
    }

    private var primaryButtonTitle: String {
        switch game.phase {
        case .ready: return s("break.overlay.start")
        case .paused: return s("break.overlay.resume")
        case .won, .lost: return s("break.overlay.play_again")
        case .running: return ""
        }
    }

    private func primaryAction() {
        switch game.phase {
        case .ready, .won, .lost: game.start()
        case .paused: game.togglePause()
        case .running: break
        }
    }
}

private struct BreakLaunchPreview: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let groundY = h - 46

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(dynamicDark: 0x1C212B, light: 0xDCE8FF),
                                Color(dynamicDark: 0x151A23, light: 0xC7DBFF)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Capsule()
                    .fill(Color(dynamicDark: 0x5E6674, light: 0x8FA1C2, darkAlpha: 0.92, lightAlpha: 0.92))
                    .frame(width: w * 0.34, height: 22)
                    .position(x: w * 0.22, y: groundY)

                Capsule()
                    .fill(Color(dynamicDark: 0x5E6674, light: 0x8FA1C2, darkAlpha: 0.92, lightAlpha: 0.92))
                    .frame(width: w * 0.30, height: 22)
                    .position(x: w * 0.62, y: groundY)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: 0xFF453A))
                    .frame(width: 26, height: 34)
                    .position(x: w * 0.24, y: groundY - 30)

                Circle()
                    .fill(Color(hex: 0xFFD60A))
                    .frame(width: 16, height: 16)
                    .position(x: w * 0.48, y: groundY - 54)

                Image(safeSystemName: "flag.fill", fallback: "flag")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF9F0A))
                    .position(x: w * 0.84, y: groundY - 54)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }
}

private enum BreakHaptics {
    static func start() {
        #if os(iOS)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        let soft = UIImpactFeedbackGenerator(style: .soft)
        medium.impactOccurred(intensity: 0.95)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            soft.impactOccurred(intensity: 0.65)
        }
        #endif
    }

    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.62)
        #endif
    }

    static func jump() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.78)
        #endif
    }

    static func coin() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.72)
        #endif
    }

    static func damage() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.86)
        }
        #endif
    }

    static func win() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.70)
        }
        #endif
    }
}

// =======================================================
// MARK: - Game Engine
// =======================================================
private enum BreakGamePhase {
    case ready
    case running
    case paused
    case won
    case lost
}

private struct BreakPlatform: Identifiable {
    let id: Int
    let rect: CGRect
}

private struct BreakCoin: Identifiable {
    let id: Int
    let position: CGPoint
    let radius: CGFloat
}

private struct BreakHazard: Identifiable {
    let id: Int
    let rect: CGRect
}

private final class BreakGameModel: ObservableObject {
    static let bestScoreKey = "lippi_break_best_score"

    @Published private(set) var phase: BreakGamePhase = .ready
    @Published private(set) var score: Int = 0
    @Published private(set) var lives: Int = 3
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var bestScore: Int = 0
    @Published private(set) var playerCenter: CGPoint
    @Published private(set) var cameraX: CGFloat = 0
    @Published private(set) var collectedCoins: Set<Int> = []

    let worldSize = CGSize(width: 3400, height: 360)
    let finishX: CGFloat = 3310
    let playerSize = CGSize(width: 30, height: 38)

    let platforms: [BreakPlatform]
    let hazards: [BreakHazard]
    let coins: [BreakCoin]

    private let groundTop: CGFloat = 320
    private let gravity: CGFloat = 1800
    private let acceleration: CGFloat = 1900
    private let friction: CGFloat = 1600
    private let maxSpeed: CGFloat = 270
    private let jumpVelocity: CGFloat = -650
    private let maxFallVelocity: CGFloat = 1100
    private let checkpoints: [CGFloat] = [80, 620, 1060, 1500, 1960, 2460, 2940]

    private var velocity: CGVector = .zero
    private var movingLeft = false
    private var movingRight = false
    private var queuedJump = false
    private var isGrounded = false

    init() {
        self.platforms = BreakGameModel.buildPlatforms()
        self.hazards = BreakGameModel.buildHazards()
        self.coins = BreakGameModel.buildCoins()
        self.playerCenter = CGPoint(x: 80, y: 280)
        self.bestScore = UserDefaults.standard.integer(forKey: Self.bestScoreKey)
        reset(toReady: true)
    }

    var totalCoins: Int { coins.count }

    var playerFrame: CGRect {
        CGRect(
            x: playerCenter.x - playerSize.width * 0.5,
            y: playerCenter.y - playerSize.height * 0.5,
            width: playerSize.width,
            height: playerSize.height
        )
    }

    var progress: Double {
        min(max(Double(playerCenter.x / finishX), 0), 1)
    }

    var timeLabel: String {
        let total = Int(elapsed.rounded())
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }

    func start() {
        BreakHaptics.start()
        reset(toReady: false)
    }

    func pauseIfRunning() {
        if phase == .running {
            phase = .paused
        }
        stopMovement()
    }

    func togglePause() {
        switch phase {
        case .running:
            phase = .paused
            stopMovement()
        case .paused:
            phase = .running
        default:
            break
        }
    }

    func setMovingLeft(_ active: Bool) {
        movingLeft = active
    }

    func setMovingRight(_ active: Bool) {
        movingRight = active
    }

    func stopMovement() {
        movingLeft = false
        movingRight = false
    }

    func jump() {
        guard phase == .running else { return }
        queuedJump = true
    }

    func updateCamera(viewportWidth: CGFloat) {
        cameraX = clampedCameraX(for: viewportWidth)
    }

    func tick(dt: CGFloat, viewportWidth: CGFloat) {
        guard phase == .running else { return }
        guard dt > 0 else { return }

        elapsed += TimeInterval(dt)

        if movingLeft == movingRight {
            let decel = friction * dt
            if abs(velocity.dx) <= decel {
                velocity.dx = 0
            } else {
                velocity.dx += velocity.dx > 0 ? -decel : decel
            }
        } else {
            let direction: CGFloat = movingRight ? 1 : -1
            velocity.dx += direction * acceleration * dt
            velocity.dx = min(max(velocity.dx, -maxSpeed), maxSpeed)
        }

        if queuedJump {
            if isGrounded {
                velocity.dy = jumpVelocity
                isGrounded = false
                BreakHaptics.jump()
            }
            queuedJump = false
        }

        velocity.dy = min(velocity.dy + gravity * dt, maxFallVelocity)

        let halfW = playerSize.width * 0.5
        let halfH = playerSize.height * 0.5
        let previousCenter = playerCenter

        var nextCenter = CGPoint(
            x: playerCenter.x + velocity.dx * dt,
            y: playerCenter.y + velocity.dy * dt
        )

        if nextCenter.x < halfW {
            nextCenter.x = halfW
            velocity.dx = 0
        }
        if nextCenter.x > worldSize.width - halfW {
            nextCenter.x = worldSize.width - halfW
            velocity.dx = 0
        }

        isGrounded = false
        if velocity.dy >= 0 {
            let previousBottom = previousCenter.y + halfH
            let nextBottom = nextCenter.y + halfH
            var landingTop: CGFloat?

            for platform in platforms {
                let platformRect = platform.rect
                let overlapsHorizontally =
                    (nextCenter.x + halfW) > platformRect.minX &&
                    (nextCenter.x - halfW) < platformRect.maxX

                guard overlapsHorizontally else { continue }

                if previousBottom <= platformRect.minY + 2,
                   nextBottom >= platformRect.minY {
                    landingTop = min(landingTop ?? platformRect.minY, platformRect.minY)
                }
            }

            if let top = landingTop {
                nextCenter.y = top - halfH
                velocity.dy = 0
                isGrounded = true
            }
        }

        playerCenter = nextCenter
        cameraX = clampedCameraX(for: viewportWidth)

        collectCoins()

        if hitHazard(playerFrame: playerFrame) {
            loseLife()
            return
        }

        if playerFrame.minY > worldSize.height + 80 {
            loseLife()
            return
        }

        if playerCenter.x >= finishX {
            phase = .won
            stopMovement()
            updateBestScoreIfNeeded()
            BreakHaptics.win()
        }
    }

    private func collectCoins() {
        guard phase == .running else { return }
        let grabRadius: CGFloat = 20
        for coin in coins where !collectedCoins.contains(coin.id) {
            let dx = playerCenter.x - coin.position.x
            let dy = playerCenter.y - coin.position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance <= (grabRadius + coin.radius) {
                collectedCoins.insert(coin.id)
                score += 1
                BreakHaptics.coin()
            }
        }
    }

    private func hitHazard(playerFrame: CGRect) -> Bool {
        let hitbox = playerFrame.insetBy(dx: 4, dy: 2)
        for hazard in hazards where hitbox.intersects(hazard.rect) {
            return true
        }
        return false
    }

    private func loseLife() {
        lives -= 1
        stopMovement()
        BreakHaptics.damage()

        if lives <= 0 {
            phase = .lost
            updateBestScoreIfNeeded()
            return
        }

        respawnAtCheckpoint()
    }

    private func respawnAtCheckpoint() {
        let checkpoint = checkpoints.last(where: { $0 <= playerCenter.x }) ?? checkpoints.first ?? 80
        let yTop = surfaceTopY(at: checkpoint)
        playerCenter = CGPoint(x: checkpoint, y: yTop - playerSize.height * 0.5)
        velocity = .zero
        isGrounded = true
        queuedJump = false
    }

    private func surfaceTopY(at x: CGFloat) -> CGFloat {
        var minY = groundTop
        for platform in platforms where x >= platform.rect.minX && x <= platform.rect.maxX {
            minY = min(minY, platform.rect.minY)
        }
        return minY
    }

    private func clampedCameraX(for viewportWidth: CGFloat) -> CGFloat {
        let target = playerCenter.x - (viewportWidth * 0.38)
        let maxCamera = max(0, worldSize.width - viewportWidth)
        return min(max(target, 0), maxCamera)
    }

    private func updateBestScoreIfNeeded() {
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: Self.bestScoreKey)
        }
    }

    private func reset(toReady: Bool) {
        phase = toReady ? .ready : .running
        score = 0
        lives = 3
        elapsed = 0
        collectedCoins.removeAll()
        velocity = .zero
        movingLeft = false
        movingRight = false
        queuedJump = false
        isGrounded = true

        let startY = surfaceTopY(at: 80)
        playerCenter = CGPoint(x: 80, y: startY - playerSize.height * 0.5)
        cameraX = 0
    }

    private static func buildPlatforms() -> [BreakPlatform] {
        let groundY: CGFloat = 320
        let data: [CGRect] = [
            CGRect(x: 0, y: groundY, width: 460, height: 42),
            CGRect(x: 560, y: groundY, width: 360, height: 42),
            CGRect(x: 980, y: groundY, width: 420, height: 42),
            CGRect(x: 1490, y: groundY, width: 350, height: 42),
            CGRect(x: 1920, y: groundY, width: 420, height: 42),
            CGRect(x: 2440, y: groundY, width: 360, height: 42),
            CGRect(x: 2860, y: groundY, width: 560, height: 42),
            CGRect(x: 220, y: 252, width: 130, height: 18),
            CGRect(x: 720, y: 252, width: 130, height: 18),
            CGRect(x: 1180, y: 248, width: 120, height: 18),
            CGRect(x: 1700, y: 246, width: 120, height: 18),
            CGRect(x: 2140, y: 244, width: 120, height: 18),
            CGRect(x: 2660, y: 242, width: 120, height: 18)
        ]
        return data.enumerated().map { BreakPlatform(id: $0.offset, rect: $0.element) }
    }

    private static func buildHazards() -> [BreakHazard] {
        let data: [CGRect] = [
            CGRect(x: 492, y: 298, width: 54, height: 22),
            CGRect(x: 940, y: 298, width: 46, height: 22),
            CGRect(x: 1434, y: 298, width: 48, height: 22),
            CGRect(x: 1862, y: 298, width: 46, height: 22),
            CGRect(x: 2362, y: 298, width: 50, height: 22),
            CGRect(x: 2822, y: 298, width: 38, height: 22)
        ]
        return data.enumerated().map { BreakHazard(id: $0.offset, rect: $0.element) }
    }

    private static func buildCoins() -> [BreakCoin] {
        let points: [CGPoint] = [
            CGPoint(x: 280, y: 224),
            CGPoint(x: 760, y: 224),
            CGPoint(x: 1200, y: 220),
            CGPoint(x: 1725, y: 218),
            CGPoint(x: 2158, y: 216),
            CGPoint(x: 2680, y: 214),
            CGPoint(x: 640, y: 284),
            CGPoint(x: 1080, y: 284),
            CGPoint(x: 1560, y: 284),
            CGPoint(x: 2010, y: 284),
            CGPoint(x: 2520, y: 284),
            CGPoint(x: 3060, y: 284)
        ]
        return points.enumerated().map { BreakCoin(id: $0.offset, position: $0.element, radius: 8) }
    }
}

// =======================================================
// MARK: - Game Scene
// =======================================================
private struct BreakGameScene: View {
    @ObservedObject var game: BreakGameModel

    var body: some View {
        Canvas(opaque: true, colorMode: .linear, rendersAsynchronously: true) { ctx, size in
            drawBackground(in: &ctx, size: size)
            drawParallax(in: &ctx, size: size)
            drawPlatforms(in: &ctx, size: size)
            drawHazards(in: &ctx, size: size)
            drawCoins(in: &ctx, size: size)
            drawFinish(in: &ctx, size: size)
            drawPlayer(in: &ctx, size: size)
            drawTopHUD(in: &ctx, size: size)
        }
        .allowsHitTesting(false)
    }

    private func drawBackground(in ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(dynamicDark: 0x1A1E26, light: 0xDDE8FF),
                    Color(dynamicDark: 0x141820, light: 0xC9DBFF),
                    Color(dynamicDark: 0x10131A, light: 0xBFD3FF)
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawParallax(in ctx: inout GraphicsContext, size: CGSize) {
        let unit: CGFloat = 320
        let offsetSlow = (game.cameraX * 0.22).truncatingRemainder(dividingBy: unit)
        let offsetFast = (game.cameraX * 0.42).truncatingRemainder(dividingBy: unit)

        for i in -1...4 {
            let xSlow = CGFloat(i) * unit - offsetSlow
            let hillSlow = CGRect(x: xSlow - 40, y: size.height - 140, width: 220, height: 110)
            ctx.fill(
                Path(ellipseIn: hillSlow),
                with: .color(Color(dynamicDark: 0x2A313D, light: 0xB7C9EF, darkAlpha: 0.50, lightAlpha: 0.55))
            )

            let xFast = CGFloat(i) * unit - offsetFast
            let hillFast = CGRect(x: xFast + 40, y: size.height - 100, width: 200, height: 90)
            ctx.fill(
                Path(ellipseIn: hillFast),
                with: .color(Color(dynamicDark: 0x343D4C, light: 0xAFC4EC, darkAlpha: 0.48, lightAlpha: 0.52))
            )
        }
    }

    private func drawPlatforms(in ctx: inout GraphicsContext, size: CGSize) {
        for platform in game.platforms {
            let rect = CGRect(
                x: platform.rect.minX - game.cameraX,
                y: platform.rect.minY,
                width: platform.rect.width,
                height: platform.rect.height
            )
            guard rect.maxX >= -40, rect.minX <= size.width + 40 else { continue }

            let rounded = RoundedRectangle(cornerRadius: 6, style: .continuous)
            ctx.fill(rounded.path(in: rect), with: .color(Color(dynamicDark: 0x6E7583, light: 0x8FA0BF, darkAlpha: 0.94, lightAlpha: 0.94)))
            ctx.stroke(rounded.path(in: rect), with: .color(Color.white.opacity(0.12)), lineWidth: 1)

            let topLine = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3)
            ctx.fill(Path(topLine), with: .color(Color.white.opacity(0.12)))
        }
    }

    private func drawHazards(in ctx: inout GraphicsContext, size: CGSize) {
        for hazard in game.hazards {
            let rect = CGRect(
                x: hazard.rect.minX - game.cameraX,
                y: hazard.rect.minY,
                width: hazard.rect.width,
                height: hazard.rect.height
            )
            guard rect.maxX >= -20, rect.minX <= size.width + 20 else { continue }

            let spikes = max(2, Int(rect.width / 14))
            let spikeWidth = rect.width / CGFloat(spikes)

            for i in 0..<spikes {
                let x = rect.minX + CGFloat(i) * spikeWidth
                var path = Path()
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x + spikeWidth * 0.5, y: rect.minY))
                path.addLine(to: CGPoint(x: x + spikeWidth, y: rect.maxY))
                path.closeSubpath()
                ctx.fill(path, with: .color(Color(hex: 0xFF5A5F)))
            }
        }
    }

    private func drawCoins(in ctx: inout GraphicsContext, size: CGSize) {
        for coin in game.coins where !game.collectedCoins.contains(coin.id) {
            let center = CGPoint(x: coin.position.x - game.cameraX, y: coin.position.y)
            guard center.x >= -30, center.x <= size.width + 30 else { continue }

            let rect = CGRect(
                x: center.x - coin.radius,
                y: center.y - coin.radius,
                width: coin.radius * 2,
                height: coin.radius * 2
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xFFD60A)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0xFFB300)), lineWidth: 1.6)

            let shine = CGRect(
                x: center.x - coin.radius * 0.45,
                y: center.y - coin.radius * 0.55,
                width: coin.radius * 0.55,
                height: coin.radius * 0.55
            )
            ctx.fill(Path(ellipseIn: shine), with: .color(Color.white.opacity(0.35)))
        }
    }

    private func drawFinish(in ctx: inout GraphicsContext, size: CGSize) {
        let x = game.finishX - game.cameraX
        guard x >= -20, x <= size.width + 40 else { return }

        let pole = CGRect(x: x, y: 196, width: 6, height: 124)
        ctx.fill(Path(pole), with: .color(Color.white.opacity(0.85)))

        var flag = Path()
        flag.move(to: CGPoint(x: x + 6, y: 206))
        flag.addLine(to: CGPoint(x: x + 44, y: 218))
        flag.addLine(to: CGPoint(x: x + 6, y: 232))
        flag.closeSubpath()
        ctx.fill(flag, with: .color(Color(hex: 0xFF9F0A)))
    }

    private func drawPlayer(in ctx: inout GraphicsContext, size: CGSize) {
        let frame = game.playerFrame
        let rect = CGRect(x: frame.minX - game.cameraX, y: frame.minY, width: frame.width, height: frame.height)
        guard rect.maxX >= -30, rect.minX <= size.width + 30 else { return }

        let bodyRect = rect.insetBy(dx: 2, dy: 2)
        let body = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ctx.fill(body.path(in: bodyRect), with: .color(Color(hex: 0xFF453A)))
        ctx.stroke(body.path(in: bodyRect), with: .color(Color.white.opacity(0.22)), lineWidth: 1)

        let capRect = CGRect(x: bodyRect.minX - 1, y: bodyRect.minY - 6, width: bodyRect.width + 2, height: 10)
        let cap = RoundedRectangle(cornerRadius: 5, style: .continuous)
        ctx.fill(cap.path(in: capRect), with: .color(Color(hex: 0xFF9F0A)))

        let eyeRect = CGRect(x: bodyRect.minX + bodyRect.width * 0.58, y: bodyRect.minY + 10, width: 4, height: 4)
        ctx.fill(Path(ellipseIn: eyeRect), with: .color(.white.opacity(0.92)))
    }

    private func drawTopHUD(in ctx: inout GraphicsContext, size: CGSize) {
        let progress = max(0, min(1, game.progress))
        let barRect = CGRect(x: 12, y: 12, width: size.width - 24, height: 8)

        let back = RoundedRectangle(cornerRadius: 4, style: .continuous)
        ctx.fill(back.path(in: barRect), with: .color(Color.black.opacity(0.22)))

        let fillRect = CGRect(x: barRect.minX, y: barRect.minY, width: max(8, barRect.width * progress), height: barRect.height)
        ctx.fill(
            back.path(in: fillRect),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x34C759), Color(hex: 0x64D2FF)]),
                startPoint: CGPoint(x: fillRect.minX, y: fillRect.minY),
                endPoint: CGPoint(x: fillRect.maxX, y: fillRect.maxY)
            )
        )
    }
}

// =======================================================
// MARK: - Reusable Controls
// =======================================================
private struct BreakHUDChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Image(safeSystemName: icon, fallback: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.86))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.text(0.60))
                    .singleLine()
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.92))
                    .monospacedDigit()
                    .singleLine()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.glassFill(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }
}

private struct HoldMoveButton: View {
    let icon: String
    let title: String
    let onPressChanged: (Bool) -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 4) {
            Image(safeSystemName: icon, fallback: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.text(0.92))
                .frame(width: 44, height: 44)
                .background(DS.glassFill(isPressed ? 0.18 : 0.11), in: Circle())
                .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
                .scaleEffect(isPressed ? 0.96 : 1.0)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.text(0.66))
                .singleLine()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    BreakHaptics.tap()
                    onPressChanged(true)
                }
                .onEnded { _ in
                    guard isPressed else { return }
                    isPressed = false
                    onPressChanged(false)
                }
        )
        .onDisappear {
            if isPressed {
                isPressed = false
                onPressChanged(false)
            }
        }
    }
}

private struct ActionControlButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(TightLabelStyle())
                .frame(minWidth: 94)
        }
        .simultaneousGesture(
            TapGesture().onEnded { BreakHaptics.tap() }
        )
        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
    }
}
