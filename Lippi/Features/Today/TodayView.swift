import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - TODAY (with transparent nav bar)
// =======================================================
struct TodayView: View {
    @EnvironmentObject private var store: TaskStore
    @EnvironmentObject private var stats: StatsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var showAdd = false

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    private var performanceMode: Bool { DS.runtimeConstrained || reduceTransparency }
    private var activeTasksCount: Int { store.tasks.filter { !$0.isCompleted }.count }
    private var doneTasksCount: Int { store.tasks.filter { $0.isCompleted }.count }
    private var totalTasksCount: Int { max(store.tasks.count, 1) }
    private var hasUpcomingTask: Bool { store.upcoming() != nil }
    private var completionProgress: Double {
        min(max(Double(doneTasksCount) / Double(totalTasksCount), 0), 1)
    }

    private var quickActionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10, alignment: .top),
            GridItem(.flexible(), spacing: 10, alignment: .top)
        ]
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return s("today.greeting.morning")
        case 12..<18: return s("today.greeting.day")
        default: return s("today.greeting.evening")
        }
    }

    private var todayBackdrop: some View {
        ZStack {
            AppBackdrop()

            LinearGradient(
                colors: [
                    Color.white.opacity(performanceMode ? 0.02 : 0.05),
                    Color.clear,
                    Color.black.opacity(performanceMode ? 0.08 : 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.overlay)

            if !performanceMode {
                RadialGradient(
                    colors: [DS.brandA.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 260
                )
                .offset(x: -26, y: -48)

                RadialGradient(
                    colors: [DS.brandB.opacity(0.14), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 280
                )
                .offset(x: 24, y: 40)
                .opacity(reduceMotion ? 0.85 : 1.0)
            }
        }
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                todayBackdrop

                ScrollView {
                    LazyVStack(spacing: 16) {
                        headerCard
                        CountdownCardView()
                        StatsCardView()
                        nextTaskCard
                        quickActions
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .transaction { $0.animation = nil }
            }
            .navigationTitle(s("today.nav_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Label(s("today.toolbar.new_task"), systemImage: "plus.circle.fill")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
            }
            // ✅ Нижний отступ под TabBar (чтобы контент не уходил под него)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 92)
            }
            .sheet(isPresented: $showAdd) {
                AddEditTaskView { store.add($0) }
                    .presentationDetents([.medium, .large])
            }
        }
        // ✅ Убираем системный фон NavigationStack “на всякий”
        .background(Color.clear)
    }

    // MARK: - Subviews
    private var headerCard: some View {
        GlassCard(padding: 18, cornerRadius: 28, style: .full) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textSecondary)
                            .singleLine()

                        Text(greetingTitle)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.textPrimary)
                            .singleLine()

                        Text(s("today.header.subtitle"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.textTertiary)
                            .singleLine()
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 8) {
                        dayProgressBadge

                        Label(
                            L10n.fmt("today.header.done_count", lang, doneTasksCount),
                            systemImage: "checkmark.circle.fill"
                        )
                            .font(.caption2.weight(.semibold))
                            .labelStyle(TightLabelStyle())
                            .foregroundStyle(DS.textSecondary)
                            .singleLine()
                    }
                }

                HStack(spacing: 8) {
                    heroMetricChip(title: s("today.metric.active"), value: "\(activeTasksCount)", systemImage: "circle")
                    heroMetricChip(title: s("today.metric.streak"), value: "\(stats.productiveStreak)", systemImage: "flame.fill")
                    heroMetricChip(title: s("today.metric.done"), value: "\(doneTasksCount)", systemImage: "checkmark.circle.fill")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DS.glassFill(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DS.brandSoftGradient)
                                .opacity(0.42)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DS.glassStroke(0.12), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    headerChip(s("today.chip.focus"), systemImage: "bolt.fill")
                    headerChip(s("today.chip.selfcare"), systemImage: "heart.text.square")
                }
            }
        }
    }

    private var dayProgressBadge: some View {
        ZStack {
            Circle()
                .stroke(DS.glassStroke(0.14), lineWidth: 7)

            Circle()
                .trim(from: 0, to: completionProgress)
                .stroke(
                    AngularGradient(colors: [DS.brandA, DS.brandB], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int((completionProgress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()

                Text(s("today.progress.day"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
            }
        }
        .frame(width: 64, height: 64)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DS.brandSoftGradient)
                        .opacity(0.55)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.glassStroke(0.16), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : DS.motionQuick, value: completionProgress)
    }

    private func heroMetricChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(DS.glassFill(0.12))
                    .overlay(Circle().stroke(DS.glassStroke(0.18), lineWidth: 1))

                Image(safeSystemName: systemImage, fallback: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.text(0.90))
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                    .singleLine()

                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
                    .singleLine()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.glassFill(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.brandSoftGradient)
                        .opacity(0.20)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.glassStroke(0.14), lineWidth: 1)
        )
    }

    private func headerChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .labelStyle(TightLabelStyle())
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(DS.glassFill(0.08), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.16), lineWidth: 1))
    }

    private var nextTaskCard: some View {
        let next = store.upcoming()
        return GlassCard(padding: 16, cornerRadius: 24, style: .lightweight) {
            HStack(alignment: .top, spacing: 10) {
                    LippiSectionHeader(
                    title: s("today.next.title"),
                    subtitle: s("today.next.subtitle"),
                    icon: "timer",
                    accent: DS.accent
                )

                Spacer()

                #if canImport(ActivityKit)
                if #available(iOS 16.2, *) {
                    Button {
                        if let t = next { Task { await LiveActivityManager.startTask(t) } }
                    } label: {
                        Label(s("today.next.to_island"), systemImage: "wave.3.right")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .primary, compact: true))
                    .padding(.top, 2)
                }
                #endif
            }

            if let next {
                VStack(alignment: .leading, spacing: 8) {
                    Text(next.title)
                        .font(.title3.weight(.semibold))
                        .singleLine()

                    Label(next.category.title, systemImage: next.category.symbol)
                        .font(.caption2.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.glassFill(0.10), in: Capsule())
                        .overlay(Capsule().stroke(DS.glassStroke(0.18), lineWidth: 1))

                    if let due = next.dueDate {
                        Text(due, format: .dateTime.day().month().hour().minute())
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.text(0.75))
                            .singleLine()
                    } else {
                        Text(s("today.next.no_due"))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DS.text(0.65))
                            .singleLine()
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DS.glassFill(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DS.brandSoftGradient)
                                .opacity(0.22)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DS.glassStroke(0.12), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(safeSystemName: "sparkles", fallback: "star")
                            .imageScale(.large)
                            .foregroundStyle(DS.text(0.85))
                        Text(s("today.next.empty_title"))
                            .foregroundStyle(DS.text(0.75))
                            .singleLine()
                    }

                    Button { showAdd = true } label: {
                        Label(s("today.next.empty_button"), systemImage: "plus")
                            .labelStyle(TightLabelStyle())
                    }
                    .buttonStyle(LippiButtonStyle(kind: .secondary, compact: true))
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var quickActions: some View {
        GlassCard(padding: 14, cornerRadius: 24, style: .full) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    LippiSectionHeader(
                        title: s("today.quick.title"),
                        subtitle: s("today.quick.subtitle"),
                        icon: "bolt.fill",
                        accent: Color(hex: 0x64D2FF)
                    )

                    Spacer()

                    Label(s("today.quick.today"), systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .labelStyle(TightLabelStyle())
                        .foregroundStyle(DS.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.glassFill(0.08), in: Capsule())
                        .overlay(Capsule().stroke(DS.glassStroke(0.14), lineWidth: 1))
                        .padding(.top, 2)
                }

                LazyVGrid(columns: quickActionColumns, spacing: 10) {
                    quickActionTile(
                        title: s("today.quick.new"),
                        icon: "plus",
                        tone: DS.brandA
                    ) {
                        showAdd = true
                    }
                    .gridCellColumns(2)

                    quickActionTile(
                        title: s("today.quick.done"),
                        icon: "checkmark.circle",
                        tone: Color(hex: 0x30D158)
                    ) {
                        if let task = store.upcoming() {
                            var updated = task
                            updated.isCompleted = true
                            store.update(updated)
                            #if os(iOS)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                        }
                    }
                    .opacity(hasUpcomingTask ? 1.0 : 0.56)
                    .allowsHitTesting(hasUpcomingTask)

                    quickActionTile(
                        title: s("today.quick.eyes"),
                        icon: "eye",
                        tone: Color(hex: 0x64D2FF)
                    ) {
                        NotificationCenter.default.post(name: .suggestEyeExercise, object: nil)
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        #endif
                    }
                }
            }
        }
    }

    private func quickActionTile(
        title: String,
        icon: String,
        tone: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DS.glassFill(0.11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tone.opacity(0.28))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.glassStroke(0.16), lineWidth: 1)
                        )

                    Image(safeSystemName: icon, fallback: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DS.text(0.94))
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .singleLine()

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.glassFill(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tone.opacity(0.10))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.glassStroke(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle(scale: 0.986, opacity: 0.98))
    }
}


// =======================================================
