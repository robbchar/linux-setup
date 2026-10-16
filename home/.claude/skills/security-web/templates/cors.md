# CORS — correct allowlist pattern

The only safe credentialed CORS is an **exact-match allowlist**. `*` with
credentials is browser-rejected; reflecting `Origin` unconditionally
reintroduces the same hole. Substring/`endsWith`/regex matches are how
`evil-example.com` and `example.com.attacker.io` get in — use a `Set`.

```ts
const ALLOWED = new Set([
  "https://your-app.web.app",
  "https://your-app.firebaseapp.com",
  "http://localhost:5173",  // dev only — remove in production
]);

function corsHeaders(origin: string | null): Record<string, string> {
  if (!origin || !ALLOWED.has(origin)) return {};  // no CORS = denied
  return {
    "Access-Control-Allow-Origin": origin,          // echo the matched origin
    "Vary": "Origin",                                // cache correctness
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Max-Age": "600",
  };
}
```

## Cloud Functions (onRequest)

```ts
exports.myFn = functions.https.onRequest(async (req, res) => {
  const origin = req.headers.origin ?? null;
  Object.entries(corsHeaders(origin)).forEach(([k, v]) => res.set(k, v));

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  // ... handler
});
```

## Express in Cloud Functions

```ts
import cors from "cors";

const ALLOWED = new Set(["https://your-app.web.app"]);

app.use(cors({
  origin: (o, cb) => (ALLOWED.has(o ?? "") ? cb(null, true) : cb(null, false)),
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"],
}));
```

## Rules

- Public, credential-free, read-only API → `Access-Control-Allow-Origin: *`
  is acceptable (and then **never** `Allow-Credentials: true`).
- Credentialed API → exact-match allowlist only, always `Vary: Origin`.
- `null` origin (sandboxed iframe, `file://`, some redirects) is **not**
  trusted — never allowlist the literal string `"null"`.
- Preflight (`OPTIONS`) must apply the *same* allowlist as the actual request.
- CORS controls who can *read cross-origin responses in a browser*. It is
  **not** authn/authz and not CSRF defense — those are still required.
