import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set(
    "test",
    `${process.pid}-${Date.now()}-${pathname.replaceAll("/", "-")}`,
  );
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Lippi product page with the supplied showcase", async () => {
  const response = await render("/");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(
    html,
    /<title>Lippi — Фокус, умные цели и забота о себе<\/title>/i,
  );
  assert.match(
    html,
    /<meta[^>]+name="description"[^>]+Lippi помогает держать важное в фокусе/i,
  );
  assert.match(
    html,
    /<meta[^>]+property="og:image"[^>]+showcase\/introducing-lippi\.jpg/i,
  );
  assert.match(html, /Важное — в фокусе\./);
  assert.match(html, /Возможности, которые/);
  assert.match(html, /Ваши цели остаются/);
  assert.match(html, /href="\/privacy"/i);
  assert.match(html, /href="#possibilities"/i);
  assert.match(html, /href="#intelligence"/i);
  assert.match(html, /src="\/motion\.js"/i);
  assert.match(html, /class="ambient-field"/i);
  assert.match(html, /liquid-glass/i);
  assert.match(html, /liquid-panel/i);
  assert.match(html, /https:\/\/github\.com\/BlackSnaker\/Lippi\/issues/);

  for (const imageName of [
    "introducing-lippi",
    "day-harmony",
    "watch-health",
    "smart-goals",
    "voice-assistant",
    "pomodoro",
    "widgets",
    "adaptive-goals",
    "local-intelligence",
  ]) {
    assert.match(html, new RegExp(`showcase/${imageName}\\.jpg`, "i"));
  }

  assert.doesNotMatch(html, /ChatGPT/i);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("keeps the bilingual App Store privacy policy on its own route", async () => {
  const response = await render("/privacy");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(
    html,
    /<title>Lippi — Политика конфиденциальности \/ Privacy Policy<\/title>/i,
  );
  assert.match(html, /<article[^>]+id="english"/i);
  assert.match(html, /<article[^>]+id="russian"[^>]+lang="ru"/i);
  assert.match(html, /Lippi Privacy Policy/);
  assert.match(html, /Политика конфиденциальности Lippi/);
  assert.match(html, /No ads\. No tracking\. No sale of personal data\./);
  assert.match(html, /does not send HealthKit data to external AI providers/i);
  assert.match(html, /не передаёт их внешним ИИ-провайдерам/i);
  assert.match(html, /https:\/\/github\.com\/BlackSnaker\/Lippi\/issues/);
  assert.match(html, /July 24, 2026/);
  assert.doesNotMatch(html, /ChatGPT/i);
});

test("keeps product metadata, hosting, and image assets explicit", async () => {
  const [layout, page, privacyPage, motion, packageJson, hosting] =
    await Promise.all([
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/privacy/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../public/motion.js", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
  ]);

  assert.match(layout, /default:\s*"Lippi — Фокус, умные цели/);
  assert.match(layout, /template:\s*"Lippi — %s"/);
  assert.match(layout, /<html lang="ru">/);
  assert.match(layout, /src="\/motion\.js"/);
  assert.doesNotMatch(layout, /chatgpt\.site/i);
  assert.match(page, /title:\s*"Фокус, умные цели и забота о себе"/);
  assert.match(page, /Скоро в App Store/);
  assert.match(page, /href="\/privacy"/);
  assert.match(privacyPage, /const effectiveDate = "July 24, 2026"/);
  assert.match(privacyPage, /href="#english"/);
  assert.match(privacyPage, /href="#russian"/);
  assert.match(privacyPage, /no third-party\s+analytics SDK/i);
  assert.match(
    privacyPage,
    /не отслеживает вас между приложениями и сайтами/i,
  );
  assert.match(packageJson, /"name": "lippi-product-site"/);
  assert.match(motion, /IntersectionObserver/);
  assert.match(motion, /prefers-reduced-motion/);
  assert.match(motion, /requestAnimationFrame/);
  assert.match(motion, /nav-glass-indicator/);
  assert.match(motion, /--glass-x/);

  const hostingConfig = JSON.parse(hosting);
  assert.equal(
    hostingConfig.project_id,
    "appgprj_6a633f975b988191ae45d47947737531",
  );
  assert.equal(hostingConfig.d1, null);
  assert.equal(hostingConfig.r2, null);

  const imageStats = await Promise.all(
    [
      "introducing-lippi",
      "day-harmony",
      "watch-health",
      "smart-goals",
      "voice-assistant",
      "pomodoro",
      "widgets",
      "adaptive-goals",
      "local-intelligence",
    ].map((name) =>
      stat(new URL(`../public/showcase/${name}.jpg`, import.meta.url)),
    ),
  );

  for (const imageStat of imageStats) {
    assert.ok(imageStat.size > 50_000);
  }
});
