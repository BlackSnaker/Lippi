# Lippi Privacy

Public bilingual privacy policy for the Lippi App Store product page.

- Production: https://lippi-privacy.contu4575gazeta-pl.chatgpt.site
- Languages: Russian and English
- Hosting project: declared in `.openai/hosting.json`
- Data services: none

## Local verification

Requires Node.js `>=22.13.0`.

```bash
npm install
npm test
npm run lint
```

`npm test` creates the production build and verifies the rendered privacy
content, navigation anchors, contact details, and App Store-facing statements.

## Source map

- `app/page.tsx` — policy content and page structure
- `app/globals.css` — responsive visual design
- `tests/rendered-html.test.mjs` — production-output checks
- `public/og.png` — social preview
- `.openai/hosting.json` — existing Sites project binding

The site is intentionally public and does not require authentication, store
visitor data, or connect to a database.
