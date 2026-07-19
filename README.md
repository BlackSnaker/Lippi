<div align="center">

# Lippi

### Focus deeply. Recover gently. Reach meaningful goals without overload.

**Осознанный фокус, бережное восстановление и движение к важным целям без перегруза.**

<p>
  <img alt="iOS 18.5+" src="https://img.shields.io/badge/iOS-18.5%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="Swift 5" src="https://img.shields.io/badge/Swift-5.0-FA7343?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-111111?style=for-the-badge&logo=apple&logoColor=white">
</p>
<p>
  <img alt="HealthKit" src="https://img.shields.io/badge/HealthKit-Integrated-FF375F?style=flat-square">
  <img alt="Apple Watch" src="https://img.shields.io/badge/Apple%20Watch-Aware-30D158?style=flat-square">
  <img alt="PrismML Bonsai" src="https://img.shields.io/badge/Bonsai-On--device-64D2FF?style=flat-square">
  <img alt="Local AI storage" src="https://img.shields.io/badge/Local%20AI-~577%20MB-30D158?style=flat-square">
  <img alt="Widgets" src="https://img.shields.io/badge/WidgetKit-Ready-BF5AF2?style=flat-square">
  <img alt="Languages" src="https://img.shields.io/badge/Languages-RU%20·%20EN%20·%20DE%20·%20ES-FF9F0A?style=flat-square">
  <img alt="License" src="https://img.shields.io/badge/License-Proprietary-5E5CE6?style=flat-square">
</p>

