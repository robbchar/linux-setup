# Secure response headers & cookie flags — target state

Recommend these defaults; a per-route relaxation must carry a comment
saying why. Tighten CSP to your actual sources — a CSP with
`unsafe-inline`/`unsafe-eval` (or `*`) is barely a CSP; flag it.

## The header set

| Header | Value (baseline) | Why |
|---|---|---|
| `Content-Security-Policy` | `default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; script-src 'self'` | XSS mitigation, anti-framing |
| `X-Content-Type-Options` | `nosniff` | stop MIME sniffing |
| `X-Frame-Options` | `DENY` | legacy clickjacking (CSP `frame-ancestors` is primary) |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | HTTPS only (HTTPS sites only) |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | limit referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | reduce feature surface |
| `Cache-Control` (authed responses) | `no-store` | don't cache per-user data |

## Cookie flags (session/auth cookies)

```
Set-Cookie: sid=…; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=86400
```
- `HttpOnly` — JS can't read it (limits XSS token theft).
- `Secure` — HTTPS only.
- `SameSite=Lax` minimum; `None` requires `Secure` **and** a written
  cross-site reason; `Strict` for the most sensitive.

## Firebase Hosting (`firebase.json`)

Firebase Hosting is where the Vite SPA is served. Set headers here.
Note: Firebase SDK needs `connect-src` to reach Google APIs.

```json
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "X-Content-Type-Options", "value": "nosniff" },
          { "key": "X-Frame-Options", "value": "DENY" },
          { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
          { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" },
          { "key": "Strict-Transport-Security", "value": "max-age=63072000; includeSubDomains; preload" },
          {
            "key": "Content-Security-Policy",
            "value": "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com https://identitytoolkit.googleapis.com; script-src 'self'"
          }
        ]
      },
      {
        "source": "**/*.@(js|css|woff2)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      }
    ]
  }
}
```

**CSP note:** Firebase Auth (Google sign-in redirect flow) may require
additional `frame-src` and `connect-src` entries. Test with the browser
console open — CSP violations are logged there.

## Cloud Functions (Express in Functions)

If you're using Express inside a Cloud Function, set headers with `helmet`:

```ts
import express from "express";
import helmet from "helmet";

const app = express();

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      objectSrc: ["'none'"],
      baseUri: ["'none'"],
      frameAncestors: ["'none'"],
    },
  },
  hsts: {
    maxAge: 63072000,
    includeSubDomains: true,
    preload: true,
  },
}));

// CORS before other middleware
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.has(origin)) cb(null, true);
    else cb(new Error("Not allowed by CORS"));
  },
  credentials: true,
}));
```

For `onRequest` functions without Express, add headers manually:

```ts
res.set({
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Content-Security-Policy":
    "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'",
});
```
