# React / Vite — Security Reference

React/Vite-specific traps that the generic frontend reference doesn't cover.
Read `references/frontend.md` first; this file adds the layer-specific detail.

---

## §secrets — VITE_ env var leakage

**Threat:** Any environment variable prefixed `VITE_` is statically inlined
into the client bundle at build time by Vite. It is public. Every user who
downloads your app has it.

```ts
// ❌ secret is now in every user's browser
const key = import.meta.env.VITE_STRIPE_SECRET_KEY;
const adminToken = import.meta.env.VITE_ADMIN_API_KEY;
```

```ts
// ✅ secret stays server-side (Cloud Function / backend)
// Only publishable/designed-public values belong in VITE_ vars:
const publishableKey = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY; // fine
const projectId = import.meta.env.VITE_FIREBASE_PROJECT_ID;         // fine — web config is public
```

**Review notes:**
- `import.meta.env.VITE_*` → always check the value. Is this a *real secret*
  or a *designed-public* value?
- Firebase web config (`apiKey`, `authDomain`, `projectId`, `storageBucket`,
  `messagingSenderId`, `appId`) is intentionally public — it identifies the
  project, doesn't grant access. Not a finding. Firestore Security Rules and
  Firebase Auth are the access controls.
- Service account keys, signing secrets, privileged API keys (OpenAI, Stripe
  secret, SendGrid, etc.) must never appear in `VITE_*` vars. They live in
  Cloud Functions environment config (`.env` files in `functions/`, or
  Firebase environment variables).
- Source maps (`.map` files) can also expose source; disable in production
  builds or restrict to error-tracking services only.

**False positives:** The "secret" is a designed-public value (Firebase config,
Stripe publishable key, Sentry DSN, public Mapbox token). Confirm it is the
publishable/non-privileged variant.

---

## §xss-react — React-specific XSS sinks

React escapes JSX text content by default. These are the bypasses to grep for:

```tsx
// ❌ direct HTML injection
<div dangerouslySetInnerHTML={{ __html: userContent }} />
<div dangerouslySetInnerHTML={{ __html: marked(userInput) }} />  // markdown → raw HTML

// ❌ href/src with unvalidated user URLs
<a href={user.website}>link</a>        // javascript: executes
<img src={user.avatarUrl} />           // data: can carry payloads

// ❌ ref + direct DOM manipulation bypasses React escaping
ref.current.innerHTML = userContent;

// ❌ eval / new Function / setTimeout(string)
eval(config.expression);
new Function("return " + userCode)();
```

```tsx
// ✅ let React escape text by default
<div>{userContent}</div>

// ✅ if HTML is genuinely needed, sanitize first
import DOMPurify from "isomorphic-dompurify";
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />

// ✅ validate URL scheme before rendering
const safe = /^https?:\/\//i.test(user.website) ? user.website : "#";
<a href={safe} target="_blank" rel="noopener noreferrer">{label}</a>
```

**Review notes:** Markdown renderers (`marked`, `react-markdown`, `markdown-it`)
emit raw HTML by default — they need either a sanitizer or `disallowedElements`
config. `react-markdown` with `rehype-sanitize` is the safer default.

---

## §vite-config — Vite build configuration

```ts
// vite.config.ts — production-hardening checklist

export default defineConfig({
  build: {
    // disable source maps in production (or use 'hidden' for error tracking only)
    sourcemap: false,          // or 'hidden' to ship to Sentry without exposing publicly

    // no minification bypass for debugging
    minify: "esbuild",
  },
  // NEVER put real secrets in define — they are inlined into the bundle
  define: {
    // ❌ __SECRET__: JSON.stringify(process.env.SECRET),
  },
});
```

**Review notes:** `define` in `vite.config.ts` inlines values into the bundle
exactly like `VITE_*` env vars — same risk, less obvious. Check both.

---

## §config-injection — Runtime config injection into HTML

A "build once, deploy anywhere" pattern: instead of baking env-specific
values into the Vite bundle at build time, a deploy script injects them
into `index.html` at deploy/startup time — typically as a `<script>` block
setting `window.__CONFIG__`, or as a generated `/config.js` file.

**Why this is a good pattern:** one artifact, no per-environment rebuilds.

**What doesn't change:** `window.__CONFIG__` is readable by any JavaScript
running on the page — same exposure as `VITE_*`. The same rules apply for
what belongs here.

```html
<!-- ❌ real secret in injected config — still readable by any JS on the page -->
<script>
  window.__CONFIG__ = {
    apiEndpoint: "https://api.example.com",
    stripeSecretKey: "sk_live_...",
  };
</script>

<!-- ✅ only designed-public values -->
<script>
  window.__CONFIG__ = {
    apiEndpoint: "https://api.example.com",
    firebaseProjectId: "my-project",
    stripePublishableKey: "pk_live_...",
    featureFlags: { newDashboard: true },
  };
</script>
```

### CSP gotcha — inline scripts break `script-src 'self'`

An inline `<script>` block injected into the HTML violates a strict CSP
unless you explicitly allow it. Two safe approaches:

**Option 1 — Generate a separate `/config.js` file (recommended)**

The deploy script writes `public/config.js` instead of an inline block.
The HTML references it normally with `<script src="/config.js"></script>`.
Works with `script-src 'self'` out of the box.

**Option 2 — Nonce the inline block**

Add a per-deploy nonce and reference it in the CSP header. The nonce must
be unpredictable and change each deploy:

```html
<script nonce="DEPLOY_NONCE_PLACEHOLDER">
  window.__CONFIG__ = { ... };
</script>
```
```
Content-Security-Policy: script-src 'self' 'nonce-abc123xyz'
```

### Injection mechanism must JSON-encode values

A config value containing `</script>` or quotes can break out of the block
if naively string-interpolated:

```bash
# ❌ raw substitution — breaks on special characters, enables script injection
sed "s/__API_URL__/$API_URL/" index.html

# ✅ use a tool that JSON.stringify()s each value before substitution
```

### Typed accessor pattern

```ts
// ✅ one place reads window.__CONFIG__ — everywhere else imports this
interface AppConfig {
  apiEndpoint: string;
  firebaseProjectId: string;
  stripePublishableKey: string;
}

export function getConfig(): AppConfig {
  const cfg = (window as unknown as { __CONFIG__?: AppConfig }).__CONFIG__;
  if (!cfg) throw new Error("App config not injected");
  return cfg;
}
```

**Review checklist:**
- [ ] `window.__CONFIG__` contains only designed-public values
- [ ] Inline script uses a nonce in CSP, OR config is a separate `/config.js` file
- [ ] Injection mechanism JSON-encodes values (no raw string interpolation)
- [ ] Config accessed via a typed accessor, not `window.__CONFIG__` spread everywhere

---

## Quick triage

| Seen in diff | Default severity |
|---|---|
| `VITE_` var containing a real secret/key | High (rotate immediately) |
| Real secret in `window.__CONFIG__` / injected config | High (rotate immediately) |
| Inline config `<script>` without CSP nonce | Medium (CSP bypass) |
| Config injection using string interpolation, not JSON encode | High (script injection) |
| `dangerouslySetInnerHTML` on request-derived data | High (stored) / Medium (reflected) |
| Markdown renderer without sanitizer | High (stored XSS) |
| `href`/`src` from user input without scheme check | Medium |
| `define` in vite.config with sensitive value | High |
| Source maps deployed to production | Low–Medium |
