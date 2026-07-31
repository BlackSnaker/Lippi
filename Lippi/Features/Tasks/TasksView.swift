import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - TASKS (dark Apple-style backdrop, fixed)
// =======================================================
struct TasksView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var stats: StatsStore
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var editing: TaskItem?
    @State private var query = ""
    @State private var showAdd = false
    @State private var sortByDate = true

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    // Тёмный эпловский фон
    private var tasksBackdrop: some View {
        AppBackdrop()
    }

    // MARK: - Filtering / sorting
    private var partitionedItems: (active: [TaskItem], done: [TaskItem]) {
        var filtered: [TaskItem]

        if query.isEmpty {
            filtered = store.tasks
        } else {
            filtered = store.tasks.filter { t in
                t.title.localizedCaseInsensitiveContains(query) ||
                t.notes.localizedCaseInsensitiveContains(query)
            }
        }

        if sortByDate {
            filtered.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        } else {
            filtered.sort { $0.createdAt > $1.createdAt }
        }

        let active = filtered.filter { !$0.isCompleted }
        let done = filtered.filter { $0.isCompleted }
        return (active, done)
    }

    var body: some View {
        let partition = partitionedItems
        let activeItems = partition.active
        let doneItems = partition.done
        let activeCount = activeItems.count
        let doneCount = doneItems.count
        let overdueCount = activeItems.filter { item in
            guard let due = item.dueDate else { return false }
            return due < .now
        }.count
        let dueTodayCount = activeItems.filter { item in
            guard let due = item.dueDate else { return false }
            return Calendar.current.isDateInToday(due) && due >= .now
        }.count

        NavigationStack {
            ZStack {
                tasksBackdrop

                List {
                    Section {
                        taskOverview(
                            activeCount: activeCount,
                            doneCount: doneCount,
                            overdueCount: overdueCount,
                            dueTodayCount: dueTodayCount
                        )
                            .lippiMotionScene(0)
                            .listRowInsets(.init(top: 8, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    if activeItems.isEmpty && doneItems.isEmpty {
                        emptyState
                            .lippiMotionScene(1)
                            .listRowInsets(.init(top: 18, leading: 16, bottom: 18, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        if !activeItems.isEmpty {
                            Section {
                                ForEach(activeItems) { item in
                                    row(item)
                                }
                            } header: {
                                sectionHeader(title: s("tasks.section_active"), count: activeItems.count, systemImage: "circle")
                            }
                        }

                        if !doneItems.isEmpty {
                            Section {
                                ForEach(doneItems) { item in
                                    row(item)
                                }
                            } header: {
                                sectionHeader(title: s("tasks.section_done"), count: doneItems.count, systemImage: "checkmark.circle.fill")
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 88)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .lippiScrollPerformance()
            }
            .navigationTitle(s("tasks.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .clearNavBarBackgroundIfAvailable()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(safeSystemName: "plus.circle.fill", fallback: "plus")
                    }
                    .accessibilityLabel(s("today.toolbar.new_task"))
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: s("tasks.search_prompt")
            )
            .sheet(isPresented: $showAdd) {
                AddEditTaskView { store.add($0) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editing) { item in
                AddEditTaskView(item: item) { store.update($0) }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Pieces

    private func taskOverview(
        activeCount: Int,
        doneCount: Int,
        overdueCount: Int,
        dueTodayCount: Int
    ) -> some View {
        GlassCard(padding: 16, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(s("tasks.overview.title"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DS.textPrimary)

                        Label(
                            overviewStatus(overdueCount: overdueCount, dueTodayCount: dueTodayCount),
                            systemImage: overdueCount > 0 ? "exclamationmark.circle.fill" : "checkmark.seal.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .foregroundStyle(overdueCount > 0 ? Color(hex: 0xFF453A) : DS.textSecondary)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Menu {
                        Picker(s("tasks.sort.label"), selection: $sortByDate) {
                            Text(s("tasks.sort.by_due")).tag(true)
                            Text(s("tasks.sort.by_date")).tag(false)
                        }
                    } label: {
                        Image(safeSystemName: "arrow.up.arrow.down.circle.fill", fallback: "arrow.up.arrow.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DS.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DS.glassFill(0.10), in: Circle())
                            .lippiSystemGlass(in: Circle(), tint: DS.accent.opacity(0.10), interactive: true)
                            .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
                    }
                    .accessibilityLabel(s("tasks.sort.label"))
                }

                HStack(spacing: 8) {
                    overviewMetric(value: activeCount, title: s("tasks.overview.active"), symbol: "circle", tone: DS.accent)
                    overviewMetric(value: overdueCount + dueTodayCount, title: s("tasks.overview.due"), symbol: "calendar", tone: overdueCount > 0 ? Color(hex: 0xFF453A) : Color(hex: 0xFF9F0A))
                    overviewMetric(value: doneCount, title: s("tasks.overview.done"), symbol: "checkmark.circle.fill", tone: Color(hex: 0x30D158))
                }
            }
        }
    }

    private func overviewMetric(value: Int, title: String, symbol: String, tone: Color) -> some View {
        HStack(spacing: 7) {
            Image(safeSystemName: symbol, fallback: "circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(tone)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewStatus(overdueCount: Int, dueTodayCount: Int) -> String {
        if overdueCount > 0 {
            return L10n.fmt("tasks.overview.overdue", lang, overdueCount)
        }
        if dueTodayCount > 0 {
            return L10n.fmt("tasks.overview.today", lang, dueTodayCount)
        }
        return s("tasks.overview.clear")
    }

    private func sectionHeader(title: String, count: Int, systemImage: String) -> some View {
        HStack(spacing: 8) {
                Image(safeSystemName: systemImage, fallback: systemImage)
                    .foregroundStyle(title == s("tasks.section_done") ? Color(hex: 0x30D158) : DS.accent)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textSecondary)
        }
        .textCase(nil)
        .padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(safeSystemName: "sparkles", fallback: "star")
                    .imageScale(.large)
                    .foregroundStyle(DS.text(0.9))
                Text(s("tasks.empty.title"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.text(0.95))
            }

            Text(s("tasks.empty.subtitle"))
                .font(.footnote)
                .foregroundStyle(DS.text(0.75))

            Button { showAdd = true } label: {
                Label(s("tasks.empty.button"), systemImage: "plus")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(DS.glassTint)
                        .opacity(0.30)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DS.stroke, lineWidth: 1)
                )
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            tint: DS.accent.opacity(0.10)
        )
        .shadow(color: DS.depthShadow(0.14), radius: 6, x: 0, y: 3)
    }

    private func row(_ item: TaskItem) -> some View {
        TaskRow(
            item: item,
            onToggle: {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    store.toggle(item.id)
                }
            },
            onEdit: { editing = item }
        )
        .equatable()
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    store.remove(item.id)
                }
            } label: {
                Label(s("tasks.swipe.delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    store.toggle(item.id)
                }
            } label: {
                Label(item.isCompleted ? s("tasks.swipe.restore") : s("tasks.swipe.done"),
                      systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
        .contextMenu {
            Button {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    store.toggle(item.id)
                }
            } label: {
                Label(
                    item.isCompleted ? s("tasks.menu.make_active") : s("tasks.menu.mark_done"),
                    systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }
            Button { editing = item } label: {
                Label(s("tasks.menu.edit"), systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
                withAnimation(reduceMotion ? nil : DS.motionState) {
                    store.remove(item.id)
                }
            } label: {
                Label(s("tasks.menu.delete"), systemImage: "trash")
            }
        }
    }
}


// =======================================================
// MARK: - Task Row
// =======================================================
struct TaskRow: View, Equatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: TaskItem
    var onToggle: () -> Void
    var onEdit: () -> Void
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    static func == (lhs: TaskRow, rhs: TaskRow) -> Bool {
        lhs.item == rhs.item
    }

    private var dueTone: Color {
        guard let due = item.dueDate, !item.isCompleted else { return categoryTone }
        if due < .now { return Color(hex: 0xFF453A) }
        if Calendar.current.isDateInToday(due) { return Color(hex: 0xFF9F0A) }
        return categoryTone
    }

    private var categoryTone: Color {
        item.category == .other ? DS.textSecondary : item.category.tint
    }

    private var dueChip: some View {
        Group {
            if let due = item.dueDate {
                Label(dueText(due), systemImage: "clock")
                    .font(.caption2.weight(.semibold))
                    .labelStyle(TightLabelStyle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(dueTone.opacity(item.isCompleted ? 0.06 : 0.12), in: Capsule())
                    .lippiSystemGlass(
                        in: Capsule(),
                        tint: dueTone.opacity(0.10)
                    )
                    .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                    .foregroundStyle(item.isCompleted ? DS.text(0.45) : dueTone)
            }
        }
    }

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 20, style: .lightweight) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(
                        safeSystemName: item.isCompleted ? "checkmark.circle.fill" : "circle",
                        fallback:       item.isCompleted ? "checkmark.circle"      : "circle"
                    )
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(item.isCompleted ? Color(hex: 0x30D158) : DS.textSecondary)
                    .frame(width: 44, height: 44)
                    .scaleEffect(reduceMotion ? 1 : (item.isCompleted ? 1.08 : 1.0))
                    .rotationEffect(.degrees(reduceMotion ? 0 : (item.isCompleted ? -4 : 0)))
                    .animation(reduceMotion ? nil : DS.motionState, value: item.isCompleted)
                    .background(categoryTone.opacity(item.isCompleted ? 0.10 : 0.14), in: Circle())
                    .lippiSystemGlass(
                        in: Circle(),
                        tint: categoryTone.opacity(0.10),
                        interactive: true
                    )
                    .overlay(Circle().stroke(DS.glassStroke(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(
                    item.isCompleted ? s("tasks.menu.make_active") : s("tasks.menu.mark_done")
                )

                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(item.isCompleted ? DS.textSecondary : DS.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .strikethrough(item.isCompleted, color: DS.textTertiary)

                        if !item.notes.isEmpty {
                            Text(item.notes)
                                .font(.caption)
                                .foregroundStyle(item.isCompleted ? DS.textTertiary.opacity(0.72) : DS.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        HStack(spacing: 8) {
                            Label(item.category.title, systemImage: item.category.symbol)
                                .font(.caption2.weight(.semibold))
                                .labelStyle(TightLabelStyle())
                                .foregroundStyle(item.isCompleted ? DS.textTertiary : categoryTone)

                            Spacer(minLength: 0)

                            dueChip

                            Image(safeSystemName: "chevron.right", fallback: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DS.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .opacity(item.isCompleted ? 0.72 : 1)
        .animation(reduceMotion ? nil : DS.motionState, value: item.isCompleted)
    }

    // MARK: - Helpers

    private func dueText(_ due: Date) -> String {
        // “Сегодня / Завтра” — очень по-эпловски, остальное — лаконично
        let cal = Calendar.current
        if cal.isDateInToday(due) {
            return L10n.fmt("tasks.due.today", lang, due.formatted(.dateTime.hour().minute()))
        }
        if cal.isDateInTomorrow(due) {
            return L10n.fmt("tasks.due.tomorrow", lang, due.formatted(.dateTime.hour().minute()))
        }
        // Пример: “15 янв, 14:30”
        let locale = Locale(identifier: lang == .ru ? "ru_RU" : "en_US")
        return due.formatted(.dateTime.locale(locale).day().month(.abbreviated).hour().minute())
    }
}

// =======================================================
