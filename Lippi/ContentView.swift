import SwiftUI
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(Charts)
import Charts
#endif
#if os(iOS)
import UIKit
import AudioToolbox
#endif

// =======================================================
// MARK: - Safe SF Symbols (чуть проще и дешевле)
// =======================================================
extension Image {

    // Внутренний кэш, чтобы не проверять UIImage(systemName:) снова и снова
    private struct _SFSymbolCache {
        static var availability: [String: Bool] = [:]
        static let lock = NSLock()

        static func isAvailable(_ name: String) -> Bool {
            lock.lock()
            if let v = availability[name] {
                lock.unlock()
                return v
            }
            lock.unlock()

            let ok = (UIImage(systemName: name) != nil)

            lock.lock()
            availability[name] = ok
            lock.unlock()

            return ok
        }
    }

    init(safeSystemName name: String, fallback: String = "square") {
        #if os(iOS)
        let picked: String
        if _SFSymbolCache.isAvailable(name) {
            picked = name
        } else if _SFSymbolCache.isAvailable(fallback) {
            picked = fallback
        } else {
            picked = "square"
        }
        self = Image(systemName: picked)
        #else
        self = Image(systemName: name)
        #endif
    }
}


// =======================================================
// MARK: - Helpers
// =======================================================
fileprivate func safeEnd(from start: Date, proposed end: Date?) -> Date? {
    guard let end else { return nil }
    return end > start ? end : start.addingTimeInterval(1)
}
fileprivate func atLeastOneSecond(_ seconds: TimeInterval) -> TimeInterval { max(seconds, 1) }
fileprivate func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

enum PomodoroRingtone: String, CaseIterable, Identifiable, Codable {
    case radar
    case beacon
    case chime
    case signal

    static let storageKey = "pomodoro.ringtone"
    static let defaultRingtone: PomodoroRingtone = .radar

    var id: String { rawValue }

    var systemSoundID: UInt32 {
        switch self {
        case .radar:  return 1005
        case .beacon: return 1007
        case .chime:  return 1008
        case .signal: return 1013
        }
    }

    func title(_ lang: AppLang) -> String {
        L10n.tr("settings.pomodoro.ringtone.\(rawValue)", lang)
    }

    static func fromStored(_ rawValue: String?) -> PomodoroRingtone {
        guard let rawValue, let tone = PomodoroRingtone(rawValue: rawValue) else {
            return .defaultRingtone
        }
        return tone
    }
}

enum PomodoroRingtonePlayer {
    static func selectedFromDefaults() -> PomodoroRingtone {
        PomodoroRingtone.fromStored(UserDefaults.standard.string(forKey: PomodoroRingtone.storageKey))
    }

    static func playSelected() {
        play(selectedFromDefaults())
    }

    static func play(_ ringtone: PomodoroRingtone) {
        #if os(iOS)
        AudioServicesPlaySystemSound(SystemSoundID(ringtone.systemSoundID))
        #endif
    }

    static func playTimerFinished() {
        #if os(iOS)
        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        haptic.notificationOccurred(.success)
        #endif
        playSelected()
    }
}

final class PomodoroAlarmCenter: ObservableObject {
    static let shared = PomodoroAlarmCenter()

    @Published private(set) var isActive: Bool = false
    @Published private(set) var finishedPhaseTitle: String = ""

    private var repeatTimer: Timer?
    private var lastStartedAt: Date = .distantPast

    private init() {}

    func start(phaseTitle: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let now = Date()
            if now.timeIntervalSince(self.lastStartedAt) < 0.8 { return }
            self.lastStartedAt = now

            self.finishedPhaseTitle = phaseTitle
            self.isActive = true
            self.repeatTimer?.invalidate()

            PomodoroRingtonePlayer.playTimerFinished()

            let timer = Timer(timeInterval: 2.2, repeats: true) { _ in
                PomodoroRingtonePlayer.playSelected()
            }
            timer.tolerance = 0.25
            RunLoop.main.add(timer, forMode: .common)
            self.repeatTimer = timer
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.repeatTimer?.invalidate()
            self.repeatTimer = nil
            self.isActive = false
            self.finishedPhaseTitle = ""
        }
    }
}

// =======================================================
// MARK: - Notifications (stability-first)
// =======================================================
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private var didConfigure = false
    /// Если хочешь обрабатывать тап по уведомлению (deeplink и т.п.)
    var onResponse: ((UNNotificationResponse) -> Void)?

    private override init() {
        super.init()
        center.delegate = self
    }

    /// Вызови рано (например, в App.init()), чтобы delegate точно был установлен.
    func configure() {
        // idempotent: можно вызывать сколько угодно раз
        guard !didConfigure else { return }
        didConfigure = true
        center.delegate = self
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        configure()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("🔔 Notifications auth error:", error) }
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    // MARK: - Scheduling

    /// Разовая по дате (надежнее, чем timeInterval для будущих дат и смены времени/таймзоны)
    func schedule(id: String, title: String, body: String, at date: Date, replaceExisting: Bool = true) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }
            if replaceExisting { self.cancel(ids: [id]) }

            let content = self.makeContent(title: title, body: body)

            // если дата уже прошла/почти прошла — сдвигаем, чтобы не было “тихого” фейла
            let now = Date()
            let fireDate = (date > now.addingTimeInterval(0.5)) ? date : now.addingTimeInterval(1)

            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            // фиксируем к текущей таймзоне на момент планирования (чтобы сработало “в абсолютный момент”)
            comps.timeZone = TimeZone.current

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            self.center.add(req) { error in
                if let error { print("🔔 add request error:", error, "id:", id) }
            }
        }
    }

    /// Разовая через секунды (идеально для таймеров/помодоро)
    func scheduleAfterSeconds(id: String, title: String, body: String, seconds: TimeInterval, replaceExisting: Bool = true) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }
            if replaceExisting { self.cancel(ids: [id]) }

            let content = self.makeContent(title: title, body: body)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: atLeastOneSecond(seconds), repeats: false)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            self.center.add(req) { error in
                if let error { print("🔔 add request error:", error, "id:", id) }
            }
        }
    }

    /// Повторяющееся ежедневно по времени
    func scheduleDaily(id: String, title: String, body: String, hour: Int, minute: Int, replaceExisting: Bool = true) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }
            if replaceExisting { self.cancel(ids: [id]) }

            let h = min(max(hour, 0), 23)
            let m = min(max(minute, 0), 59)

            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            comps.second = 0
            // для daily лучше НЕ фиксировать timeZone: тогда будет “по местному времени” даже при смене TZ
            comps.timeZone = nil

            let content = self.makeContent(title: title, body: body)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            self.center.add(req) { error in
                if let error { print("🔔 add request error:", error, "id:", id) }
            }
        }
    }

    // MARK: - Cancel

    func cancel(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids) // убираем “залипшие”
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let isPomodoroNotification = notification.request.identifier.hasPrefix("pomodoro-")
        if isPomodoroNotification {
            PomodoroAlarmCenter.shared.start(phaseTitle: notification.request.content.title)
        }
        if #available(iOS 14.0, *) {
            completionHandler(isPomodoroNotification ? [.banner, .list] : [.banner, .sound, .list])
        } else {
            completionHandler(isPomodoroNotification ? [.alert] : [.alert, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // отдаём наружу (если нужно обработать тап / deeplink)
        DispatchQueue.main.async { [weak self] in
            self?.onResponse?(response)
        }
        completionHandler()
    }

    // MARK: - Private

    private func ensureAuthorized(_ completion: @escaping (Bool) -> Void) {
        configure()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }

            case .notDetermined:
                self.requestAuthorization { granted in
                    completion(granted)
                }

            case .denied:
                DispatchQueue.main.async { completion(false) }

            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    private func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        return content
    }
}


// =======================================================
// MARK: - Countdown Model & Store (stability-first)
// =======================================================
import Foundation
import Combine

// ✅ Добавил Sendable, чтобы безопасно передавать ev в @Sendable замыкания GCD (Swift 6).
struct CountdownEvent: Codable, Hashable, Sendable {
    var title: String
    var date: Date
    var anchor: Date

    init(title: String = L10n.trCurrent("countdown.default_title"),
         date: Date = .now.addingTimeInterval(3600),
         anchor: Date = .now) {
        self.title = title
        self.date = date
        self.anchor = anchor
    }

    // Стабильная декодировка (не падаем, если в старом JSON нет anchor,
    // или дата была строкой ISO вместо числа)
    enum CodingKeys: String, CodingKey { case title, date, anchor }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let rawTitle = (try? c.decode(String.self, forKey: .title)) ?? L10n.trCurrent("countdown.default_title")
        self.title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        self.date = CountdownEvent.decodeDate(c, key: .date) ?? Date().addingTimeInterval(3600)
        self.anchor = CountdownEvent.decodeDate(c, key: .anchor) ?? Date()
    }

    private static func decodeDate(_ c: KeyedDecodingContainer<CodingKeys>,
                                   key: CodingKeys) -> Date? {
        if let d = try? c.decode(Date.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) {
            let f = ISO8601DateFormatter()
            return f.date(from: s)
        }
        return nil
    }
}

