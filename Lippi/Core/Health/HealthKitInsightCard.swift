import SwiftUI

struct HealthKitInsightCard: View {
    @ObservedObject var manager: HealthKitManager
    let lang: AppLang
    var showsManagementActions: Bool = false
    var onUseBreathing: (() -> Void)? = nil
    var onOpenEyes: (() -> Void)? = nil
    @AppStorage(HealthKitManager.pairingOnboardingCompletedKey) private var hasCompletedPairingOnboarding = false
    @State private var showsPairingOnboarding = false

    private func s(_ key: String) -> String { L10n.tr(key, lang) }

    var body: some View {
        GlassCard(padding: 16, cornerRadius: 26, style: .lightweight) {
            VStack(alignment: .leading, spacing: 14) {
                header

                if !manager.isEnabled {
                    connectionPrompt
                } else if manager.snapshot == nil,
                          manager.state == .requesting || manager.state == .refreshing {
                    loadingState
                } else if let snapshot = manager.snapshot,
                          let recommendation = manager.recommendation {
                    connectedContent(snapshot: snapshot, recommendation: recommendation)
                } else {
                    emptyState
                }

                privacyFooter
            }
        }
        .fullScreenCover(isPresented: $showsPairingOnboarding) {
            AppleWatchPairingView(
                manager: manager,
                hasCompletedOnboarding: $hasCompletedPairingOnboarding
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            LippiSectionHeader(
                title: s("healthkit.title"),
                subtitle: s("healthkit.subtitle"),
                icon: "heart.text.square.fill",
                accent: Color(hex: 0xFF375F)
            )

            HStack(spacing: 7) {
                Circle()
                    .fill(statusTone)
                    .frame(width: 7, height: 7)

                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if manager.snapshot?.hasAppleWatchData == true {
                    Label(s("healthkit.watch.connected"), systemImage: "applewatch")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.textSecondary)
                        .labelStyle(TightLabelStyle())
                }
            }
        }
    }

