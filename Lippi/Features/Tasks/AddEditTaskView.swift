import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Add / Edit Task (Glass sections, dark Apple backdrop)
// =======================================================
struct AddEditTaskView: View {
    var item: TaskItem?
    var onSave: (TaskItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var category: TaskCategory = .other

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    // Тёмный эпловский фон
    private var addBackdrop: some View {
        AppBackdrop(renderMode: .force)
    }

    init(item: TaskItem? = nil, onSave: @escaping (TaskItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _notes = State(initialValue: item?.notes ?? "")
        if let d = item?.dueDate {
            _hasDueDate = State(initialValue: true)
            _dueDate = State(initialValue: d)
        }
        _category = State(initialValue: item?.category ?? .other)
    }

    private var isEditing: Bool { item != nil }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ Фон внутри NavigationStack — не пропадает
                addBackdrop

                ScrollView {
                    VStack(spacing: 16) {
                        heroHeader

                        // ---------- Основное ----------
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LippiSectionHeader(
                                    title: s("task_editor.main.title"),
                                    subtitle: s("task_editor.main.subtitle"),
                                    icon: "textformat",
                                    accent: Color(hex: 0x64D2FF)
                                )

                                fieldRow(
                                    icon: "textformat",
                                    title: s("task_editor.main.name"),
                                    content: {
                                        TextField(s("task_editor.main.name_placeholder"), text: $title)
                                            .textFieldStyle(.plain)
                                            .foregroundStyle(DS.text(0.95))
                                            .singleLine()
                                    }
                                )

                                notesEditor
                            }
                        }

                        // ---------- Срок ----------
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LippiSectionHeader(
                                    title: s("task_editor.due.title"),
                                    subtitle: s("task_editor.due.subtitle"),
                                    icon: "calendar",
                                    accent: Color(hex: 0x30D158)
                                )

                                toggleRow(
                                    icon: "calendar",
                                    title: s("task_editor.due.toggle"),
                                    isOn: $hasDueDate
                                )

                                if hasDueDate {
                                    HStack(spacing: 12) {
                                        Image(safeSystemName: "clock", fallback: "clock")
                                            .foregroundStyle(DS.text(0.7))
                                            .frame(width: 22)

                                        DatePicker(
                                            "",
                                            selection: $dueDate,
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                        .labelsHidden()
                                        .tint(DS.text(0.9))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.glassStroke(0.12)))
                                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                }
                            }
                        }
                        .animation(reduceMotion ? nil : DS.motionSmooth, value: hasDueDate)

                        // ---------- Категория ----------
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LippiSectionHeader(
                                    title: s("task_editor.category.title"),
                                    subtitle: s("task_editor.category.subtitle"),
                                    icon: "tag.fill",
                                    accent: Color(hex: 0xFF9F0A)
                                )

                                HStack(spacing: 12) {
                                    Image(systemName: category.symbol)
                                        .foregroundStyle(DS.text(0.8))
                                        .frame(width: 22)

                                    Picker(s("task_editor.category.picker"), selection: $category) {
                                        ForEach(TaskCategory.allCases) { c in
                                            Text(c.title).tag(c)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()

                                    Spacer()

                                    Label(category.title, systemImage: category.symbol)
                                        .font(.caption.weight(.semibold))
                                        .labelStyle(TightLabelStyle())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(DS.glassFill(0.10), in: Capsule())
                                        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                                        .foregroundStyle(DS.text(0.85))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.glassStroke(0.12)))
                            }
                        }

                        // воздух перед липкой кнопкой
                        Color.clear.frame(height: 96)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? s("task_editor.nav.edit") : s("task_editor.nav.new"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(s("task_editor.cancel")) { dismiss() }
                        .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            }

            // ✅ Липкая кнопка “Сохранить” — всегда под пальцем
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button { save() } label: {
                        Label(
                            isEditing ? s("task_editor.save_changes") : s("task_editor.save"),
                            systemImage: "checkmark.seal.fill"
                        )
                            .labelStyle(TightLabelStyle())
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                    .buttonStyle(LippiButtonStyle(kind: .primary))
                    .opacity(canSave ? 1 : 0.55)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(DS.glassFill(0.12))
                        .opacity(0.20)
                        .ignoresSafeArea()
                )
            }
        }
    }

    // MARK: - Subviews

    private var heroHeader: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(safeSystemName: isEditing ? "square.and.pencil" : "plus.circle.fill",
                      fallback: isEditing ? "square.and.pencil" : "plus")
                    .foregroundStyle(DS.text(0.92))
                    .frame(width: 44, height: 44)
                    .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(isEditing ? s("task_editor.hero.edit") : s("task_editor.hero.new"))
                        .font(.headline)
                        .foregroundStyle(DS.text(0.95))
                        .singleLine()

                    Text(isEditing ? s("task_editor.hero.edit_subtitle") : s("task_editor.hero.new_subtitle"))
                        .font(.footnote)
                        .foregroundStyle(DS.text(0.65))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.text(0.70))
                .singleLine()

            HStack(spacing: 10) {
                Image(safeSystemName: icon, fallback: icon)
                    .foregroundStyle(DS.text(0.70))
                    .frame(width: 22)

                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.glassStroke(0.12)))
        }
    }

    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s("task_editor.main.notes"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DS.text(0.70))
                .singleLine()

            HStack(alignment: .top, spacing: 10) {
                Image(safeSystemName: "note.text", fallback: "note")
                    .foregroundStyle(DS.text(0.70))
                    .frame(width: 22)
                    .padding(.top, 2)

                TextEditor(text: $notes)
                    .frame(minHeight: 88, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(DS.text(0.90))
                    .font(.body)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.glassStroke(0.12)))
        }
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(safeSystemName: icon, fallback: icon)
                .foregroundStyle(DS.text(0.70))
                .frame(width: 22)

            Text(title)
                .foregroundStyle(DS.text(0.90))

            Spacer()

            Toggle("", isOn: isOn.animation(reduceMotion ? nil : DS.motionQuick))
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.glassFill(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DS.glassStroke(0.12)))
    }

    // MARK: - Save

    private func save() {
        let t = trimmedTitle
        guard !t.isEmpty else { return }

        var newItem = item ?? TaskItem(title: t)
        newItem.title = t
        newItem.notes = notes
        newItem.dueDate = hasDueDate ? dueDate : nil
        newItem.category = category

        onSave(newItem)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        dismiss()
    }
}
