import Foundation

enum L10nEN: L10nModule {
    static let language: AppLang = .en

    static let table: [L10nKey: String] = [
        .common_ok: "OK",
        .common_cancel: "Cancel",
        .common_delete: "Delete",

        .tab_today: "Today",
        .tab_tasks: "Tasks",
        .tab_pomodoro: "Pomodoro",
        .tab_break: "Break",
        .tab_health: "Health",
        .tab_eye: "Eyes",
        .tab_settings: "Settings",

        .auth_loading_restore: "Restoring session",
        .auth_error_title: "Error",
        .auth_unknown_error: "Unknown error",
        .auth_brand_subtitle: "Secure sign in",
        .auth_brand_description: "Sign in with your email and password to continue.",
        .auth_language_title: "App language",
        .auth_language_hint: "Choose the interface language before signing in.",
        .auth_mode_sign_in: "Sign In",
        .auth_mode_sign_up: "Sign Up",
        .auth_mode_sign_in_subtitle: "Sign in with email and password",
        .auth_mode_sign_up_subtitle: "Create an account for sync",
        .auth_mode_sign_in_button: "Sign In",
        .auth_mode_sign_up_button: "Create account",
        .auth_field_name: "Name",
        .auth_field_email: "Email",
        .auth_field_password: "Password",
        .auth_name_placeholder: "Your name",
        .auth_email_placeholder: "name@example.com",
        .auth_password_placeholder: "At least 8 characters",
        .auth_security_title: "Session is stored in Keychain",
        .auth_security_description: "Passwords are never stored in plain text and are protected with hashing.",

        .settings_nav_title: "Settings",
        .settings_alert_clear_title: "Delete all tasks?",
        .settings_alert_clear_message: "This action cannot be undone.",
        .settings_hero_title: "Settings hub",
        .settings_hero_subtitle: "Pomodoro, reminders, eye exercises, and widgets in one place.",
        .settings_stat_active: "Active",
        .settings_stat_done: "Done",
        .settings_account_title: "Account",
        .settings_account_subtitle: "Authentication management",
        .settings_user_fallback: "User",
        .settings_session_inactive: "Session is inactive",
        .settings_provider_email: "Email sign in",
        .settings_sign_out: "Sign out",
        .settings_theme_title: "Appearance",
        .settings_theme_subtitle: "Choose app theme",
        .settings_theme_hint: "Theme is applied instantly and adapts to the system light/dark mode.",
        .settings_language_title: "Language",
        .settings_language_subtitle: "Choose app language",
        .settings_language_hint: "Language applies instantly on login, settings, and navigation.",
        .settings_data_title: "Data",
        .settings_data_subtitle: "Danger zone",
        .settings_clear_tasks: "Clear all tasks"
    ]
}
