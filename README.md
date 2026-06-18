# Lippi

<div align="center">
  <p><strong>Personal focus, health routines, and voice assistance in one iPhone app.</strong></p>
  <p>
    <a href="#english">English</a>
    ·
    <a href="#русский">Русский</a>
  </p>
  <p>
    <img alt="iOS" src="https://img.shields.io/badge/iOS-18.5%2B-0A84FF?style=for-the-badge">
    <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-FA7343?style=for-the-badge">
    <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-111111?style=for-the-badge">
    <img alt="Widgets" src="https://img.shields.io/badge/Widgets-Yes-2D9C5E?style=for-the-badge">
    <img alt="License" src="https://img.shields.io/badge/License-Proprietary%20(All%20Rights%20Reserved)-B00020?style=for-the-badge">
  </p>
</div>

---

## License Notice / Лицензионное уведомление

<table>
  <tr>
    <td width="50%" align="left" valign="top">
      <strong>English</strong><br>
      This repository is proprietary. Copying, modifying, building, using, and distributing the code without explicit written permission from the copyright holder is strictly prohibited.
      <br><br>
      Full terms:
      <a href="LICENSE"><code>LICENSE (EN)</code></a>,
      <a href="LICENSE.ru.md"><code>LICENSE.ru.md (RU)</code></a>
    </td>
    <td width="50%" align="left" valign="top">
      <strong>Русский</strong><br>
      Этот репозиторий является проприетарным. Копирование, изменение, сборка, использование и распространение кода без явного письменного разрешения правообладателя строго запрещены.
      <br><br>
      Полные условия:
      <a href="LICENSE.ru.md"><code>LICENSE.ru.md (RU)</code></a>,
      <a href="LICENSE"><code>LICENSE (EN)</code></a>
    </td>
  </tr>
</table>

---

## Screenshots / Скриншоты

<p align="center">
  <img src="docs/screenshots/01-home.png" alt="Lippi Home" width="220">
  <img src="docs/screenshots/02-tasks.png" alt="Lippi Tasks" width="220">
  <img src="docs/screenshots/03-health-breathing.png" alt="Lippi Health Breathing" width="220">
</p>

<p align="center">
  <img src="docs/screenshots/04-health-analytics.png" alt="Lippi Health Analytics" width="220">
  <img src="docs/screenshots/05-eyes.png" alt="Lippi Eyes" width="220">
  <img src="docs/screenshots/06-settings.png" alt="Lippi Settings" width="220">
</p>

<p align="center">
  <img src="docs/screenshots/07-assistant.png" alt="Lippi Voice Assistant" width="220">
</p>

<p align="center"><sub>Home · Tasks · Health · Health Analytics · Eyes · Settings · Voice Assistant</sub></p>

---

## Latest Changes / Последние изменения

<div align="center">
  <p>
    <img alt="Update" src="https://img.shields.io/badge/Update-June%2018%2C%202026-0A84FF?style=for-the-badge">
    <img alt="Design" src="https://img.shields.io/badge/Design-Liquid%20Glass-64D2FF?style=for-the-badge">
    <img alt="Simulator" src="https://img.shields.io/badge/Checked-iPhone%2017%20Simulator-30D158?style=for-the-badge">
  </p>
</div>

<table>
  <tr>
    <td width="50%" align="left" valign="top">
      <h3>English</h3>
      <p><strong>Design and interaction update focused on clarity, system feel, and smooth daily use.</strong></p>
      <ul>
        <li><strong>More system Liquid Glass everywhere:</strong> cards, buttons, tabs, chips, input fields, task rows, settings, auth, Pomodoro, Health, Eye Health, Break, and assistant surfaces now share a stronger native glass layer.</li>
        <li><strong>Redesigned Today screen:</strong> clearer daily status, main focus panel, progress badge, quick actions, and compact day-plan rows make the home screen easier to scan.</li>
        <li><strong>Better information hierarchy:</strong> longer Russian labels now wrap more gracefully, key actions stay closer to the thumb, and status chips make the current day state obvious.</li>
        <li><strong>Dynamic Island polish:</strong> Pomodoro and task Live Activities use richer glass panels, clearer progress, compact controls, and app-matched visual tones.</li>
        <li><strong>Performance-minded visuals:</strong> glass effects remain enabled for modern 60 FPS devices, while Low Power Mode, thermal pressure, and Reduce Transparency still get safer lightweight rendering.</li>
        <li><strong>Verified build:</strong> the app builds successfully for iOS Simulator with the current Xcode toolchain.</li>
      </ul>
    </td>
    <td width="50%" align="left" valign="top">
      <h3>Русский</h3>
      <p><strong>Обновление дизайна и взаимодействий с акцентом на читаемость, системность и плавное ежедневное использование.</strong></p>
      <ul>
        <li><strong>Больше системного Liquid Glass во всем приложении:</strong> карточки, кнопки, таббар, чипы, поля ввода, строки задач, настройки, вход, Pomodoro, Health, Eye Health, Break и ассистент получили единый более выразительный стеклянный слой.</li>
        <li><strong>Новый главный экран Today:</strong> понятный статус дня, панель главного фокуса, индикатор прогресса, быстрые действия и компактный план дня помогают быстрее считывать информацию.</li>
        <li><strong>Лучше иерархия информации:</strong> длинные русские подписи аккуратнее переносятся, важные действия ближе к пальцу, а статусные чипы сразу показывают состояние дня.</li>
        <li><strong>Полировка Dynamic Island:</strong> Live Activity для Pomodoro и задач получила более богатые стеклянные панели, понятный прогресс, компактные действия и визуальный стиль Lippi.</li>
        <li><strong>Визуалы с учетом производительности:</strong> glass-эффекты включены для современных 60 FPS устройств, а Low Power Mode, перегрев и Reduce Transparency по-прежнему используют более легкий рендеринг.</li>
        <li><strong>Проверенная сборка:</strong> приложение успешно собирается для iOS Simulator на текущем Xcode toolchain.</li>
      </ul>
    </td>
  </tr>