    private var connectionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(s("healthkit.connect.description"))
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsPairingOnboarding = true
            } label: {
                Label(s("healthkit.connect.button"), systemImage: "heart.fill")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
            .disabled(manager.state == .requesting)
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(DS.accent)
            Text(s("healthkit.loading"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func connectedContent(
        snapshot: HealthWellnessSnapshot,
        recommendation: HealthWellnessRecommendation
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            readinessSummary(recommendation)
            metrics(snapshot)

            if !recommendation.signals.isEmpty {
                signalList(recommendation.signals)
            }

            recommendedScenario(recommendation)

            if recommendation.suggestsBreathing || recommendation.suggestsEyeBreak {
                recommendationActions(recommendation)
            }

            if manager.diagnosticReport.hasActionableIssue, !showsManagementActions {
                diagnosticShortcut
            }

            if showsManagementActions {
                managementActions
            }
        }
    }

    private func readinessSummary(_ recommendation: HealthWellnessRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(safeSystemName: icon(for: recommendation.band), fallback: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tone(for: recommendation.band))
                .frame(width: 40, height: 40)
                .background(tone(for: recommendation.band).opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(s("healthkit.band.\(recommendation.band.rawValue).title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(s("healthkit.band.\(recommendation.band.rawValue).description"))
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tone(for: recommendation.band).opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tone(for: recommendation.band).opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metrics(_ snapshot: HealthWellnessSnapshot) -> some View {
        let values = metricValues(snapshot)
        if !values.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(values) { metric in
                    HealthKitMetricTile(metric: metric)
                }
            }
        }
    }

    private func signalList(_ signals: [HealthWellnessSignal]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(s("healthkit.basis.title"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.textTertiary)

            ForEach(Array(signals.prefix(3)), id: \.self) { signal in
                HStack(alignment: .top, spacing: 8) {
                    Image(safeSystemName: "checkmark.circle.fill", fallback: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: 0x64D2FF))
                        .padding(.top, 1)
                    Text(s("healthkit.signal.\(signal.rawValue)"))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func recommendedScenario(_ recommendation: HealthWellnessRecommendation) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(safeSystemName: "timer", fallback: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.accent)
                .frame(width: 34, height: 34)
                .background(DS.accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(s("healthkit.scenario.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.textTertiary)
                Text(L10n.fmt("healthkit.scenario.focus", lang, recommendation.suggestedFocusMinutes))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recommendationActions(_ recommendation: HealthWellnessRecommendation) -> some View {
        VStack(spacing: 8) {
            if recommendation.suggestsBreathing, let onUseBreathing {
                Button(action: onUseBreathing) {
                    Label(s("healthkit.action.breathing"), systemImage: "lungs.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))
            }

            if recommendation.suggestsEyeBreak, let onOpenEyes {
                Button(action: onOpenEyes) {
                    Label(s("healthkit.action.eyes"), systemImage: "eye.fill")
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
            }
        }
    }

    private var managementActions: some View {
        VStack(spacing: 8) {
            Button {
                showsPairingOnboarding = true
            } label: {
                Label(s("healthkit.diagnostics.open"), systemImage: "stethoscope")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))

            Button {
                Task { await manager.refresh() }
            } label: {
                Label(s("healthkit.refresh"), systemImage: "arrow.clockwise")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
            .disabled(manager.state == .refreshing)

            Button(role: .destructive) {
                manager.stopUsingInsights()
            } label: {
                Text(s("healthkit.stop_using"))
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.textTertiary)
            .padding(.vertical, 6)
        }
    }

    private var diagnosticShortcut: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(s("healthkit.diagnostics.attention"), systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: 0xFF9F0A))

            Text(s("healthkit.diagnostics.attention.subtitle"))
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsPairingOnboarding = true
            } label: {
                Label(s("healthkit.diagnostics.open"), systemImage: "stethoscope")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))
        }
        .padding(12)
        .background(Color(hex: 0xFF9F0A).opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xFF9F0A).opacity(0.18), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(emptyStateTitle, systemImage: manager.state == .failed ? "exclamationmark.circle.fill" : "heart.text.square")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(s("healthkit.empty.description"))
                .font(.footnote)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsPairingOnboarding = true
            } label: {
                Label(s("healthkit.diagnostics.open"), systemImage: "stethoscope")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, allowsMultiline: true))

            Button {
                Task { await manager.refresh() }
            } label: {
                Label(s("healthkit.refresh"), systemImage: "arrow.clockwise")
                    .labelStyle(TightLabelStyle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .secondary, allowsMultiline: true))

            if showsManagementActions {
                Button(role: .destructive) {
                    manager.stopUsingInsights()
                } label: {
                    Text(s("healthkit.stop_using"))
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.textTertiary)
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(DS.glassFill(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var privacyFooter: some View {
        Label(s("healthkit.privacy"), systemImage: "lock.shield.fill")
            .font(.caption2)
            .foregroundStyle(DS.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var emptyStateTitle: String {
        manager.state == .failed ? s("healthkit.error.title") : s("healthkit.empty.title")
    }

    private var statusTitle: String {
        switch manager.state {
        case .unavailable: return s("healthkit.status.unavailable")
        case .notConnected: return s("healthkit.status.not_connected")
        case .requesting: return s("healthkit.status.requesting")
        case .refreshing: return s("healthkit.status.refreshing")
        case .connected: return s("healthkit.status.connected")
        case .noRecentData: return s("healthkit.status.no_data")
        case .failed: return s("healthkit.status.failed")
        }
    }

    private var statusTone: Color {
        switch manager.state {
        case .connected: return Color(hex: 0x30D158)
        case .requesting, .refreshing, .noRecentData: return Color(hex: 0x64D2FF)
        case .failed: return Color(hex: 0xFF453A)
        case .unavailable, .notConnected: return DS.textTertiary
        }
    }

    private func icon(for band: HealthReadinessBand) -> String {
        switch band {
        case .unknown: return "questionmark.circle.fill"
        case .recovery: return "moon.stars.fill"
        case .light: return "leaf.fill"
        case .balanced: return "circle.hexagongrid.fill"
        case .ready: return "bolt.heart.fill"
        }
    }

    private func tone(for band: HealthReadinessBand) -> Color {
        switch band {
        case .unknown: return DS.textTertiary
        case .recovery: return Color(hex: 0xAF52DE)
        case .light: return Color(hex: 0x64D2FF)
        case .balanced: return Color(hex: 0x30D158)
        case .ready: return DS.accent
        }
    }

    private func metricValues(_ snapshot: HealthWellnessSnapshot) -> [HealthKitMetricValue] {
        var values: [HealthKitMetricValue] = []
        if let sleep = snapshot.recentSleepHours {
            values.append(.init(
                id: "sleep",
                icon: "bed.double.fill",
                title: s("healthkit.metric.sleep"),
                value: L10n.fmt("healthkit.value.hours", lang, number(sleep, digits: 1)),
                tone: Color(hex: 0xAF52DE)
            ))
        }
        if let hrv = snapshot.hrvSDNN {
            values.append(.init(
                id: "hrv",
                icon: "waveform.path.ecg",
                title: s("healthkit.metric.hrv"),
                value: L10n.fmt("healthkit.value.ms", lang, number(hrv, digits: 0)),
                tone: Color(hex: 0xFF375F)
            ))
        }
        if let heartRate = snapshot.restingHeartRate {
            values.append(.init(
                id: "rhr",
                icon: "heart.fill",
                title: s("healthkit.metric.resting_hr"),
                value: L10n.fmt("healthkit.value.bpm", lang, number(heartRate, digits: 0)),
                tone: Color(hex: 0xFF453A)
            ))
        }
        if let steps = snapshot.stepsToday {
            values.append(.init(
                id: "steps",
                icon: "figure.walk",
                title: s("healthkit.metric.steps"),
                value: number(steps, digits: 0),
                tone: Color(hex: 0x30D158)
            ))
        }
        return Array(values.prefix(4))
    }

    private func number(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: lang.localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct HealthKitMetricValue: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
    let tone: Color
}

private struct HealthKitMetricTile: View {
    let metric: HealthKitMetricValue

    var body: some View {
        HStack(spacing: 8) {
            Image(safeSystemName: metric.icon, fallback: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(metric.tone)
                .frame(width: 30, height: 30)
                .background(metric.tone.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(metric.title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(DS.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DS.glassFill(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DS.glassStroke(0.09), lineWidth: 1)
        )
    }
}
