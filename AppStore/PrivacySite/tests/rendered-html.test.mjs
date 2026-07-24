import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
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

test("server-renders the public bilingual Lippi privacy policy", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Privacy Policy — Lippi · Lippi<\/title>/i);
  assert.match(
    html,
    /<meta[^>]+name="description"[^>]+How Lippi keeps goals[^>]+private/i,
  );
  assert.match(html, /<meta[^>]+property="og:image"[^>]+\/og\.png/i);
  assert.match(html, /<article[^>]+id="english"/i);
  assert.match(html, /<article[^>]+id="russian"[^>]+lang="ru"/i);
  assert.match(html, /Lippi Privacy Policy/);
  assert.match(html, /Политика конфиденциальности Lippi/);
  assert.match(html, /No ads\. No tracking\. No sale of personal data\./);
  assert.match(html, /does not send HealthKit data to external AI providers/i);
  assert.match(html, /не передаёт их внешним ИИ-провайдерам/i);
  assert.match(html, /https:\/\/github\.com\/BlackSnaker\/Lippi\/issues/);
  assert.match(html, /July 24, 2026/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("keeps App Store-facing policy metadata and hosting explicit", async () => {
  const [layout, page, packageJson, hosting] = await Promise.all([
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../.openai/hosting.json", import.meta.url), "utf8"),
  ]);

  assert.match(
    layout,
    /https:\/\/lippi-privacy\.contu4575gazeta-pl\.chatgpt\.site/,
  );
  assert.match(layout, /default:\s*"Lippi — Privacy Policy"/);
  assert.match(layout, /card:\s*"summary_large_image"/);
  assert.match(page, /const effectiveDate = "July 24, 2026"/);
  assert.match(page, /href="#english"/);
  assert.match(page, /href="#russian"/);
  assert.match(page, /no third-party\s+analytics SDK/i);
  assert.match(
    page,
    /не отслеживает вас между приложениями и сайтами/i,
  );
  assert.match(packageJson, /"name": "lippi-privacy-site"/);

  const hostingConfig = JSON.parse(hosting);
  assert.equal(
    hostingConfig.project_id,
    "appgprj_6a633f975b988191ae45d47947737531",
  );
  assert.equal(hostingConfig.d1, null);
  assert.equal(hostingConfig.r2, null);
});
