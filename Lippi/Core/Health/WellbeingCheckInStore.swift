import Foundation
import SwiftUI

struct WellbeingCheckIn: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var recordedAt: Date = .now
    var state: GoalUserState
}

@MainActor
final class WellbeingCheckInStore: ObservableObject {
    static let storageKey = "health.wellbeing.checkins"

    @Published private(set) var entries: [WellbeingCheckIn] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let maximumStoredEntries = 60

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        restore()
    }

    func record(_ state: GoalUserState, at date: Date = .now) {
        entries.removeAll { calendar.isDate($0.recordedAt, inSameDayAs: date) }
        entries.append(WellbeingCheckIn(recordedAt: date, state: state))
        entries = Array(entries.sorted { $0.recordedAt > $1.recordedAt }.prefix(maximumStoredEntries))
        persist()
    }

    func entry(on date: Date) -> WellbeingCheckIn? {
        entries.first { calendar.isDate($0.recordedAt, inSameDayAs: date) }
    }

    func datesForRecentWeek(reference: Date = .now) -> [Date] {
        let start = calendar.startOfDay(for: reference)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: start)
        }
    }

    private func restore() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([WellbeingCheckIn].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded.sorted { $0.recordedAt > $1.recordedAt }.prefix(maximumStoredEntries))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
