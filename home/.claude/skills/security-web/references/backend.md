# Backend / Server-Side — full reference

Each section: **threat**, a **vulnerable** pattern, the **fix**, **review
notes**, **false positives**. The server is the only place trust decisions
are real. Every handler is internet-facing regardless of which UI you
think calls it.

---

## §auth-sessions — Authentication, sessions, JWT, cookies

**Threats:** credential stuffing/brute force, session fixation, token
theft/replay, weak password storage, JWT `alg:none`/`HS256`-with-public-key
confusion, missing expiry/rotation, user-enumeration oracles.

```ts
// ❌ MD5/SHA, no work factor; timing-leaky compare; unsigned-trust JWT
if (md5(pw) === user.hash) ...
jwt.verify(token, secret, { algorithms: undefined }); // accepts "none"
res.cookie("sid", id);                                 // no flags
```
```ts
// ✅
const ok = await argon2.verify(user.hash, pw);     // or bcrypt/scrypt/Bun.password
jwt.verify(token, secret, { algorithms: ["HS256"] }); // pin the alg
res.cookie("sid", id, {
  httpOnly: true, secure: true, sameSite: "lax",
  maxAge: 86_400_000, path: "/",
});
```

**Review checklist:**
- Password hash = bcrypt/scrypt/argon2/`Bun.password` with a real cost.
  SHA*/MD5/PBKDF2-low/`crypto.createHash` for passwords → High.
