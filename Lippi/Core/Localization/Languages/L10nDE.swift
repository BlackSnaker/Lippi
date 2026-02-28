import Foundation

enum L10nDE: L10nModule {
    static let language: AppLang = .de

    static let table: [L10nKey: String] = [
        .common_ok: "OK",
        .common_cancel: "Abbrechen",
        .common_delete: "Löschen",

        .tab_today: "Heute",
        .tab_tasks: "Aufgaben",
        .tab_pomodoro: "Pomodoro",
        .tab_break: "Pause",
        .tab_health: "Gesundheit",
        .tab_eye: "Augen",
        .tab_settings: "Einstellungen",

        .auth_loading_restore: "Sitzung wird wiederhergestellt",
        .auth_error_title: "Fehler",
        .auth_unknown_error: "Unbekannter Fehler",
        .auth_brand_subtitle: "Sicherer Login",
        .auth_brand_description: "Melde dich mit E-Mail und Passwort an, um fortzufahren.",
        .auth_language_title: "App-Sprache",
        .auth_language_hint: "Wähle die Sprache vor dem Anmelden.",
        .auth_mode_sign_in: "Anmelden",
        .auth_mode_sign_up: "Registrieren",
        .auth_mode_sign_in_subtitle: "Mit E-Mail und Passwort anmelden",
        .auth_mode_sign_up_subtitle: "Konto für die Synchronisierung erstellen",
        .auth_mode_sign_in_button: "Anmelden",
        .auth_mode_sign_up_button: "Konto erstellen",
        .auth_field_name: "Name",
        .auth_field_email: "E-Mail",
        .auth_field_password: "Passwort",
        .auth_name_placeholder: "Dein Name",
        .auth_email_placeholder: "name@example.com",
        .auth_password_placeholder: "Mindestens 8 Zeichen",
        .auth_security_title: "Sitzung im Keychain gespeichert",
        .auth_security_description: "Passwörter werden nicht im Klartext gespeichert und per Hashing geschützt.",

        .settings_nav_title: "Einstellungen",
        .settings_alert_clear_title: "Alle Aufgaben löschen?",
        .settings_alert_clear_message: "Diese Aktion kann nicht rückgängig gemacht werden.",
        .settings_hero_title: "Einstellungszentrale",
        .settings_hero_subtitle: "Pomodoro, Erinnerungen, Augentraining und Widgets an einem Ort.",
        .settings_stat_active: "Aktiv",
        .settings_stat_done: "Erledigt",
        .settings_account_title: "Konto",
        .settings_account_subtitle: "Anmeldeverwaltung",
        .settings_user_fallback: "Benutzer",
        .settings_session_inactive: "Sitzung ist inaktiv",
        .settings_provider_email: "Anmeldung per E-Mail",
        .settings_sign_out: "Abmelden",
        .settings_theme_title: "Design",
        .settings_theme_subtitle: "App-Design auswählen",
        .settings_theme_hint: "Das Design wird sofort angewendet und folgt dem hellen/dunklen Systemmodus.",
        .settings_language_title: "Sprache",
        .settings_language_subtitle: "App-Sprache auswählen",
        .settings_language_hint: "Die Sprache wird sofort in Login, Einstellungen und Navigation angewendet.",
        .settings_data_title: "Daten",
        .settings_data_subtitle: "Gefahrenbereich",
        .settings_clear_tasks: "Alle Aufgaben löschen"
    ]
}
