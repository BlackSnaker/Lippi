// EyeExerciseModule.swift
// Lippi — Eye Trainer (advanced)
// Self‑contained module: settings+store+modes+stats+achievements+UI
// Requires your existing helpers: GlassCard, TightLabelStyle, LippiButtonStyle, AnimatedBackground
// Optional: Charts (guarded by canImport(Charts))

import SwiftUI
#if canImport(Charts)
import Charts
#endif
#if os(iOS)
import UIKit
import AudioToolbox
#endif

// =======================================================
// MARK: - Settings & Models
// =======================================================
struct EyeExerciseSettings: Codable, Hashable {
    // Suggestion logic
    var autoSuggestEnabled: Bool = true
    var suggestThresholdMinutes: Int = 40
    var cooldownMinutes: Int = 45

    // Base session config
    var targetsPerSession: Int = 16
    var maxTimePerTarget: Double = 2.0
    var dotSize: CGFloat = 34

    // Difficulty knobs
    var enableAdaptive: Bool = true
    var adaptiveStepEvery: Int = 3
    var minDotScale: Double = 0.6
    var minTimeScale: Double = 0.5

    // Modes toggles (can be switched in UI anyway)
    var enableMoving: Bool = true
    var enableColor: Bool = true
    var enablePeripheral: Bool = true
    var enableTracking: Bool = true

    // Breaks
    var enableBreaks: Bool = true
    var breakAfterTargets: Int = 8
    var breakDurationSec: Int = 20

    // Feedback
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
}

enum EyeGameMode: String, Codable, CaseIterable, Identifiable {
    case classic = "Классика"
    case moving = "Движение"
    case color = "Цвет"
    case peripheral = "Периферия"
    case tracking = "Слежение"
    var id: String { rawValue }

    func title(_ lang: AppLang = L10n.currentLang) -> String {
        switch self {
        case .classic: return L10n.tr("eye.mode.classic", lang)
        case .moving: return L10n.tr("eye.mode.moving", lang)
        case .color: return L10n.tr("eye.mode.color", lang)
        case .peripheral: return L10n.tr("eye.mode.peripheral", lang)
        case .tracking: return L10n.tr("eye.mode.tracking", lang)
        }
    }
}

struct EyeSessionHistory: Codable, Identifiable {
    var id: UUID = .init()
    var date: Date = .now
    var mode: EyeGameMode
    var hits: Int
    var misses: Int
    var total: Int
    var avgReaction: Double?
    var bestReaction: Double?
    var bestStreak: Int
}

enum EyeAchievement: String, Codable, CaseIterable, Identifiable {
    case firstSession = "Первая тренировка"
    case tenHitsStreak = "10 попаданий подряд"
    case sub200ms = "Реакция < 200 мс"
    case noMiss = "0 промахов"
    case fiveDays = "5 дней подряд"
    case proHawk = "Орлиный глаз"
    var id: String { rawValue }

    func title(_ lang: AppLang = L10n.currentLang) -> String {
        switch self {
        case .firstSession: return L10n.tr("eye.achievement.first_session", lang)
        case .tenHitsStreak: return L10n.tr("eye.achievement.ten_hits_streak", lang)
        case .sub200ms: return L10n.tr("eye.achievement.sub_200ms", lang)
        case .noMiss: return L10n.tr("eye.achievement.no_miss", lang)
        case .fiveDays: return L10n.tr("eye.achievement.five_days", lang)
        case .proHawk: return L10n.tr("eye.achievement.pro_hawk", lang)
        }
    }
}

// =======================================================
// MARK: - Store (Settings + History + Achievements)
// =======================================================
final class EyeExerciseStore: ObservableObject {
    @Published var settings: EyeExerciseSettings { didSet { saveSettings() } }
    @Published private(set) var history: [EyeSessionHistory] = []
    @Published private(set) var achievements: Set<EyeAchievement> = []

