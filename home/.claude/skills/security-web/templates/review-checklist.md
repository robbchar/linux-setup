# Web security review checklist

Run before sign-off. For each item: pass / finding (→ `templates/finding.md`)
/ N/A-with-reason. Skipping an item silently is not allowed.

## Attack surface mapped
- [ ] Every Cloud Function, Firestore Security Rule path, form input, file
      upload, outbound fetch, `postMessage`, and `VITE_*` env var enumerated.

## AuthN / AuthZ (rule 1)
- [ ] Every Cloud Function (`onRequest`) calls `verifyIdToken` before touching data.
- [ ] Every callable function (`onCall`) null-checks `context.auth` before
      using `context.auth.uid`.
- [ ] Every id/slug from the request is authorized at the object level
      (ownership/user_id in the query or Firestore rule — not just existence check).
- [ ] Role/permission checks are server-side (Cloud Function or Firestore rule),
      not just hidden UI or client-side route guards.
- [ ] Firestore Security Rules: no `allow read, write: if true` on non-public
      collections; no unscoped `allow write: if request.auth != null`.
- [ ] Sessions/cookies: `HttpOnly`+`Secure`+`SameSite`.

## Input & output (rules 2, 4)
- [ ] External input schema-parsed at the boundary with zod (no raw cast/spread).
- [ ] No mass assignment (`...req.body` into a model; no Firestore client writing
      privilege fields like `isAdmin`, `role`).
- [ ] No `dangerouslySetInnerHTML`/`innerHTML`/`eval` on request-derived data
      without a traced sanitizer (DOMPurify).
- [ ] MySQL: parameterized queries (`execute()` not `query()`), no string
      concatenation into SQL, dynamic identifiers allowlisted.

## Network & data egress (rules 3, 5)
- [ ] No secret in `VITE_*` env vars or client bundle (Firebase web config is OK;
      service account keys, signing secrets, privileged API keys are not).
- [ ] Server data projected to DTOs (no full DB rows or Firebase documents
      returned to the client with extra fields).
- [ ] Outbound user-influenced URLs: scheme+host allowlist, private-IP block,
      redirects handled (SSRF).
- [ ] Cloud Function CORS: exact-match allowlist, no `*`+credentials.

## Hardening (rules 5, 6, 8)
- [ ] Security headers set in `firebase.json` hosting config
      (`templates/security-headers.md`).
- [ ] Rate limiting on auth/sensitive Cloud Functions.
- [ ] File upload (if applicable): generated names, path-confined, type-by-content,
      size cap, served safely.
- [ ] Cloud Function errors fail closed; no stack traces or internal detail
      in responses to clients.
- [ ] Dependencies pinned, lockfile committed, `npm audit` / `yarn audit` clean.

## Firebase-specific pass
- [ ] Ran `references/firebase.md` triage table against the diff.
- [ ] Firestore Security Rules tested with Firebase Emulator (not just assumed).
- [ ] No service account key files committed or in client code.

## React/Vite pass
- [ ] Ran `references/react-vite.md` triage table against the diff.
- [ ] `VITE_*` vars in the diff verified as designed-public values only.

## Output
- [ ] Findings reported in `templates/finding.md` format with severity +
      concrete exploit + minimal fix. Observations labeled as such.
