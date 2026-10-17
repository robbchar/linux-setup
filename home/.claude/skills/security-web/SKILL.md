---
name: security-web
description: >-
  Web application security review for Robb's stack: React/Vite frontend,
  Firebase (Auth, Firestore, Cloud Functions, Hosting), and MySQL backend.
  Covers XSS and output encoding, CSRF, clickjacking, secrets leaking into
  the Vite client bundle, authn/authz and IDOR, injection (SQL/command/
  template), SSRF, mass assignment, file upload, path traversal, security
  headers, cookie flags, and dependency risk. Includes targeted rules for
  React/Vite (VITE_ leakage, dangerouslySetInnerHTML), Firebase Cloud
  Functions (token verification, CORS, public endpoint assumptions),
  Firestore Security Rules (default-deny, uid scoping, rule gaps), and
  MySQL (parameterized queries, driver patterns). Use when reviewing or
  writing web code for vulnerabilities, triaging a security finding, or
  answering "is this exploitable / how do I fix it" questions.
---

# Web Application Security Review

Treat every byte that crossed a network boundary as hostile until proven
otherwise, and prove it on the server. The client is an untrusted rendering
surface you do not control.

In Robb's stack, the trust boundaries are:
- **React/Vite client** — any `VITE_*` var is in the public bundle
- **Firebase Cloud Functions** — each function is a public HTTP endpoint;
  Firebase does not gate them automatically
- **Firestore Security Rules** — the rules ARE the authorization layer when
  the client talks directly; a misconfigured rule is a data breach
- **MySQL** — parameterized queries only; any string interpolation is a finding

## How to use this skill (review workflow)

1. **Map the attack surface first.** Every trust boundary: HTTP handlers
   (Cloud Functions), Firestore Security Rules paths, form inputs, file
   uploads, outbound fetches, `postMessage`, `process.env`/`VITE_*` reaching
   the client, third-party script tags.
2. **Triage each input against the decision guide** below.
3. **Apply the stack reference** for the specific layer (React/Vite, Firebase,
   MySQL) — the generic finding almost always has a stack-specific trap.
4. **Report findings in the standard format** (`templates/finding.md`):
   severity, location (`file:line`), a concrete exploit walkthrough, and the
   minimal fix.
5. **Recommend the secure default**, not a bespoke patch. Templates are the
   target state.

## Severity

| Severity | Bar |
|---|---|
| **Critical** | Unauthenticated RCE, auth bypass, secret/PII mass disclosure, SQLi on a reachable path |
| **High** | Stored XSS, IDOR on sensitive data, SSRF to internal network, privilege escalation, CSRF on a state-changing action |
| **Medium** | Reflected XSS needing interaction, missing security headers with real impact, weak session handling, verbose error leakage |
| **Low** | Defense-in-depth gaps with no direct exploit, missing hardening, informational |

Rank by exploitability and blast radius on this codebase, not generic CVSS.

## The hard rules (non-negotiable defaults)

1. **All trust decisions happen server-side, per request, per object.**
   Authentication establishes *who*; authorization re-checks *may this
   principal touch this specific resource* on every access. A hidden button,
   a disabled field, or a client-side route guard is UX, never a control.
   In Firestore: the Security Rule is the control, and it must scope every
   read/write to `request.auth.uid` or an equivalent ownership check.

2. **Untrusted data is validated at the boundary and encoded at the sink.**
   Parse external input with a schema (zod) into a typed value before it
   touches any interpreter (SQL, HTML, filesystem). `dangerouslySetInnerHTML`
   with anything request-derived is a finding unless a vetted sanitizer
   (DOMPurify) is proven in the path.

3. **Secrets never cross to the client.** Any `VITE_*` env var is inlined
   into the client bundle — it is public. Firebase web config (`apiKey`,
   `projectId`, etc.) is designed to be public; that is not the concern.
   The concern is real secrets (service account keys, signing secrets, API
   keys for privileged services) that should never appear in `VITE_*` vars,
   client code, or the bundle. Treat any secret that ever shipped as
   compromised: the fix is rotation, not deletion.

4. **Injection is closed by structure, not by filtering.** Parameterized
   queries for MySQL; never string-concatenate input into SQL. No
   user-controlled keys into `eval`/`Function`/template compilation.

