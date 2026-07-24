# Lippi Product Site

Public product site for the Lippi iPhone app, with a separate bilingual privacy
policy for App Store review.

- Primary language: Russian
- Privacy policy: `/privacy`
- Hosting project: declared in `.openai/hosting.json`
- Custom domain: pending owner DNS configuration
- Data services: none

## Local verification

Requires Node.js `>=22.13.0`.

```bash
npm install
npm test
npm run lint
```

`npm test` creates the production build and verifies both the product page and
privacy policy, including navigation, metadata, imagery, support details, and
App Store-facing statements.

## Source map

- `app/page.tsx` — product page and feature showcase
- `app/privacy/page.tsx` — bilingual privacy policy
- `app/globals.css` — responsive visual design
- `tests/rendered-html.test.mjs` — production-output checks for both routes
- `public/showcase/` — product visuals supplied for the Lippi launch site
- `.openai/hosting.json` — existing Sites project binding

The site does not require authentication, store visitor data, or connect to a
database. It is designed to be published under a Lippi-owned custom domain.