[Возможности](#возможности) · [Последнее обновление](#последнее-обновление--latest-release) · [Архитектура](#архитектура--architecture) · [Запуск](#локальный-запуск--run-locally) · [English](#english) · [Changelog](CHANGELOG.md)

</div>

---

## Lippi в одном взгляде

Lippi объединяет планирование, фокус и восстановление в одном спокойном iPhone-приложении. Вместо бесконечного списка требований пользователь видит понятный следующий шаг, а темп может бережно адаптироваться по прогрессу, самочувствию и разрешённым данным Apple Здоровья.

<table>
  <tr>
    <td width="50%" valign="top">
      <strong>🎯 Умные цели</strong><br>
      Объяснимая дорожная карта и небольшие следующие шаги.<br>
      <sub>Goal roadmaps that stay manageable.</sub>
    </td>
    <td width="50%" valign="top">
      <strong>⏱️ Фокус</strong><br>
      Pomodoro, задачи и ясный план дня без визуального шума.<br>
      <sub>Calm sessions and contextual controls.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <strong>❤️ Здоровье</strong><br>
      HealthKit, Apple Watch, дыхание и разминка глаз.<br>
      <sub>Wellness signals with user control.</sub>
    </td>
    <td width="50%" valign="top">
      <strong>✨ Помощник</strong><br>
      Голосовые команды и быстрые действия без лишней навигации.<br>
      <sub>Voice assistance one tap away.</sub>
    </td>
  </tr>
</table>

## Возможности

| Раздел | Что получает пользователь |
|---|---|
| **Сегодня** | Спокойный обзор дня, главный фокус, прогресс и быстрый переход к нужному действию. |
| **Умные цели** | Диалоговое планирование, измеримые этапы, адаптивный ритм и перенос просроченных шагов только после подтверждения. |
| **Задачи и Pomodoro** | Контекстные действия, гибкие фокус-сессии, надёжные пауза и продолжение, статистика без визуального шума. |
| **Здоровье** | Разрешённые показатели HealthKit, сигналы Apple Watch, личная база, отметки самочувствия и объяснимые рекомендации. |
| **Восстановление** | Дыхательные практики, упражнения для глаз и мягкие сценарии перерыва, которые не превращаются в новые обязательства. |
| **Голосовой помощник** | Управление функциями голосом, компактная кнопка у правого края и отдельные действия VoiceOver. |
| **Виджеты** | Быстрый взгляд на задачи, таймер и важные действия с домашнего экрана и экрана блокировки. |

## Принципы продукта

- **Спокойствие по умолчанию.** Один главный акцент на экран, короткие подписи и постепенное раскрытие деталей.
- **Пользователь управляет планом.** Lippi предлагает изменения, объясняет причины и применяет их только после подтверждения.
- **Приватность HealthKit.** Показатели обрабатываются на устройстве и не добавляются в запросы к внешним AI-провайдерам.
- **Плавность важнее декора.** Стекло, тени и анимации упрощаются во время прокрутки, энергосбережения и нагрева.
- **Доступность встроена.** Dynamic Type, VoiceOver, Reduce Motion и Reduce Transparency учитываются общей дизайн-системой.

## Последнее обновление · Latest release

### 19 июля 2026 — интеллект PrismML полностью на iPhone

- Mac-провайдер Ollama заменён на **PrismML Bonsai 4B 1-bit**, работающий локально через Metal.
- Модель загружается прямо на iPhone только после подтверждения пользователя и не увеличивает размер приложения на 573 МБ.
- В iPhone-приложение добавляется около **4,8 МБ** runtime; модель занимает **573 МБ** отдельно, полный объём локального AI после загрузки — примерно **577 МБ**.
- В настройках появились прогресс, пауза, продолжение, проверка целостности, локальный тест и безопасное удаление весов.
- Умные цели и анализ прогресса используют один приватный on-device runtime; Foundation Models остаётся системным fallback.
- Вес модели, runtime и источник закреплены по ревизии и SHA-256; сторонние лицензии включены в приложение.

[Читать полную историю изменений →](CHANGELOG.md)

### Размер приложения и локальной модели

| Компонент | Объём на iPhone |
|---|---:|
| Runtime PrismML внутри приложения | ≈ 4,8 МБ |
| Bonsai 4B Q1_0 после загрузки | 572 270 624 байта · ≈ 573 МБ |
| Полный дополнительный объём локального AI | ≈ 577 МБ |

Модель хранится отдельно в Application Support и может быть удалена из настроек без удаления приложения или пользовательских данных. Итоговый размер самого приложения в App Store может немного отличаться после оптимизации и сжатия Apple.

## Технологии

| Область | Реализация |
|---|---|
| Интерфейс | SwiftUI, собственная дизайн-система, адаптивный Liquid Glass |
| Платформа | iOS 18.5+, Swift 5 |
| Здоровье | HealthKit, фоновые observer queries, Apple Watch source awareness |
| Виджеты | WidgetKit, Live Activities, Dynamic Island |
| Интеллект | PrismML Bonsai 4B 1-bit на iPhone, Foundation Models fallback, ручной черновик |
| Голос | Speech, AVFoundation, системная и локальная neural voice озвучка |
| Качество | Swift Testing, UI Tests, device crash diagnostics |

## Архитектура · Architecture

```text
Lippi/
├── Core/
│   ├── AI/             # PrismML runtime, verified model storage and inference
│   ├── Goals/          # adaptive planning and gentle coaching
│   ├── Health/         # HealthKit, diagnostics, Watch and wellbeing
│   └── Localization/   # RU, EN, DE and ES
├── Features/
│   ├── Today · Tasks · Pomodoro
│   ├── Goals · Health · EyeHealth
│   └── Assistant · Settings
├── UI/                 # design system, glass and motion
└── Assets.xcassets/

LippiWidgets/           # home and lock-screen widgets
OrganizerWidget/        # organizer widget extension
LippiTests/             # unit and integration coverage
LippiUITests/           # interface scenarios
Scripts/                # local voice provider tooling
```

## Локальный запуск · Run locally

> Репозиторий является проприетарным. Инструкции предназначены только для владельца и авторизованных участников проекта.

1. Откройте `Lippi.xcodeproj` в Xcode.
2. Выберите схему `Lippi` и команду разработки в Signing & Capabilities.
3. Для реальных показателей Apple Здоровья используйте физический iPhone; интерфейс можно проверять в Simulator.
4. Запустите приложение на iOS 18.5 или новее.
5. Откройте **Настройки → ИИ → Локальный интеллект** и подтвердите загрузку Bonsai на iPhone. После проверки модель работает без Mac и облачного AI.
6. Для необязательной локальной neural voice озвучки один раз выполните `./Scripts/install-local-tts.zsh` и держите Mac и iPhone в одной Wi‑Fi сети.

## English

Lippi is a calm productivity and wellbeing app for iPhone. It brings daily planning, Smart Goals, Pomodoro focus, HealthKit insights, Apple Watch signals, eye care, breathing practices, widgets, and voice assistance into one coherent experience.

The product is designed around four promises:

- **A clear next step** instead of an intimidating backlog.
- **Explainable adaptation** that never changes a plan without confirmation.
- **Private wellness processing** on the device.
- **Responsive interaction** that scales visual effects down before they can affect scrolling or battery life.

### Latest release

The July 19 update replaces the Mac-hosted Ollama intelligence path with PrismML Bonsai 4B 1-bit running directly on iPhone through Metal. Lippi now provides an explicit 573 MB model download, progress and pause controls, pinned artifact verification, local readiness testing, and safe model removal while keeping Foundation Models as a system fallback.

[Read the complete bilingual changelog →](CHANGELOG.md)

## Статус · Status

**Active development.** Основной фокус проекта — надёжность на физическом устройстве, ясная визуальная иерархия, бережная персонализация и плавность интерфейса.

## Лицензия · License

Lippi — проприетарное программное обеспечение. Копирование, изменение, сборка, использование и распространение без явного письменного разрешения правообладателя запрещены.

Lippi is proprietary software. Copying, modifying, building, using, or distributing the project without explicit written permission from the copyright holder is prohibited.

[Лицензия на русском](LICENSE.ru.md) · [English license](LICENSE)

---

<div align="center">
  <strong>Built for focus that feels sustainable.</strong><br>
  <sub>Создано для продуктивности, которую можно поддерживать каждый день.</sub>
</div>
