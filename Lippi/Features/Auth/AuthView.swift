import SwiftUI

private enum AuthMode: String, CaseIterable {
    case signIn
    case signUp

    var buttonIcon: String {
        switch self {
        case .signIn: return "arrow.right.circle.fill"
        case .signUp: return "person.badge.plus"
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if auth.isRestoring {
                AuthLoadingView()
            } else if auth.isAuthenticated {
                ContentView()
            } else {
                AuthView()
            }
        }
        .task {
            auth.bootstrapIfNeeded()
        }
    }
}

private struct AuthLoadingView: View {
    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    private var lang: AppLang { L10n.lang(from: langRaw) }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            VStack(spacing: 12) {
                ProgressView()
                    .tint(DS.text(0.95))
                Text(L10n.tr(.auth_loading_restore, lang))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DS.text(0.7))
            }
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var auth: AuthStore

    @AppStorage(L10n.storageKey) private var langRaw: String = AppLang.fallback.rawValue
    @State private var mode: AuthMode = .signIn
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    private var lang: AppLang { L10n.lang(from: langRaw) }

    private func t(_ key: L10nKey) -> String {
        L10n.tr(key, lang)
    }

    var body: some View {
        ZStack {
            AppBackdrop(renderMode: .force)

            ScrollView {
                VStack(spacing: 16) {
                    brandCard
                    languageCard
                    modeCard
                    formCard
                    securityCard
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .alert(t(.auth_error_title), isPresented: Binding(
            get: { auth.errorMessage != nil },
            set: { if !$0 { auth.errorMessage = nil } }
        )) {
            Button(t(.common_ok), role: .cancel) { auth.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? t(.auth_unknown_error))
        }
    }

    private var brandCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(safeSystemName: "lock.shield.fill", fallback: "lock")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.text(0.95))
                        .frame(width: 44, height: 44)
                        .background(DS.glassFill(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DS.glassStroke(0.18), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lippi")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.text(0.95))
                        Text(t(.auth_brand_subtitle))
                            .font(.caption)
                            .foregroundStyle(DS.text(0.66))
                    }

                    Spacer()
                }

                Text(t(.auth_brand_description))
                    .font(.footnote)
                    .foregroundStyle(DS.text(0.7))
            }
        }
    }

    private var languageCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 10) {
                LippiSectionHeader(
                    title: t(.auth_language_title),
                    subtitle: t(.auth_language_hint),
                    icon: "globe",
                    accent: Color(hex: 0x5AC8FA)
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 120), spacing: 8),
                        GridItem(.flexible(minimum: 120), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(AppLang.allCases) { option in
                        Button {
                            guard lang != option else { return }
                            langRaw = option.rawValue
                            #if os(iOS)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        } label: {
                            HStack(spacing: 8) {
                                Text(option.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(DS.text(0.92))
                                    .singleLine()

                                Spacer(minLength: 4)

                                if lang == option {
                                    Image(safeSystemName: "checkmark.circle.fill", fallback: "checkmark.circle")
                                        .foregroundStyle(DS.accent)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(DS.glassFill(lang == option ? 0.15 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(lang == option ? DS.accent.opacity(0.52) : DS.glassStroke(0.14), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.988, opacity: 0.96))
                    }
                }
            }
        }
    }

    private func modeTitle(_ value: AuthMode) -> String {
        switch value {
        case .signIn: return t(.auth_mode_sign_in)
        case .signUp: return t(.auth_mode_sign_up)
        }
    }

    private func modeSubtitle(_ value: AuthMode) -> String {
        switch value {
        case .signIn: return t(.auth_mode_sign_in_subtitle)
        case .signUp: return t(.auth_mode_sign_up_subtitle)
        }
    }

    private func modeButtonTitle(_ value: AuthMode) -> String {
        switch value {
        case .signIn: return t(.auth_mode_sign_in_button)
        case .signUp: return t(.auth_mode_sign_up_button)
        }
    }

    private var modeCard: some View {
        GlassCard(style: .lightweight) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(AuthMode.allCases, id: \.rawValue) { item in
                        Button {
                            mode = item
                        } label: {
                            Text(modeTitle(item))
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(mode == item ? AnyShapeStyle(DS.brand) : AnyShapeStyle(DS.glassFill(0.08)))
                                )
                                .foregroundStyle(mode == item ? Color.white : DS.text(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(modeSubtitle(mode))
                    .font(.caption)
                    .foregroundStyle(DS.text(0.62))
            }
        }
    }

    private var formCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                LippiSectionHeader(
                    title: modeTitle(mode),
                    subtitle: modeSubtitle(mode),
                    icon: "person.crop.circle.fill",
                    accent: Color(hex: 0x64D2FF)
                )

                if mode == .signUp {
                    labeledField(title: t(.auth_field_name), icon: "person.fill") {
                        TextField(t(.auth_name_placeholder), text: $displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .fieldGlass()
                    }
                }

                labeledField(title: t(.auth_field_email), icon: "envelope.fill") {
                    TextField(t(.auth_email_placeholder), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .fieldGlass()
                }

                labeledField(title: t(.auth_field_password), icon: "lock.fill") {
                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
                                TextField(t(.auth_password_placeholder), text: $password)
                            } else {
                                SecureField(t(.auth_password_placeholder), text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(safeSystemName: showPassword ? "eye.slash.fill" : "eye.fill", fallback: "eye")
                                .foregroundStyle(DS.text(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .fieldGlass()
                }

                Button {
                    submitCredentials()
                } label: {
                    Label(modeButtonTitle(mode), systemImage: mode.buttonIcon)
                        .labelStyle(TightLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LippiButtonStyle(kind: .primary))
                .buttonStyle(PressScaleStyle(scale: 0.985, opacity: 0.95))
                .disabled(!canSubmit || auth.isBusy)

                if auth.isBusy {
                    ProgressView()
                        .tint(DS.text(0.9))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var securityCard: some View {
        GlassCard(style: .flat) {
            VStack(alignment: .leading, spacing: 8) {
                Label(t(.auth_security_title), systemImage: "key.fill")
                    .labelStyle(TightLabelStyle())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.text(0.86))

                Text(t(.auth_security_description))
                    .font(.caption)
                    .foregroundStyle(DS.text(0.64))
            }
        }
    }

    private var canSubmit: Bool {
        let hasEmail = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPassword = password.count >= 8
        if mode == .signUp {
            return hasEmail && hasPassword && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasEmail && hasPassword
    }

    private func submitCredentials() {
        guard !auth.isBusy else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            if mode == .signIn {
                await auth.signIn(email: trimmedEmail, password: password)
            } else {
                await auth.signUp(email: trimmedEmail, password: password, displayName: trimmedName)
            }
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: icon)
                .labelStyle(TightLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.text(0.70))

            content()
        }
    }
}
