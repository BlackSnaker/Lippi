import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Lippi",
  description:
    "How Lippi keeps goals, health context, voice interactions, and local intelligence private.",
};

const effectiveDate = "July 24, 2026";

function Mark() {
  return (
    <span className="mark" aria-hidden="true">
      <span />
    </span>
  );
}

function SummaryCard({
  eyebrow,
  title,
  body,
}: {
  eyebrow: string;
  title: string;
  body: string;
}) {
  return (
    <article className="summary-card">
      <p className="eyebrow">{eyebrow}</p>
      <h3>{title}</h3>
      <p>{body}</p>
    </article>
  );
}

export default function Home() {
  return (
    <main>
      <nav aria-label="Privacy policy navigation">
        <a className="brand" href="#top" aria-label="Lippi privacy policy">
          <Mark />
          <span>Lippi</span>
        </a>
        <div className="nav-links">
          <a href="#english">English</a>
          <a href="#russian">Русский</a>
        </div>
      </nav>

      <section className="hero" id="top">
        <div className="hero-orb" aria-hidden="true">
          <div className="shield">L</div>
        </div>
        <p className="kicker">Privacy, by design</p>
        <h1>Your day stays yours.</h1>
        <p className="lede">
          Lippi is designed around on-device intelligence, clear permission
          boundaries, and data minimization. No ads. No tracking. No sale of
          personal data.
        </p>
        <p className="date">Effective {effectiveDate}</p>
      </section>

      <section className="summary-grid" aria-label="Privacy highlights">
        <SummaryCard
          eyebrow="On device"
          title="Personal by default"
          body="Your account, plans, goals, progress, and wellbeing context are stored locally on your device."
        />
        <SummaryCard
          eyebrow="Your choice"
          title="Permission first"
          body="Health, microphone, and speech access only begin after you choose to grant the relevant system permission."
        />
        <SummaryCard
          eyebrow="No profiling"
          title="Nothing to follow"
          body="Lippi contains no advertising SDKs, third-party analytics, or cross-app tracking."
        />
      </section>

      <article className="policy" id="english">
        <header className="section-heading">
          <p className="eyebrow">English</p>
          <h2>Lippi Privacy Policy</h2>
          <p>
            This policy explains what information Lippi processes, where that
            processing happens, and the controls available to you.
          </p>
        </header>

        <section>
          <h3>1. Information Lippi processes</h3>
          <p>
            Depending on the features you use, Lippi may process the name and
            email you enter for a local account; tasks, goals, routines,
            progress, focus sessions, and app preferences; voice commands;
            and Apple Health information you explicitly authorize.
          </p>
          <p>
            This information supports the features you request. It is not used
            to build advertising profiles or sold to anyone.
          </p>
        </section>

        <section>
          <h3>2. Local accounts and storage</h3>
          <p>
            Lippi accounts are local to the app. Account records, including a
            one-way password hash, are kept in the app container; the active
            session is protected by the Apple Keychain. Tasks, goals, settings,
            and progress remain in the app container or Lippi&apos;s shared App
            Group for its widgets.
          </p>
          <p>
            Removing the app normally removes its app-container data. Keychain
            behavior is controlled by the operating system. You can also stop
            using a feature, revoke permissions in iOS Settings, or delete
            downloaded AI and voice models from Lippi.
          </p>
        </section>

        <section>
          <h3>3. Apple Health and Apple Watch</h3>
          <p>
            If you opt in, Lippi reads only the HealthKit categories shown in
            Apple&apos;s permission sheet and may save completed breathing
            practices as mindful sessions. Health information is used on your
            device to shape gentle planning and wellbeing suggestions. Lippi
            does not send HealthKit data to external AI providers, advertisers,
            or analytics services.
          </p>
          <p>
            Lippi provides general wellbeing support and is not a medical
            device, diagnosis, or substitute for professional care.
          </p>
        </section>

        <section>
          <h3>4. Voice and local intelligence</h3>
          <p>
            Lippi&apos;s neural voice and Bonsai intelligence models run on your
            device after their model files are downloaded. Goal text and model
            output stay local. Voice recognition uses Apple&apos;s Speech
            framework. On-device recognition is required whenever the device
            supports it; where the operating system cannot provide it, Apple
            may process speech under Apple&apos;s own privacy terms. Lippi does
            not keep raw microphone audio after a command finishes.
          </p>
        </section>

        <section>
          <h3>5. Network access</h3>
          <p>
            Lippi makes limited network requests to download optional AI and
            voice model files from their published sources and to retrieve
            public reference pages used to ground certain Smart Goal roadmaps.
            These requests do not include your goal text, health information,
            account details, or voice recordings. Like ordinary internet
            requests, the destination may receive technical information such as
            an IP address and request headers under its own privacy policy.
          </p>
        </section>

        <section>
          <h3>6. Sharing, tracking, and retention</h3>
          <p>
            Lippi does not sell personal data, share it for targeted
            advertising, or track you across apps and websites. Lippi has no
            developer-operated cloud account database and no third-party
            analytics SDK. Locally stored information remains until you delete
            it, reset the relevant feature, or remove the app, subject to normal
            iOS and Keychain behavior.
          </p>
        </section>

        <section>
          <h3>7. Children and changes</h3>
          <p>
            Lippi is a general productivity and wellbeing app and is not
            directed to children under 13. We may update this policy when Lippi
            changes or legal requirements evolve. The effective date above will
            always identify the current version.
          </p>
        </section>

        <section>
          <h3>8. Contact</h3>
          <p>
            For privacy questions, support requests, or deletion guidance,
            contact the Lippi developer through the project&apos;s{" "}
            <a
              href="https://github.com/BlackSnaker/Lippi/issues"
              rel="noreferrer"
            >
              public support page
            </a>
            .
          </p>
        </section>
      </article>

      <article className="policy" id="russian" lang="ru">
        <header className="section-heading">
          <p className="eyebrow">Русский</p>
          <h2>Политика конфиденциальности Lippi</h2>
          <p>
            Здесь описано, какие данные обрабатывает Lippi, где происходит
            обработка и чем управляете вы.
          </p>
        </header>

        <section>
          <h3>1. Какие данные обрабатывает Lippi</h3>
          <p>
            В зависимости от выбранных функций Lippi может обрабатывать имя и
            email локального аккаунта, задачи, цели, привычки, прогресс,
            фокус-сессии и настройки, голосовые команды, а также данные Apple
            Здоровья, к которым вы отдельно разрешили доступ.
          </p>
          <p>
            Эти сведения нужны только для выбранных вами функций. Они не
            используются для рекламного профилирования и никому не продаются.
          </p>
        </section>

        <section>
          <h3>2. Локальный аккаунт и хранение</h3>
          <p>
            Аккаунт Lippi существует только внутри приложения. Данные аккаунта,
            включая односторонний хеш пароля, хранятся в контейнере приложения,
            а активная сессия защищена Apple Keychain. Задачи, цели, настройки и
            прогресс остаются в контейнере Lippi или в общей App Group,
            необходимой для виджетов.
          </p>
          <p>
            При удалении приложения iOS обычно удаляет данные его контейнера.
            Поведение Keychain определяется операционной системой. Вы можете
            отключить функцию, отозвать разрешение в настройках iOS или удалить
            загруженные модели ИИ и голоса в Lippi.
          </p>
        </section>

        <section>
          <h3>3. Apple Здоровье и Apple Watch</h3>
          <p>
            После вашего согласия Lippi читает только категории HealthKit,
            показанные в системном окне Apple, и может сохранять завершённые
            дыхательные практики как минуты осознанности. Данные здоровья
            обрабатываются на устройстве и помогают составлять бережные планы.
            Lippi не передаёт их внешним ИИ-провайдерам, рекламе или аналитике.
          </p>
          <p>
            Lippi даёт общие рекомендации для самочувствия и не является
            медицинским устройством, диагнозом или заменой специалиста.
          </p>
        </section>

        <section>
          <h3>4. Голос и локальный интеллект</h3>
          <p>
            Нейроголос Lippi и модель Bonsai работают на устройстве после
            загрузки файлов моделей. Текст целей и ответы модели остаются
            локальными. Для распознавания используется Speech framework Apple.
            Когда устройство поддерживает локальное распознавание, Lippi
            требует именно его; в остальных случаях речь может обрабатываться
            Apple по собственным условиям конфиденциальности. Lippi не хранит
            исходную запись микрофона после завершения команды.
          </p>
        </section>

        <section>
          <h3>5. Доступ к сети</h3>
          <p>
            Lippi обращается к сети, чтобы скачать необязательные модели ИИ и
            голоса из их официальных источников, а также получить публичные
            справочные страницы для некоторых дорожных карт «Умных целей». В
            эти запросы не включаются текст вашей цели, данные здоровья, данные
            аккаунта или записи голоса. Как и при любом интернет-запросе,
            получатель может видеть IP-адрес и технические заголовки согласно
            собственной политике.
          </p>
        </section>

        <section>
          <h3>6. Передача, отслеживание и срок хранения</h3>
          <p>
            Lippi не продаёт данные, не передаёт их для таргетированной рекламы
            и не отслеживает вас между приложениями и сайтами. У Lippi нет
            облачной базы аккаунтов разработчика и сторонних SDK аналитики.
            Локальные сведения хранятся, пока вы не удалите их, не сбросите
            соответствующую функцию или не удалите приложение, с учётом
            обычного поведения iOS и Keychain.
          </p>
        </section>

        <section>
          <h3>7. Дети и изменения</h3>
          <p>
            Lippi — универсальное приложение для продуктивности и самочувствия,
            не предназначенное специально для детей младше 13 лет. Политика
            может обновляться вместе с приложением или требованиями закона.
            Текущую версию всегда показывает дата в начале страницы.
          </p>
        </section>

        <section>
          <h3>8. Связаться с нами</h3>
          <p>
            По вопросам конфиденциальности, поддержки или удаления данных
            напишите разработчику Lippi через{" "}
            <a
              href="https://github.com/BlackSnaker/Lippi/issues"
              rel="noreferrer"
            >
              публичную страницу поддержки
            </a>
            .
          </p>
        </section>
      </article>

      <footer>
        <a className="brand" href="#top">
          <Mark />
          <span>Lippi</span>
        </a>
        <p>Private focus. Thoughtful progress.</p>
        <p>© 2026 Lippi. All rights reserved.</p>
      </footer>
    </main>
  );
}
