//
//  TaskStore.swift
//  Organizer
//
//  Created by Oleg on 07.09.2025.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Task Model
struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var category: TaskCategory

    init(id: UUID = UUID(),
         title: String,
         notes: String = "",
         isCompleted: Bool = false,
         createdAt: Date = Date(),
         dueDate: Date? = nil,
         category: TaskCategory = .other) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.category = category
    }
}

// MARK: - Categories
enum TaskCategory: String, CaseIterable, Codable, Identifiable {
    case work, personal, study, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .work:     return "Работа"
        case .personal: return "Личное"
        case .study:    return "Учёба"
        case .other:    return "Другое"
        }
    }

    var symbol: String {
        switch self {
        case .work:     return "briefcase.fill"
        case .personal: return "person.fill"
        case .study:    return "book.fill"
        case .other:    return "square.and.pencil"
        }
    }
}

// MARK: - Store
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []

    // локальное хранение
    private let storageKey = "tasks"

    // 🔒 App Group — ДОЛЖНА совпадать с тем, что включено в обоих таргетах (App и Widget) в Signing & Capabilities → App Groups
    private enum WG {
        static let suiteID  = "group.illumionix.lippi"   // ← единая точка правды
        static let titleKey = "nextTaskTitle"
        static let dueKey   = "nextTaskDue"
    }

    // App Group для обмена с виджетом
    private var widgetDefaults: UserDefaults? { UserDefaults(suiteName: WG.suiteID) }

    // дебаунс для перезагрузки таймлайнов виджета
    private var widgetReloadWorkItem: DispatchWorkItem?

    init() {
        load()

        // Диагностика доступности App Group
        if widgetDefaults == nil {
            print("❌ [TaskStore] App Group '\(WG.suiteID)' недоступна. Проверь App Groups у App-таргета.")
        } else {
            print("✅ [TaskStore] App Group '\(WG.suiteID)' доступна.")
        }

        // при старте сразу пробрасываем текущую «ближайшую задачу»
        updateWidgetWithNextTask()
    }

    // MARK: CRUD
    func add(_ item: TaskItem) {
        tasks.append(item)
        save()
        updateWidgetWithNextTask()
    }

    func update(_ item: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == item.id }) {
            tasks[i] = item
            save()
            updateWidgetWithNextTask()
        }
    }

    func remove(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
        updateWidgetWithNextTask()
    }

    func clearAll() {
        tasks.removeAll()
        save()
        updateWidgetWithNextTask()
    }

    func toggle(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isCompleted.toggle()
        save()
        updateWidgetWithNextTask()
    }

    /// Ближайшая невыполненная задача (без срока уходит в конец)
    func upcoming() -> TaskItem? {
        tasks
            .filter { !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .first
    }

    // MARK: Persistence (локально в UserDefaults)
    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
    }

    // MARK: Widget sync via App Group
    private func updateWidgetWithNextTask() {
        if let next = upcoming() {
            writeNextTaskToAppGroup(title: next.title, due: next.dueDate)
        } else {
            // не пишем "Нет задач" — виджет сам покажет плейсхолдер
            writeNextTaskToAppGroup(title: nil, due: nil)
        }
        debounceWidgetReload()
    }

    /// Публичный пинок — удобно вызывать из onAppear любого экрана.
    func syncWidgetNow() {
        updateWidgetWithNextTask()
    }

    /// Запись данных для виджета в App Group
    private func writeNextTaskToAppGroup(title: String?, due: Date?) {
        guard let defaults = widgetDefaults else {
            print("❌ [TaskStore] Не удалось записать в App Group '\(WG.suiteID)' — UserDefaults(suiteName:) == nil")
            return
        }

        // title
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = trimmed, !t.isEmpty {
            defaults.set(t, forKey: WG.titleKey)
        } else {
            defaults.removeObject(forKey: WG.titleKey)
        }

        // due
        if let due {
            defaults.set(due.timeIntervalSince1970, forKey: WG.dueKey)
        } else {
            defaults.removeObject(forKey: WG.dueKey)
        }

        defaults.synchronize()

        #if DEBUG
        let dbgTitle = defaults.string(forKey: WG.titleKey) ?? "—"
        let dbgDue = defaults.object(forKey: WG.dueKey) as? Double
        let dueString = dbgDue != nil ? Date(timeIntervalSince1970: dbgDue!).description : "nil"
        print("📤 [TaskStore] → Widget AppGroup write: title='\(dbgTitle)', due=\(dueString)")
        #endif
    }

    /// Мягкий дебаунс перезагрузки таймлайнов, чтобы не спамить WidgetKit
    private func debounceWidgetReload() {
        widgetReloadWorkItem?.cancel()
        let work = DispatchWorkItem {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            #if DEBUG
            print("🔁 [TaskStore] WidgetCenter.reloadAllTimelines()")
            #endif
        }
        widgetReloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
