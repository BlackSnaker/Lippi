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
import AVFoundation
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

    /// Резервный сценарий для iOS до 26 или когда Live Activities выключены.
    /// На iOS 26+ тот же alert доставляет запланированная Live Activity без
    /// дублирующего уведомления.
    func scheduleEyeBreak(at date: Date, opensCamera: Bool) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }

            let id = "lippi-eye-break"
            self.cancel(ids: [id])

            let content = UNMutableNotificationContent()
            content.title = L10n.trCurrent("eye.live.notification.title")
            content.body = L10n.trCurrent(
                opensCamera
                    ? "eye.live.notification.body_camera"
                    : "eye.live.notification.body_point"
            )
            content.sound = .default
            content.threadIdentifier = "lippi-eye-care"
            content.userInfo = [
                "url": opensCamera
                    ? "lippi://eye?mode=camera"
                    : "lippi://eye?mode=point"
            ]
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 0.72
            }

            let now = Date()
            let fireDate = date > now.addingTimeInterval(1) ? date : now.addingTimeInterval(2)
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            components.timeZone = TimeZone.current

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error { print("🔔 eye break request error:", error) }
            }
        }
    }

    /// Тихая подсказка: без звука, без Time Sensitive и только в Notification Center,
    /// если приложение сейчас открыто. Подходит для необязательных советов.
    func scheduleGentle(
        id: String,
        title: String,
        body: String,
        at date: Date,
        replaceExisting: Bool = true,
        userInfo: [AnyHashable: Any] = [:],
        threadIdentifier: String = "lippi-care"
    ) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }
            if replaceExisting { self.cancel(ids: [id]) }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil
            content.userInfo = userInfo
            content.threadIdentifier = threadIdentifier
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .passive
                content.relevanceScore = 0.15
            }

            let now = Date()
            let fireDate = date > now.addingTimeInterval(1) ? date : now.addingTimeInterval(2)
            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            components.timeZone = TimeZone.current

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            self.center.add(request) { error in
                if let error { print("🔔 gentle suggestion error:", error, "id:", id) }
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

    /// Повторяющееся еженедельно по дню недели Calendar: 1 = Sunday, 2 = Monday...
    func scheduleWeekly(
        id: String,
        title: String,
        body: String,
        weekday: Int,
        hour: Int,
        minute: Int,
        replaceExisting: Bool = true,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        ensureAuthorized { [weak self] ok in
            guard let self, ok else { return }
            if replaceExisting { self.cancel(ids: [id]) }

            var comps = DateComponents()
            comps.weekday = min(max(weekday, 1), 7)
            comps.hour = min(max(hour, 0), 23)
            comps.minute = min(max(minute, 0), 59)
            comps.second = 0
            comps.timeZone = nil

            let content = self.makeContent(title: title, body: body)
            content.userInfo = userInfo
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            self.center.add(req) { error in
                if let error { print("🔔 add weekly request error:", error, "id:", id) }
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
        let isGentleSuggestion = notification.request.identifier.hasPrefix("goal-care-")
            || notification.request.identifier.hasPrefix("lippi-care-")
        if isPomodoroNotification {
            PomodoroAlarmCenter.shared.start(phaseTitle: notification.request.content.title)
        }
        if #available(iOS 14.0, *) {
            if isGentleSuggestion {
                completionHandler([.list])
            } else {
                completionHandler(isPomodoroNotification ? [.banner, .list] : [.banner, .sound, .list])
            }
        } else {
            completionHandler(isGentleSuggestion ? [] : (isPomodoroNotification ? [.alert] : [.alert, .sound]))
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
    private let loadQueue = DispatchQueue(label: "StatsStore.load", qos: .userInitiated)
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
    private struct SeriesCache {
        let referenceDay: Date
        let values: [DayStats]
    }
    private var cachedAggByDay: [Date: DayAgg]? = nil
    private var cachedSeries: [Int: SeriesCache] = [:]
    private var purgeCutoff: Date?
    private var hasFinishedInitialLoad = false
    private var needsSaveAfterLoad = false

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
        if let cached = cachedSeries[daysCount], cached.referenceDay == today {
            return cached.values
        }

        // окно дат (как было), но без force unwrap в map
        var window: [Date] = []
        window.reserveCapacity(daysCount)
        for i in (0..<daysCount).reversed() {
            if let d = cal.date(byAdding: .day, value: -i, to: today) {
                window.append(d)
            }
        }

        let agg = aggregatedByDay()

        let values = window.map { day in
            let a = agg[day] ?? DayAgg()
            return DayStats(date: day, focusMinutes: a.focusMinutes, tasksDone: a.tasksDone)
        }
        cachedSeries[daysCount] = SeriesCache(referenceDay: today, values: values)
        return values
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
        purgeCutoff = limit
        events.removeAll { startOfDay($0.date) < limit }

        rebuildIndexes()
        invalidateCaches()
        scheduleSave()
    }

    private func loadOrMigrate() {
        let eventsURL = urlEvents
        let legacyURL = urlLegacy
        loadQueue.async { [weak self] in
            var loaded: [StatsEvent] = []
            var migratedLegacy = false

            if let data = try? Data(contentsOf: eventsURL),
               let decoded = try? JSONDecoder().decode([StatsEvent].self, from: data) {
                loaded = decoded
            } else if let data = try? Data(contentsOf: legacyURL),
                      let legacy = try? JSONDecoder().decode([DayStats].self, from: data) {
                loaded.reserveCapacity(legacy.count * 2)
                for day in legacy {
                    let midday = Calendar.current.date(
                        bySettingHour: 12,
                        minute: 0,
                        second: 0,
                        of: startOfDay(day.date)
                    ) ?? day.date
                    if day.focusMinutes > 0 {
                        loaded.append(
                            StatsEvent(
                                date: midday,
                                type: .focus,
                                seconds: day.focusMinutes * 60,
                                taskId: nil
                            )
                        )
                    }
                    if day.tasksDone > 0 {
                        for _ in 0..<day.tasksDone {
                            loaded.append(
                                StatsEvent(date: midday, type: .taskDone, seconds: nil, taskId: nil)
                            )
                        }
                    }
                }
                migratedLegacy = true
            }

            let result = loaded
            let didMigrate = migratedLegacy
            DispatchQueue.main.async { [weak self] in
                self?.installLoadedEvents(result, migratedLegacy: didMigrate)
            }
        }
    }

    private func installLoadedEvents(_ loaded: [StatsEvent], migratedLegacy: Bool) {
        var prepared = loaded
        if let purgeCutoff {
            prepared.removeAll { startOfDay($0.date) < purgeCutoff }
        }

        if events.isEmpty {
            events = prepared
        } else {
            let currentIDs = Set(events.map(\.id))
            events = prepared.filter { !currentIDs.contains($0.id) } + events
        }
        rebuildIndexes()
        invalidateCaches()
        hasFinishedInitialLoad = true

        if migratedLegacy || needsSaveAfterLoad {
            needsSaveAfterLoad = false
            scheduleSave()
        }
        if migratedLegacy {
            let legacyURL = urlLegacy
            loadQueue.async {
                try? FileManager.default.removeItem(at: legacyURL)
            }
        }
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
        cachedSeries.removeAll(keepingCapacity: true)
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
        guard hasFinishedInitialLoad else {
            needsSaveAfterLoad = true
            return
        }
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

struct TodayTaskOverview {
    let active: [TaskItem]
    let overdue: [TaskItem]
    let dueToday: [TaskItem]
    let upcoming: [TaskItem]
}

final class TaskStore: ObservableObject {
    // УБРАЛИ didSet { save() } — это писало на диск при каждом изменении и лагало UI
    @Published private(set) var tasks: [TaskItem] = [] {
        didSet { cachedTodayOverview = nil }
    }

    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("tasks.json")

    // -------------------------------------------------------
    // MARK: - Debounced background save (главное ускорение)
    // -------------------------------------------------------
    private let saveQueue = DispatchQueue(label: "TaskStore.save", qos: .utility)
    private let loadQueue = DispatchQueue(label: "TaskStore.load", qos: .userInitiated)
    private var pendingSave: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.35
    private var hasFinishedInitialLoad = false
    private var needsSaveAfterLoad = false
    private var cachedTodayOverview: (createdAt: Date, value: TodayTaskOverview)?

    init() {
        load()
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

    func todayOverview(now: Date = .now) -> TodayTaskOverview {
        if let cachedTodayOverview,
           now.timeIntervalSince(cachedTodayOverview.createdAt) < 1 {
            return cachedTodayOverview.value
        }

        let active = tasks.filter { !$0.isCompleted }
        let overdue = active.filter { item in
            guard let due = item.dueDate else { return false }
            return due < now
        }
        let dueToday = active.filter { item in
            guard let due = item.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && due >= now
        }
        let upcoming = active.sorted { lhs, rhs in
            let left = lhs.dueDate ?? .distantFuture
            let right = rhs.dueDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
        let value = TodayTaskOverview(
            active: active,
            overdue: overdue,
            dueToday: dueToday,
            upcoming: upcoming
        )
        cachedTodayOverview = (now, value)
        return value
    }

    // MARK: - Persistence

    private func load() {
        let url = fileURL
        loadQueue.async { [weak self] in
            let loaded: [TaskItem]
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
                loaded = decoded
            } else {
                loaded = []
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.tasks.isEmpty {
                    if !self.needsSaveAfterLoad {
                        self.tasks = loaded
                    }
                } else {
                    let currentIDs = Set(self.tasks.map(\.id))
                    self.tasks = loaded.filter { !currentIDs.contains($0.id) } + self.tasks
                }
                self.hasFinishedInitialLoad = true
                self.refreshNextTaskWidget()
                if self.needsSaveAfterLoad {
                    self.needsSaveAfterLoad = false
                    self.scheduleSave()
                }
            }
        }
    }

    /// Debounced save — чтобы не тормозить скролл/анимации.
    private func scheduleSave() {
        guard hasFinishedInitialLoad else {
            needsSaveAfterLoad = true
            return
        }
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

enum EyeBreakLiveActivityMode: String, Codable, Hashable {
    case pointOnly
    case cameraAvailable
}

struct PomodoroConfig: Codable, Hashable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var roundsBeforeLongBreak: Int = 4
}

@MainActor
final class PomodoroManager: ObservableObject {
    static let configStorageKey = "pomodoro.config.v2"
    static let rhythmHistoryStorageKey = "pomodoro.rhythm.history.v1"

    @Published private(set) var phase: PomodoroPhase = .stopped
    @Published private(set) var round: Int = 0
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published private(set) var sessionTotalDuration: TimeInterval?
    @Published private(set) var rhythmHistory: PomodoroRhythmHistory
    @Published private(set) var lastSessionRecord: PomodoroSessionRecord?
    @Published var config: PomodoroConfig {
        didSet { persistConfig() }
    }

    weak var stats: StatsStore?

    private let defaults: UserDefaults
    private var notifIds: [String] = []
    private var pausedRemaining: TimeInterval?
    private var pausedPhase: PomodoroPhase?
    private var movementScheduledAt: Date?
    private var accumulatedSessionSeconds: TimeInterval = 0
    private let movementNotificationID = "pomodoro-movement-safety"
    private let eyeBreakNotificationID = "lippi-eye-break"
    private var eyeBreakAutoSuggestEnabled = true
    private var eyeBreakThresholdMinutes = 40
    private var eyeBreakDuration: TimeInterval = 60
    private var eyeBreakPlanID: UUID?
    private var eyeBreakSchedulingTask: Task<Void, Never>?
    private var eyeBreakScheduledForCurrentSession = false
    private var eyeBreakWasPresentedForCurrentSession = false
    private var plannedEyeBreakStartDate: Date?

    var pausedSessionRemaining: TimeInterval? { pausedRemaining }

    func configureEyeBreaks(_ settings: EyeExerciseSettings) {
        eyeBreakAutoSuggestEnabled = settings.autoSuggestEnabled
        eyeBreakThresholdMinutes = min(max(settings.suggestThresholdMinutes, 5), 180)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.configStorageKey),
           let saved = try? JSONDecoder().decode(PomodoroConfig.self, from: data) {
            config = saved
        } else {
            config = PomodoroConfig()
        }
        if let data = defaults.data(forKey: Self.rhythmHistoryStorageKey),
           let saved = try? JSONDecoder().decode(PomodoroRhythmHistory.self, from: data) {
            rhythmHistory = saved
        } else {
            rhythmHistory = PomodoroRhythmHistory()
        }
        WidgetUpdater.clearPomodoro()
    }

    func startFocus(customMinutes: Int? = nil) {
        _ = finalizeCurrentSession(reason: .replaced)
        beginFocus(minutes: customMinutes ?? config.focusMinutes)
    }

    func startShortBreak() {
        _ = finalizeCurrentSession(reason: .replaced)
        beginBreak(long: false)
    }

    func startLongBreak() {
        _ = finalizeCurrentSession(reason: .replaced)
        beginBreak(long: true)
    }

    func applyRecommendation(_ recommendation: AdaptivePomodoroRecommendation) {
        config = recommendation.config
    }

    private func beginFocus(minutes: Int) {
        let replacesWithAnotherEyeBreak = eyeBreakAutoSuggestEnabled
            && minutes >= eyeBreakThresholdMinutes
        cancelEyeBreakPlan(
            resetSession: true,
            endLiveActivity: !replacesWithAnotherEyeBreak
        )
        accumulatedSessionSeconds = 0
        eyeBreakWasPresentedForCurrentSession = false
        eyeBreakScheduledForCurrentSession = false
        phase = .focus
        start(
            for: min(max(minutes, 1), 180),
            title: L10n.trCurrent("pomodoro.phase.focus"),
            notifBody: L10n.trCurrent("pomodoro.notification.focus_body")
        )
        scheduleMovementIfNeeded()
    }

    private func beginBreak(long: Bool) {
        cancelEyeBreakPlan(resetSession: true)
        accumulatedSessionSeconds = 0
        phase = long ? .longBreak : .shortBreak
        start(
            for: long ? config.longBreakMinutes : config.shortBreakMinutes,
            title: L10n.trCurrent(long ? "pomodoro.phase.long_break" : "pomodoro.phase.short_break"),
            notifBody: L10n.trCurrent(long ? "pomodoro.notification.long_break_body" : "pomodoro.notification.short_break_body")
        )
        cancelMovementNotification()
    }

    func pause() {
        guard phase != .paused, phase != .stopped, let end = endDate else { return }
        let activePhase = phase
        if let startDate {
            accumulatedSessionSeconds += max(Date.now.timeIntervalSince(startDate), 0)
        }
        pausedPhase = activePhase
        pausedRemaining = max(end.timeIntervalSinceNow, 0)
        if let plannedEyeBreakStartDate, plannedEyeBreakStartDate <= .now {
            eyeBreakWasPresentedForCurrentSession = true
        }
        cancelEyeBreakPlan(resetSession: false)
        endDate = nil
        phase = .paused
        cancelTimerNotifications()
        cancelMovementNotification()
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

        if let endDate {
            scheduleTimerNotification(
                title: titleForPhase(restorePhase),
                body: notificationBody(for: restorePhase),
                at: endDate
            )
        }

        if restorePhase == .focus {
            scheduleMovementIfNeeded()
            prepareEyeBreakIfNeeded()
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
        _ = finalizeCurrentSession(reason: .stopped)
        phase = .stopped
        round = 0
        startDate = nil
        endDate = nil
        pausedRemaining = nil
        pausedPhase = nil
        accumulatedSessionSeconds = 0
        sessionTotalDuration = nil
        cancelTimerNotifications()
        cancelMovementNotification()
        cancelEyeBreakPlan(resetSession: true)
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { Task { await PomodoroLiveManager.endAll() } }
        #endif
        WidgetUpdater.clearPomodoro()
    }

    private func start(for minutes: Int, title: String, notifBody: String) {
        cancelTimerNotifications()
        let secs = atLeastOneSecond(TimeInterval(minutes * 60))
        sessionTotalDuration = secs
        startDate = .now
        endDate = Date(timeIntervalSinceNow: secs)
        pausedRemaining = nil
        pausedPhase = nil

        if let endDate {
            scheduleTimerNotification(title: title, body: notifBody, at: endDate)
        }

        if phase == .focus {
            prepareEyeBreakIfNeeded()
        } else {
            cancelEyeBreakPlan(resetSession: true)
        }

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), let s = startDate {
            Task { await PomodoroLiveManager.start(title: title, phase: phase, start: s, end: endDate, round: round) }
        }
        #endif
        syncPomodoroWidget()
    }

    func advance(reason: PomodoroTransitionReason = .skipped) {
        let completedPhase = phase == .paused ? pausedPhase : phase
        let record = finalizeCurrentSession(reason: reason)

        switch completedPhase {
        case .focus:
            if record?.wasCompleted == true { round += 1 }
            let cycleLength = max(config.roundsBeforeLongBreak, 1)
            let needsLongBreak = record?.wasCompleted == true && round > 0 && round % cycleLength == 0
            beginBreak(long: needsLongBreak)
        case .shortBreak, .longBreak:
            beginFocus(minutes: config.focusMinutes)
        case .paused, .stopped, .none:
            break
        }
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), let s = startDate {
            Task { await PomodoroLiveManager.update(phase: phase, title: titleForPhase(phase), start: s, end: endDate, round: round) }
        }
        #endif
        syncPomodoroWidget()
    }

    /// Планирует короткий проверочный сценарий ухода за глазами, чтобы пользователь
    /// успел заблокировать iPhone и увидеть уведомление / Dynamic Island.
    func scheduleEyeBreakTest(after delay: TimeInterval = 10) {
        let breakStart = Date.now.addingTimeInterval(max(delay, 2))
        let breakEnd = breakStart.addingTimeInterval(eyeBreakDuration)
        let mode: EyeBreakLiveActivityMode
        #if os(iOS)
        mode = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            ? .cameraAvailable
            : .pointOnly
        #else
        mode = .pointOnly
        #endif

        #if canImport(ActivityKit)
        if #available(iOS 26.0, *) {
            Task {
                let scheduled = await EyeBreakLiveActivityManager.schedule(
                    sessionID: UUID(),
                    start: breakStart,
                    end: breakEnd,
                    mode: mode,
                    languageCode: L10n.currentLang.rawValue,
                    replacesExisting: true
                )
                if !scheduled {
                    NotificationManager.shared.scheduleEyeBreak(
                        at: breakStart,
                        opensCamera: mode == .cameraAvailable
                    )
                }
            }
            return
        }
        #endif

        NotificationManager.shared.scheduleEyeBreak(
            at: breakStart,
            opensCamera: mode == .cameraAvailable
        )
    }

    @discardableResult
    private func finalizeCurrentSession(reason: PomodoroTransitionReason) -> PomodoroSessionRecord? {
        guard let activePhase = phase == .paused ? pausedPhase : Optional(phase),
              activePhase == .focus || activePhase == .shortBreak || activePhase == .longBreak,
              let planned = sessionTotalDuration else { return nil }

        var active = accumulatedSessionSeconds
        if phase != .paused, let startDate {
            active += max(0, Date.now.timeIntervalSince(startDate))
        }
        if reason == .timerCompleted {
            active = max(active, planned)
        }
        active = min(max(active, 0), planned)
        accumulatedSessionSeconds = 0
        guard active >= 1 else { return nil }

        let record = PomodoroSessionRecord(
            phase: activePhase,
            plannedSeconds: planned,
            activeSeconds: active,
            transitionReason: reason
        )
        rhythmHistory.append(record)
        lastSessionRecord = record
        persistRhythmHistory()

        if activePhase == .focus {
            stats?.recordFocus(seconds: active, on: record.endedAt)
            NotificationCenter.default.post(
                name: .focusWorkLogged,
                object: nil,
                userInfo: [
                    "seconds": active,
                    "eyeBreakHandled": eyeBreakScheduledForCurrentSession || eyeBreakWasPresentedForCurrentSession
                ]
            )
        }
        return record
    }

    private func scheduleTimerNotification(title: String, body: String, at date: Date) {
        let id = "pomodoro-\(UUID().uuidString)"
        notifIds.append(id)
        NotificationManager.shared.schedule(id: id, title: title, body: body, at: date)
    }

    private func cancelTimerNotifications() {
        guard !notifIds.isEmpty else { return }
        NotificationManager.shared.cancel(ids: notifIds)
        notifIds.removeAll()
    }

    private func notificationBody(for phase: PomodoroPhase) -> String {
        switch phase {
        case .focus:
            return L10n.trCurrent("pomodoro.notification.focus_body")
        case .shortBreak:
            return L10n.trCurrent("pomodoro.notification.short_break_body")
        case .longBreak:
            return L10n.trCurrent("pomodoro.notification.long_break_body")
        case .paused, .stopped:
            return ""
        }
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

    private func scheduleMovementIfNeeded() {
        guard phase == .focus,
              let total = sessionTotalDuration,
              total > 50 * 60,
              movementScheduledAt == nil else { return }

        let remainingUntilMovement = max(50 * 60 - accumulatedSessionSeconds, 60)
        let when = Date().addingTimeInterval(remainingUntilMovement)
        movementScheduledAt = when
        let tip = MovementTips.randomTip()

        NotificationManager.shared.schedule(
            id: movementNotificationID,
            title: L10n.trCurrent("movement.notification.title"),
            body: tip,
            at: when
        )
    }

    private func cancelMovementNotification() {
        NotificationManager.shared.cancel(ids: [movementNotificationID])
        movementScheduledAt = nil
    }

    private func prepareEyeBreakIfNeeded() {
        guard phase == .focus,
              eyeBreakAutoSuggestEnabled,
              !eyeBreakWasPresentedForCurrentSession,
              let focusStart = startDate,
              let focusEnd = endDate,
              let plannedDuration = sessionTotalDuration else {
            return
        }

        let threshold = TimeInterval(eyeBreakThresholdMinutes * 60)
        guard plannedDuration >= threshold else { return }

        let activeBeforeThisSegment = accumulatedSessionSeconds
        let delay = max(threshold - activeBeforeThisSegment, 2)
        let breakStart = focusStart.addingTimeInterval(delay)
        guard breakStart <= focusEnd.addingTimeInterval(1) else { return }

        let breakEnd = breakStart.addingTimeInterval(eyeBreakDuration)
        let mode: EyeBreakLiveActivityMode
        #if os(iOS)
        mode = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            ? .cameraAvailable
            : .pointOnly
        #else
        mode = .pointOnly
        #endif

        eyeBreakSchedulingTask?.cancel()
        NotificationManager.shared.cancel(ids: [eyeBreakNotificationID])

        let planID = UUID()
        eyeBreakPlanID = planID
        plannedEyeBreakStartDate = breakStart
        eyeBreakScheduledForCurrentSession = true

        #if canImport(ActivityKit)
        if #available(iOS 26.0, *) {
            eyeBreakSchedulingTask = Task { [weak self] in
                let scheduled = await EyeBreakLiveActivityManager.schedule(
                    sessionID: planID,
                    start: breakStart,
                    end: breakEnd,
                    mode: mode,
                    languageCode: L10n.currentLang.rawValue
                )
                guard !Task.isCancelled,
                      let self,
                      self.eyeBreakPlanID == planID else { return }
                if !scheduled {
                    NotificationManager.shared.scheduleEyeBreak(
                        at: breakStart,
                        opensCamera: mode == .cameraAvailable
                    )
                }
            }
            return
        }
        #endif

        NotificationManager.shared.scheduleEyeBreak(
            at: breakStart,
            opensCamera: mode == .cameraAvailable
        )
    }

    private func cancelEyeBreakPlan(
        resetSession: Bool,
        endLiveActivity: Bool = true
    ) {
        eyeBreakSchedulingTask?.cancel()
        eyeBreakSchedulingTask = nil
        eyeBreakPlanID = nil
        plannedEyeBreakStartDate = nil
        NotificationManager.shared.cancel(ids: [eyeBreakNotificationID])
        #if canImport(ActivityKit)
        if endLiveActivity, #available(iOS 26.0, *) {
            Task { await EyeBreakLiveActivityManager.endAll() }
        }
        #endif
        if resetSession {
            eyeBreakScheduledForCurrentSession = false
            eyeBreakWasPresentedForCurrentSession = false
        }
    }

    private func persistConfig() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.configStorageKey)
    }

    private func persistRhythmHistory() {
        guard let data = try? JSONEncoder().encode(rhythmHistory) else { return }
        defaults.set(data, forKey: Self.rhythmHistoryStorageKey)
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
        var categoryTitle: String
        var categorySymbol: String
        var startDate: Date
        var dueDate: Date?
        var isCompleted: Bool
    }
    var taskId: UUID
}