5. **Outbound requests to user-influenced URLs are denied by default.**
   SSRF: allowlist host + scheme, block private/link-local IPs, disable
   auto-redirects. Cloud Functions making outbound fetches to user-supplied
   URLs is High until proven constrained.

6. **Cookies and headers carry their security flags or it's a finding.**
   Session cookies: `HttpOnly`, `Secure`, `SameSite`. Responses: CSP,
   `X-Content-Type-Options: nosniff`, `frame-ancestors`, HSTS.
   See `templates/security-headers.md`.

7. **Every Cloud Function is a public endpoint.** Firebase does not
   automatically authenticate callers to Cloud Functions. Each function
   needs explicit token verification (`auth.verifyIdToken()`), input
   validation, and CORS config. The fact that only your UI calls it is
   not a control. See `references/firebase.md`.

8. **Firestore Security Rules must default-deny.** `allow read, write: if
   false` is the implicit default for uncovered paths, but any `allow read:
   if true` on a non-public collection is a finding. Rules must be tested
   with the Firebase Emulator Suite, not assumed. See `references/firebase.md`.

9. **Fail closed and quiet.** On auth/validation failure: deny, log
   server-side, return a generic error. No stack traces, no SQL, no
   "user not found vs wrong password" oracles in responses.

## Decision guide

| Symptom / what you're reviewing | Where |
|---|---|
| Request data rendered into DOM / JSX | `references/frontend.md` §XSS |
| `dangerouslySetInnerHTML`, `innerHTML`, `eval` | `references/frontend.md` §XSS |
| `postMessage` handler without origin check | `references/frontend.md` §postMessage |
| Page can be framed; clickjacking | `references/frontend.md` §clickjacking |
| Credential/secret in a `VITE_*` env var or bundle | `references/react-vite.md` §secrets |
| `target="_blank"` without `rel`, open redirect | `references/frontend.md` §navigation |
| Firebase Auth token verification in a Cloud Function | `references/firebase.md` §auth |
| Firestore Security Rules — read/write paths | `references/firebase.md` §rules |
| Cloud Function — CORS, input validation, rate limiting | `references/firebase.md` §functions |
| SQL query built from input (MySQL) | `references/mysql.md` §injection |
| An id from the request used to fetch or mutate a record | `references/backend.md` §authz-idor |
| Server fetches a URL the user supplied | `references/backend.md` §ssrf |
| `Object.assign`/spread of request body into a model | `references/backend.md` §mass-assignment |
| File upload, path/filename from input | `references/backend.md` §files |
| CORS config, `Access-Control-Allow-Origin: *` | `references/backend.md` §cors |
| Dependency risk, lockfile, postinstall | `references/backend.md` §supply-chain |

## Reference files

- `references/frontend.md` — browser-side: XSS, CSP, postMessage, clickjacking,
  secrets in the bundle, client storage, third-party scripts
- `references/backend.md` — server-side: authn/session/JWT, authz/IDOR, SSRF,
  mass assignment, deserialization, file handling, CORS, rate limiting, errors
- `references/react-vite.md` — React/Vite specifics: VITE_ leakage, Vite config,
  React-specific XSS sinks
- `references/firebase.md` — Firebase Auth token verification, Firestore Security
  Rules, Cloud Functions as public endpoints, CORS, Firebase Hosting headers
- `references/mysql.md` — mysql2 and Drizzle parameterized patterns, connection
  security, injection anti-patterns

## Templates

| File | Use |
|---|---|
| `templates/finding.md` | Report format every finding must follow |
| `templates/security-headers.md` | CSP + headers for Firebase Hosting + Express |
| `templates/cors.md` | Correct CORS allowlist for Cloud Functions |
| `templates/input-validation.ts` | Boundary schema-parse pattern (zod) |
| `templates/review-checklist.md` | Pass to run before sign-off |

## What this skill will not do

- Bless input sanitization by denylist/regex as an injection or XSS fix
- Bless client-side-only authorization, validation, or "security by obscurity"
- Bless `dangerouslySetInnerHTML` on request-derived data without a named,
  proven sanitizer (DOMPurify)
- Bless `Access-Control-Allow-Origin: *` with credentials
- Bless a custom crypto/JWT/hash implementation where a vetted library exists
- Downgrade a finding to "won't fix" — it reports severity and the fix;
  the human owns acceptance