    private let settingsURL: URL
    private let historyURL: URL
    private let achieveURL: URL

    private var lastSuggestedAt: Date?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        settingsURL = docs.appendingPathComponent("eye_settings.json")
        historyURL  = docs.appendingPathComponent("eye_history.json")
        achieveURL  = docs.appendingPathComponent("eye_achievements.json")

        if let data = try? Data(contentsOf: settingsURL), let s = try? JSONDecoder().decode(EyeExerciseSettings.self, from: data) {
            self.settings = s
        } else {
            self.settings = EyeExerciseSettings()
        }
        if let data = try? Data(contentsOf: historyURL), let h = try? JSONDecoder().decode([EyeSessionHistory].self, from: data) {
            self.history = h
        }
        if let data = try? Data(contentsOf: achieveURL), let a = try? JSONDecoder().decode(Set<EyeAchievement>.self, from: data) {
            self.achievements = a
        }

        // Auto-suggest hook
        NotificationCenter.default.addObserver(forName: .focusWorkLogged, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard self.settings.autoSuggestEnabled else { return }
            let secs = (note.userInfo?["seconds"] as? TimeInterval) ?? 0
            if secs >= Double(self.settings.suggestThresholdMinutes * 60) {
                if let last = self.lastSuggestedAt,
                   Date().timeIntervalSince(last) < Double(self.settings.cooldownMinutes * 60) {
                    return
                }
                self.lastSuggestedAt = Date()
                NotificationCenter.default.post(name: .suggestEyeExercise, object: nil)
            }
        }
    }

    func addSession(_ s: EyeSessionHistory) {
        history.insert(s, at: 0)
        saveHistory()
        evaluateAchievements(for: s)
    }

    var dayStreak: Int {
        guard !history.isEmpty else { return 0 }
        let cal = Calendar.current
        var streak = 0
        var day = Date()
        while true {
            if history.contains(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else { break }
        }
        return streak
    }

    private func evaluateAchievements(for s: EyeSessionHistory) {
        var newOnes: [EyeAchievement] = []
        if !achievements.contains(.firstSession) { newOnes.append(.firstSession) }
        if s.bestStreak >= 10 { newOnes.append(.tenHitsStreak) }
        if (s.bestReaction ?? 999) < 0.200 { newOnes.append(.sub200ms) }
        if s.misses == 0 { newOnes.append(.noMiss) }
        if dayStreak >= 5 { newOnes.append(.fiveDays) }
        if s.hits >= s.total && (s.avgReaction ?? 1) < 0.25 && s.bestStreak >= 15 { newOnes.append(.proHawk) }
        let added = Set(newOnes).subtracting(achievements)
        if !added.isEmpty { achievements.formUnion(added); saveAchievements() }
    }

    private func saveSettings() { try? JSONEncoder().encode(settings).write(to: settingsURL, options: .atomic) }
    private func saveHistory()  { try? JSONEncoder().encode(history ).write(to: historyURL,  options: .atomic) }
    private func saveAchievements() { try? JSONEncoder().encode(achievements).write(to: achieveURL, options: .atomic) }
}

