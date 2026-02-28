// AlarmFeature.swift
import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Alarm Config
// =======================================================
struct AlarmConfig: Codable, Hashable {
    var enabled: Bool = false

    /// Подпись к будильнику (что будет в body)
    var label: String = L10n.trCurrent("alarm.default_label")

    /// Время будильника
    var hour: Int = 8
    var minute: Int = 0

    /// За сколько минут заранее прислать «готовиться»
    var preparationMinutes: Int = 15
}

// =======================================================
// MARK: - Alarm Store
// =======================================================
final class AlarmStore: ObservableObject {
    @Published var config: AlarmConfig { didSet { save(); reschedule() } }

    // Хранилище
    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        .first!.appendingPathComponent("alarm_config.json")

    // IDs уведомлений
    private let idMain = "alarm-main"
    private let idPrep = "alarm-prep"

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let cfg = try? JSONDecoder().decode(AlarmConfig.self, from: data) {
            self.config = cfg
        } else {
            self.config = AlarmConfig()
        }

        // При старте проекта — пересоздать уведомления
        DispatchQueue.main.async { self.reschedule() }
    }

    func reschedule() {
        // снимаем старые
        NotificationManager.shared.cancel(ids: [idMain, idPrep])

        guard config.enabled else { return }

        let h = clamp(config.hour, 0, 23)
        let m = clamp(config.minute, 0, 59)

        // Основной будильник
        NotificationManager.shared.scheduleDaily(
            id: idMain,
            title: L10n.trCurrent("alarm.notification.main_title"),
            body: config.label.isEmpty ? L10n.trCurrent("alarm.default_label") : config.label,
            hour: h,
            minute: m
        )

        // Подготовка заранее
        let prep = max(0, config.preparationMinutes)
        if prep > 0 {
            let totalMin = h * 60 + m
            let prepTotal = (totalMin - prep + 24 * 60) % (24 * 60)
            let prepHour = prepTotal / 60
            let prepMinute = prepTotal % 60

            NotificationManager.shared.scheduleDaily(
                id: idPrep,
                title: L10n.trCurrent("alarm.notification.prep_title"),
                body: L10n.fmtCurrent("alarm.notification.prep_body", prep, config.label.isEmpty ? L10n.trCurrent("alarm.default_label") : config.label),
                hour: prepHour,
                minute: prepMinute
            )
        }
    }

    func testFire(in seconds: TimeInterval = 3) {
        NotificationManager.shared.scheduleAfterSeconds(
            id: "alarm-test-\(UUID().uuidString)",
            title: L10n.trCurrent("alarm.notification.test_title"),
            body: L10n.trCurrent("alarm.notification.test_body"),
            seconds: seconds
        )
    }

    func setTime(from date: Date) {
        let cal = Calendar.current
        config.hour = cal.component(.hour, from: date)
        config.minute = cal.component(.minute, from: date)
    }

    func timeAsDate() -> Date {
        let cal = Calendar.current
        let comps = DateComponents(hour: clamp(config.hour, 0, 23),
                                   minute: clamp(config.minute, 0, 59))
        return cal.date(from: comps) ?? Date()
    }

    private func save() {
        do { try JSONEncoder().encode(config).write(to: fileURL, options: .atomic) } catch { }
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
}

// =======================================================
// MARK: - Alarm UI Section (вставляешь в SettingsView)
// =======================================================
struct AlarmSettingsSection: View {
    @EnvironmentObject private var alarm: AlarmStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            alarmToggleRow(s("alarm.settings.toggle"), isOn: Binding(
                get: { alarm.config.enabled },
                set: { alarm.config.enabled = $0 }
            ))

            TextField(s("alarm.settings.label_placeholder"), text: Binding(
                get: { alarm.config.label },
                set: { alarm.config.label = $0 }
            ))
            .alarmFieldGlass()

            alarmLabeledGlass(s("alarm.settings.time")) {
                DatePicker(
                    "",
                    selection: Binding<Date>(
                        get: { alarm.timeAsDate() },
                        set: { alarm.setTime(from: $0) }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
            }

            alarmLabeledGlass(L10n.fmt("alarm.settings.prep", lang, alarm.config.preparationMinutes)) {
                Stepper("", value: Binding(
                    get: { alarm.config.preparationMinutes },
                    set: { alarm.config.preparationMinutes = max(0, min(240, $0)) }
                ), in: 0...240, step: 5)
                .labelsHidden()
            }

            HStack(spacing: 10) {
                Button {
                    alarm.reschedule()
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                } label: {
                    Label(s("alarm.settings.save"), systemImage: "alarm")
                        .labelStyle(TightLabelStyle())
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))

                Button { alarm.testFire(in: 3) } label: {
                    Label(s("alarm.settings.test"), systemImage: "paperplane.fill")
                        .labelStyle(TightLabelStyle())
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary))
            }

            Text(s("alarm.settings.info"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // --- локальные стеклянные строки (чтобы файл был автономным и без конфликтов) ---
    @ViewBuilder
    private func alarmToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
    }

    @ViewBuilder
    private func alarmLabeledGlass(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline)
            HStack { content() }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12)))
        }
        .padding(.horizontal, 4)
    }
}

// =======================================================
// MARK: - Glass field helper (чтобы не конфликтовать с твоим fieldGlass())
// =======================================================
private extension View {
    func alarmFieldGlass() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
    }
}
