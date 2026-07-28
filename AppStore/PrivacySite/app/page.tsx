import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Фокус, умные цели и забота о себе",
  description:
    "Lippi помогает держать важное в фокусе, строить умные цели, беречь энергию и управлять днём — прямо на iPhone.",
  openGraph: {
    title: "Lippi — ваш день в гармонии",
    description:
      "Фокус, умные цели, голосовой помощник и бережная продуктивность на iPhone.",
    type: "website",
    images: [
      {
        url: "/showcase/introducing-lippi.jpg",
        width: 3072,
        height: 2048,
        alt: "Представляем Lippi — помощника для продуктивности, концентрации и заботы о себе",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Lippi — ваш день в гармонии",
    description:
      "Фокус, умные цели, голосовой помощник и бережная продуктивность на iPhone.",
    images: ["/showcase/introducing-lippi.jpg"],
  },
};

const featureCards = [
  {
    icon: "◎",
    tone: "blue",
    title: "Фокус без лишнего",
    text: "Органайзер и Помодоро помогают начать с главного, выдержать ритм и вовремя сделать паузу.",
  },
  {
    icon: "↗",
    tone: "mint",
    title: "Цели, которые становятся планом",
    text: "Lippi уточняет контекст, разбивает большое на выполнимые этапы и мягко адаптирует маршрут.",
  },
  {
    icon: "◌",
    tone: "violet",
    title: "Помощник, который слышит",
    text: "Добавляйте задачи, запускайте фокус и открывайте нужный раздел естественной голосовой командой.",
  },
  {
    icon: "♡",
    tone: "coral",
    title: "Забота входит в план",
    text: "Сон, активность и восстановление учитываются только с вашего разрешения и остаются под вашим контролем.",
  },
];

const gallery = [
  {
    src: "/showcase/smart-goals.jpg",
    alt: "Умные цели Lippi превращают большую цель в персональный маршрут",
    label: "Умные цели",
    caption: "Из желания — в понятную дорожную карту.",
    className: "gallery-card gallery-card-wide",
  },
  {
    src: "/showcase/voice-assistant.jpg",
    alt: "Голосовой помощник Lippi помогает управлять приложением без рук",
    label: "Голосовой помощник",
    caption: "Когда руки заняты, идеи всё равно попадают в план.",
    className: "gallery-card",
  },
  {
    src: "/showcase/pomodoro.jpg",
    alt: "Таймер Помодоро Lippi с циклами фокуса и перерывами",
    label: "Помодоро",
    caption: "Глубокая работа без забытого отдыха.",
    className: "gallery-card",
  },
  {
    src: "/showcase/widgets.jpg",
    alt: "Виджеты Lippi на экране блокировки iPhone",
    label: "Виджеты",
    caption: "Главное остаётся на виду и всегда под рукой.",
    className: "gallery-card gallery-card-wide",
  },
];

function LippiMark() {
  return (
    <span className="lippi-mark" aria-hidden="true">
      <i />
      <i />
      <i />
      <i />
      <i />
    </span>
  );
}

function Brand() {
  return (
    <span className="brand-lockup">
      <LippiMark />
      <span>Lippi</span>
    </span>
  );
}

function Arrow() {
  return <span aria-hidden="true">↗</span>;
}

export default function Home() {
  return (
    <main className="landing-page">
      <div className="ambient-field" aria-hidden="true">
        <span className="ambient-orb ambient-orb-blue" />
        <span className="ambient-orb ambient-orb-mint" />
        <span className="ambient-orb ambient-orb-violet" />
        <span className="ambient-arc ambient-arc-one" />
        <span className="ambient-arc ambient-arc-two" />
      </div>

      <header className="site-header liquid-glass glass-interactive">
        <a className="brand" href="#top" aria-label="Lippi — на главную">
          <Brand />
        </a>
        <nav className="desktop-nav" aria-label="Навигация по сайту">
          <a href="#possibilities">Возможности</a>
          <a href="#intelligence">Интеллект</a>
          <a href="#privacy">Приватность</a>
        </nav>
        <a
          className="header-cta liquid-glass glass-prominent glass-interactive"
          href="#release"
        >
          Скоро в App Store
        </a>
      </header>

      <section className="landing-hero" id="top">
        <div className="hero-glow hero-glow-blue" aria-hidden="true" />
        <div className="hero-glow hero-glow-mint" aria-hidden="true" />
        <div className="hero-copy">
          <p className="overline">
            <span className="status-dot" aria-hidden="true" />
            Персональный помощник для iPhone
          </p>
          <h1>
            Важное — в фокусе.
            <span>Ваш ритм — в центре.</span>
          </h1>
          <p className="hero-lede">
            Lippi соединяет планы, умные цели, фокус и заботу о себе в одном
            спокойном пространстве. Без лишнего шума и давления.
          </p>
          <div className="hero-actions">
            <a
              className="button button-primary liquid-glass glass-prominent glass-interactive"
              href="#possibilities"
            >
              Познакомиться с Lippi
              <span aria-hidden="true">↓</span>
            </a>
            <Link
              className="button button-secondary liquid-glass glass-interactive"
              href="/privacy"
            >
              Как Lippi хранит данные
            </Link>
          </div>
        </div>

        <figure className="hero-visual">
          <Image
            src="/showcase/day-harmony.jpg"
            alt="Главный экран Lippi с органайзером дня на iPhone"
            width={1536}
            height={1024}
            priority
            sizes="(max-width: 900px) 100vw, 1320px"
          />
          <figcaption className="liquid-glass glass-interactive">
            <span>Один день</span>
            <strong>Один спокойный ритм.</strong>
            <span>Фокус · Прогресс · Забота</span>
          </figcaption>
        </figure>

        <div
          className="trust-row liquid-glass glass-interactive"
          aria-label="Основные преимущества"
        >
          <span>Работает на iPhone</span>
          <span>Локальный интеллект</span>
          <span>Apple Watch и HealthKit</span>
          <span>Русский нейроголос</span>
        </div>
      </section>

      <section className="feature-overview" id="possibilities">
        <div className="section-intro">
          <p className="overline">Продуман до мелочей</p>
          <h2>
            Всё, что помогает двигаться.
            <span>Ничего, что мешает жить.</span>
          </h2>
          <p>
            Lippi подстраивается под ваш день, а не требует подстроить день под
            приложение.
          </p>
        </div>

        <div className="feature-grid">
          {featureCards.map((feature) => (
            <article
              className={`feature-card liquid-panel glass-interactive liquid-panel-${feature.tone}`}
              key={feature.title}
            >
              <span className={`feature-icon feature-icon-${feature.tone}`}>
                {feature.icon}
              </span>
              <h3>{feature.title}</h3>
              <p>{feature.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section
        className="intelligence-story liquid-panel story-panel"
        id="intelligence"
      >
        <div className="story-copy">
          <p className="overline">Интеллект Lippi</p>
          <h2>
            Понимает намерение.
            <span>Помогает сделать первый шаг.</span>
          </h2>
          <p>
            Опишите, чего хотите добиться, своими словами. Lippi учитывает
            пожелания, доступное время и текущий ритм, чтобы предложить
            содержательный маршрут — с конкретикой, а не общими фразами.
          </p>
          <ul className="check-list">
            <li>Уточняет смысл и контекст цели</li>
            <li>Строит этапы, задачи и полезные ориентиры</li>
            <li>Адаптирует нагрузку без потери направления</li>
          </ul>
        </div>
        <figure className="story-image">
          <Image
            src="/showcase/adaptive-goals.jpg"
            alt="Lippi адаптирует умные цели в фоне под прогресс пользователя"
            width={1536}
            height={1024}
            sizes="(max-width: 900px) 100vw, 58vw"
          />
        </figure>
      </section>

      <section className="showcase-section" aria-labelledby="showcase-title">
        <div className="section-intro section-intro-centered">
          <p className="overline">Ближе к вашему дню</p>
          <h2 id="showcase-title">
            Возможности, которые
            <span>ощущаются естественно.</span>
          </h2>
        </div>

        <div className="gallery-grid">
          {gallery.map((item) => (
            <figure
              className={`${item.className} liquid-panel glass-interactive`}
              key={item.src}
            >
              <div className="gallery-image">
                <Image
                  src={item.src}
                  alt={item.alt}
                  width={1536}
                  height={1024}
                  sizes={
                    item.className.includes("wide")
                      ? "(max-width: 900px) 100vw, 1200px"
                      : "(max-width: 900px) 100vw, 50vw"
                  }
                />
              </div>
              <figcaption>
                <span>{item.label}</span>
                <strong>{item.caption}</strong>
              </figcaption>
            </figure>
          ))}
        </div>
      </section>

      <section className="ecosystem-section liquid-panel story-panel">
        <figure className="ecosystem-image">
          <Image
            src="/showcase/watch-health.jpg"
            alt="Интеграция Lippi с Apple Watch и Apple Здоровьем"
            width={1536}
            height={1024}
            sizes="(max-width: 900px) 100vw, 58vw"
          />
        </figure>
        <div className="ecosystem-copy">
          <p className="overline">Ваш ритм — в центре плана</p>
          <h2>
            iPhone, часы и самочувствие.
            <span>В одном бережном контексте.</span>
          </h2>
          <p>
            Если вы разрешите, Lippi учитывает доступные показатели Apple
            Здоровья и предлагает темп, который поддерживает продуктивность, а
            не выжимает её.
          </p>
          <div className="mini-points">
            <span>Рекомендации на iPhone</span>
            <span>Напоминания на Apple Watch</span>
            <span>Каждое разрешение — под вашим контролем</span>
          </div>
        </div>
      </section>

      <section
        className="privacy-section liquid-panel story-panel"
        id="privacy"
      >
        <div className="privacy-copy">
          <p className="overline">Приватность по умолчанию</p>
          <h2>
            Ваши цели остаются
            <span>на вашем iPhone.</span>
          </h2>
          <p>
            Локальная модель Bonsai создаёт планы прямо на устройстве. Lippi не
            строит рекламный профиль, не отслеживает вас между приложениями и
            не отправляет текст целей внешнему ИИ.
          </p>
          <Link className="text-link" href="/privacy">
            Прочитать политику конфиденциальности
            <Arrow />
          </Link>
        </div>
        <figure className="privacy-image">
          <Image
            src="/showcase/local-intelligence.jpg"
            alt="Локальный интеллект Lippi работает на iPhone и сохраняет приватность"
            width={1536}
            height={1024}
            sizes="(max-width: 900px) 100vw, 58vw"
          />
        </figure>
      </section>

      <section className="release-section" id="release">
        <div className="release-visual">
          <Image
            src="/showcase/introducing-lippi.jpg"
            alt="Представляем Lippi — помощника для продуктивности, концентрации и заботы о себе"
            width={3072}
            height={2048}
            sizes="(max-width: 900px) 100vw, 1200px"
            quality={100}
            unoptimized
          />
        </div>
        <div className="release-copy liquid-glass glass-interactive">
          <span className="release-pill">Скоро в App Store</span>
          <h2>Спокойнее планировать. Увереннее двигаться.</h2>
          <p>
            Lippi готовится к первому релизу для iPhone. А пока можно
            познакомиться с возможностями и задать вопрос разработчику.
          </p>
          <a
            className="button button-primary liquid-glass glass-prominent glass-interactive"
            href="https://github.com/BlackSnaker/Lippi/issues"
            rel="noreferrer"
          >
            Связаться с поддержкой
            <Arrow />
          </a>
        </div>
      </section>

      <footer className="site-footer">
        <a className="brand footer-brand" href="#top">
          <Brand />
        </a>
        <div className="footer-links">
          <a href="#possibilities">Возможности</a>
          <Link href="/privacy">Конфиденциальность</Link>
          <a
            href="https://github.com/BlackSnaker/Lippi/issues"
            rel="noreferrer"
          >
            Поддержка
          </a>
        </div>
        <p>© 2026 Lippi. Сделано с заботой о вашем внимании.</p>
      </footer>
    </main>
  );
}
