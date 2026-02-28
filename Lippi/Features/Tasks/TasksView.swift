import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - TASKS (dark Apple-style backdrop, fixed)
// =======================================================
struct TasksView: View {
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

        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // ✅ Фон внутри NavigationStack (иначе системный фон может перекрыть градиент)
                tasksBackdrop

                List {
                    // Верхняя “стеклянная” панель управления
                    Section {
                        controlPanel(activeCount: activeCount, doneCount: doneCount)
                            .listRowInsets(.init(top: 10, leading: 16, bottom: 10, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    // Контент
                    if activeItems.isEmpty && doneItems.isEmpty {
                        emptyState
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

                    // ✅ Нижний воздух, чтобы последнее не пряталось под TabBar
                    Color.clear
                        .frame(height: 84)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .transaction { $0.animation = nil }

                // FAB — удобно большим пальцем
                Button { showAdd = true } label: {
                    Image(safeSystemName: "plus", fallback: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DS.text())
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(DS.glassFill(0.12))
                                .overlay(Circle().stroke(DS.glassStroke(0.18), lineWidth: 1))
                        )
                        .shadow(radius: 16)
                }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
            .navigationTitle(s("tasks.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                // Оставляем аккуратный тулбар — но основная панель управления уже в списке
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(safeSystemName: "plus.circle.fill", fallback: "plus")
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
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

    private func controlPanel(activeCount: Int, doneCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                LippiSectionHeader(
                    title: s("tasks.control.summary"),
                    subtitle: s("tasks.control.subtitle"),
                    icon: "tray.full.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                Spacer()

                // Мини-статус
                HStack(spacing: 8) {
                    badge(text: L10n.fmt("tasks.badge.active", lang, activeCount), systemImage: "circle")
                    badge(text: L10n.fmt("tasks.badge.done", lang, doneCount), systemImage: "checkmark.circle.fill")
                }
                .padding(.top, 2)
            }

            Text(s("tasks.info.subtitle"))
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.textTertiary)
                .singleLine()

            HStack(spacing: 10) {
                Picker("", selection: $sortByDate) {
                    Text(s("tasks.sort.by_due")).tag(true)
                    Text(s("tasks.sort.by_date")).tag(false)
                }
                .pickerStyle(.segmented)

                Button {
                    query = ""
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                } label: {
                    Image(safeSystemName: "xmark.circle.fill", fallback: "xmark")
                        .foregroundStyle(DS.text(query.isEmpty ? 0.25 : 0.85))
                        .imageScale(.large)
                }
                .disabled(query.isEmpty)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DS.glassTint)
                        .opacity(0.30)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DS.stroke, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(DS.cardTopLine)
                        .frame(width: 84, height: 1.3)
                        .padding(.top, 10)
                        .padding(.leading, 14)
                }
        )
    }

    private func badge(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .labelStyle(TightLabelStyle())
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DS.glassFill(0.10), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.16), lineWidth: 1))
            .foregroundStyle(DS.text(0.9))
    }

    private func sectionHeader(title: String, count: Int, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(safeSystemName: systemImage, fallback: systemImage)
                    .foregroundStyle(DS.text(0.85))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.9))

                Spacer()

                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DS.glassFill(0.10), in: Capsule())
                    .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
            }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [DS.accent.opacity(0.42), DS.accent.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .textCase(nil)
        .padding(.top, 6)
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
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(DS.cardTopLine)
                        .frame(width: 92, height: 1.3)
                        .padding(.top, 10)
                        .padding(.leading, 14)
                }
        )
    }

    private func row(_ item: TaskItem) -> some View {
        TaskRow(
            item: item,
            onToggle: { store.toggle(item.id) },
            onEdit: { editing = item }
        )
        .equatable()
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { store.remove(item.id) } label: {
                Label(s("tasks.swipe.delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { store.toggle(item.id) } label: {
                Label(item.isCompleted ? s("tasks.swipe.restore") : s("tasks.swipe.done"),
                      systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
        .contextMenu {
            Button { store.toggle(item.id) } label: {
                Label(
                    item.isCompleted ? s("tasks.menu.make_active") : s("tasks.menu.mark_done"),
                    systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }
            Button { editing = item } label: {
                Label(s("tasks.menu.edit"), systemImage: "square.and.pencil")
            }
            Button(role: .destructive) { store.remove(item.id) } label: {
                Label(s("tasks.menu.delete"), systemImage: "trash")
            }
        }
    }
}


// =======================================================
// MARK: - Task Row
// =======================================================
struct TaskRow: View, Equatable {
    let item: TaskItem
    var onToggle: () -> Void
    var onEdit: () -> Void
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    static func == (lhs: TaskRow, rhs: TaskRow) -> Bool {
        lhs.item == rhs.item
    }

    private var checkIconStyle: AnyShapeStyle {
        item.isCompleted ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.text(0.55))
    }

    private var titleStyle: AnyShapeStyle {
        item.isCompleted ? AnyShapeStyle(DS.text(0.55)) : AnyShapeStyle(DS.text(0.95))
    }

    private var notesStyle: AnyShapeStyle {
        AnyShapeStyle(DS.text(item.isCompleted ? 0.35 : 0.65))
    }

    private var chipFillColor: Color {
        DS.glassFill(item.isCompleted ? 0.06 : 0.10)
    }

    private var miniCardFillColor: Color {
        DS.glassFill(item.isCompleted ? 0.05 : 0.09)
    }

    private var dueChip: some View {
        Group {
            if let due = item.dueDate {
                Label(dueText(due), systemImage: "clock")
                    .font(.caption2.weight(.semibold))
                    .labelStyle(TightLabelStyle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(chipFillColor, in: Capsule())
                    .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                    .foregroundStyle(DS.text(item.isCompleted ? 0.45 : 0.80))
            }
        }
    }

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 18, style: .flat) {
            HStack(spacing: 12) {

                // ✅ Большой удобный чек “в стекле”
                Button(action: onToggle) {
                    Image(
                        safeSystemName: item.isCompleted ? "checkmark.circle.fill" : "circle",
                        fallback:       item.isCompleted ? "checkmark.circle"      : "circle"
                    )
                    .imageScale(.large)
                    .foregroundStyle(checkIconStyle)
                    .frame(width: 36, height: 36)
                    .background(miniCardFillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                VStack(alignment: .leading, spacing: 8) {
                    // Заголовок + срок в одной строке (чисто, без перегруза)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(titleStyle)
                            .lineLimit(1)
                            .strikethrough(item.isCompleted, color: DS.text(0.45))

                        Spacer(minLength: 0)

                        dueChip
                    }

                    if !item.notes.isEmpty {
                        Text(item.notes)
                            .font(.caption)
                            .foregroundStyle(notesStyle)
                            .lineLimit(2)
                    }

                    // Категория — как аккуратный чип
                    Label(item.category.title, systemImage: item.category.symbol)
                        .font(.caption2.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(chipFillColor, in: Capsule())
                        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                        .foregroundStyle(DS.text(item.isCompleted ? 0.45 : 0.85))
                }

                // Справа — “редактировать” в стекле
                Button(action: onEdit) {
                    Image(safeSystemName: "pencil", fallback: "square.and.pencil")
                        .foregroundStyle(DS.text(0.9))
                        .frame(width: 34, height: 34)
                        .background(miniCardFillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.glassStroke(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .transaction { $0.animation = nil }
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
        return due.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

// =======================================================