@MainActor
final class CountdownStore: ObservableObject {
    @Published private(set) var event: CountdownEvent?

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "CountdownStore.io", qos: .utility)

    // ✅ Swift 6: GCD closures are @Sendable, поэтому state должен быть Sendable.
    // Мы гарантируем, что token читается/пишется ТОЛЬКО на ioQueue.
    private final class IOState: @unchecked Sendable { var token = UUID() }
    private let ioState = IOState()

    private let notifId = "countdown-event"
    private let saveDelay: TimeInterval = 0.35

    init() {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.fileURL = dir.appendingPathComponent("countdown.json")
        } else {
            self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("countdown.json")
        }
        load()
    }

    func setEvent(title: String, date: Date) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let safeDate = (date > now.addingTimeInterval(1)) ? date : now.addingTimeInterval(1)

        let ev = CountdownEvent(
            title: t.isEmpty ? L10n.trCurrent("countdown.default_title") : t,
            date: safeDate,
            anchor: now
        )

        event = ev
        persistDebounced(ev)
        rescheduleNotification(for: ev)
    }

    func clear() {
        event = nil
        invalidatePendingIO()

        NotificationManager.shared.cancel(ids: [notifId])
        removeFileAsync()
    }

    // MARK: - Private

    private func load() {
        let url = fileURL
        ioQueue.async { [weak self] in
            let decoded: CountdownEvent? = {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(CountdownEvent.self, from: data)
            }()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.event = decoded

                if let ev = decoded {
                    if ev.date <= Date() {
                        self.clear()
                    } else {
                        self.rescheduleNotification(for: ev)
                    }
                }
            }
        }
    }

    private func rescheduleNotification(for ev: CountdownEvent) {
        NotificationManager.shared.cancel(ids: [notifId])
        guard ev.date > Date().addingTimeInterval(1) else { return }

        NotificationManager.shared.schedule(
            id: notifId,
            title: L10n.trCurrent("countdown.event_reached"),
            body: ev.title,
            at: ev.date
        )
    }

    private func persistDebounced(_ ev: CountdownEvent) {
        let url = fileURL
        let state = ioState
        let token = UUID()

        // инвалидируем все прошлые отложенные записи
        ioQueue.async { state.token = token }

        ioQueue.asyncAfter(deadline: .now() + saveDelay) { [url, ev, state] in
            guard state.token == token else { return } // был новый вызов/clear — эту запись пропускаем
            do {
                let data = try JSONEncoder().encode(ev)
                try data.write(to: url, options: .atomic)
            } catch {
                print("⛔️ CountdownStore save error:", error)
            }
        }
    }

    private func invalidatePendingIO() {
        let state = ioState
        ioQueue.async { state.token = UUID() }
    }

    private func removeFileAsync() {
        let url = fileURL
        ioQueue.async {
            do { try FileManager.default.removeItem(at: url) }
            catch { /* файл мог не существовать — норм */ }
        }
    }
}



// =======================================================
// MARK: - Daily Reminder — stability-first (safe IO + debounce + no didSet loops)
// =======================================================

import Foundation

struct DailyReminderConfig: Codable, Hashable {
    var enabled: Bool = false
    var title: String = L10n.trCurrent("daily.default_title")
    var hour: Int = 10
    var minute: Int = 0
    /// За сколько минут заранее напомнить «готовиться»
    var preparationMinutes: Int = 30

    // UI helpers
    var timeText: String { String(format: "%02d:%02d", hour, minute) }

    func normalized() -> DailyReminderConfig {
        var c = self
        c.hour = Swift.max(0, Swift.min(23, c.hour))
        c.minute = Swift.max(0, Swift.min(59, c.minute))
        c.preparationMinutes = Swift.max(0, c.preparationMinutes)
        c.title = c.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if c.title.isEmpty { c.title = L10n.trCurrent("daily.default_title") }
        return c
    }
}

@MainActor
final class DailyReminderStore: ObservableObject {
    @Published var config: DailyReminderConfig {
        didSet { onConfigChanged() }
    }

    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first?.appendingPathComponent("daily_reminder.json")
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("daily_reminder.json")

    private let idMain = "daily-reminder-main"
    private let idPrep = "daily-reminder-prep"

    // защита от рекурсивного didSet
    private var isInternalSet = false

    // debounce: сохранение в файл
    private let ioQueue = DispatchQueue(label: "DailyReminderStore.io", qos: .utility)
    private var pendingSave: DispatchWorkItem?

    // debounce: перепланирование уведомлений
    private var rescheduleTask: Task<Void, Never>?

    init() {
        if let cfg = Self.load(from: fileURL) {
            self.config = cfg.normalized()
        } else {
            self.config = DailyReminderConfig().normalized()
        }
        scheduleDebounced(immediate: true)
    }

    // MARK: - Public

    /// Совместимость со старым UI: можно вызывать store.reschedule()
    func reschedule() {
        let n = config.normalized()
        if n != config {
            isInternalSet = true
            config = n
            isInternalSet = false
        }
        reschedule(using: n)
    }

    /// Если где-то уже используешь “Now” — оставляем
    func rescheduleNow() {
        reschedule()
    }

    func testFireIn(_ seconds: TimeInterval = 3) {
        NotificationManager.shared.scheduleAfterSeconds(
            id: "daily-reminder-test-\(UUID().uuidString)",
            title: L10n.trCurrent("daily.notification.test_title"),
            body: L10n.trCurrent("daily.notification.test_body"),
            seconds: seconds
        )
    }

    // MARK: - Private

    private func onConfigChanged() {
        if isInternalSet { return }

        let n = config.normalized()
        if n != config {
            // нормализуем один раз, без зацикливания
            isInternalSet = true
            config = n
            isInternalSet = false
            // продолжаем уже с нормализованным
            persistDebounced(n)
            scheduleDebounced()
            return
        }

        persistDebounced(config)
        scheduleDebounced()
    }

    private func scheduleDebounced(immediate: Bool = false) {
        rescheduleTask?.cancel()
        let snapshot = config.normalized()

        rescheduleTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s
            }
            // тут вызываем приватный метод напрямую (без изменения config)
            self.reschedule(using: snapshot)
        }
    }

    private func reschedule(using cfg: DailyReminderConfig) {
        NotificationManager.shared.cancel(ids: [idMain, idPrep])
        guard cfg.enabled else { return }

        let h = cfg.hour
        let m = cfg.minute

        // Основное «Пора работать»
        NotificationManager.shared.scheduleDaily(
            id: idMain,
            title: L10n.trCurrent("daily.notification.work_title"),
            body: cfg.title,
            hour: h,
            minute: m
        )

        // Подготовка заранее
        let prep = cfg.preparationMinutes
        if prep > 0 {
            let totalMin = h * 60 + m
            let prepTotal = (totalMin - prep + 24 * 60) % (24 * 60)
            let prepHour = prepTotal / 60
            let prepMinute = prepTotal % 60

            NotificationManager.shared.scheduleDaily(
                id: idPrep,
                title: L10n.trCurrent("daily.notification.prep_title"),
                body: L10n.fmtCurrent("daily.notification.prep_body", prep, cfg.title),
                hour: prepHour,
                minute: prepMinute
            )
        }
    }

    private func persistDebounced(_ cfg: DailyReminderConfig) {
        pendingSave?.cancel()

        let item = DispatchWorkItem { [fileURL] in
            do {
                let data = try JSONEncoder().encode(cfg)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                print("⛔️ DailyReminderStore save error:", error)
            }
        }

        pendingSave = item
        ioQueue.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    private static func load(from url: URL) -> DailyReminderConfig? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DailyReminderConfig.self, from: data)
    }
}


// =======================================================
// MARK: - Categories & Stats DTOs (iOS 26–style, glass-ready)
// - Оптимизация: статические кэши для meta и стилей (градиенты не пересоздаются в списках)
// =======================================================

#if canImport(SwiftUI)
import SwiftUI
#endif

// =======================================================
// MARK: - TaskCategory (lean + scroll-friendly)
// =======================================================

