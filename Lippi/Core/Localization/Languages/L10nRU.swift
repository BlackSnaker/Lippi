import Foundation

enum L10nRU: L10nModule {
    static let language: AppLang = .ru

    static let table: [L10nKey: String] = [
        .common_ok: "OK",
        .common_cancel: "Отмена",
        .common_delete: "Удалить",

        .tab_today: "Сегодня",
        .tab_tasks: "Задачи",
        .tab_pomodoro: "Помодоро",
        .tab_break: "Перерыв",
        .tab_health: "Здоровье",
        .tab_eye: "Глаза",
        .tab_settings: "Настройки",

        .auth_loading_restore: "Восстановление сессии",
        .auth_error_title: "Ошибка",
        .auth_unknown_error: "Неизвестная ошибка",
        .auth_brand_subtitle: "Безопасный вход",
        .auth_brand_description: "Войдите по email и паролю, чтобы продолжить.",
        .auth_language_title: "Язык приложения",
        .auth_language_hint: "Выберите язык интерфейса до входа в аккаунт.",
        .auth_mode_sign_in: "Вход",
        .auth_mode_sign_up: "Регистрация",
        .auth_mode_sign_in_subtitle: "Войдите по email и паролю",
        .auth_mode_sign_up_subtitle: "Создайте аккаунт для синхронизации",
        .auth_mode_sign_in_button: "Войти",
        .auth_mode_sign_up_button: "Создать аккаунт",
        .auth_field_name: "Имя",
        .auth_field_email: "Email",
        .auth_field_password: "Пароль",
        .auth_name_placeholder: "Ваше имя",
        .auth_email_placeholder: "name@example.com",
        .auth_password_placeholder: "Минимум 8 символов",
        .auth_security_title: "Сессия хранится в Keychain",
        .auth_security_description: "Пароли не сохраняются в открытом виде и защищены хешированием.",

        .settings_nav_title: "Настройки",
        .settings_alert_clear_title: "Удалить все задачи?",
        .settings_alert_clear_message: "Действие необратимо.",
        .settings_hero_title: "Панель настроек",
        .settings_hero_subtitle: "Помодоро, уведомления, гимнастика и виджеты — всё в одном месте.",
        .settings_stat_active: "Актив",
        .settings_stat_done: "Готово",
        .settings_account_title: "Аккаунт",
        .settings_account_subtitle: "Управление авторизацией",
        .settings_user_fallback: "Пользователь",
        .settings_session_inactive: "Сессия не активна",
        .settings_provider_email: "Вход по email",
        .settings_sign_out: "Выйти из аккаунта",
        .settings_theme_title: "Оформление",
        .settings_theme_subtitle: "Выбери тему интерфейса",
        .settings_theme_hint: "Тема применяется сразу и автоматически подстраивается под светлый/тёмный режим системы.",
        .settings_language_title: "Язык",
        .settings_language_subtitle: "Выбери язык интерфейса",
        .settings_language_hint: "Язык применяется сразу на экране входа, в настройках и навигации.",
        .settings_data_title: "Данные",
        .settings_data_subtitle: "Опасные действия",
        .settings_clear_tasks: "Очистить все задачи"
    ]
}