// =======================================================
// MARK: - Helpers (Sound/Haptics)
// =======================================================
struct EyeFeedback {
    static func hit(sound: Bool, haptic: Bool) {
        #if os(iOS)
        if haptic { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if sound { AudioServicesPlaySystemSound(1104) } // Tock
        #endif
    }
    static func miss(sound: Bool, haptic: Bool) {
        #if os(iOS)
        if haptic { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        if sound { AudioServicesPlaySystemSound(1053) } // Short low
        #endif
    }
}

// =======================================================
// MARK: - Main View (Game + Modes + Stats)
// =======================================================
struct EyeExerciseGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: EyeExerciseStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    // State
    private enum GameState { case intro, playing, onBreak, finished }
    @State private var state: GameState = .intro
    @State private var selectedMode: EyeGameMode = .classic

    @State private var areaSize: CGSize = .zero
    @State private var targetPos: CGPoint = .zero
    @State private var lastQuadrant: Int? = nil

    @State private var hits: Int = 0
    @State private var misses: Int = 0
    @State private var totalTargets: Int = 0
    @State private var startTime: Date?

    // per-target timing
    @State private var deadline: Date?
    @State private var spawnedAt: Date?
    @State private var remainRatio: Double = 1

    // adaptive
    @State private var curDot: CGFloat = 34
    @State private var curMaxTime: Double = 2
    @State private var streak: Int = 0
    @State private var bestStreak: Int = 0

    // color/peripheral
    @State private var correctColor: Color = .green
    @State private var targetColor: Color = .green
    @State private var peripheralTargets: [CGPoint] = []
    @State private var peripheralColors: [Color] = []

    // moving/tracking
    @State private var movingVelocity: CGSize = .zero
    @State private var isTrackingActive: Bool = false

    // reaction stats
    @State private var reactions: [Double] = []

    // break timer
    @State private var breakUntil: Date?

    // halo
    @State private var haloScale: CGFloat = 1
    @State private var haloOpacity: Double = 0

    // pause
    @State private var paused: Bool = false

    private var cfg: EyeExerciseSettings { store.settings }
    private var progress: Double { Double(hits + misses) / Double(max(1, cfg.targetsPerSession)) }
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            VStack(spacing: 14) {
                header

                GlassCard {
                    ZStack {
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { areaSize = geo.size }
                                .onChange(of: geo.size) { _, new in areaSize = new }

                            if state == .playing {
                                // Mode-specific draw
                                modeLayer(in: geo.size)

                                // universal halo
                                Circle()
                                    .strokeBorder(.white.opacity(0.7), lineWidth: 2)
                                    .frame(width: curDot * 2.2, height: curDot * 2.2)
                                    .scaleEffect(haloScale)
                                    .opacity(haloOpacity)
                                    .position(targetPos)
                            }

                            if state == .onBreak { breakOverlay }
                            if state == .intro { introOverlay }
                            if state == .finished { summaryOverlay }
                        }
                        .frame(minHeight: 340)
                        .contentShape(Rectangle())
                        .onTapGesture { backgroundTap() }
                    }
                }

                controls
            }
            .padding(20)
        }
        .onAppear { bootstrap() }
        .onReceive(Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()) { t in
            guard state == .playing || state == .onBreak else { return }
            tick(t)
        }
    }

    // ===================================================
    // MARK: - Overlays
    // ===================================================
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                    Text(s("eye.game.title")).font(.headline).singleLine()
                }
                Spacer()
                if state == .playing {
                    HStack(spacing: 8) {
                        capsuleText("\(Int(progress*100))%")
                        capsuleText(L10n.fmt("eye.game.streak", lang, streak))
                        capsuleText(L10n.fmt("eye.game.left_seconds", lang, Int(ceil(remainRatio * curMaxTime))))
                    }
                }
            }
            modePicker
        }
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EyeGameMode.allCases) { m in
                    Button(action: { selectedMode = m }) {
                        Text(m.title(lang)).singleLine().padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    .buttonStyle(LippiButtonStyle(kind: selectedMode == m ? .primary : .secondary))
                }
            }
        }
    }

    private func capsuleText(_ s: String) -> some View {
        Text(s)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(DS.glassFill(0.10), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.16), lineWidth: 1))
            .foregroundStyle(DS.text(0.9))
    }

    private var introOverlay: some View {
        overlayPanel {
            VStack(spacing: 10) {
                Text(s("eye.game.intro.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Text(s("eye.game.intro.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Label(L10n.fmt("eye.game.intro.targets", lang, cfg.targetsPerSession), systemImage: "target")
                    Label(L10n.fmt("eye.game.intro.seconds_per_target", lang, Int(cfg.maxTimePerTarget)), systemImage: "clock")
                    Label("\(Int(cfg.dotSize)) pt", systemImage: "circle")
                }
                .font(.footnote.weight(.semibold))
                .labelStyle(TightLabelStyle())
                .padding(.top, 6)
                .foregroundStyle(DS.text(0.88))
            }
        }
    }

    private var breakOverlay: some View {
        overlayPanel {
            VStack(spacing: 12) {
                Text(s("eye.game.break.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Text(s("eye.game.break.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)

                if let until = breakUntil {
                    let left = max(0, Int(until.timeIntervalSince(.now)))
                    Text(L10n.fmt("eye.game.break.left", lang, left))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.text(0.88))
                }

                Button(s("eye.game.break.skip")) { endBreak() }
                    .buttonStyle(LippiButtonStyle(kind: .secondary))
            }
        }
    }

    private var summaryOverlay: some View {
        overlayPanel {
            VStack(spacing: 10) {
                Text(s("eye.game.summary.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Text(L10n.fmt("eye.game.summary.hits_misses", lang, hits, misses))
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)

                if !reactions.isEmpty {
                    let avg = reactions.reduce(0,+)/Double(reactions.count)
                    let best = reactions.min() ?? 0
                    Text(L10n.fmt("eye.game.summary.reaction", lang, formatMs(avg), formatMs(best), bestStreak))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.text(0.86))
                }

                achievementsRow
                historyMiniChart
            }
        }
    }

    private var achievementsRow: some View {
        let set = store.achievements
        return HStack(spacing: 8) {
            ForEach(EyeAchievement.allCases) { a in
                Image(systemName: set.contains(a) ? "seal.fill" : "seal")
                    .foregroundStyle(set.contains(a) ? .green : .secondary)
                    .help(a.title(lang))
            }
        }
    }

    @ViewBuilder private var historyMiniChart: some View {
        #if canImport(Charts)
        if !store.history.isEmpty {
            let items = store.history.prefix(12)
            Chart(Array(items.enumerated()), id: \.offset) { idx, h in
                if let v = h.avgReaction {
                    LineMark(x: .value(s("eye.chart.session"), idx), y: .value(s("eye.chart.seconds"), v))
                }
            }
            .frame(height: 120)
        }
        #endif
    }

    // ===================================================
    // MARK: - Mode Layer
    // ===================================================
    @ViewBuilder private func modeLayer(in size: CGSize) -> some View {
        // countdown ring
        Circle()
            .trim(from: 0, to: max(0, min(1, remainRatio)))
            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotation(Angle(degrees: -90))
            .frame(width: curDot * 1.8, height: curDot * 1.8)
            .position(targetPos)
            .opacity(paused ? 0.2 : 0.9)

        switch selectedMode {
        case .classic:
            targetCircle(color: .white)
        case .moving:
            targetCircle(color: .white)
                .onChange(of: targetPos) { _, _ in }
        case .color:
            targetCircle(color: targetColor)
            // decoys (wrong colors)
            ForEach(decoyPositions(count: 3), id: \.self) { p in
                Circle().fill(decoyColor())
                    .frame(width: curDot * 0.9, height: curDot * 0.9)
                    .position(p)
                    .onTapGesture { miss() }
            }
        case .peripheral:
            // several points; click only the highlighted (green) one
            ForEach(peripheralTargets.indices, id: \.self) { i in
                Circle().fill(peripheralColors[i])
                    .frame(width: curDot * 0.9, height: curDot * 0.9)
                    .position(peripheralTargets[i])
                    .onTapGesture { peripheralTap(index: i) }
            }
        case .tracking:
            // show moving target; user should press when it stops (at deadline)
            targetCircle(color: .white)
        }
    }

    private func targetCircle(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: curDot, height: curDot)
            .position(targetPos)
            .shadow(radius: 4)
            .contentShape(Circle())
            .onTapGesture { hit() }
    }

    private func decoyPositions(count: Int) -> [CGPoint] {
        guard areaSize.width > 10, areaSize.height > 10 else { return [] }
        let inset: CGFloat = max(curDot, 24)
        let w = max(areaSize.width  - inset*2, 10)
        let h = max(areaSize.height - inset*2, 10)
        return (0..<count).map { _ in
            let x = inset + CGFloat.random(in: 0...1) * w
            let y = inset + CGFloat.random(in: 0...1) * h
            return CGPoint(x: x, y: y)
        }
    }

    private func decoyColor() -> Color {
        let palette: [Color] = [.red, .orange, .yellow, .blue, .purple]
        return palette.randomElement() ?? .red
    }

    // Peripheral tap handler
    private func peripheralTap(index: Int) {
        if peripheralColors[index] == correctColor { hit() } else { miss() }
    }

    // Background taps count as miss only in playing state & not paused
    private func backgroundTap() {
        guard state == .playing && !paused else { return }
        // do not count background taps for tracking mode when target moves automatically
        if selectedMode != .tracking { miss() }
    }

    // ===================================================
    // MARK: - Lifecycle
    // ===================================================
    private func bootstrap() {
        curDot = cfg.dotSize
        curMaxTime = cfg.maxTimePerTarget
    }

    private func start() {
        hits = 0; misses = 0; totalTargets = 0; streak = 0; bestStreak = 0
        reactions = []
        state = .playing
        paused = false
        spawn()
    }

    private func finish() {
        state = .finished
        let avg = reactions.isEmpty ? nil : reactions.reduce(0,+)/Double(reactions.count)
        let best = reactions.min()
        let hist = EyeSessionHistory(mode: selectedMode, hits: hits, misses: misses, total: cfg.targetsPerSession, avgReaction: avg, bestReaction: best, bestStreak: bestStreak)
        store.addSession(hist)
    }

    private func maybeBreak() {
        guard cfg.enableBreaks, (hits+misses) > 0, (hits+misses) % max(1,cfg.breakAfterTargets) == 0, (hits+misses) < cfg.targetsPerSession else { return }
        state = .onBreak
        breakUntil = Date().addingTimeInterval(Double(cfg.breakDurationSec))
    }

    private func endBreak() {
        state = .playing
        breakUntil = nil
    }

    // ===================================================
    // MARK: - Ticks & Spawning
    // ===================================================
    private func tick(_ t: Date) {
        guard state == .playing && !paused else {
            if state == .onBreak, let until = breakUntil, t >= until { endBreak() }
            return
        }
        if let dl = deadline {
            let left = dl.timeIntervalSince(t)
            remainRatio = max(0.0, min(1.0, left / max(0.01, curMaxTime)))
            if left <= 0 {
                if selectedMode == .tracking {
                    // in tracking, stop movement and expect the tap quickly; here consider miss if no tap in time
                    miss()
                } else {
                    miss()
                }
            }
        }
        // moving/ tracking continuous movement
        if selectedMode == .moving || selectedMode == .tracking {
            moveTarget(step: 5) // px per tick (~20fps)
        }
    }

    private func spawn() {
        switch selectedMode {
        case .classic:
            spawnRandomTarget()
        case .moving:
            spawnRandomTarget()
            randomizeVelocity()
        case .color:
            spawnRandomTarget()
            targetColor = [.green, .red, .blue, .yellow].randomElement() ?? .green
            correctColor = .green // нажимать на зелёную
        case .peripheral:
            spawnPeripheral()
        case .tracking:
            spawnRandomTarget()
            randomizeVelocity()
            isTrackingActive = true
        }
        spawnedAt = Date()
        deadline = Date().addingTimeInterval(max(0.5, curMaxTime))
        remainRatio = 1
    }

    private func spawnRandomTarget() {
        let inset: CGFloat = max(curDot, 24)
        let w = max(areaSize.width  - inset*2, 10)
        let h = max(areaSize.height - inset*2, 10)
        let quad = nextQuadrant()
        let rx: CGFloat = (quad == 1 || quad == 3) ? CGFloat.random(in: 0.5...1) : CGFloat.random(in: 0...0.5)
        let ry: CGFloat = (quad == 2 || quad == 3) ? CGFloat.random(in: 0.5...1) : CGFloat.random(in: 0...0.5)
        let x = inset + w * rx
        let y = inset + h * ry
        let point = CGPoint(x: x, y: y)
        if reduceMotion {
            targetPos = point
        } else {
            withAnimation(DS.motionFadeQuick) { targetPos = point }
        }
    }

    private func spawnPeripheral() {
        let count = 4
        peripheralTargets = []
        peripheralColors = []
        let inset: CGFloat = max(curDot, 24)
        let w = max(areaSize.width  - inset*2, 10)
        let h = max(areaSize.height - inset*2, 10)
        for _ in 0..<count {
            let x = inset + CGFloat.random(in: 0...1) * w
            let y = inset + CGFloat.random(in: 0...1) * h
            peripheralTargets.append(CGPoint(x: x, y: y))
            peripheralColors.append([.red, .blue, .yellow, .green].randomElement() ?? .red)
        }
        // ensure at least one correct
        if !peripheralColors.contains(correctColor) {
            let i = Int.random(in: 0..<count)
            peripheralColors[i] = correctColor
        }
        // set main target to the correct one for halo position
        if let idx = peripheralColors.firstIndex(of: correctColor) { targetPos = peripheralTargets[idx] }
    }

    private func nextQuadrant() -> Int {
        var q = Int.random(in: 0...3)
        if let last = lastQuadrant, q == last { q = (q + Int.random(in: 1...3)) % 4 }
        lastQuadrant = q
        return q
    }

    private func moveTarget(step: CGFloat) {
        guard areaSize.width > 0 else { return }
        if movingVelocity == .zero { randomizeVelocity() }
        var new = targetPos
        new.x += movingVelocity.width * step
        new.y += movingVelocity.height * step
        let inset: CGFloat = max(curDot, 24)
        let minX = inset, maxX = areaSize.width - inset
        let minY = inset, maxY = areaSize.height - inset
        if new.x < minX || new.x > maxX { movingVelocity.width *= -1; new.x = max(minX, min(maxX, new.x)) }
        if new.y < minY || new.y > maxY { movingVelocity.height *= -1; new.y = max(minY, min(maxY, new.y)) }
        targetPos = new
    }

    private func randomizeVelocity() {
        let dx = CGFloat.random(in: -1...1)
        let dy = CGFloat.random(in: -1...1)
        let norm = max(0.3, sqrt(dx*dx + dy*dy))
        movingVelocity = CGSize(width: dx/norm, height: dy/norm)
    }

    // ===================================================
    // MARK: - Hit/Miss & Difficulty
    // ===================================================
    private func hit() {
        guard state == .playing && !paused else { return }
        hits += 1
        streak += 1
        bestStreak = max(bestStreak, streak)
        if let spawn = spawnedAt { reactions.append(Date().timeIntervalSince(spawn)) }
        EyeFeedback.hit(sound: cfg.soundEnabled, haptic: cfg.hapticsEnabled)
        haloPulse()
        adapt(onHit: true)
        advance()
    }

    private func miss() {
        guard state == .playing && !paused else { return }
        misses += 1
        streak = 0
        EyeFeedback.miss(sound: cfg.soundEnabled, haptic: cfg.hapticsEnabled)
        adapt(onHit: false)
        advance()
    }

    private func advance() {
        totalTargets += 1
        if totalTargets >= cfg.targetsPerSession { finish() } else { maybeBreak(); if state == .playing { spawn() } }
    }

    private func adapt(onHit: Bool) {
        guard cfg.enableAdaptive else { return }
        let minDot = max(18, cfg.dotSize * cfg.minDotScale)
        let maxDot = max(cfg.dotSize, 20)
        let minTime = max(0.6, cfg.maxTimePerTarget * cfg.minTimeScale)
        let maxTime = max(cfg.maxTimePerTarget, 0.8)
        if onHit {
            if streak % max(1,cfg.adaptiveStepEvery) == 0 {
                curDot = max(minDot, curDot - 2)
                curMaxTime = max(minTime, curMaxTime - 0.1)
            }
        } else {
            curDot = min(maxDot, curDot + 2)
            curMaxTime = min(maxTime, curMaxTime + 0.15)
        }
    }

    private func haloPulse() {
        if reduceMotion {
            haloScale = 1.0
            haloOpacity = 0
            return
        }

        withAnimation(DS.motionGentle) { haloScale = 1; haloOpacity = 0 }
        haloScale = 0.6
        haloOpacity = 1
        withAnimation(DS.motionGentle) { haloScale = 1.35; haloOpacity = 0 }
    }

    // ===================================================
    // MARK: - Controls
    // ===================================================
    private var controls: some View {
        Group {
            switch state {
            case .intro:
                HStack(spacing: 12) {
                    Button { start() } label: { Label(s("eye.game.start"), systemImage: "play.fill").labelStyle(TightLabelStyle()) }
                        .buttonStyle(LippiButtonStyle(kind: .primary))
                    Button { dismiss() } label: { Text(s("eye.game.later")).singleLine() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            case .playing:
                GlassCard {
                    HStack(spacing: 12) {
                        Label(L10n.fmt("eye.game.targets_progress", lang, hits + misses, cfg.targetsPerSession), systemImage: "target").labelStyle(TightLabelStyle())
                        Spacer()
                        Label(L10n.fmt("eye.game.hits", lang, hits), systemImage: "checkmark.circle").labelStyle(TightLabelStyle())
                        Label(L10n.fmt("eye.game.misses", lang, misses), systemImage: "xmark.circle").labelStyle(TightLabelStyle())
                    }.font(.footnote.weight(.semibold))
                }
                HStack(spacing: 12) {
                    Button { togglePause() } label: {
                        Label(paused ? s("eye.game.resume") : s("eye.game.pause"), systemImage: paused ? "play.circle" : "pause.circle").labelStyle(TightLabelStyle())
                    }.buttonStyle(LippiButtonStyle(kind: .secondary))

                    Button(role: .destructive) { finish() } label: { Text(s("eye.game.finish")).singleLine() }
                        .buttonStyle(LippiButtonStyle(kind: .destructive))
                }
            case .onBreak:
                HStack(spacing: 12) {
                    Button { endBreak() } label: { Text(s("eye.game.resume")).singleLine() }
                        .buttonStyle(LippiButtonStyle(kind: .primary))
                }
            case .finished:
                HStack(spacing: 12) {
                    Button { start() } label: { Label(s("eye.game.again"), systemImage: "arrow.clockwise").labelStyle(TightLabelStyle()) }
                        .buttonStyle(LippiButtonStyle(kind: .primary))
                    Button { dismiss() } label: { Text(s("eye.game.done")).singleLine() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary))
                }
            }
        }
    }

    private func togglePause() {
        paused.toggle()
        if paused, let dl = deadline {
            let left = max(0, dl.timeIntervalSince(.now))
            deadline = Date().addingTimeInterval(left + 10_000)
        } else if !paused, deadline != nil {
            let left = remainRatio * curMaxTime
            deadline = Date().addingTimeInterval(left)
        }
    }

    // ===================================================
    // MARK: - Formatters
    // ===================================================
    private func formatMs(_ t: TimeInterval) -> String {
        let ms = Int((t * 1000).rounded())
        return L10n.fmt("eye.unit.ms", lang, ms)
    }

    @ViewBuilder
    private func overlayPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack { content() }
            .padding(16)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
            )
    }
}