- JWT: algorithm **pinned** on verify; secret strong and server-only; short
  exp + refresh rotation; no sensitive data in the (readable) payload; a
  revocation/session story (pure stateless JWT can't be revoked — note it).
- Session id regenerated on privilege change (login) → prevents fixation.
- Cookies: `HttpOnly`+`Secure`+`SameSite`; `__Host-`/`__Secure-` prefix
  where applicable; sensible `Max-Age`.
- Login/reset/registration give **identical** responses & timing for
  valid/invalid accounts (no enumeration). Rate-limited + lockout/backoff.
- MFA/reset tokens: single-use, expiring, high-entropy, constant-time
  compared.

**False positives:** verification is delegated to a vetted provider
(Auth.js/Lucia/Clerk/Supabase) with defaults intact; the "hash" is for a
non-secret; algorithm is pinned by the library config.

---

## §authz-idor — Authorization & Insecure Direct Object Reference

**Threat:** the request supplies an id/slug/path and the server returns or
mutates it **without checking the principal owns/may access it**. The
single most common High/Critical web bug. Authentication ≠ authorization.

```ts
// ❌ any logged-in user reads/edits any invoice by changing the id
app.get("/api/invoices/:id", auth, async (c) =>
  db.invoice.findUnique({ where: { id: c.req.param("id") } }));
```
```ts
// ✅ scope every query to the principal; ownership is part of the query
const inv = await db.invoice.findFirst({
  where: { id, orgId: session.orgId },   // not just by id
});
if (!inv) return c.notFound();           // 404, don't confirm existence
```

**Review notes:** check **every** handler that takes an id-like input —
read *and* write, nested routes, GraphQL node ids, batch endpoints,
file/report download, "export", admin-ish actions. Ownership must be in
the WHERE clause or an explicit policy check *before* the effect, not a
post-hoc filter you can forget. Function/role checks too: is `requireRole`
enforced server-side, or only the menu hidden? Mass/bulk endpoints must
authorize each element. Prefer unguessable ids as defense-in-depth, never
as the control.

**False positives:** the resource is genuinely public; ownership is
enforced by a middleware/policy you traced for this route; row-level
security in Postgres enforces it (verify the connection actually sets the
tenant).

---

## §injection — SQL / NoSQL / ORM-raw / command / template

**Threat:** input crosses into an interpreter (SQL, Mongo query, shell,
template engine, LDAP) as code. SQLi on a reachable path is Critical;
command injection is Critical (RCE).

```ts
// ❌ SQL string-built (mysql2)
conn.query(`SELECT * FROM users WHERE email = '${email}'`);
conn.execute(`SELECT * FROM users WHERE id = ${req.params.id}`);
// ❌ Drizzle raw sql with string interpolation
db.execute(sql`SELECT * FROM users WHERE email = '${email}'`);
// ❌ command — shell parses the string
exec(`convert ${name} out.png`);
ejs.render(userTemplate, data);  // user controls the template source
```
```ts
// ✅ parameterize / structure (see references/mysql.md for full detail)
conn.execute("SELECT * FROM users WHERE email = ?", [email]);
db.query.users.findFirst({ where: eq(users.email, email) }); // Drizzle query builder
execFile("convert", [name, "out.png"]);   // arg array, no shell
// templates: never compile user input as a template; pass it as data only
```

**Review notes:** the fix is *structural*, never escaping/denylist.
For MySQL with mysql2: use `execute()` not `query()` for parameterized
statements. For Drizzle: the query builder is safe; `sql` tagged templates
are safe when using `${value}` (parameter); raw string interpolation inside
them is not. Shell: prefer `execFile`/`spawn` with an arg array and
`shell:false`. Template/SSTI: user input is *data passed to* a template,
never the template source. Dynamic column/table names must be allowlisted.
See `references/mysql.md` for the full mysql2/Drizzle picture.

**False positives:** value is a typed, schema-validated enum/number bound
as a parameter; the "concat" is of trusted constants; ORM call is the safe
tagged form.

---

## §ssrf — Server-Side Request Forgery

**Threat:** the server makes an HTTP/TCP request to a URL/host the user
influenced (webhook, image/avatar fetch, link preview, PDF/screenshot,
import-from-URL, OIDC discovery). Attacker pivots to cloud metadata
(`169.254.169.254`), internal services, `file://`, port scans. High–Critical.

```ts
// ❌ fetches whatever the user asked for
const img = await fetch(req.body.imageUrl);
```
```ts
// ✅ allowlist + resolve + block private ranges + no redirect
function assertPublicUrl(raw: string) {
  const u = new URL(raw);
  if (!["https:", "http:"].includes(u.protocol)) throw new Error("scheme");
  if (!ALLOWED_HOSTS.has(u.hostname)) throw new Error("host");
  return u;
}
const u = assertPublicUrl(req.body.imageUrl);
const res = await fetch(u, { redirect: "manual", signal: AbortSignal.timeout(5000) });
// re-validate any Location before following; cap size; pin DNS if possible
```

**Review notes:** denylisting IP literals is insufficient — DNS rebinding,
IPv6 (`[::1]`, `::ffff:127.0.0.1`), decimal/octal IPs, `0.0.0.0`, redirects,
and `localhost` aliases bypass it. Real fix: scheme+host allowlist, resolve
the hostname and reject private/loopback/link-local/ULA, `redirect:
"manual"` with re-validation, timeouts, response size cap, and least-
privilege egress (the strongest control is network-level egress filtering —
recommend it). Cloud metadata access from an app fetch is Critical.

**False positives:** the host set is a fixed allowlist of your own
domains/partners and redirects are disabled; egress is firewalled and
documented.

---

## §mass-assignment — over-posting / autobinding

**Threat:** request body spread into a model lets the attacker set fields
they shouldn't (`isAdmin`, `role`, `balance`, `ownerId`, `emailVerified`).

```ts
// ❌ user controls every column
await db.user.update({ where: { id }, data: req.body });
Object.assign(user, req.body);
```
```ts
// ✅ parse to an explicit allowlist schema; assign only those fields
const dto = UpdateProfile.parse(req.body);     // zod: name, bio only
await db.user.update({ where: { id: session.userId }, data: dto });
```

**Review notes:** look for `...req.body`, `Object.assign`, `Object.entries`
loops, ORM `create/update(body)`, GraphQL input passthrough. Fix is an
explicit input DTO/schema (allowlist), not a denylist of "dangerous" keys.
Privilege fields must be set by server logic, never bindable.

**False positives:** the schema/DTO already constrains fields and is the
thing being assigned; ORM is configured with field-level select/protected.

---

## §deserialization — untrusted bytes → objects

**Threat:** `node-serialize`, `funcster`, `js-yaml` `load` (non-`safeLoad`),
`vm`/`vm2`, `eval(JSON)`, deserializing cookies/JWT-payload into class
instances → RCE or prototype pollution.

**Fix:** `JSON.parse` (+ schema validate) for data; `yaml.parse`/safe
schema only; never `eval`; never deserialize into live objects from
untrusted input; keep `vm2` off (deprecated/broken sandbox) — if isolation
is needed, use `isolated-vm` and treat as Critical-sensitive.

**False positives:** input is trusted server-internal; `JSON.parse` output
is schema-validated before use.

---

## §files — upload, download, path traversal

**Threat:** `../` in a filename/path reads or writes outside the intended
dir; uploaded content is served back and executed (stored XSS via SVG/HTML,
or RCE if in a script dir); content-type trusted from the client; zip-slip;
decompression bombs.

```ts
// ❌ path traversal
res.sendFile(path.join(UPLOAD_DIR, req.params.name));   // name = ../../etc/passwd
fs.writeFile(path.join(DIR, upload.filename), buf);     // attacker filename
```
```ts
// ✅ generate the name; resolve and confine
const id = crypto.randomUUID();
const dest = path.join(UPLOAD_DIR, id);
if (!path.resolve(dest).startsWith(path.resolve(UPLOAD_DIR) + path.sep))
  throw new Error("traversal");
// validate type by sniffing magic bytes (not the Content-Type header);
// size cap; store outside web root; serve with Content-Disposition:
// attachment + nosniff; never trust/echo the original filename in a path
```

**Review notes:** never use the client filename for the stored path —
generate it. Validate type by content, enforce size limits before reading
fully, store outside the served/script root, serve user files from a
distinct origin/CDN with `nosniff` and `attachment`. Decompression: cap
output size and entry count (zip-slip + bomb).

**False positives:** path segment is a server-generated id with no client
influence; library (multer/busboy) limits + a confined dir are configured.

---

## §cors — Cross-Origin Resource Sharing

**Threat:** `Access-Control-Allow-Origin: *` *with credentials*, or
reflecting the request `Origin` unconditionally with
`Allow-Credentials: true`, lets any site make authenticated cross-origin
calls and read responses.

```ts
// ❌ reflects any origin + credentials = no SOP protection
cors({ origin: (o, cb) => cb(null, true), credentials: true });
```
```ts
// ✅ explicit allowlist; credentials only for known origins
cors({ origin: ["https://app.example.com"], credentials: true });
```

**Review notes:** `*` is acceptable only for truly public, credential-free
APIs. Reflecting `Origin` is only safe against a strict allowlist (and
beware substring matches: `evil-example.com`). `Allow-Credentials: true`
with `*` is rejected by browsers but a reflected origin reintroduces the
bug. See `templates/cors.md`.

**False positives:** API is public and stateless (no cookies/auth that the
browser attaches automatically); allowlist is exact-match.

---

## §abuse — rate limiting, brute force, resource exhaustion

**Threat:** no throttling on auth, OTP, password reset, search, or
expensive endpoints → credential stuffing, enumeration, cost/DoS.
ReDoS from user-controlled regex; unbounded body/JSON; unbounded
pagination; N+1 amplification.

**Fix:** per-IP **and** per-account rate limits with backoff on auth-class
endpoints; CAPTCHA/lockout after thresholds; body size limits; pagination
caps; timeouts on outbound and DB calls; avoid user-supplied regex (or
bound it); idempotency on payment-class actions.

**False positives:** an upstream gateway/WAF/CDN enforces limits (verify it
actually covers this route and method).

---

## §error-handling — leakage & fail-open

**Threat:** stack traces, SQL, file paths, internal hostnames, library
versions in responses; `try/catch` that swallows an auth error and
continues; different errors for "user not found" vs "bad password".

**Fix:** generic client message + server-side structured log with context;
centralized error handler; deny on exception in any auth/authz path (fail
closed); uniform auth responses.

**False positives:** verbose errors gated to non-prod by config you traced.

---

## §supply-chain — dependencies

**Threat:** malicious/compromised package, typosquat, `postinstall`
scripts, unpinned ranges, abandoned deps with known CVEs, CDN scripts
without SRI.

**Fix:** committed lockfile (`yarn.lock`); `yarn audit` in CI; pin and
review additions; minimize footprint; SRI for CDN assets; renovate/
dependabot with review. Flag any new dependency added in the diff that
is unfamiliar, recently published, or low-download for a sensitive
function (crypto, auth, parsing).

**False positives:** dep is well-known, pinned, lockfile-tracked, and
audit-clean.

---

## Quick triage table

| Pattern | Default severity |
|---|---|
| SQLi/command injection on a reachable path | Critical |
| Auth bypass / JWT alg confusion / `alg:none` accepted | Critical |
| IDOR on sensitive data (read or write) | High |
| SSRF reaching internal/metadata | High–Critical |
| Mass assignment of a privilege field | High |
| Weak password hashing (MD5/SHA/plain) | High |
| Missing object-level authz on a mutation | High |
| CORS reflect-origin + credentials | High |
| Path traversal in file read/write | High |
| No rate limit on auth/OTP | Medium |
| Cookie missing HttpOnly/Secure/SameSite | Medium |
| Error/stack leakage | Low–Medium |
