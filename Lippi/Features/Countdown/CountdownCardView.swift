import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - COUNTDOWN CARD (Premium) — smoother scroll (60fps only for graphics)
// =======================================================
struct CountdownCardView: View {
    @EnvironmentObject private var countdown: CountdownStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    // ТЕКСТ: обновляем раз в секунду (не чаще)
    @State private var textTick: Date = .now
    @State private var isCardVisible = true

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    // Кэш форматтеров (важно: не пересоздавать на каждый body)
    private static let formatterDHMS: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = [.pad]
        return f
    }()

    private static let formatterTitleTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: - Core math (pure)
    private func progress(at now: Date, ev: CountdownEvent) -> Double {
        let total = max(ev.date.timeIntervalSince(ev.anchor), 1)
        let done  = max(now.timeIntervalSince(ev.anchor), 0)
        return min(max(done / total, 0), 1)
    }

    private func remaining(at now: Date, ev: CountdownEvent) -> TimeInterval {
        max(ev.date.timeIntervalSince(now), 0)
    }

    private var tPrimary: Color { DS.text(0.94) }
    private var tSecondary: Color { DS.text(0.72) }
    private var isSceneActive: Bool { scenePhase == .active }
    private var textTimerInterval: TimeInterval {
        if !isSceneActive || !isCardVisible { return 3.0 }
        return reduceMotion ? 2.0 : 1.0
    }

    var body: some View {
        GlassCard(padding: 18, cornerRadius: 24) {
            if let ev = countdown.event {
                VStack(alignment: .leading, spacing: 14) {

                    header(ev)

                    // ❗️ТУТ БОЛЬШЕ НЕТ TimelineView: весь layout/материалы/тексты не гоняются на 60fps
                    content(ev)

                    actions
                }
            } else {
                emptyState
            }
        }
        // Текст обновляем 1 раз/сек (или реже при Reduce Motion / неактивной сцене)
        .onReceive(
            Timer.publish(
                every: textTimerInterval,
                on: .main,
                in: .common
            ).autoconnect()
        ) { t in
            guard isCardVisible else { return }
            textTick = t
        }
        .onAppear { isCardVisible = true }
        .onDisappear { isCardVisible = false }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(s("countdown.accessibility")))
    }

    // MARK: - Header
    private func header(_ ev: CountdownEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            LippiSectionHeader(
                title: s("countdown.header.title"),
                subtitle: s("countdown.header.subtitle"),
                icon: "calendar.badge.clock",
                accent: Color(hex: 0x64D2FF)
            )

            Spacer()

            Text(ev.date, formatter: Self.formatterTitleTime)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DS.glassFill(0.10), in: Capsule())
                .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                .singleLine()
                .padding(.top, 2)
        }
    }

    // MARK: - Main content (layout static, graphics animated)
    private func content(_ ev: CountdownEvent) -> some View {
        HStack(alignment: .center, spacing: 14) {

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(DS.glassTint).opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.stroke, lineWidth: 1))
                    .shadow(color: DS.depthShadow(0.12), radius: 6, x: 0, y: 3)

                // ✅ 60fps ТОЛЬКО ЗДЕСЬ (кольцо)
                CountdownRingAnimated(
                    reduceMotion: reduceMotion,
                    sceneActive: isSceneActive && isCardVisible
                ) { now in
                    progress(at: now, ev: ev)
                }
                .frame(width: 92, height: 92)
                .transaction { $0.animation = nil }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 10) {
                Text(ev.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tPrimary)
                    .singleLine()

                // ТЕКСТ таймера — от textTick (1/сек)
                timerChip(ev)

                // ✅ 60fps ТОЛЬКО ЗДЕСЬ (линейный бар)
                CountdownBarAnimated(
                    reduceMotion: reduceMotion,
                    sceneActive: isSceneActive && isCardVisible
                ) { now in
                    progress(at: now, ev: ev)
                }
                .frame(maxWidth: 280)
                .transaction { $0.animation = nil }

                microStats(ev)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Timer chip (1/sec)
    private func timerChip(_ ev: CountdownEvent) -> some View {
        let r = remaining(at: textTick, ev: ev)

        return HStack(spacing: 10) {
            Image(systemName: r > 0 ? "timer" : "sparkles")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.text(0.90))

            if r > 0 {
                Text(Self.formatterDHMS.string(from: r) ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tPrimary)
                    .singleLine()
                    .transaction { $0.animation = nil }
            } else {
                Text(s("countdown.event_reached"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(tPrimary)
                    .singleLine()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DS.stroke, lineWidth: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(DS.strokeInner, lineWidth: 1)
                        .padding(1)
                        .blendMode(.overlay)
                )
        )
        .shadow(color: DS.depthShadow(0.10), radius: 5, x: 0, y: 2)
    }

    private func microStats(_ ev: CountdownEvent) -> some View {
        let r = remaining(at: textTick, ev: ev)
        let days = max(0, Int(ceil(r / 86400)))
        let hours = Int((r.truncatingRemainder(dividingBy: 86400)) / 3600)

        return HStack(spacing: 10) {
            statChip(L10n.fmt("countdown.stats.days", lang, days), systemImage: "sun.max.fill")
            statChip(L10n.fmt("countdown.stats.hours", lang, hours),  systemImage: "clock")
        }
    }

    private func statChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(tSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DS.glassFill(0.10), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
            .singleLine()
            .transaction { $0.animation = nil }
    }

    // MARK: - Actions
    private var actions: some View {
        HStack(spacing: 10) {
            #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                Button {
                    guard let ev = countdown.event else { return }
                    let s = Date()
                    Task {
                        await PomodoroLiveManager.start(title: ev.title, phase: .focus, start: s, end: ev.date)
                    }
                } label: {
                    Label(s("countdown.actions.to_island"), systemImage: "wave.3.right")
                        .labelStyle(TightLabelStyle())
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
            }
            #endif

            Button(role: .destructive) { countdown.clear() } label: {
                Label(s("countdown.actions.reset"), systemImage: "trash")
                    .labelStyle(TightLabelStyle())
            }
            .buttonStyle(LippiButtonStyle(kind: .destructive, compact: true))

            Spacer()
        }
        .padding(.top, 2)
    }

    // MARK: - Empty state
    private var emptyState: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(DS.glassTint).opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.stroke, lineWidth: 1))
                Image(safeSystemName: "calendar.badge.clock", fallback: "calendar")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.text(0.9))
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(s("countdown.empty.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tPrimary)
                    .singleLine()

                Text(s("countdown.empty.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(tSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// =======================================================
// MARK: - Animated Ring (isolated 60fps)
// =======================================================
private struct CountdownRingAnimated: View {
    let reduceMotion: Bool
    let sceneActive: Bool
    let compute: (Date) -> Double

    private var frameInterval: TimeInterval {
        if !sceneActive { return 1.0 }
        return reduceMotion ? (1.0 / 12.0) : (1.0 / 24.0)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval,
                                paused: !sceneActive)) { timeline in
            RingProgressView(progress: compute(timeline.date), lineWidth: 14)
                .transaction { $0.animation = nil }
        }
    }
}

// =======================================================
// MARK: - Animated Bar (isolated 60fps)
// =======================================================
private struct CountdownBarAnimated: View {
    let reduceMotion: Bool
    let sceneActive: Bool
    let compute: (Date) -> Double

    private var frameInterval: TimeInterval {
        if !sceneActive { return 1.0 }
        return reduceMotion ? (1.0 / 12.0) : (1.0 / 24.0)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval,
                                paused: !sceneActive)) { timeline in
            FancyLinearProgressBar(progress: compute(timeline.date), height: 10)
                .transaction { $0.animation = nil }
        }
    }
}
