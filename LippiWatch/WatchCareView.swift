import SwiftUI

struct WatchCareView: View {
    @EnvironmentObject private var care: WatchCareStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                suggestionCard
                contextRow
                quickActions
                if let step = care.snapshot.nextGoalStep, !step.isEmpty {
                    goalCard(step)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
        .background(background.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let confirmation = care.confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.88), in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: care.confirmation)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.badge.mic")
                .font(.caption.weight(.bold))
                .foregroundStyle(.cyan)
            Text("Lippi")
                .font(.headline.weight(.bold))
            Spacer(minLength: 2)
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 5)
    }

    private var suggestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: suggestionIcon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(suggestionTone)
                    .frame(width: 30, height: 30)
                    .background(suggestionTone.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(care.snapshot.suggestionTitle)
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(care.snapshot.suggestionBody)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            if care.snapshot.suggestionAction != "none" {
                Button {
                    care.send(action: care.snapshot.suggestionAction)
                } label: {
                    Text(care.snapshot.suggestionActionTitle)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(suggestionTone)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(suggestionTone.opacity(0.22), lineWidth: 1)
        )
    }

    private var contextRow: some View {
        HStack(spacing: 6) {
            contextPill(
                icon: care.snapshot.isFocusRunning ? "timer" : "heart.fill",
                value: care.snapshot.isFocusRunning
                    ? "\(care.snapshot.focusMinutes) min"
                    : care.snapshot.paceTitle
            )
            if let steps = care.snapshot.stepsToday {
                contextPill(icon: "figure.walk", value: "\(steps)")
            }
        }
    }

    private func contextPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06), in: Capsule())
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            quickButton("logWater", title: care.snapshot.waterLabel, icon: "drop.fill", tone: .cyan)
            quickButton("logMeal", title: care.snapshot.mealLabel, icon: "fork.knife", tone: .orange)
            quickButton("logMovement", title: care.snapshot.moveLabel, icon: "figure.walk", tone: .green)
            quickButton("openRecovery", title: care.snapshot.restLabel, icon: "heart.fill", tone: .pink)
        }
    }

    private func quickButton(_ action: String, title: String, icon: String, tone: Color) -> some View {
        Button {
            care.send(action: action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(tone)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func goalCard(_ step: String) -> some View {
        Button {
            care.send(action: "openGoal")
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(care.snapshot.goalLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(step)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionIcon: String {
        switch care.snapshot.suggestionKind {
        case "eyeBreak": return "eye.fill"
        case "recovery": return "heart.fill"
        case "mealCheck": return "fork.knife"
        case "movement": return "figure.walk"
        case "hydration": return "drop.fill"
        case "goalStep": return "scope"
        default: return "sparkles"
        }
    }

    private var suggestionTone: Color {
        switch care.snapshot.suggestionKind {
        case "eyeBreak": return .purple
        case "recovery": return .pink
        case "mealCheck": return .orange
        case "movement": return .green
        case "hydration": return .cyan
        case "goalStep": return .blue
        default: return .cyan
        }
    }

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [.blue.opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 2,
                endRadius: 135
            )
            RadialGradient(
                colors: [.green.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 2,
                endRadius: 120
            )
        }
    }
}
