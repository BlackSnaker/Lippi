import Foundation

enum L10nES: L10nModule {
    static let language: AppLang = .es

    static let table: [L10nKey: String] = [
        .common_ok: "OK",
        .common_cancel: "Cancelar",
        .common_delete: "Eliminar",

        .tab_today: "Hoy",
        .tab_tasks: "Tareas",
        .tab_pomodoro: "Pomodoro",
        .tab_break: "Descanso",
        .tab_health: "Salud",
        .tab_eye: "Ojos",
        .tab_settings: "Ajustes",

        .auth_loading_restore: "Restaurando sesión",
        .auth_error_title: "Error",
        .auth_unknown_error: "Error desconocido",
        .auth_brand_subtitle: "Inicio de sesión seguro",
        .auth_brand_description: "Inicia sesión con correo y contraseña para continuar.",
        .auth_language_title: "Idioma de la app",
        .auth_language_hint: "Elige el idioma antes de iniciar sesión.",
        .auth_mode_sign_in: "Iniciar sesión",
        .auth_mode_sign_up: "Registro",
        .auth_mode_sign_in_subtitle: "Inicia sesión con correo y contraseña",
        .auth_mode_sign_up_subtitle: "Crea una cuenta para sincronizar",
        .auth_mode_sign_in_button: "Iniciar sesión",
        .auth_mode_sign_up_button: "Crear cuenta",
        .auth_field_name: "Nombre",
        .auth_field_email: "Correo",
        .auth_field_password: "Contraseña",
        .auth_name_placeholder: "Tu nombre",
        .auth_email_placeholder: "name@example.com",
        .auth_password_placeholder: "Mínimo 8 caracteres",
        .auth_security_title: "La sesión se guarda en Keychain",
        .auth_security_description: "Las contraseñas no se guardan en texto plano y se protegen con hash.",

        .settings_nav_title: "Ajustes",
        .settings_alert_clear_title: "¿Eliminar todas las tareas?",
        .settings_alert_clear_message: "Esta acción no se puede deshacer.",
        .settings_hero_title: "Centro de ajustes",
        .settings_hero_subtitle: "Pomodoro, recordatorios, ejercicios para ojos y widgets en un solo lugar.",
        .settings_stat_active: "Activas",
        .settings_stat_done: "Hechas",
        .settings_account_title: "Cuenta",
        .settings_account_subtitle: "Gestión de autenticación",
        .settings_user_fallback: "Usuario",
        .settings_session_inactive: "Sesión inactiva",
        .settings_provider_email: "Inicio con correo",
        .settings_sign_out: "Cerrar sesión",
        .settings_theme_title: "Apariencia",
        .settings_theme_subtitle: "Elige el tema de la app",
        .settings_theme_hint: "El tema se aplica al instante y se adapta al modo claro/oscuro del sistema.",
        .settings_language_title: "Idioma",
        .settings_language_subtitle: "Elige el idioma de la app",
        .settings_language_hint: "El idioma se aplica al instante en inicio, ajustes y navegación.",
        .settings_data_title: "Datos",
        .settings_data_subtitle: "Zona de riesgo",
        .settings_clear_tasks: "Borrar todas las tareas"
    ]
}