</table>

---

## English

### Product Overview
Lippi is a polished iOS productivity and wellbeing app that combines task planning, Pomodoro focus sessions, eye-care breaks, breathing recovery, health analytics, and a built-in voice assistant.  
The goal is simple: help users stay focused, recover faster, and keep a sustainable daily rhythm.

### Key Features
- Daily workflow: task planning, "Today" screen, and quick progress tracking.
- Focus engine: Pomodoro sessions, customizable timer behavior, and ringtone selection.
- Health tools: eye exercise section, breathing and recovery routines, concise analytics.
- Voice assistant: fast in-app actions, command recognition, and spoken guidance.
- Widgets: home/lock-screen widgets with useful quick entry points.
- Personalization: dynamic themes, adaptive full-screen backgrounds, liquid-glass style.
- Localization: Russian, English, German, and Spanish across the app.

### Technical Highlights
- Modular feature structure (`Features`, `Core`, `UI`, `Widgets`).
- SwiftUI-first architecture with reusable design system components.
- WidgetKit integration for glanceable productivity and assistant access.
- Localized language environment and shared app/widget bridge keys.

### Project Structure
- `Lippi/` - main iOS app target
- `Lippi/Features/` - product features (Today, Tasks, Health, Assistant, Settings, etc.)
- `Lippi/Core/` - localization, auth, theme, shared services
- `Lippi/UI/` - design system and reusable visual components
- `LippiWidgets/`, `OrganizerWidget/` - widget extensions
- `LippiTests/`, `LippiUITests/` - tests

### Run Locally
1. Clone the repository.
2. Open `Lippi.xcodeproj` in Xcode.
3. Select the `Lippi` scheme.
4. Build and run on iPhone or Simulator with iOS 18.5+.

### Status
Active development. UI quality, performance smoothness, and assistant intelligence are continuously improved.

### License
Proprietary software. All rights reserved.  
Copying, modifying, building, using, and distributing this project are strictly prohibited for third parties without explicit written permission from the copyright holder.  
Full texts: `LICENSE` (English), `LICENSE.ru.md` (Russian).

---

## Русский

### Описание продукта
Lippi - это аккуратное iOS-приложение для продуктивности и восстановления, которое объединяет планирование задач, Pomodoro-фокус, разминку глаз, дыхательные практики, аналитику здоровья и встроенного голосового помощника.  
Главная цель: помочь пользователю сохранять концентрацию, быстрее восстанавливаться и держать стабильный ритм дня.

### Ключевые возможности
- Ежедневная продуктивность: задачи, экран "Сегодня", быстрый контроль прогресса.
- Фокус-движок: Pomodoro-сессии, гибкие настройки таймера и выбор рингтонов.
- Инструменты здоровья: раздел для глаз, дыхание и восстановление, лаконичная аналитика.
- Голосовой помощник: быстрые команды внутри приложения и голосовые ответы.
- Виджеты: удобные виджеты для домашнего экрана и экрана блокировки.
- Персонализация: темы оформления, адаптивный фон на весь экран, liquid-glass стиль.
- Локализация: русский, английский, немецкий и испанский языки.

### Технические особенности
- Модульная структура (`Features`, `Core`, `UI`, `Widgets`).
- Архитектура на SwiftUI с переиспользуемой дизайн-системой.
- Интеграция с WidgetKit для быстрого доступа к ключевым функциям.
- Единая система локализации и общие ключи для связи приложения и виджетов.

### Структура проекта
- `Lippi/` - основной таргет iOS-приложения
- `Lippi/Features/` - модули функций (Today, Tasks, Health, Assistant, Settings и др.)
- `Lippi/Core/` - локализация, авторизация, темы, общие сервисы
- `Lippi/UI/` - дизайн-система и переиспользуемые визуальные компоненты
- `LippiWidgets/`, `OrganizerWidget/` - расширения виджетов
- `LippiTests/`, `LippiUITests/` - тесты

### Локальный запуск
1. Склонируйте репозиторий.
2. Откройте `Lippi.xcodeproj` в Xcode.
3. Выберите схему `Lippi`.
4. Запустите на iPhone или Simulator с iOS 18.5+.

### Статус
Проект активно развивается: улучшаются качество интерфейса, плавность работы и интеллект помощника.

### Лицензия
Проприетарное ПО. Все права защищены.  
Копирование, изменение, сборка, использование и распространение проекта третьими лицами строго запрещены без явного письменного разрешения правообладателя.  
Полные тексты: `LICENSE.ru.md` (русский), `LICENSE` (английский).
