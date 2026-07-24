import assert from "node:assert/strict";
import {
  cp,
  mkdir,
  readFile,
  readdir,
  rm,
  unlink,
  writeFile,
} from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputRoot = resolve(projectRoot, "static-export");
const clientRoot = resolve(projectRoot, "dist/client");
const workerPath = resolve(projectRoot, "dist/server/index.js");

async function render(pathname) {
  const workerUrl = pathToFileURL(workerPath);
  workerUrl.searchParams.set(
    "staticExport",
    `${process.pid}-${Date.now()}-${pathname.replaceAll("/", "-")}`,
  );
  const { default: worker } = await import(workerUrl.href);

  const response = await worker.fetch(
    new Request(`https://lippi.lenuma.ru${pathname}`, {
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

  assert.equal(response.status, 200, `Unable to render ${pathname}`);
  return response.text();
}

function makeStatic(html, pathname) {
  const canonicalUrl = new URL(pathname, "https://lippi.lenuma.ru").href;

  return html
    .replace(
      /<link rel="preload" as="image"[^>]*\/>/g,
      '<link rel="preload" as="image" href="/showcase/day-harmony.jpg"/>',
    )
    .replace(/<link rel="modulepreload"[^>]*\/?>/g, "")
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/g, "")
    .replace(/\s+srcSet="[^"]*"/g, "")
    .replace(/\s+data-nimg="1"/g, "")
    .replace(
      /\/_vinext\/image\?url=%2Fshowcase%2F([^&"]+)&amp;w=\d+&amp;q=\d+/g,
      "/showcase/$1",
    )
    .replace(
      "</head>",
      `<link rel="canonical" href="${canonicalUrl}"/></head>`,
    );
}

async function exportPage(pathname, destination) {
  const html = makeStatic(await render(pathname), pathname);
  assert.doesNotMatch(html, /chatgpt|openai/i);
  assert.doesNotMatch(html, /_vinext\/image/i);
  assert.doesNotMatch(html, /<script\b/i);
  assert.match(html, /href="\/assets\/[^"]+\.css"/i);

  const outputPath = resolve(outputRoot, destination);
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, html, "utf8");
}

await rm(outputRoot, { force: true, recursive: true });
await mkdir(outputRoot, { recursive: true });
await cp(clientRoot, outputRoot, { recursive: true });
await rm(resolve(outputRoot, ".vite"), { force: true, recursive: true });
await rm(resolve(outputRoot, "_headers"), { force: true });
await rm(resolve(outputRoot, ".assetsignore"), { force: true });

const exportedFiles = await readdir(outputRoot, {
  recursive: true,
  withFileTypes: true,
});
await Promise.all(
  exportedFiles
    .filter((entry) => entry.isFile() && entry.name.endsWith(".js"))
    .map((entry) => unlink(resolve(entry.parentPath, entry.name))),
);

await Promise.all([
  exportPage("/", "index.html"),
  exportPage("/privacy", "privacy/index.html"),
  writeFile(
    resolve(outputRoot, ".htaccess"),
    [
      "DirectoryIndex index.html",
      "Options -Indexes",
      "",
      "<IfModule mod_headers.c>",
      '  Header always set X-Content-Type-Options "nosniff"',
      '  Header always set Referrer-Policy "strict-origin-when-cross-origin"',
      '  Header always set X-Frame-Options "SAMEORIGIN"',
      "</IfModule>",
      "",
    ].join("\n"),
    "utf8",
  ),
]);

for (const requiredFile of [
  "index.html",
  "privacy/index.html",
  "favicon.svg",
  "showcase/introducing-lippi.jpg",
]) {
  await readFile(resolve(outputRoot, requiredFile));
}

console.log(`Static site exported to ${outputRoot}`);