enum TaskCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case work, study, health, rest, home, other
    var id: String { rawValue }

    // MARK: - Meta (single source of truth)

    struct Meta: Hashable {
        let title: String
        let subtitle: String
        let symbol: String
        let emoji: String
    }

    // Кэш символов/эмодзи и локализация title/subtitle через текущий язык.
    private static let symbols: [TaskCategory: String] = [
        .work: "briefcase.fill",
        .study: "book.fill",
        .health: "heart.fill",
        .rest: "moon.stars.fill",
        .home: "house.fill",
        .other: "sparkles"
    ]
    private static let emojis: [TaskCategory: String] = [
        .work: "💼",
        .study: "📚",
        .health: "❤️",
        .rest: "🌙",
        .home: "🏠",
        .other: "✨"
    ]

    @inline(__always)
    var meta: Meta {
        let lang = L10n.currentLang
        let symbol = Self.symbols[self] ?? "sparkles"
        let emoji = Self.emojis[self] ?? "✨"
        switch self {
        case .work:
            return .init(title: L10n.tr("task.category.work.title", lang),
                         subtitle: L10n.tr("task.category.work.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        case .study:
            return .init(title: L10n.tr("task.category.study.title", lang),
                         subtitle: L10n.tr("task.category.study.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        case .health:
            return .init(title: L10n.tr("task.category.health.title", lang),
                         subtitle: L10n.tr("task.category.health.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        case .rest:
            return .init(title: L10n.tr("task.category.rest.title", lang),
                         subtitle: L10n.tr("task.category.rest.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        case .home:
            return .init(title: L10n.tr("task.category.home.title", lang),
                         subtitle: L10n.tr("task.category.home.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        case .other:
            return .init(title: L10n.tr("task.category.other.title", lang),
                         subtitle: L10n.tr("task.category.other.subtitle", lang),
                         symbol: symbol, emoji: emoji)
        }
    }

    @inline(__always) var title: String { meta.title }
    @inline(__always) var subtitle: String { meta.subtitle }
    @inline(__always) var symbol: String { meta.symbol }
    @inline(__always) var emoji: String { meta.emoji }
}

#if canImport(SwiftUI)
extension TaskCategory {

    // MARK: - Style cache (главное ускорение для скролла)
    private struct Style {
        let tint: Color
        let glow: Color
        let gradient: LinearGradient
        let iconGradient: LinearGradient
        let chipStroke: Color
        let chipFill: Color
        let chipShadow: Color
    }

    @inline(__always)
    private var isNeutral: Bool { self == .other }

    // Базовые tint-цвета (один раз)
    private static let tints: [TaskCategory: Color] = [
        .work:   Color(red: 1.00, green: 0.78, blue: 0.32), // amber
        .study:  Color(red: 0.36, green: 0.74, blue: 1.00), // sky
        .health: Color(red: 1.00, green: 0.34, blue: 0.44), // pink-red
        .rest:   Color(red: 0.72, green: 0.58, blue: 1.00), // violet
        .home:   Color(red: 0.38, green: 0.88, blue: 0.66), // mint
        .other:  Color(red: 0.92, green: 0.92, blue: 0.98)  // neutral
    ]

    // Полный кэш стилей (градиенты и derived-цвета создаются один раз)
    private static let styles: [TaskCategory: Style] = {
        func makeStyle(tint: Color, neutral: Bool) -> Style {
            let glow = tint.opacity(neutral ? 0.18 : 0.22)

            let gradient = LinearGradient(
                colors: [
                    tint.opacity(0.98),
                    tint.opacity(0.58),
                    tint.opacity(neutral ? 0.26 : 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            let iconGradient = LinearGradient(
                colors: [
                    tint.opacity(1.00),
                    tint.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            let chipStroke = DS.glassStroke(neutral ? 0.14 : 0.18)
            let chipFill   = tint.opacity(neutral ? 0.10 : 0.14)
            let chipShadow = tint.opacity(neutral ? 0.08 : 0.16)

            return Style(
                tint: tint,
                glow: glow,
                gradient: gradient,
                iconGradient: iconGradient,
                chipStroke: chipStroke,
                chipFill: chipFill,
                chipShadow: chipShadow
            )
        }

        var dict: [TaskCategory: Style] = [:]
        dict.reserveCapacity(TaskCategory.allCases.count)

        for c in TaskCategory.allCases {
            let tint = Self.tints[c] ?? .white
            dict[c] = makeStyle(tint: tint, neutral: (c == .other))
        }
        return dict
    }()

    @inline(__always)
    private var style: Style { Self.styles[self]! }

    // MARK: - Public API (как было, но теперь без пересозданий)

    /// Базовый tint (единая точка истины)
    var tint: Color { style.tint }

    /// Для мягкого свечения/ореола
    var glow: Color { style.glow }

    /// “Системный” градиент
    var gradient: LinearGradient { style.gradient }

    /// Градиент для иконки/символа
    var iconGradient: LinearGradient { style.iconGradient }

    /// Микро-бордер для стеклянных чипов/плашек
    var chipStroke: Color { style.chipStroke }

    /// Подложка чипа/бейджа поверх glass
    var chipFill: Color { style.chipFill }

    /// Цветная тень (не чёрная)
    var chipShadow: Color { style.chipShadow }
}
#endif


// =======================================================
// MARK: - DayStats (UI-friendly + normalized + scroll-friendly)
// - Оптимизация: нормализуем date к startOfDay, кэшируем форматтер,
//   минимизируем строковые операции, inline для горячих геттеров.
// =======================================================

import Foundation

struct DayStats: Codable, Hashable, Identifiable {
    /// Стабильный id для ForEach/List (уменьшает дрожание diffing-а)
    var id: Int { Self.dayKey(date) }

    var date: Date
    var focusMinutes: Int
    var tasksDone: Int

    init(date: Date, focusMinutes: Int, tasksDone: Int) {
        self.date = Self.normalizeDay(date)
        self.focusMinutes = max(0, focusMinutes)
        self.tasksDone = max(0, tasksDone)
    }

    // MARK: - UI-friendly

    @inline(__always)
    var hasActivity: Bool { focusMinutes != 0 || tasksDone != 0 }

    @inline(__always)
    var focusHours: Double { Double(focusMinutes) * (1.0 / 60.0) }

    /// Строка для UI (кэшируем через DateComponentsFormatter)
    var focusText: String { Self.formatMinutes(focusMinutes) }

    /// Быстрый “витринный” текст для карточек статистики.
    /// (делаем минимум интерполяций и ветвлений)
    var summaryText: String {
        let f = focusMinutes
        let t = tasksDone
        let lang = L10n.currentLang

        if f != 0 {
            if t != 0 { return L10n.fmt("stats.day.summary.focus_and_tasks", lang, Self.formatMinutes(f), t) }
            return L10n.fmt("stats.day.summary.focus_only", lang, Self.formatMinutes(f))
        }
        if t != 0 { return L10n.fmt("stats.day.summary.tasks_only", lang, t) }
        return L10n.tr("stats.day.summary.none", lang)
    }

    /// Нормализованная “интенсивность” дня (для opacity/scale в UI).
    /// sqrt сглаживает малые значения — приятнее для анимаций.
    @inline(__always)
    var activityStrength: Double {
        // 3 часа = 1.0, 12 задач = 1.0
        let f = min(Double(focusMinutes) * (1.0 / 180.0), 1.0)
        let t = min(Double(tasksDone) * (1.0 / 12.0), 1.0)
        return (max(f, t)).squareRoot()
    }

    // MARK: - Helpers (fast + stable)

    /// Нормализуем дату к началу суток, чтобы не было “разных” дат одного дня.
    @inline(__always)
    private static func normalizeDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Быстрый ключ дня: YYYYMMDD в Int (удобно как id и для словарей).
    private static func dayKey(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return y * 10_000 + m * 100 + d
    }

    /// Кэш форматтера: дешевле, чем ручная сборка строк на каждом кадре,
    /// особенно если у тебя много ячеек в списке.
    private static let minutesFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.hour, .minute]
        f.zeroFormattingBehavior = []
        // Локаль берёт системную — ок для RU/EN, если ты не форсишь свою.
        return f
    }()

    private static func formatMinutes(_ minutes: Int) -> String {
        let m = max(0, minutes)
        let lang = L10n.currentLang
        guard m != 0 else { return L10n.fmt("stats.minutes", lang, 0) }

        // DateComponentsFormatter ожидает секунды
        let seconds = TimeInterval(m * 60)

        if let s = minutesFormatter.string(from: seconds), !s.isEmpty {
            // Иногда abbreviated даёт "1h 5m" на EN — тебе может быть норм.
            // Если хочешь строго "ч/мин" по-русски, скажи — сделаю локализатором.
            return s
        }

        // Фолбэк (очень быстрый)
        if m < 60 { return L10n.fmt("stats.minutes", lang, m) }
        let h = m / 60
        let r = m % 60
        return r == 0
        ? L10n.fmt("stats.hours", lang, h)
        : L10n.fmt("stats.hours_minutes", lang, h, r)
    }
}


// =======================================================
// MARK: - Stats Events (scroll-friendly)
// - Оптимизация: кэш meta + tint/градиента, inline геттеры,
//   быстрый расчёт минут (без Double), быстрый durationText.
// =======================================================

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum StatsEventType: String, Codable, CaseIterable, Hashable, Identifiable {
    case focus, taskDone
    var id: String { rawValue }

    // MARK: - Meta cache

    struct Meta: Hashable {
        let title: String
        let symbol: String
    }

    private static let metas: [StatsEventType: Meta] = [
        .focus:    .init(title: "stats.event.focus",  symbol: "timer"),
        .taskDone: .init(title: "stats.event.task_done", symbol: "checkmark.circle.fill")
    ]

    @inline(__always)
    private var meta: Meta { Self.metas[self]! }

    @inline(__always) var title: String { L10n.tr(meta.title, L10n.currentLang) }
    @inline(__always) var symbol: String { meta.symbol }

    #if canImport(SwiftUI)
    // MARK: - Style cache

    private struct Style {
        let tint: Color
        let iconGradient: LinearGradient
    }

    private static let styles: [StatsEventType: Style] = {
        func make(tint: Color) -> Style {
            let grad = LinearGradient(
                colors: [tint.opacity(1.00), tint.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )
            return Style(tint: tint, iconGradient: grad)
        }

        return [
            .focus:    make(tint: Color(red: 0.40, green: 0.72, blue: 1.00)), // sky
            .taskDone: make(tint: Color(red: 0.44, green: 0.87, blue: 0.67))  // mint
        ]
    }()

    @inline(__always)
    private var style: Style { Self.styles[self]! }

    /// Тинт событий — чтобы таймлайн/лист выглядел как системный.
    var tint: Color { style.tint }

    /// Градиент для иконки — закэширован, не пересоздаётся в списках.
    var iconGradient: LinearGradient { style.iconGradient }
    #endif
}

struct StatsEvent: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var type: StatsEventType
    var seconds: Int?
    var taskId: UUID?

    // MARK: - UI/logic helpers (fast)

    @inline(__always)
    var focusSeconds: Int { (type == .focus) ? (seconds ?? 0) : 0 }

    /// Округление “по-человечески”: 30 сек → 1 мин, 29 сек → 0 мин.
    /// Быстрее и стабильнее без Double.
    @inline(__always)
    var focusMinutesRounded: Int {
        let s = focusSeconds
        if s <= 0 { return 0 }
        // round(s/60) = (s + 30) / 60 для целых
        return (s + 30) / 60
    }

    /// Для таймлайна: короткая строка длительности (если это фокус).
    var durationText: String? {
        guard type == .focus else { return nil }
        let lang = L10n.currentLang

        let m = focusMinutesRounded
        if m <= 0 { return L10n.tr("eye.common.em_dash", lang) }
        if m < 60 { return L10n.fmt("stats.minutes", lang, m) }

        let h = m / 60
        let r = m - (h * 60) // чуть дешевле, чем %
        return (r == 0)
        ? L10n.fmt("stats.hours", lang, h)
        : L10n.fmt("stats.hours_minutes", lang, h, r)
    }
}


// =======================================================
// MARK: - Stats Store
// =======================================================
final class StatsStore: ObservableObject {
    // УБРАЛИ didSet { save() } — он писал на диск на каждом append/remove и рвал скролл
    @Published private(set) var events: [StatsEvent] = []

    private let urlEvents: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("stats_events.json")
    private let urlLegacy: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("stats.json")

    // -------------------------------------------------------
    // MARK: - Debounced save (background)
    // -------------------------------------------------------
    private let saveQueue = DispatchQueue(label: "StatsStore.save", qos: .utility)
    private var pendingSave: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.4

    // -------------------------------------------------------
    // MARK: - Fast index + cache for series()
    // -------------------------------------------------------
    private struct TaskDoneKey: Hashable {
        let day: Date
        let taskId: UUID
    }
    private var taskDoneIndex: Set<TaskDoneKey> = []

    private struct DayAgg {
        var focusMinutes: Int = 0
        var tasksDone: Int = 0
    }
    private var cachedAggByDay: [Date: DayAgg]? = nil

    init() { loadOrMigrate() }

    func recordFocus(seconds: TimeInterval, on date: Date = .now) {
        guard seconds > 0.5 else { return }
        let ev = StatsEvent(date: date, type: .focus, seconds: Int(seconds.rounded()), taskId: nil)
        events.append(ev)
        invalidateCaches()
        scheduleSave()
    }

    func recordTaskDone(taskId: UUID, on date: Date = .now) {
        let day = startOfDay(date)
        let key = TaskDoneKey(day: day, taskId: taskId)

        // вместо events.contains(...) — O(1) проверка
        guard !taskDoneIndex.contains(key) else { return }

        let ev = StatsEvent(date: date, type: .taskDone, seconds: nil, taskId: taskId)
        events.append(ev)
        taskDoneIndex.insert(key)

        invalidateCaches()
        scheduleSave()
    }

    func undoTaskDone(taskId: UUID, on date: Date = .now) {
        let day = startOfDay(date)

        if let idx = events.lastIndex(where: { $0.type == .taskDone && $0.taskId == taskId && startOfDay($0.date) == day }) {
            events.remove(at: idx)
            taskDoneIndex.remove(TaskDoneKey(day: day, taskId: taskId))

            invalidateCaches()
            scheduleSave()
        }
    }

    func series(last daysCount: Int) -> [DayStats] {
        guard daysCount > 0 else { return [] }

        let cal = Calendar.current
        let today = startOfDay(.now)

        // окно дат (как было), но без force unwrap в map
        var window: [Date] = []
        window.reserveCapacity(daysCount)
        for i in (0..<daysCount).reversed() {
            if let d = cal.date(byAdding: .day, value: -i, to: today) {
                window.append(d)
            }
        }

        let agg = aggregatedByDay()

        return window.map { day in
            let a = agg[day] ?? DayAgg()
            return DayStats(date: day, focusMinutes: a.focusMinutes, tasksDone: a.tasksDone)
        }
    }

    func totals(for series: [DayStats]) -> (focus: Int, tasks: Int) {
        // чуть дешевле, чем два reduce
        var f = 0
        var t = 0
        for d in series { f += d.focusMinutes; t += d.tasksDone }
        return (f, t)
    }

    var today: DayStats {
        series(last: 1).first ?? DayStats(date: startOfDay(.now), focusMinutes: 0, tasksDone: 0)
    }

    var last7Days: DayStats {
        let s = series(last: 7)
        var f = 0
        var t = 0
        for d in s { f += d.focusMinutes; t += d.tasksDone }
        return DayStats(date: s.first?.date ?? startOfDay(.now), focusMinutes: f, tasksDone: t)
    }

    var productiveStreak: Int {
        let s = series(last: 90).reversed()
        var streak = 0
        for d in s {
            if d.focusMinutes > 0 || d.tasksDone > 0 { streak += 1 } else { break }
        }
        return streak
    }

    func purge(olderThan days: Int = 365) {
        let limit = Calendar.current.date(byAdding: .day, value: -days, to: startOfDay(.now))!
        events.removeAll { startOfDay($0.date) < limit }

        rebuildIndexes()
        invalidateCaches()
        scheduleSave()
    }

    private func loadOrMigrate() {
        if let data = try? Data(contentsOf: urlEvents),
           let evs = try? JSONDecoder().decode([StatsEvent].self, from: data) {
            events = evs
            rebuildIndexes()
            invalidateCaches()
            return
        }

        if let data = try? Data(contentsOf: urlLegacy),
           let legacy = try? JSONDecoder().decode([DayStats].self, from: data) {
            var migrated: [StatsEvent] = []
            migrated.reserveCapacity(legacy.count * 2)

            for d in legacy {
                let midday = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay(d.date)) ?? d.date
                if d.focusMinutes > 0 {
                    migrated.append(StatsEvent(date: midday, type: .focus, seconds: d.focusMinutes * 60, taskId: nil))
                }
                if d.tasksDone > 0 {
                    for _ in 0..<d.tasksDone {
                        migrated.append(StatsEvent(date: midday, type: .taskDone, seconds: nil, taskId: nil))
                    }
                }
            }

            events = migrated
            rebuildIndexes()
            invalidateCaches()

            // сохраняем уже в новом формате, но НЕ блокируем UI
            scheduleSave()
            try? FileManager.default.removeItem(at: urlLegacy)
            return
        }

        events = []
        rebuildIndexes()
        invalidateCaches()
    }

    // -------------------------------------------------------
    // MARK: - Aggregation (fast)
    // -------------------------------------------------------
    private func aggregatedByDay() -> [Date: DayAgg] {
        if let cached = cachedAggByDay { return cached }

        var dict: [Date: DayAgg] = [:]
        dict.reserveCapacity(max(16, events.count / 3))

        for ev in events {
            let day = startOfDay(ev.date)

            switch ev.type {
            case .focus:
                let sec = ev.seconds ?? 0
                if sec > 0 {
                    // round(sec/60) = (sec + 30) / 60 — без Double
                    let mins = (sec + 30) / 60
                    if mins > 0 {
                        var a = dict[day] ?? DayAgg()
                        a.focusMinutes += mins
                        dict[day] = a
                    }
                }

            case .taskDone:
                var a = dict[day] ?? DayAgg()
                a.tasksDone += 1
                dict[day] = a
            }
        }

        cachedAggByDay = dict
        return dict
    }

    private func invalidateCaches() {
        cachedAggByDay = nil
    }

    private func rebuildIndexes() {
        taskDoneIndex.removeAll(keepingCapacity: true)
        if !events.isEmpty { taskDoneIndex.reserveCapacity(events.count / 2) }

        for ev in events {
            guard ev.type == .taskDone, let tid = ev.taskId else { continue }
            taskDoneIndex.insert(TaskDoneKey(day: startOfDay(ev.date), taskId: tid))
        }
    }

    // -------------------------------------------------------
    // MARK: - Debounced Save (background)
    // -------------------------------------------------------
    private func scheduleSave() {
        pendingSave?.cancel()

        let snapshot = events
        let target = urlEvents

        let work = DispatchWorkItem(qos: .utility) {
            do {
                let encoder = JSONEncoder() // локальный — безопасно для фонового потока
                let data = try encoder.encode(snapshot)
                try data.write(to: target, options: .atomic)
            } catch {
                #if DEBUG
                print("Stats save error: \(error)")
                #endif
            }
        }

        pendingSave = work
        saveQueue.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }

    // Оставляю метод save() как “ручной” на всякий случай (можно больше не вызывать)
    private func save() {
        // чтобы не ломать возможные старые вызовы — просто делаем debounced-save
        scheduleSave()
    }
}

// Быстрые подсказки для двигательных пауз
enum MovementTips {
    static func tips(for lang: AppLang) -> [String] {
        [
            L10n.tr("movement.tip.1", lang),
            L10n.tr("movement.tip.2", lang),
            L10n.tr("movement.tip.3", lang),
            L10n.tr("movement.tip.4", lang),
            L10n.tr("movement.tip.5", lang)
        ]
    }
    static func randomTip() -> String {
        let lang = L10n.currentLang
        return tips(for: lang).randomElement() ?? L10n.tr("movement.tip.fallback", lang)
    }
}


// =======================================================
// MARK: - Tasks model & store (optimized)
// =======================================================
struct TaskItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var category: TaskCategory

    init(id: UUID = UUID(),
         title: String,
         notes: String = "",
         dueDate: Date? = nil,
         isCompleted: Bool = false,
         createdAt: Date = .now,
         category: TaskCategory = .other) {
        self.id = id; self.title = title; self.notes = notes
        self.dueDate = dueDate; self.isCompleted = isCompleted; self.createdAt = createdAt
        self.category = category
    }
}

final class TaskStore: ObservableObject {
    // УБРАЛИ didSet { save() } — это писало на диск при каждом изменении и лагало UI
    @Published private(set) var tasks: [TaskItem] = []

    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("tasks.json")

    // -------------------------------------------------------
    // MARK: - Debounced background save (главное ускорение)
    // -------------------------------------------------------
    private let saveQueue = DispatchQueue(label: "TaskStore.save", qos: .utility)
    private var pendingSave: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.35

    init() {
        load()
        refreshNextTaskWidget()
    }

    // MARK: - CRUD

    func add(_ item: TaskItem) {
        tasks.insert(item, at: 0)

        // уведомление — только если есть dueDate и задача не выполнена
        syncNotification(for: item, old: nil)

        refreshNextTaskWidget()
        scheduleSave()
    }

    func update(_ item: TaskItem) {
        guard let i = tasks.firstIndex(where: { $0.id == item.id }) else { return }
        let old = tasks[i]
        tasks[i] = item

        // уведомления трогаем только если реально что-то изменилось
        syncNotification(for: item, old: old)

        if old.isCompleted != item.isCompleted {
            NotificationCenter.default.post(
                name: .taskCompletionChanged,
                object: nil,
                userInfo: ["taskId": item.id, "completed": item.isCompleted]
            )
        }

        refreshNextTaskWidget()
        scheduleSave()
    }

    func toggle(_ id: UUID, stats: StatsStore? = nil) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }

        let old = tasks[i]
        tasks[i].isCompleted.toggle()
        let newItem = tasks[i]

        // уведомления: при выполнении — отменяем, при возврате — восстанавливаем (если dueDate есть)
        syncNotification(for: newItem, old: old)

        // статистика
        if newItem.isCompleted {
            stats?.recordTaskDone(taskId: id)
        } else {
            stats?.undoTaskDone(taskId: id)
        }

        // событие смены completion (раньше в toggle не отправлялось — теперь консистентно)
        NotificationCenter.default.post(
            name: .taskCompletionChanged,
            object: nil,
            userInfo: ["taskId": id, "completed": newItem.isCompleted]
        )

        refreshNextTaskWidget()
        scheduleSave()
    }

    func remove(_ id: UUID) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks.remove(at: idx)
        } else {
            return
        }

        NotificationManager.shared.cancel(ids: [id.uuidString])
        refreshNextTaskWidget()
        scheduleSave()
    }

    func clearAll() {
        // отмена пачкой
        let ids = tasks.map { $0.id.uuidString }
        NotificationManager.shared.cancel(ids: ids)

        tasks.removeAll()
        refreshNextTaskWidget()
        scheduleSave()
    }

    // MARK: - Queries

    func upcoming() -> TaskItem? {
        // Один проход: сначала задачи с ближайшим dueDate, затем без срока.
        let snapshot = tasks
        var best: TaskItem?
        var bestDue = Date.distantFuture
        var bestCreated = Date.distantFuture

        for t in snapshot where !t.isCompleted {
            let due = t.dueDate ?? .distantFuture
            if due < bestDue || (due == bestDue && t.createdAt < bestCreated) {
                best = t
                bestDue = due
                bestCreated = t.createdAt
            }
        }

        return best
    }

    // MARK: - Persistence

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            tasks = []
        }
    }

    /// Debounced save — чтобы не тормозить скролл/анимации.
    private func scheduleSave() {
        pendingSave?.cancel()

        let snapshot = tasks
        let url = fileURL

        let work = DispatchWorkItem(qos: .utility) {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                // молча, как у тебя (но без лагов)
            }
        }

        pendingSave = work
        saveQueue.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }

    /// На случай, если где-то в коде всё ещё зовётся save()
    private func save() { scheduleSave() }

    private func refreshNextTaskWidget() {
        let next = upcoming()
        WidgetUpdater.update(nextTitle: next?.title, due: next?.dueDate)
    }

    // MARK: - Notifications (minimal work)

    private func syncNotification(for item: TaskItem, old: TaskItem?) {
        let nid = item.id.uuidString

        // если выполнено или нет даты — напоминание не нужно
        guard !item.isCompleted, let due = item.dueDate else {
            NotificationManager.shared.cancel(ids: [nid])
            return
        }

        // не планируем напоминание в прошлом (чтобы не спамило сразу)
        if due <= Date() {
            NotificationManager.shared.cancel(ids: [nid])
            return
        }

        // если ничего значимого не поменялось — не трогаем планировщик
        if let old = old,
           old.isCompleted == item.isCompleted,
           old.dueDate == item.dueDate,
           old.title == item.title {
            return
        }

        // обновляем расписание
        NotificationManager.shared.cancel(ids: [nid])
        NotificationManager.shared.schedule(id: nid, title: L10n.trCurrent("task.notification.reminder"), body: item.title, at: due)
    }
}

extension Notification.Name {
    static let taskCompletionChanged = Notification.Name("taskCompletionChanged")

    // Новые события для гимнастики глаз
    /// Отправляется PomodoroManager после завершения фокус-сессии
    static let focusWorkLogged    = Notification.Name("focusWorkLogged")
    /// Сигнал о том, что пора предложить упражнение для глаз
    static let suggestEyeExercise = Notification.Name("suggestEyeExercise")
}




// =======================================================
// MARK: - Pomodoro core
// =======================================================
enum PomodoroPhase: String, Codable, Hashable { case focus, shortBreak, longBreak, paused, stopped }

struct PomodoroConfig: Codable, Hashable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var roundsBeforeLongBreak: Int = 4
}

final class PomodoroManager: ObservableObject {
    @Published private(set) var phase: PomodoroPhase = .stopped
    @Published private(set) var round: Int = 0
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published var config = PomodoroConfig()

    weak var stats: StatsStore?

    private var notifIds: [String] = []
    private var pausedRemaining: TimeInterval?
    private var pausedPhase: PomodoroPhase?
    private var movementScheduledAt: Date?

    init() {
        WidgetUpdater.clearPomodoro()
    }

    func startFocus(customMinutes: Int? = nil) {
        phase = .focus
        start(
            for: customMinutes ?? config.focusMinutes,
            title: L10n.trCurrent("pomodoro.phase.focus"),
            notifBody: L10n.trCurrent("pomodoro.notification.focus_body")
        )
        scheduleMovementIfNeeded()
    }
    func startShortBreak() {
        logFocusIfNeeded()
        phase = .shortBreak
        start(
            for: config.shortBreakMinutes,
            title: L10n.trCurrent("pomodoro.phase.short_break"),
            notifBody: L10n.trCurrent("pomodoro.notification.short_break_body")
        )
        movementScheduledAt = nil
    }
    func startLongBreak() {
        logFocusIfNeeded()
        phase = .longBreak
        start(
            for: config.longBreakMinutes,
            title: L10n.trCurrent("pomodoro.phase.long_break"),
            notifBody: L10n.trCurrent("pomodoro.notification.long_break_body")
        )
        movementScheduledAt = nil
    }

    func pause() {
        guard phase != .paused, let end = endDate else { return }
        pausedPhase = phase
        pausedRemaining = max(end.timeIntervalSinceNow, 0)
        endDate = nil
        phase = .paused
        syncPomodoroWidget()
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task { await PomodoroLiveManager.update(phase: .paused, title: L10n.trCurrent("pomodoro.phase.paused"), end: nil) }
        }
        #endif
    }

    func resume() {
        guard phase == .paused, let remaining = pausedRemaining else { return }

        let restorePhase = pausedPhase ?? .focus

        startDate = .now
        endDate = Date(timeIntervalSinceNow: atLeastOneSecond(remaining))
        pausedRemaining = nil
        pausedPhase = nil
        phase = restorePhase

        if restorePhase == .focus {
            scheduleMovementIfNeeded(resume: true)
        }
        syncPomodoroWidget()

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task {
                await PomodoroLiveManager.update(
                    phase: restorePhase,
                    title: titleForPhase(restorePhase),
                    start: startDate,
                    end: endDate
                )
            }
        }
        #endif
    }

    func stop() {
        logFocusIfNeeded()
        phase = .stopped
        startDate = nil
        endDate = nil
        pausedRemaining = nil
        pausedPhase = nil
        movementScheduledAt = nil
        NotificationManager.shared.cancel(ids: notifIds)
        notifIds.removeAll()
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { Task { await PomodoroLiveManager.endAll() } }
        #endif
        WidgetUpdater.clearPomodoro()
    }

    private func start(for minutes: Int, title: String, notifBody: String) {
        let secs = atLeastOneSecond(TimeInterval(minutes * 60))
        startDate = .now
        endDate = Date(timeIntervalSinceNow: secs)

        let id = "pomodoro-\(UUID().uuidString)"
        notifIds.append(id)
        if let endDate { NotificationManager.shared.schedule(id: id, title: title, body: notifBody, at: endDate) }

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), let s = startDate {
            Task { await PomodoroLiveManager.start(title: title, phase: phase, start: s, end: endDate) }
        }
        #endif
        syncPomodoroWidget()
    }

    func advance() {
        logFocusIfNeeded()
        switch phase {
        case .focus:
            round += 1
            if round % config.roundsBeforeLongBreak == 0 { startLongBreak() } else { startShortBreak() }
        case .shortBreak, .longBreak:
            startFocus()
        case .paused, .stopped:
            break
        }
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), let s = startDate {
            Task { await PomodoroLiveManager.update(phase: phase, title: titleForPhase(phase), start: s, end: endDate, round: round) }
        }
        #endif
        syncPomodoroWidget()
    }

    private func logFocusIfNeeded() {
        guard phase == .focus, let s = startDate else { return }
        let secs = max(0, Date().timeIntervalSince(s))
        stats?.recordFocus(seconds: secs, on: Date())

        // NEW: сообщаем системе, сколько подряд отработано — для автопредложения гимнастики глаз
        NotificationCenter.default.post(name: .focusWorkLogged,
                                        object: nil,
                                        userInfo: ["seconds": secs])
    }

    private func titleForPhase(_ p: PomodoroPhase) -> String {
        switch p {
        case .focus:      return L10n.trCurrent("pomodoro.phase.focus")
        case .shortBreak: return L10n.trCurrent("pomodoro.phase.short_break")
        case .longBreak:  return L10n.trCurrent("pomodoro.phase.long_break")
        case .paused:     return L10n.trCurrent("pomodoro.phase.paused")
        case .stopped:    return L10n.trCurrent("pomodoro.phase.stopped")
        }
    }

    private func scheduleMovementIfNeeded(resume: Bool = false) {
        // если уже назначали — ничего не делаем (в т.ч. при resume)
        if movementScheduledAt != nil { return }

        let when = Date().addingTimeInterval(60 * 60)
        movementScheduledAt = when
        let tip = MovementTips.randomTip()

        NotificationManager.shared.schedule(
            id: "move-\(UUID().uuidString)",
            title: L10n.trCurrent("movement.notification.title"),
            body: tip,
            at: when
        )
    }

    private func syncPomodoroWidget() {
        WidgetUpdater.updatePomodoro(
            phase: phase,
            start: startDate,
            end: endDate,
            round: round
        )
    }
} // ←←← ЗАКРЫВАЕМ PomodoroManager (исправление)