@available(iOS 16.2, *)
enum LiveActivityManager {
    static func startTask(_ task: TaskItem) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let attributes = OrganizerAttributes(taskId: task.id)
        let state = OrganizerAttributes.ContentState(
            taskTitle: task.title,
            categoryTitle: task.category.title,
            categorySymbol: task.category.symbol,
            startDate: now,
            dueDate: safeEnd(from: now, proposed: task.dueDate),
            isCompleted: task.isCompleted
        )
        let content = ActivityContent(state: state, staleDate: nil)
        _ = try? Activity<OrganizerAttributes>.request(attributes: attributes, content: content, pushType: nil)
    }
    static func endTask(_ taskId: UUID) async {
        for a in Activity<OrganizerAttributes>.activities where a.attributes.taskId == taskId {
            var state = a.content.state
            state.isCompleted = true
            await a.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
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

@available(iOS 26.0, *)
struct EyeBreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var mode: EyeBreakLiveActivityMode
        var languageCode: String
    }

    var sessionID: UUID
}

@available(iOS 26.0, *)
enum EyeBreakLiveActivityManager {
    @MainActor
    static func schedule(
        sessionID: UUID,
        start: Date,
        end: Date,
        mode: EyeBreakLiveActivityMode,
        languageCode: String,
        replacesExisting: Bool = true
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              end > start,
              start > Date.now.addingTimeInterval(1) else { return false }

        if replacesExisting {
            await endAll()
        }
        guard !Task.isCancelled else { return false }

        let attributes = EyeBreakActivityAttributes(sessionID: sessionID)
        let state = EyeBreakActivityAttributes.ContentState(
            startDate: start,
            endDate: end,
            mode: mode,
            languageCode: languageCode
        )
        let content = ActivityContent(
            state: state,
            staleDate: end,
            relevanceScore: 100
        )

        do {
            _ = try Activity<EyeBreakActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil,
                style: .standard,
                alertConfiguration: alertConfiguration(languageCode: languageCode, mode: mode),
                start: start
            )
            return true
        } catch {
            print("👁️ Unable to schedule eye break Live Activity:", error)
            return false
        }
    }

    @MainActor
    static func endAll() async {
        for activity in Activity<EyeBreakActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @MainActor
    static func removeExpired(at date: Date = .now) async {
        for activity in Activity<EyeBreakActivityAttributes>.activities
        where activity.content.state.endDate <= date {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func alertConfiguration(
        languageCode: String,
        mode: EyeBreakLiveActivityMode
    ) -> AlertConfiguration {
        switch languageCode.lowercased() {
        case "en":
            return AlertConfiguration(
                title: "A short break for your eyes",
                body: mode == .cameraAvailable
                    ? "Follow the point in Dynamic Island or open precise camera mode."
                    : "Follow the point in Dynamic Island — no camera is needed.",
                sound: .default
            )
        case "de":
            return AlertConfiguration(
                title: "Eine kurze Pause für die Augen",
                body: mode == .cameraAvailable
                    ? "Folge dem Punkt in der Dynamic Island oder öffne den präzisen Kameramodus."
                    : "Folge dem Punkt in der Dynamic Island — ganz ohne Kamera.",
                sound: .default
            )
        case "es":
            return AlertConfiguration(
                title: "Una pausa breve para la vista",
                body: mode == .cameraAvailable
                    ? "Sigue el punto en Dynamic Island o abre el modo preciso con cámara."
                    : "Sigue el punto en Dynamic Island; no hace falta cámara.",
                sound: .default
            )
        default:
            return AlertConfiguration(
                title: "Короткая пауза для глаз",
                body: mode == .cameraAvailable
                    ? "Следите за точкой в Dynamic Island или откройте точный режим с камерой."
                    : "Следите за точкой в Dynamic Island — камера не нужна.",
                sound: .default
            )
        }
    }
}

@available(iOS 16.2, *)
enum PomodoroLiveManager {
    static func start(title: String, phase: PomodoroPhase, start: Date, end: Date?, round: Int = 0) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PomodoroAttributes(sessionId: UUID())
        let state = PomodoroAttributes.ContentState(title: title, phase: phase, startDate: start, endDate: end, round: round)
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

enum AppTab: Hashable {
    case today, tasks, pomodoro, `break`, health, eye, settings

    static let navigationOrder: [AppTab] = [.today, .tasks, .pomodoro, .break, .health, .eye, .settings]
    static let primaryTabs: [AppTab] = [.today, .tasks, .pomodoro]
    static let overflowTabs: [AppTab] = [.break, .health, .eye, .settings]

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .tasks: return "checklist"
        case .pomodoro: return "hourglass"
        case .break: return "gamecontroller.fill"
        case .health: return "heart.text.square.fill"
        case .eye: return "eye"
        case .settings: return "gearshape"
        }
    }

    var fallbackIcon: String {
        switch self {
        case .today: return "sun.max"
        case .tasks: return "list.bullet"
        case .pomodoro: return "hourglass"
        case .break: return "gamecontroller"
        case .health: return "heart.fill"
        case .eye: return "eye"
        case .settings: return "gearshape"
        }
    }

    func title(lang: AppLang) -> String {
        switch self {
        case .today: return L10n.tr(.tab_today, lang)
        case .tasks: return L10n.tr(.tab_tasks, lang)
        case .pomodoro: return L10n.tr(.tab_pomodoro, lang)
        case .break: return L10n.tr(.tab_break, lang)
        case .health: return L10n.tr(.tab_health, lang)
        case .eye: return L10n.tr(.tab_eye, lang)
        case .settings: return L10n.tr(.tab_settings, lang)
        }
    }

    var isOverflow: Bool {
        Self.overflowTabs.contains(self)
    }

    var navigationIndex: Int {
        Self.navigationOrder.firstIndex(of: self) ?? 0
    }
}

struct ContentView: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.defaultTheme.rawValue
    @AppStorage("goal.progress.userState") private var goalUserStateRaw: String = GoalUserState.calm.rawValue
    @AppStorage("assistant.launcher.isCollapsed") private var isVoiceAssistantCollapsed = false
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private var langCode: String { lang.rawValue }
    private var selectedTheme: AppTheme { AppTheme(rawValue: themeRaw) ?? AppTheme.defaultTheme }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var eye: EyeExerciseStore

    @State private var showEyes = false
    @State private var showPointEyeExercise = false
    @StateObject private var store = TaskStore()
    @StateObject private var stats = StatsStore()
    @StateObject private var pomo = PomodoroManager()
    @StateObject private var pomodoroCoach = AdaptivePomodoroCoach()
    @StateObject private var pomodoroAlarm = PomodoroAlarmCenter.shared
    @StateObject private var voiceAssistant = AppVoiceAssistantCenter()
    @StateObject private var countdown = CountdownStore()
    @StateObject private var dailyReminder = DailyReminderStore()
    @StateObject private var scrollPerformance = ScrollPerformanceCoordinator()
    @StateObject private var careCenter = LippiCareCenter.shared
    @StateObject private var watchDiscovery = AppleWatchDiscovery.shared
    @State private var tab: AppTab = .today
    @State private var showGoalPlanner = false
    @State private var showAssistantCalendar = false
    @State private var openGoalProgressSummary = false
    @State private var assistantGoalDraft: String?
    @State private var showVoiceAssistant = false
    @State private var taskCompletionObserver: NSObjectProtocol?

    @ViewBuilder
    private func screenView(_ tab: AppTab) -> some View {
        switch tab {
        case .today:    TodayView(showGoalPlanner: $showGoalPlanner)
        case .tasks:    TasksView()
        case .pomodoro: PomodoroView()
        case .break:    BreakView()
        case .health:   HealthView(showGoalPlanner: $showGoalPlanner)
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

    private func switchTab(to newTab: AppTab) {
        guard newTab != tab else { return }
        scrollPerformance.stop()

        // A tab switch replaces one complete NavigationStack with another. Keeping
        // both trees alive for a cross-fade forces large offscreen render passes,
        // especially when the screens contain glass and charts. Native tab
        // navigation is immediate; the compact tab indicator still animates.
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) {
            tab = newTab
        }
    }

    private func refreshGoalCareNotifications() {
        let roadmap: GoalRoadmap?
        if let raw = UserDefaults.standard.string(forKey: GoalProgressNotificationScheduler.roadmapStorageKey),
           let data = raw.data(using: .utf8) {
            roadmap = try? JSONDecoder().decode(GoalRoadmap.self, from: data)
        } else {
            roadmap = nil
        }

        let now = Date.now
        let isFocusRunning = pomo.phase == .focus
        let focusElapsed = isFocusRunning
            ? max(0, now.timeIntervalSince(pomo.startDate ?? now))
            : 0
        let userState = GoalUserState(rawValue: goalUserStateRaw) ?? .calm
        careCenter.refresh(
            now: now,
            healthSnapshot: healthKit.snapshot,
            healthRecommendation: healthKit.recommendation,
            roadmap: roadmap,
            tasks: store.tasks,
            userState: userState,
            focusElapsed: focusElapsed,
            isFocusRunning: isFocusRunning,
            lang: lang
        )

        let audit = roadmap.flatMap { GoalPlanProgressAudit.make(roadmap: $0, tasks: store.tasks, now: now) }
        let pace = AdaptiveGoalPaceEngine.evaluate(
            health: healthKit.recommendation,
            audit: audit,
            userState: userState
        )
        watchDiscovery.syncCareContext(
            suggestion: careCenter.primarySuggestion,
            nextGoalStep: audit?.nextActiveTask ?? roadmap?.firstActions.first,
            paceTitle: L10n.tr("health.hub.pace.\(pace.level.rawValue)", lang),
            isFocusRunning: isFocusRunning,
            focusMinutes: Int(focusElapsed / 60),
            stepsToday: healthKit.snapshot?.stepsToday.map { Int($0.rounded()) },
            lang: lang
        )
    }

    private func localizedTabTitle(_ tab: AppTab) -> String {
        tab.title(lang: lang)
    }

    private func sanitizeVoiceTaskTitle(_ value: String) -> String {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if trimmed.count <= 120 { return trimmed }
        return String(trimmed.prefix(120))
    }

    private func sanitizeVoiceGoalDescription(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= 240 { return trimmed }
        return String(trimmed.prefix(240))
    }

    private func presentGoalPlannerFromAssistant(
        initialGoal: String? = nil,
        showProgress: Bool = false
    ) {
        assistantGoalDraft = sanitizeVoiceGoalDescription(initialGoal)
        openGoalProgressSummary = showProgress
        showVoiceAssistant = false

        // Let the assistant sheet finish dismissing before presenting the planner.
        // This keeps voice commands reliable when they originate inside the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showGoalPlanner = true
        }
    }

    private func presentCalendarFromAssistant() {
        showVoiceAssistant = false
        switchTab(to: .today)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            showAssistantCalendar = true
        }
    }

    private var hasSavedSmartGoal: Bool {
        guard let value = UserDefaults.standard.string(
            forKey: "goal.planner.lastRoadmap"
        ) else {
            return false
        }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func deepLinkQueryValue(_ name: String, from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?
            .first(where: { $0.name.lowercased() == name.lowercased() })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handlePomodoroDeepLink(_ url: URL) {
        switchTab(to: .pomodoro)

        let action = deepLinkQueryValue("action", from: url)?.lowercased() ?? "open"
        switch action {
        case "pause":
            pomo.pause()
        case "resume":
            pomo.resume()
        case "stop":
            pomo.stop()
        case "start":
            let requestedMinutes = deepLinkQueryValue("minutes", from: url).flatMap(Int.init)
            let minutes = min(max(requestedMinutes ?? pomo.config.focusMinutes, 1), 180)
            pomo.config.focusMinutes = minutes
            pomo.startFocus(customMinutes: minutes)
        case "break", "shortbreak", "short_break":
            pomo.startShortBreak()
        default:
            break
        }
    }

    private func handleTaskDeepLink(_ url: URL) {
        switchTab(to: .tasks)

        let action = deepLinkQueryValue("action", from: url)?.lowercased() ?? "open"
        guard action == "done" || action == "complete" else { return }

        let idString = url.pathComponents.dropFirst().first
        guard let idString, let taskId = UUID(uuidString: idString) else { return }

        if let task = store.tasks.first(where: { $0.id == taskId }), !task.isCompleted {
            store.toggle(taskId, stats: stats)
        }

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            Task { await LiveActivityManager.endTask(taskId) }
        }
        #endif
    }

    private func handleIncomingURL(_ url: URL) {
        let host = url.host?.lowercased() ?? ""

        switch host {
        case "done":
            #if canImport(ActivityKit)
            if #available(iOS 16.2, *) {
                Task {
                    await LiveActivityManager.endAllTasks()
                    await PomodoroLiveManager.endAll()
                    await GoalRoadmapLiveActivityManager.endAll()
                    if #available(iOS 26.0, *) {
                        await EyeBreakLiveActivityManager.endAll()
                    }
                }
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

        case "pomodoro":
            handlePomodoroDeepLink(url)

        case "tasks":
            switchTab(to: .tasks)

        case "health":
            switchTab(to: .health)

        case "break":
            switchTab(to: .break)

        case "eye":
            if #available(iOS 26.0, *) {
                Task { await EyeBreakLiveActivityManager.endAll() }
            }
            let mode = deepLinkQueryValue("mode", from: url)?.lowercased() ?? "camera"
            #if os(iOS)
            let cameraUnavailable = mode == "camera"
                && AVCaptureDevice.authorizationStatus(for: .video) != .authorized
                && deepLinkQueryValue("mode", from: url) != nil
            #else
            let cameraUnavailable = mode == "camera"
            #endif
            if mode == "point" || mode == "tracking" || cameraUnavailable {
                showEyes = false
                showPointEyeExercise = true
            } else {
                showPointEyeExercise = false
                showEyes = true
            }

        case "goals":
            switchTab(to: .today)
            openGoalProgressSummary = deepLinkQueryValue("mode", from: url)?.lowercased() == "progress"
            showGoalPlanner = true

        case "task":
            handleTaskDeepLink(url)

        default:
            break
        }
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard let rawURL = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: rawURL) else { return }
        handleIncomingURL(url)
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

    private func assistantDateText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: lang.localeIdentifier))
        )
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
        var responses: [String] = []
        for intent in command.intents {
            let result = executeAssistantIntent(intent)
            responses.append(result.response)
            voiceAssistant.recordCommandOutcome(
                intent: intent,
                transcript: command.transcript,
                wasSuccessful: result.wasSuccessful,
                lang: lang
            )
        }

        voiceAssistant.completePendingCommand(
            response: responses.joined(separator: " "),
            lang: lang
        )
    }

    private func executeAssistantIntent(
        _ intent: AppVoiceCommandIntent
    ) -> (response: String, wasSuccessful: Bool) {
        switch intent {
        case .addTask(let rawTitle, let category):
            let title = sanitizeVoiceTaskTitle(rawTitle)
            guard !title.isEmpty else {
                return (L10n.tr("assistant.response.unknown", lang), false)
            }
            store.add(TaskItem(title: title, category: category))
            switchTab(to: .tasks)
            return (L10n.fmt("assistant.response.task_added", lang, title), true)

        case .addScheduledTask(let rawTitle, let category, let dueDate):
            let title = sanitizeVoiceTaskTitle(rawTitle)
            guard !title.isEmpty else {
                return (L10n.tr("assistant.response.unknown", lang), false)
            }
            store.add(TaskItem(title: title, dueDate: dueDate, category: category))
            switchTab(to: .tasks)
            return (
                L10n.fmt(
                    "assistant.response.task_scheduled",
                    lang,
                    title,
                    assistantDateText(dueDate)
                ),
                true
            )

        case .completeTask(let requestedTitle):
            if let task = resolveTaskForVoice(title: requestedTitle, includeCompleted: false) {
                store.toggle(task.id, stats: stats)
                switchTab(to: .tasks)
                return (L10n.fmt("assistant.response.task_completed", lang, task.title), true)
            }
            return (L10n.tr("assistant.response.task_not_found", lang), false)

        case .reopenTask(let requestedTitle):
            if let task = resolveTaskForVoice(title: requestedTitle, includeCompleted: true) {
                if task.isCompleted { store.toggle(task.id, stats: stats) }
                switchTab(to: .tasks)
                return (L10n.fmt("assistant.response.task_reopened", lang, task.title), true)
            }
            return (L10n.tr("assistant.response.task_not_found", lang), false)

        case .deleteTask(let requestedTitle):
            if let task = resolveTaskForVoice(title: requestedTitle, includeCompleted: true) {
                store.remove(task.id)
                switchTab(to: .tasks)
                return (L10n.fmt("assistant.response.task_deleted", lang, task.title), true)
            }
            return (L10n.tr("assistant.response.task_not_found", lang), false)

        case .rescheduleTask(let requestedTitle, let dueDate):
            guard var task = resolveTaskForVoice(title: requestedTitle, includeCompleted: false) else {
                return (L10n.tr("assistant.response.task_not_found", lang), false)
            }
            task.dueDate = dueDate
            store.update(task)
            switchTab(to: .tasks)
            return (
                L10n.fmt(
                    "assistant.response.task_rescheduled",
                    lang,
                    task.title,
                    assistantDateText(dueDate)
                ),
                true
            )

        case .openTab(let requestedTab):
            switchTab(to: requestedTab)
            return (L10n.fmt("assistant.response.tab_opened", lang, localizedTabTitle(requestedTab)), true)

        case .openCalendar:
            presentCalendarFromAssistant()
            return (L10n.tr("assistant.response.calendar_opened", lang), true)

        case .startPomodoro(let requestedMinutes):
            let minutes = max(5, min(120, requestedMinutes ?? pomo.config.focusMinutes))
            switchTab(to: .pomodoro)
            pomo.startFocus(customMinutes: minutes)
            return (L10n.fmt("assistant.response.pomodoro_started", lang, minutes), true)

        case .pausePomodoro:
            switchTab(to: .pomodoro)
            pomo.pause()
            return (L10n.tr("assistant.response.pomodoro_paused", lang), true)

        case .resumePomodoro:
            switchTab(to: .pomodoro)
            pomo.resume()
            return (L10n.tr("assistant.response.pomodoro_resumed", lang), true)

        case .startShortBreak:
            switchTab(to: .pomodoro)
            pomo.startShortBreak()
            return (L10n.tr("assistant.response.short_break_started", lang), true)

        case .startLongBreak:
            switchTab(to: .pomodoro)
            pomo.startLongBreak()
            return (L10n.tr("assistant.response.long_break_started", lang), true)

        case .stopPomodoro:
            pomo.stop()
            return (L10n.tr("assistant.response.pomodoro_stopped", lang), true)

        case .openEyeExercise:
            switchTab(to: .eye)
            showEyes = true
            return (L10n.tr("assistant.response.eye_opened", lang), true)

        case .summarizeMetrics(let period):
            return (assistantMetricsSummary(for: period), true)

        case .openSmartGoals:
            presentGoalPlannerFromAssistant()
            return (L10n.tr("assistant.response.smart_goals_opened", lang), true)

        case .createSmartGoal(let description):
            let prepared = sanitizeVoiceGoalDescription(description)
            presentGoalPlannerFromAssistant(initialGoal: prepared)
            if let prepared {
                return (
                    L10n.fmt("assistant.response.smart_goal_prepared", lang, prepared),
                    true
                )
            }
            return (L10n.tr("assistant.response.smart_goal_ready", lang), true)

        case .showSmartGoalProgress:
            if hasSavedSmartGoal {
                presentGoalPlannerFromAssistant(showProgress: true)
                return (L10n.tr("assistant.response.goal_progress_opened", lang), true)
            }
            presentGoalPlannerFromAssistant()
            return (L10n.tr("assistant.response.goal_progress_missing", lang), true)

        case .showCareRecommendation:
            refreshGoalCareNotifications()
            if let suggestion = careCenter.primarySuggestion {
                return ("\(suggestion.title). \(suggestion.body)", true)
            }
            return (L10n.tr("assistant.response.care_balanced", lang), true)

        case .logCareAction(let action):
            guard action == .logWater || action == .logMeal || action == .logMovement else {
                return (L10n.tr("assistant.response.unknown", lang), false)
            }
            careCenter.record(action)
            refreshGoalCareNotifications()
            let key: String
            switch action {
            case .logWater: key = "assistant.response.water_logged"
            case .logMeal: key = "assistant.response.meal_logged"
            case .logMovement: key = "assistant.response.movement_logged"
            default: key = "assistant.response.unknown"
            }
            return (L10n.tr(key, lang), true)

        case .showCapabilities:
            return (L10n.tr("assistant.response.capabilities", lang), true)

        case .clarifyAction(let topic):
            return (L10n.fmt("assistant.response.clarify_action", lang, topic), true)

        case .unknown:
            return (L10n.tr("assistant.response.unknown", lang), false)
        }
    }

    private var bottomToolbarOverlay: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                GlassTabBar(selection: tabSelectionBinding, isInteractionEnabled: true, lang: lang)
                    .padding(.horizontal, 18)
                    .padding(.bottom, max(6, proxy.safeAreaInsets.bottom + 4))
                    .lippiMagicAppear(delay: 0.08, y: 18, scale: 0.97)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            screenView(tab)
                .padding(.top, 6)
                .id(tab.navigationIndex)
            .transaction { tx in
                if scrollPerformance.isScrolling { tx.animation = nil }
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            bottomToolbarOverlay
                .zIndex(10)
        }
        .overlay {
            GeometryReader { proxy in
                let alarmTopSpacing = max(68, proxy.safeAreaInsets.top + 16)

                VStack(spacing: 0) {
                    if pomodoroAlarm.isActive {
                        PomodoroAlarmBanner(
                            title: L10n.tr("pomodoro.alarm.title", lang),
                            subtitle: L10n.fmt("pomodoro.alarm.subtitle", lang, pomodoroAlarm.finishedPhaseTitle),
                            stopTitle: L10n.tr("pomodoro.alarm.stop", lang)
                        ) {
                            pomodoroAlarm.stop()
                        }
                        .padding(.horizontal, 14)
                        .transition(
                            reduceMotion
                            ? .opacity
                            : .move(edge: .top).combined(with: .opacity)
                        )
                        .zIndex(9)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, alarmTopSpacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VoiceAssistantLauncherButton(
                isCollapsed: $isVoiceAssistantCollapsed,
                title: L10n.tr("assistant.title", lang),
                actionTitle: L10n.tr(
                    voiceAssistant.isListening ? "assistant.button.stop" : "assistant.button.start",
                    lang
                ),
                openTitle: L10n.tr("assistant.action.open", lang),
                hideTitle: L10n.tr("assistant.launcher.hide", lang),
                showTitle: L10n.tr("assistant.launcher.show", lang),
                collapsedHint: L10n.tr("assistant.launcher.collapsed_hint", lang),
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
            .padding(.trailing, isVoiceAssistantCollapsed ? 0 : 12)
            .padding(.bottom, 98)
            .lippiMagicAppear(delay: 0.16, y: 12, scale: 0.92)
            .animation(reduceMotion ? nil : DS.motionState, value: isVoiceAssistantCollapsed)
            .zIndex(8)
        }
        .buttonBorderShape(.capsule)
        .tint(selectedTheme.accentColor)

        // Прокидываем выбранный язык по всему приложению.
        .environment(\.lippiLangCode, langCode)
        .environment(\.lippiHasGlobalBackdrop, true)
        .environment(\.lippiIsScrolling, scrollPerformance.isScrolling)
        .environment(\.lippiScrollPerformanceCoordinator, scrollPerformance)
        .lippiPerformanceResponsive()

        .environment(\.locale, Locale(identifier: lang.localeIdentifier))

        .environmentObject(store)
        .environmentObject(stats)
        .environmentObject(pomo)
        .environmentObject(pomodoroCoach)
        .environmentObject(countdown)
        .environmentObject(dailyReminder)
        .environmentObject(scrollPerformance)
        .environmentObject(careCenter)
        .task {
            await healthKit.activateIfEnabled()
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.onResponse = { response in
                DispatchQueue.main.async {
                    handleNotificationResponse(response)
                }
            }
            GoalProgressNotificationScheduler.refresh(lang: lang)
            watchDiscovery.activate()
            refreshGoalCareNotifications()
            pomo.stats = stats
            pomo.configureEyeBreaks(eye.settings)
            if #available(iOS 26.0, *) {
                Task { await EyeBreakLiveActivityManager.removeExpired() }
            }
            if taskCompletionObserver == nil {
                taskCompletionObserver = NotificationCenter.default.addObserver(forName: .taskCompletionChanged, object: nil, queue: .main) { note in
                    guard let id = note.userInfo?["taskId"] as? UUID,
                          let completed = note.userInfo?["completed"] as? Bool else { return }
                    if completed { stats.recordTaskDone(taskId: id) } else { stats.undoTaskDone(taskId: id) }
                }
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
        .fullScreenCover(isPresented: $showEyes) {
            EyeComfortCameraView()
        }
        .fullScreenCover(isPresented: $showPointEyeExercise) {
            CameraFreeEyeExerciseView(autoStart: true)
        }
        .fullScreenCover(isPresented: $showVoiceAssistant) {
            AppVoiceAssistantSheet(assistant: voiceAssistant, lang: lang)
        }
        .sheet(isPresented: $showAssistantCalendar) {
            LippiCalendarView {
                showAssistantCalendar = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    showGoalPlanner = true
                }
            }
            .environmentObject(store)
            .environmentObject(stats)
            .environmentObject(healthKit)
            .environmentObject(careCenter)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGoalPlanner, onDismiss: {
            openGoalProgressSummary = false
            assistantGoalDraft = nil
        }) {
            GoalPlannerView(
                openProgressSummaryOnAppear: openGoalProgressSummary,
                initialGoalText: assistantGoalDraft
            )
                .environmentObject(store)
                .environmentObject(stats)
                .environmentObject(healthKit)
                .environment(\.lippiIsScrolling, scrollPerformance.isScrolling)
                .environment(\.lippiScrollPerformanceCoordinator, scrollPerformance)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .suggestEyeExercise)) { _ in
            showEyes = true
        }
        .onChange(of: eye.settings) { _, settings in
            pomo.configureEyeBreaks(settings)
        }
        .modifier(
            LippiCareLifecycleModifier(
                healthKit: healthKit,
                taskStore: store,
                pomodoro: pomo,
                watch: watchDiscovery,
                userStateRaw: goalUserStateRaw,
                refresh: refreshGoalCareNotifications,
                handleWatchAction: { event in
                    careCenter.record(event.action, at: event.receivedAt)
                    switch event.action {
                    case .openEyes: showEyes = true
                    case .openRecovery: switchTab(to: .break)
                    case .openGoal:
                        switchTab(to: .today)
                        openGoalProgressSummary = true
                        showGoalPlanner = true
                    case .logMeal, .logMovement, .logWater, .none: break
                    }
                    refreshGoalCareNotifications()
                }
            )
        )
        .onChange(of: voiceAssistant.pendingCommand) { _, newValue in
            guard let command = newValue else { return }
            handleAssistantCommand(command)
        }
        .onDisappear {
            scrollPerformance.stop()
            if let taskCompletionObserver {
                NotificationCenter.default.removeObserver(taskCompletionObserver)
                self.taskCompletionObserver = nil
            }
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiHasGlobalBackdrop) private var hasGlobalBackdrop
    @AppStorage(AppTheme.storageKey) private var themeRaw: String = AppTheme.defaultTheme.rawValue
    var renderMode: RenderMode = .auto

    private var performanceMode: Bool { DS.performanceEffectsReduced || reduceTransparency }
    private var increasedContrast: Bool { colorSchemeContrast == .increased }
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

                    if colorScheme == .dark {
                        darkLighting
                    } else {
                        lightLighting
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

    private var darkLighting: some View {
        ZStack {
            RadialGradient(
                colors: [
                    themedGlowA.opacity(increasedContrast ? 0.54 : (performanceMode ? 0.72 : 1.0)),
                    .clear
                ],
                center: UnitPoint(x: 0.08, y: 0.02),
                startRadius: 0,
                endRadius: performanceMode ? 300 : 420
            )

            RadialGradient(
                colors: [
                    themedGlowB.opacity(increasedContrast ? 0.42 : (performanceMode ? 0.62 : 0.88)),
                    .clear
                ],
                center: UnitPoint(x: 0.96, y: 0.72),
                startRadius: 0,
                endRadius: performanceMode ? 310 : 460
            )

            if !performanceMode && !increasedContrast {
                RadialGradient(
                    colors: [themedGlowC.opacity(0.72), .clear],
                    center: UnitPoint(x: 0.20, y: 0.92),
                    startRadius: 0,
                    endRadius: 360
                )
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(increasedContrast ? 0.025 : 0.055),
                    .clear,
                    Color.black.opacity(increasedContrast ? 0.24 : 0.17)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var lightLighting: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(increasedContrast ? 0.74 : 0.90),
                    Color.white.opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    themedGlowA.opacity(increasedContrast ? 0.42 : (performanceMode ? 0.70 : 0.94)),
                    .clear
                ],
                center: UnitPoint(x: 0.02, y: 0.04),
                startRadius: 0,
                endRadius: performanceMode ? 320 : 470
            )

            RadialGradient(
                colors: [
                    themedGlowB.opacity(increasedContrast ? 0.34 : (performanceMode ? 0.52 : 0.72)),
                    .clear
                ],
                center: UnitPoint(x: 1.0, y: 0.62),
                startRadius: 0,
                endRadius: performanceMode ? 330 : 480
            )

            if !performanceMode && !increasedContrast {
                RadialGradient(
                    colors: [themedGlowC.opacity(0.62), .clear],
                    center: UnitPoint(x: 0.32, y: 1.0),
                    startRadius: 0,
                    endRadius: 390
                )
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.24),
                    .clear,
                    DS.depthShadow(increasedContrast ? 0.07 : 0.035)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
                    .frame(minHeight: 44)
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
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            tint: DS.accent.opacity(0.10),
            prominent: true,
            enabled: true
        )
        .shadow(color: DS.shadow.opacity(0.24), radius: 8, x: 0, y: 4)
    }
}


// =======================================================
// MARK: - GlassTabBar (quiet Liquid Glass navigation)
// Compact navigation: three primary destinations and a system overflow menu.
// =======================================================
struct GlassTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @Binding var selection: AppTab
    var isInteractionEnabled: Bool = true
    let lang: AppLang
    @Namespace private var tabSelectionNamespace

    private var simplifiedEffects: Bool { DS.performanceEffectsReduced || reduceTransparency }
    private var usesSystemGlass: Bool {
        if #available(iOS 26.0, *) {
            return !simplifiedEffects && DS.systemGlassEffectsEnabled
        }
        return false
    }

    var body: some View {
        LippiGlassEffectGroup(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(AppTab.primaryTabs, id: \.self) { tab in
                    TabButton(
                        icon: tab.icon,
                        fallback: tab.fallbackIcon,
                        title: tab.title(lang: lang),
                        tab: tab,
                        selection: $selection,
                        namespace: tabSelectionNamespace,
                        isInteractionEnabled: isInteractionEnabled,
                        simplifiedEffects: simplifiedEffects
                    )
                }

                OverflowTabMenu(
                    selection: $selection,
                    namespace: tabSelectionNamespace,
                    isInteractionEnabled: isInteractionEnabled,
                    simplifiedEffects: simplifiedEffects,
                    lang: lang
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(tabBarBackground)
            .overlay(tabBarOverlay)
            .lippiSystemGlass(
                in: tabBarShape,
                prominent: true,
                enabled: !simplifiedEffects
            )
        }
        .shadow(
            color: DS.depthShadow(
                simplifiedEffects ? 0.14 : (usesSystemGlass ? 0.16 : 0.20)
            ),
            radius: simplifiedEffects ? 5 : (usesSystemGlass ? 10 : 8),
            x: 0,
            y: simplifiedEffects ? 3 : 5
        )
        .animation(reduceMotion ? nil : DS.motionTabSwitch, value: selection)
        .accessibilityElement(children: .contain)
    }

    private var tabBarShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        let shape = tabBarShape
        if reduceTransparency {
            shape.fill(DS.solidSurface)
        } else if usesSystemGlass {
            shape
                .fill(DS.navigationSurface)
                .overlay(shape.fill(DS.navigationTint))
        } else if simplifiedEffects {
            shape
                .fill(DS.contentSurface)
                .overlay(
                    shape
                        .fill(DS.glassTint)
                        .opacity(0.20)
                )
                .overlay(
                    shape
                        .fill(DS.glassDepth)
                        .opacity(0.12)
                )
        } else {
            tabBarMaterialBase
                .overlay(
                    shape
                        .fill(DS.navigationSurface)
                )
                .overlay(
                    shape
                        .fill(DS.glassTint)
                        .opacity(0.22)
                )
                .overlay(alignment: .top) {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(
                                        dynamicDark: 0xFFFFFF,
                                        light: 0xFFFFFF,
                                        darkAlpha: 0.28,
                                        lightAlpha: 0.82
                                    ),
                                    Color(
                                        dynamicDark: 0xFFFFFF,
                                        light: 0xFFFFFF,
                                        darkAlpha: 0.08,
                                        lightAlpha: 0.20
                                    ),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 18)
                        .clipShape(shape)
                }
        }
    }

    @ViewBuilder
    private var tabBarMaterialBase: some View {
        let shape = tabBarShape
        if #available(iOS 26.0, *), DS.systemGlassEffectsEnabled {
            // The system glass modifier supplies refraction on iOS 26; stacking
            // a live Material underneath creates a redundant blur pass.
            shape.fill(DS.navigationSurface)
        } else {
            shape.fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var tabBarOverlay: some View {
        let shape = tabBarShape
        if usesSystemGlass {
            shape
                .stroke(
                    DS.stroke,
                    lineWidth: colorSchemeContrast == .increased ? 1.4 : 0.85
                )
        } else if simplifiedEffects {
            shape
                .stroke(
                    DS.stroke,
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1.0
                )
        } else {
            shape
                .stroke(
                    DS.stroke,
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1.0
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(DS.strokeInner, lineWidth: 0.8)
                        .padding(1)
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
    private var usesSystemGlass: Bool {
        if #available(iOS 26.0, *) {
            return !simplifiedEffects && DS.systemGlassEffectsEnabled
        }
        return false
    }

    var body: some View {
        Button {
            guard isInteractionEnabled else { return }
            DS.hapticSoft()
            selection = tab
        } label: {
            HStack(spacing: isSelected ? 5 : 0) {
                Image(safeSystemName: icon, fallback: fallback)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .frame(width: 20, height: 20)
                    .symbolRenderingMode(.hierarchical)
                    .symbolVariant(isSelected ? .fill : .none)
                    .scaleEffect(reduceMotion || simplifiedEffects ? 1 : (isSelected ? 1.04 : 1.0))

                if isSelected {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .singleLine()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                }
            }
            .padding(.horizontal, isSelected ? 10 : 0)
            .frame(width: isSelected ? nil : 40, height: 44)
            .frame(minWidth: isSelected ? 60 : 40, minHeight: 44)
            .background(pillBackground)
            .overlay(pillOverlay)
            .foregroundStyle(isSelected ? DS.accent : DS.text(simplifiedEffects ? 0.72 : 0.80))
            .lippiSystemGlass(
                in: Capsule(style: .continuous),
                tint: isSelected ? DS.accent.opacity(0.22) : DS.accent.opacity(0.10),
                interactive: true,
                enabled: isSelected && !simplifiedEffects
            )
            .scaleEffect(reduceMotion || simplifiedEffects ? 1 : (isSelected ? 1.012 : 0.992))
            .shadow(color: isSelected && !simplifiedEffects ? DS.depthShadow(0.18) : .clear, radius: isSelected ? 6 : 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var pillBackground: some View {
        if usesSystemGlass {
            Capsule()
                .fill(isSelected ? DS.accent.opacity(0.14) : Color.clear)
        } else if simplifiedEffects {
            Capsule()
                .fill(isSelected ? DS.glassFill(0.22, lightOpacity: 0.54) : Color.clear)
        } else {
            Capsule()
                .fill(isSelected ? DS.glassFill(0.28, lightOpacity: 0.68) : Color.clear)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isSelected ? 0.28 : 0.12),
                                    .clear,
                                    DS.depthShadow(isSelected ? 0.10 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    if isSelected {
                        Capsule()
                            .fill(DS.accent.opacity(0.24))
                            .matchedGeometryEffect(id: "selected-tab-pill", in: namespace)
                            .blendMode(.screen)
                    }
                }
        }
    }

    @ViewBuilder
    private var pillOverlay: some View {
        Capsule()
            .strokeBorder(isSelected ? DS.glassStroke(0.34) : Color.clear, lineWidth: 1)
            .overlay(alignment: .top) {
                if isSelected && !simplifiedEffects && !usesSystemGlass {
                    Capsule()
                        .fill(.white.opacity(0.30))
                        .frame(height: 1.2)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }
            }
    }
}

private struct OverflowTabMenu: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: AppTab
    let namespace: Namespace.ID
    let isInteractionEnabled: Bool
    let simplifiedEffects: Bool
    let lang: AppLang

    private var isSelected: Bool { selection.isOverflow }
    private var title: String { L10n.tr("tab.more", lang) }
    private var usesSystemGlass: Bool {
        if #available(iOS 26.0, *) {
            return !simplifiedEffects && DS.systemGlassEffectsEnabled
        }
        return false
    }

    var body: some View {
        Menu {
            ForEach(AppTab.overflowTabs, id: \.self) { tab in
                Button {
                    guard isInteractionEnabled else { return }
                    DS.hapticSoft()
                    selection = tab
                } label: {
                    Label(tab.title(lang: lang), systemImage: tab.icon)
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(safeSystemName: "ellipsis", fallback: "ellipsis")
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .frame(width: 20, height: 20)
                    .symbolRenderingMode(.hierarchical)

                if isSelected {
                    Circle()
                        .fill(DS.accent)
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 40, height: 44)
            .background(menuBackground)
            .overlay(menuOverlay)
            .foregroundStyle(isSelected ? DS.accent : DS.text(simplifiedEffects ? 0.72 : 0.80))
            .lippiSystemGlass(
                in: Capsule(style: .continuous),
                tint: isSelected ? DS.accent.opacity(0.22) : DS.accent.opacity(0.10),
                interactive: true,
                enabled: isSelected && !simplifiedEffects
            )
            .scaleEffect(reduceMotion || simplifiedEffects ? 1 : (isSelected ? 1.012 : 0.992))
            .shadow(color: isSelected && !simplifiedEffects ? DS.depthShadow(0.18) : .clear, radius: isSelected ? 6 : 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled)
        .accessibilityLabel(Text(isSelected ? "\(title): \(selection.title(lang: lang))" : title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var menuBackground: some View {
        if usesSystemGlass {
            Capsule()
                .fill(isSelected ? DS.accent.opacity(0.14) : Color.clear)
        } else if simplifiedEffects {
            Capsule()
                .fill(isSelected ? DS.glassFill(0.22, lightOpacity: 0.54) : Color.clear)
        } else {
            Capsule()
                .fill(isSelected ? DS.glassFill(0.28, lightOpacity: 0.68) : Color.clear)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isSelected ? 0.28 : 0.12),
                                    .clear,
                                    DS.depthShadow(isSelected ? 0.10 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    if isSelected {
                        Capsule()
                            .fill(DS.accent.opacity(0.24))
                            .matchedGeometryEffect(id: "selected-tab-pill", in: namespace)
                            .blendMode(.screen)
                    }
                }
        }
    }

    @ViewBuilder
    private var menuOverlay: some View {
        Capsule()
            .strokeBorder(isSelected ? DS.glassStroke(0.34) : Color.clear, lineWidth: 1)
            .overlay(alignment: .top) {
                if isSelected && !simplifiedEffects && !usesSystemGlass {
                    Capsule()
                        .fill(.white.opacity(0.30))
                        .frame(height: 1.2)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }
            }
    }
}

// MARK: - App Entry
// =======================================================
@main
struct LippiSingleApp: App {
    @StateObject private var eyeStore = EyeExerciseStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var healthKit = HealthKitManager.shared

    init() {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            // Standard bars receive Liquid Glass from the system.
        } else {
            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            nav.backgroundColor = .clear
            nav.shadowColor = .clear
            UINavigationBar.appearance().standardAppearance   = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactAppearance    = nav
        }

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
                .environmentObject(healthKit)
        }
    }
}