// =======================================================
// MARK: - Live Activities (optional)
// =======================================================
#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct OrganizerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var taskTitle: String
        var startDate: Date
        var dueDate: Date?
    }
    var taskId: UUID
}

@available(iOS 16.2, *)
enum LiveActivityManager {
    static func startTask(_ task: TaskItem) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let attributes = OrganizerAttributes(taskId: task.id)
        let state = OrganizerAttributes.ContentState(taskTitle: task.title, startDate: now, dueDate: safeEnd(from: now, proposed: task.dueDate))
        let content = ActivityContent(state: state, staleDate: nil)
        _ = try? Activity<OrganizerAttributes>.request(attributes: attributes, content: content, pushType: nil)
    }
    static func endAllTasks() async {
        for a in Activity<OrganizerAttributes>.activities {
            await a.end(ActivityContent(state: a.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}

@available(iOS 16.1, *)
struct PomodoroAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var phase: PomodoroPhase
        var startDate: Date
        var endDate: Date?
        var round: Int
    }
    var sessionId: UUID
}

@available(iOS 16.2, *)
enum PomodoroLiveManager {
    static func start(title: String, phase: PomodoroPhase, start: Date, end: Date?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PomodoroAttributes(sessionId: UUID())
        let state = PomodoroAttributes.ContentState(title: title, phase: phase, startDate: start, endDate: end, round: 0)
        let content = ActivityContent(state: state, staleDate: nil)
        _ = try? Activity<PomodoroAttributes>.request(attributes: attributes, content: content, pushType: nil)
    }
    static func update(phase: PomodoroPhase? = nil, title: String? = nil, start: Date? = nil, end: Date? = nil, round: Int? = nil) async {
        for a in Activity<PomodoroAttributes>.activities {
            var s = a.content.state
            if let p = phase { s.phase = p }
            if let t = title { s.title = t }
            if let st = start { s.startDate = st }
            if let e = end   { s.endDate = e }
            if let r = round { s.round = r }
            await a.update(ActivityContent(state: s, staleDate: nil))
        }
    }
    static func endAll() async {
        for a in Activity<PomodoroAttributes>.activities {
            await a.end(ActivityContent(state: a.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
#endif



// =======================================================
// MARK: - ROOT & TAB (iPhone-first, max info, premium)
// =======================================================

// Уникальный EnvironmentKey для языка приложения (ISO-код: "ru"/"en"/"de"/"es").
private struct LippiLangCodeKey: EnvironmentKey {
    static let defaultValue: String = "ru"
}
private struct LippiHasGlobalBackdropKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    var lippiLangCode: String {
        get { self[LippiLangCodeKey.self] }
        set { self[LippiLangCodeKey.self] = newValue }
    }
    var lippiHasGlobalBackdrop: Bool {
        get { self[LippiHasGlobalBackdropKey.self] }
        set { self[LippiHasGlobalBackdropKey.self] = newValue }
    }
}

enum AppTab: Hashable { case today, tasks, pomodoro, `break`, health, eye, settings }

struct ContentView: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.defaultTheme.rawValue
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private var langCode: String { lang.rawValue }
    private var selectedTheme: AppTheme { AppTheme(rawValue: themeRaw) ?? AppTheme.defaultTheme }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showEyes = false
    @StateObject private var store = TaskStore()
    @StateObject private var stats = StatsStore()
    @StateObject private var pomo = PomodoroManager()
    @StateObject private var pomodoroAlarm = PomodoroAlarmCenter.shared
    @StateObject private var voiceAssistant = AppVoiceAssistantCenter()
    @StateObject private var countdown = CountdownStore()
    @StateObject private var dailyReminder = DailyReminderStore()
    @State private var tab: AppTab = .today
    @State private var showVoiceAssistant = false
    @State private var tabDirection: CGFloat = 1
    @State private var isSwitchingTabs = false
    @State private var tabTransitionTask: Task<Void, Never>?

    private static let tabOrder: [AppTab] = [.today, .tasks, .pomodoro, .break, .health, .eye, .settings]

    private func tabIndex(_ value: AppTab) -> Int {
        Self.tabOrder.firstIndex(of: value) ?? 0
    }

    private func transitionDirection(from oldTab: AppTab, to newTab: AppTab) -> CGFloat {
        tabIndex(newTab) >= tabIndex(oldTab) ? 1 : -1
    }

    @ViewBuilder
    private func screenView(_ tab: AppTab) -> some View {
        switch tab {
        case .today:    TodayView()
        case .tasks:    TasksView()
        case .pomodoro: PomodoroView()
        case .break:    BreakView()
        case .health:   HealthView()
        case .eye:      EyeHealthHomeView()
        case .settings: SettingsView()
        }
    }

    private var tabSelectionBinding: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { newTab in
                switchTab(to: newTab)
            }
        )
    }

    private var tabSwitchAnimation: Animation {
        reduceMotion
        ? .linear(duration: 0.10)
        : .easeInOut(duration: 0.22)
    }

    private var screenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let offset = 14 * tabDirection
        return .asymmetric(
            insertion: .opacity
                .combined(with: .offset(x: offset, y: 0)),
            removal: .opacity
                .combined(with: .offset(x: -offset * 0.5, y: 0))
        )
    }

    private func switchTab(to newTab: AppTab) {
        guard newTab != tab else { return }
        guard !isSwitchingTabs else { return }

        tabDirection = transitionDirection(from: tab, to: newTab)
        isSwitchingTabs = true

        withAnimation(tabSwitchAnimation) {
            tab = newTab
        }

        tabTransitionTask?.cancel()
        let delay: UInt64 = reduceMotion ? 130_000_000 : 240_000_000
        tabTransitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            isSwitchingTabs = false
        }
    }

    private func localizedTabTitle(_ tab: AppTab) -> String {
        switch tab {
        case .today: return L10n.tr(.tab_today, lang)
        case .tasks: return L10n.tr(.tab_tasks, lang)
        case .pomodoro: return L10n.tr(.tab_pomodoro, lang)
        case .break: return L10n.tr(.tab_break, lang)
        case .health: return L10n.tr(.tab_health, lang)
        case .eye: return L10n.tr(.tab_eye, lang)
        case .settings: return L10n.tr(.tab_settings, lang)
        }
    }

    private func sanitizeVoiceTaskTitle(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if trimmed.count <= 120 { return trimmed }
        return String(trimmed.prefix(120))
    }

    private enum AssistantDeepLinkMode: String {
        case listen
        case menu
    }

    private func parseAssistantDeepLinkMode(from url: URL) -> AssistantDeepLinkMode {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name.lowercased() == "mode" })?.value?.lowercased(),
              let mode = AssistantDeepLinkMode(rawValue: raw) else {
            return .menu
        }
        return mode
    }

    private func handleIncomingURL(_ url: URL) {
        let host = url.host?.lowercased() ?? ""

        switch host {
        case "done":
            #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                Task { await LiveActivityManager.endAllTasks(); await PomodoroLiveManager.endAll() }
            }
            #endif

        case "assistant":
            let mode = parseAssistantDeepLinkMode(from: url)
            switch mode {
            case .listen:
                showVoiceAssistant = false
                if !voiceAssistant.isListening {
                    voiceAssistant.cancelListening()
                    voiceAssistant.startListening(lang: lang)
                }
            case .menu:
                showVoiceAssistant = true
            }

        default:
            break
        }
    }

    private func normalizeAssistantText(_ value: String) -> String {
        value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func assistantMinutesText(_ minutes: Int) -> String {
        L10n.fmt("health.analytics.minutes_value", lang, max(0, minutes))
    }

    private func assistantMetricsSummary(for period: AppVoiceMetricsPeriod) -> String {
        let todayStats = stats.today
        let weekStats = stats.last7Days
        let activeTasks = store.tasks.reduce(0) { partial, task in
            partial + (task.isCompleted ? 0 : 1)
        }
        let streak = stats.productiveStreak

        let todayLine = L10n.fmt(
            "assistant.response.metrics_today",
            lang,
            assistantMinutesText(todayStats.focusMinutes),
            todayStats.tasksDone
        )
        let weekLine = L10n.fmt(
            "assistant.response.metrics_week",
            lang,
            assistantMinutesText(weekStats.focusMinutes),
            weekStats.tasksDone
        )
        let activeLine = L10n.fmt("assistant.response.metrics_active", lang, activeTasks)
        let streakLine = L10n.fmt("assistant.response.metrics_streak", lang, streak)

        switch period {
        case .today:
            return [todayLine, weekLine, activeLine, streakLine].joined(separator: " ")
        case .week:
            return [weekLine, todayLine, activeLine, streakLine].joined(separator: " ")
        }
    }

    private func resolveTaskForVoice(title rawTitle: String?, includeCompleted: Bool) -> TaskItem? {
        let candidates = store.tasks.filter { includeCompleted || !$0.isCompleted }
        guard !candidates.isEmpty else { return nil }

        guard let rawTitle else { return candidates.first }
        let query = normalizeAssistantText(rawTitle)
        guard !query.isEmpty else { return candidates.first }

        if let exact = candidates.first(where: { normalizeAssistantText($0.title) == query }) {
            return exact
        }

        if let contains = candidates.first(where: {
            let title = normalizeAssistantText($0.title)
            return title.contains(query) || query.contains(title)
        }) {
            return contains
        }

        let queryTokens = Set(query.split(separator: " ").map(String.init))
        guard !queryTokens.isEmpty else { return candidates.first }

        var bestTask: TaskItem?
        var bestScore = 0

        for task in candidates {
            let titleTokens = Set(normalizeAssistantText(task.title).split(separator: " ").map(String.init))
            let score = queryTokens.intersection(titleTokens).count
            if score > bestScore {
                bestScore = score
                bestTask = task
            }
        }

        return bestScore > 0 ? bestTask : nil
    }

    private func handleAssistantCommand(_ command: AppVoiceCommandEnvelope) {
        let response: String
        var didHandleSuccessfully = false

        switch command.intent {
        case .addTask(let rawTitle, let category):
            let title = sanitizeVoiceTaskTitle(rawTitle)
            guard !title.isEmpty else {
                response = L10n.tr("assistant.response.unknown", lang)
                break
            }
            store.add(TaskItem(title: title, category: category))
            switchTab(to: .tasks)
            response = L10n.fmt("assistant.response.task_added", lang, title)
            didHandleSuccessfully = true

        case .completeTask(let requestedTitle):
            if let task = resolveTaskForVoice(title: requestedTitle, includeCompleted: false) {
                store.toggle(task.id, stats: stats)
                switchTab(to: .tasks)
                response = L10n.fmt("assistant.response.task_completed", lang, task.title)
                didHandleSuccessfully = true
            } else {
                response = L10n.tr("assistant.response.task_not_found", lang)
            }

        case .deleteTask(let requestedTitle):
            if let task = resolveTaskForVoice(title: requestedTitle, includeCompleted: true) {
                store.remove(task.id)
                switchTab(to: .tasks)
                response = L10n.fmt("assistant.response.task_deleted", lang, task.title)
                didHandleSuccessfully = true
            } else {
                response = L10n.tr("assistant.response.task_not_found", lang)
            }

        case .openTab(let requestedTab):
            switchTab(to: requestedTab)
            response = L10n.fmt("assistant.response.tab_opened", lang, localizedTabTitle(requestedTab))
            didHandleSuccessfully = true

        case .startPomodoro(let requestedMinutes):
            let minutes = max(5, min(120, requestedMinutes ?? pomo.config.focusMinutes))
            switchTab(to: .pomodoro)
            pomo.startFocus(customMinutes: minutes)
            response = L10n.fmt("assistant.response.pomodoro_started", lang, minutes)
            didHandleSuccessfully = true

        case .pausePomodoro:
            switchTab(to: .pomodoro)
            pomo.pause()
            response = L10n.tr("assistant.response.pomodoro_paused", lang)
            didHandleSuccessfully = true

        case .resumePomodoro:
            switchTab(to: .pomodoro)
            pomo.resume()
            response = L10n.tr("assistant.response.pomodoro_resumed", lang)
            didHandleSuccessfully = true

        case .startShortBreak:
            switchTab(to: .pomodoro)
            pomo.startShortBreak()
            response = L10n.tr("assistant.response.short_break_started", lang)
            didHandleSuccessfully = true

        case .startLongBreak:
            switchTab(to: .pomodoro)
            pomo.startLongBreak()
            response = L10n.tr("assistant.response.long_break_started", lang)
            didHandleSuccessfully = true

        case .stopPomodoro:
            pomo.stop()
            response = L10n.tr("assistant.response.pomodoro_stopped", lang)
            didHandleSuccessfully = true

        case .openEyeExercise:
            switchTab(to: .eye)
            showEyes = true
            response = L10n.tr("assistant.response.eye_opened", lang)
            didHandleSuccessfully = true

        case .summarizeMetrics(let period):
            response = assistantMetricsSummary(for: period)
            didHandleSuccessfully = true

        case .unknown:
            response = L10n.tr("assistant.response.unknown", lang)
        }

        voiceAssistant.recordCommandOutcome(
            intent: command.intent,
            transcript: command.transcript,
            wasSuccessful: didHandleSuccessfully,
            lang: lang
        )
        voiceAssistant.completePendingCommand(response: response, lang: lang)
    }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            ZStack {
                screenView(tab)
                    .id(tab)
                    .padding(.top, 6)
                    .transition(screenTransition)
                    .transaction { tx in
                        if isSwitchingTabs { tx.animation = nil }
                    }
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            GlassTabBar(selection: tabSelectionBinding, isInteractionEnabled: !isSwitchingTabs, lang: lang)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
        .overlay(alignment: .top) {
            if pomodoroAlarm.isActive {
                PomodoroAlarmBanner(
                    title: L10n.tr("pomodoro.alarm.title", lang),
                    subtitle: L10n.fmt("pomodoro.alarm.subtitle", lang, pomodoroAlarm.finishedPhaseTitle),
                    stopTitle: L10n.tr("pomodoro.alarm.stop", lang)
                ) {
                    pomodoroAlarm.stop()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .transition(
                    reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
                )
                .zIndex(9)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VoiceAssistantLauncherButton(
                title: L10n.tr("assistant.title", lang),
                state: voiceAssistant.state,
                onTap: {
                    if voiceAssistant.isListening {
                        voiceAssistant.stopListeningAndCommit(lang: lang)
                    } else {
                        voiceAssistant.startListening(lang: lang)
                    }
                },
                onLongPress: {
                    showVoiceAssistant = true
                }
            )
            .padding(.trailing, 18)
            .padding(.bottom, 94)
            .zIndex(8)
        }
        .buttonBorderShape(.capsule)
        .tint(selectedTheme.accentColor)

        // Прокидываем выбранный язык по всему приложению.
        .environment(\.lippiLangCode, langCode)
        .environment(\.lippiHasGlobalBackdrop, true)

        .environment(\.locale, Locale(identifier: lang.localeIdentifier))

        // (опционально) направление текста — на будущее (если добавишь арабский/иврит и т.п.)
        .environment(\.layoutDirection, .leftToRight)

        .environmentObject(store)
        .environmentObject(stats)
        .environmentObject(pomo)
        .environmentObject(countdown)
        .environmentObject(dailyReminder)
        .onAppear {
            NotificationManager.shared.requestAuthorization()
            pomo.stats = stats
            NotificationCenter.default.addObserver(forName: .taskCompletionChanged, object: nil, queue: .main) { note in
                guard let id = note.userInfo?["taskId"] as? UUID,
                      let completed = note.userInfo?["completed"] as? Bool else { return }
                if completed { stats.recordTaskDone(taskId: id) } else { stats.undoTaskDone(taskId: id) }
            }
            stats.purge(olderThan: 365)
            #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                let info = ActivityAuthorizationInfo()
                print("🟢 LiveActivities enabled: \(info.areActivitiesEnabled)")
            }
            #endif
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(isPresented: $showEyes) {
            EyeExerciseGameView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVoiceAssistant) {
            AppVoiceAssistantSheet(assistant: voiceAssistant, lang: lang)
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .suggestEyeExercise)) { _ in
            showEyes = true
        }
        .onChange(of: voiceAssistant.pendingCommand) { _, newValue in
            guard let command = newValue else { return }
            handleAssistantCommand(command)
        }
        .onDisappear {
            tabTransitionTask?.cancel()
            voiceAssistant.cancelListening()
        }
    }
}

/// Быстрый общий фон без дорогих blur-эффектов.
struct AppBackdrop: View {
    enum RenderMode {
        case auto
        case force
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiHasGlobalBackdrop) private var hasGlobalBackdrop
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.defaultTheme.rawValue
    var renderMode: RenderMode = .auto

    private var performanceMode: Bool { DS.runtimeConstrained || reduceTransparency }
    private var activeTheme: AppTheme { AppTheme(rawValue: themeRaw) ?? AppTheme.defaultTheme }
    private var palette: AppThemePalette { activeTheme.palette }
    private var shouldRender: Bool { renderMode == .force || !hasGlobalBackdrop }

    private var themedBackdropBase: Color {
        Color(dynamicDark: palette.backdropDark, light: palette.backdropLight)
    }

    private var themedBgBase: LinearGradient {
        let dark = palette.bgDarkStops
        let light = palette.bgLightStops
        return LinearGradient(
            colors: [
                Color(dynamicDark: dark[0], light: light[0]),
                Color(dynamicDark: dark[1], light: light[1]),
                Color(dynamicDark: dark[2], light: light[2]),
                Color(dynamicDark: dark[3], light: light[3]),
                Color(dynamicDark: dark[4], light: light[4])
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var themedGlowA: Color {
        let glow = palette.glowA
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }

    private var themedGlowB: Color {
        let glow = palette.glowB
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }

    private var themedGlowC: Color {
        let glow = palette.glowC
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }

    var body: some View {
        Group {
            if shouldRender {
                ZStack {
                    themedBackdropBase

                    themedBgBase

                    if performanceMode {
                        RadialGradient(
                            colors: [themedGlowA.opacity(0.62), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 250
                        )

                        RadialGradient(
                            colors: [themedGlowB.opacity(0.52), .clear],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 280
                        )

                        if !reduceMotion {
                            RadialGradient(
                                colors: [themedGlowC.opacity(0.44), .clear],
                                center: .bottom,
                                startRadius: 0,
                                endRadius: 220
                            )
                        }
                    } else {
                        RadialGradient(
                            colors: [themedGlowA, .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 320
                        )

                        RadialGradient(
                            colors: [themedGlowB, .clear],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 350
                        )

                        RadialGradient(
                            colors: [themedGlowC.opacity(0.74), .clear],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 280
                        )

                        LinearGradient(
                            colors: [
                                Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.020, lightAlpha: 0.052),
                                Color.clear,
                                Color(dynamicDark: 0x000000, light: 0x0F172A, darkAlpha: 0.10, lightAlpha: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .opacity(0.90)
                    }
                }
                .lippiWindowChrome()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Совместимость со старым названием фона.
private struct EyeBackdrop: View {
    var body: some View {
        AppBackdrop(renderMode: .force)
    }
}

private struct PomodoroAlarmBanner: View {
    let title: String
    let subtitle: String
    let stopTitle: String
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(safeSystemName: "bell.badge.fill", fallback: "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.text(0.94))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(DS.glassFill(0.12))
                        .overlay(Circle().stroke(DS.glassStroke(0.18), lineWidth: 1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.text(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: stopAction) {
                Text(stopTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DS.brand)
                    )
            }
            .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.95))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.glassFill(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DS.glassStroke(0.18), lineWidth: 1)
                )
        )
        .shadow(color: DS.shadow.opacity(0.24), radius: 8, x: 0, y: 4)
    }
}


// =======================================================
// MARK: - GlassTabBar (iPhone компактно + информативно)
// - Плотнее, ниже высота, выбранная вкладка показывает подпись,
//   остальные — только иконки (влезает даже на mini).
// =======================================================
struct GlassTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding var selection: AppTab
    var isInteractionEnabled: Bool = true
    let lang: AppLang
    @Namespace private var tabSelectionNamespace

    private var simplifiedEffects: Bool { DS.runtimeConstrained || reduceTransparency }

    var body: some View {
        HStack(spacing: simplifiedEffects ? 4 : 6) {
            TabButton(icon: "sun.max", fallback: "sun.max", title: L10n.tr(.tab_today, lang), tab: .today, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "checklist", fallback: "list.bullet", title: L10n.tr(.tab_tasks, lang), tab: .tasks, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "hourglass", fallback: "hourglass", title: L10n.tr(.tab_pomodoro, lang), tab: .pomodoro, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "gamecontroller.fill", fallback: "gamecontroller", title: L10n.tr(.tab_break, lang), tab: .break, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "heart.text.square.fill", fallback: "heart.fill", title: L10n.tr(.tab_health, lang), tab: .health, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "eye", fallback: "eye", title: L10n.tr(.tab_eye, lang), tab: .eye, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
            TabButton(icon: "gearshape", fallback: "gearshape", title: L10n.tr(.tab_settings, lang), tab: .settings, selection: $selection, namespace: tabSelectionNamespace, isInteractionEnabled: isInteractionEnabled, simplifiedEffects: simplifiedEffects)
        }
        .padding(.horizontal, simplifiedEffects ? 7 : 8)
        .padding(.vertical, simplifiedEffects ? 7 : 8)
        .background(tabBarBackground)
        .overlay(tabBarOverlay)
        .shadow(color: DS.shadow.opacity(simplifiedEffects ? 0.14 : 0.28), radius: simplifiedEffects ? 6 : 12, x: 0, y: simplifiedEffects ? 3 : 8)
        .animation(reduceMotion ? nil : DS.motionQuick, value: selection)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if simplifiedEffects {
            shape
                .fill(DS.glassFill(0.06))
                .overlay(
                    shape
                        .fill(DS.glassTint)
                        .opacity(0.20)
                )
        } else {
            shape
                .fill(DS.glassFill(0.07))
                .overlay(
                    shape
                        .fill(DS.glassDepth)
                        .opacity(0.44)
                )
                .overlay(
                    shape
                        .fill(DS.glassTint)
                        .opacity(0.52)
                )
                .overlay(
                    shape
                        .fill(DS.brandIridescent)
                        .blendMode(.screen)
                        .opacity(0.30)
                )
                .overlay(alignment: .top) {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)
                        .clipShape(shape)
                }
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(DS.cardTopLine)
                        .frame(width: 118, height: 1.35)
                        .padding(.top, 8)
                        .padding(.leading, 14)
                        .opacity(0.92)
                }
        }
    }

    @ViewBuilder
    private var tabBarOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if simplifiedEffects {
            shape
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        } else {
            shape
                .stroke(DS.stroke, lineWidth: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(DS.glassStroke(0.10), lineWidth: 1)
                        .padding(1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DS.depthShadow(0.14), lineWidth: 1)
                        .padding(2)
                )
        }
    }
}

private struct TabButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let icon: String
    let fallback: String
    let title: String
    let tab: AppTab
    @Binding var selection: AppTab
    let namespace: Namespace.ID
    let isInteractionEnabled: Bool
    let simplifiedEffects: Bool
    var isSelected: Bool { selection == tab }

    var body: some View {
        Button {
            guard isInteractionEnabled else { return }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            selection = tab
        } label: {
            HStack(spacing: 6) {
                Image(safeSystemName: icon, fallback: fallback)
                    .font(.system(size: isSelected ? 15 : 14, weight: .semibold, design: .rounded))
                    .frame(width: 20, height: 20)

                // ✅ Подпись только у выбранной вкладки: максимум инфы без перегруза
                if isSelected {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .singleLine()
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
                }
            }
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 9)
            .frame(minWidth: 44) // iOS tap target
            .background(pillBackground)
            .overlay(pillOverlay)
            .foregroundStyle(isSelected ? Color.white : DS.text(simplifiedEffects ? 0.80 : 0.84))
            .scaleEffect(reduceMotion || simplifiedEffects ? 1 : (isSelected ? 1 : 0.99))
            .animation(
                reduceMotion ? nil : DS.motionQuick,
                value: isSelected
            )
            .shadow(color: isSelected && !simplifiedEffects ? DS.accent.opacity(0.24) : .clear, radius: isSelected ? 5 : 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var pillBackground: some View {
        let base = Capsule()
            .fill(isSelected ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.glassFill(0.04, lightOpacity: 0.24)))
            .opacity(isSelected ? 0.98 : 1.0)

        if simplifiedEffects {
            base
                .overlay {
                    if isSelected {
                        Capsule()
                            .fill(DS.glassFill(0.07, lightOpacity: 0.20))
                            .opacity(0.72)
                    }
                }
        } else {
            base
                .overlay {
                    if isSelected {
                        Capsule()
                            .fill(DS.glassFill(0.06))
                            .matchedGeometryEffect(id: "selected-tab-pill", in: namespace)
                            .blendMode(.screen)
                            .overlay(
                                Capsule()
                                    .fill(DS.brandSoftGradient)
                                    .blendMode(.screen)
                            )
                    }
                }
                .overlay {
                    Capsule()
                        .fill(DS.liquidSheen)
                        .opacity(isSelected ? 0.28 : 0.10)
                        .mask(
                            LinearGradient(
                                colors: [.white, .white.opacity(0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
        }
    }

    private var pillOverlay: some View {
        Capsule()
            .strokeBorder(isSelected ? DS.glassStroke(0.26) : DS.glassStroke(0.12),
                          lineWidth: 1)
    }
}

// MARK: - App Entry
// =======================================================
@main
struct LippiSingleApp: App {
    @StateObject private var eyeStore = EyeExerciseStore()
    @StateObject private var authStore = AuthStore()

    init() {
        #if os(iOS)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav

        UIScrollView.appearance().backgroundColor = .clear
        UITableView.appearance().backgroundColor  = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        // ⬇︎ ВОТ ЭТА СТРОКА — С КОНКРЕТИЗАЦИЕЙ ТИПА
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear

        UIWindow.appearance().backgroundColor = .clear
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(eyeStore)
                .environmentObject(authStore)
        }
    }
}
