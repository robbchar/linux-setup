# Firebase — Security Reference

Covers Firebase Auth token verification, Firestore Security Rules, Cloud
Functions as public endpoints, and Firebase Hosting header configuration.

---

## §auth — Firebase Auth token verification in Cloud Functions

**Threat:** Cloud Functions are public HTTP endpoints. Firebase does NOT
automatically authenticate callers. If you trust a client-supplied `uid` or
skip token verification, any caller can impersonate any user.

```ts
// ❌ trusting the client's claimed uid
exports.getMyData = functions.https.onRequest(async (req, res) => {
  const uid = req.body.uid;               // attacker supplies any uid they want
  const data = await db.collection("users").doc(uid).get();
  res.json(data.data());
});

// ❌ no auth check at all
exports.deleteRecord = functions.https.onRequest(async (req, res) => {
  await db.collection("records").doc(req.body.id).delete();
  res.sendStatus(200);
});
```

```ts
// ✅ verify the Firebase ID token on every function that needs auth
import * as admin from "firebase-admin";

async function verifyAuth(req: functions.https.Request): Promise<admin.auth.DecodedIdToken> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    throw new functions.https.HttpsError("unauthenticated", "Missing token");
  }
  const token = authHeader.split("Bearer ")[1];
  return admin.auth().verifyIdToken(token);  // throws on invalid/expired token
}

exports.getMyData = functions.https.onRequest(async (req, res) => {
  try {
    const decoded = await verifyAuth(req);   // uid is now server-verified
    const data = await db.collection("users").doc(decoded.uid).get();
    res.json(data.data());
  } catch (e) {
    res.status(401).json({ error: "Unauthorized" });
  }
});
```

**Callable Functions** (`functions.https.onCall`) do receive an `auth` context
object automatically — but it can be `null` if the caller is unauthenticated.
Always check `context.auth` before using `context.auth.uid`.

```ts
// ✅ callable function auth check
exports.doSomething = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
  }
  const uid = context.auth.uid;  // server-verified, safe to trust
  // ...
});
```

**Review checklist:**
- Every `onRequest` function that requires auth: `verifyIdToken` called before
  any data access
- Every `onCall` function: `context.auth` null-checked before `context.auth.uid`
- Service account keys (`serviceAccountKey.json`) must never be committed to
  git or appear in client code — use Application Default Credentials in
  Firebase Functions (already available in the Functions environment)

---

## §rules — Firestore Security Rules

**Threat:** Firestore Security Rules are the authorization layer when clients
talk directly to Firestore. A misconfigured rule leaks or mutates data for
any authenticated (or unauthenticated) user.

### Default-deny is automatic but gaps are exploitable

Firestore denies all access by default, but any `allow read, write: if true`
on a non-public collection is a Critical finding. Test rules with the
Firebase Emulator, not assumptions.

```js
// ❌ lets any authenticated user read any user document
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;  // any logged-in user reads any user
    }
  }
}

// ❌ global wildcard — the "I'll fix later" rule
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

```js
// ✅ scope every path to ownership
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // only the user themselves can read/write their own document
      allow read, update: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow delete: if false;  // explicit; deletion goes through a Cloud Function
    }
    match /posts/{postId} {
      allow read: if true;  // public — documented intentional decision
      allow create: if request.auth != null
                    && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if request.auth != null
                             && resource.data.authorId == request.auth.uid;
    }
  }
}
```

**Review checklist:**
- Every collection: is there an explicit rule? Uncovered paths default-deny
  (good), but verify no wildcard rule covers them accidentally
- `allow read: if true` — is this genuinely public data? Document the decision
- `allow write: if request.auth != null` — this lets any logged-in user write
  to any document in the collection; almost always wrong
- Ownership checks: `resource.data.authorId == request.auth.uid` (existing doc)
  vs `request.resource.data.authorId == request.auth.uid` (new doc) — both
  needed for create vs update
- Field-level validation: `request.resource.data.keys().hasOnly([...])` to
  prevent mass assignment through the client
- Test with Firebase Emulator Suite (`firebase emulators:start`) with unit
  tests covering allowed and denied cases for each path

### Mass assignment via Firestore client

```ts
// ❌ client can set any field including isAdmin, role, ownerId
await setDoc(doc(db, "users", uid), { ...formData });

// ✅ only write the fields your rules expect, and validate in rules
await updateDoc(doc(db, "users", uid), {
  displayName: formData.displayName,
  bio: formData.bio,
  // privilege fields (isAdmin, role) are NEVER updated from client code
});
```

---

## §functions-public — Cloud Functions are public endpoints

Every deployed Cloud Function has a public HTTPS URL. There is no Firebase
firewall in front of them unless you configure it explicitly.

**Checklist for every Cloud Function:**

1. **Auth:** verify ID token (onRequest) or check `context.auth` (onCall)
2. **Input validation:** parse and validate `req.body` with zod before use
3. **CORS:** configure explicitly — don't rely on defaults
4. **Rate limiting:** `onRequest` functions have no built-in rate limiting;
   add it (e.g. `firebase-functions-rate-limiter`, or Firestore-backed)
5. **Error handling:** catch all errors; return generic messages; log detail
   server-side only
6. **Idempotency:** for payment/destructive actions, guard against replay

```ts
// ✅ minimal secure Cloud Function skeleton
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { z } from "zod";

const InputSchema = z.object({
  name: z.string().trim().min(1).max(80),
});

exports.exampleFn = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "https://your-app.web.app");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
    res.status(204).send("");
    return;
  }

  // Auth
  let uid: string;
  try {
    const token = req.headers.authorization?.split("Bearer ")[1];
    if (!token) throw new Error("no token");
    const decoded = await admin.auth().verifyIdToken(token);
    uid = decoded.uid;
  } catch {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  // Input validation
  const parsed = InputSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Bad Request" });
    return;
  }

  // Business logic
  try {
    // ... use uid and parsed.data
    res.json({ ok: true });
  } catch (e) {
    functions.logger.error("exampleFn error", e);
    res.status(500).json({ error: "Internal error" });
  }
});
```

---

## §hosting — Firebase Hosting security headers

Firebase Hosting serves your Vite SPA. Security headers are configured in
`firebase.json` under `hosting.headers`. See `templates/security-headers.md`
for the full header set.

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
          {
            "key": "Content-Security-Policy",
            "value": "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com"
          }
        ]
      },
      {
        "source": "**/*.@(js|css)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      }
    ]
  }
}
```

**CSP note for Firebase apps:** The Firebase SDK makes requests to
`*.googleapis.com` and `*.firebaseio.com` — add these to `connect-src`.
If using Firebase Auth with redirect flows, you may also need
`https://accounts.google.com` in `connect-src` and `frame-src`.

---

## Quick triage

| Pattern | Default severity |
|---|---|
| `onRequest` function with no `verifyIdToken` call | High (unauthed access) |
| `onCall` with no `context.auth` null check | High |
| Firestore rule: `allow read, write: if true` on non-public collection | Critical |
| Firestore rule: `allow write: if request.auth != null` (no ownership) | High |
| Service account key in client code or committed to git | Critical |
| No CORS config on a credentialed Cloud Function | High |
| Missing security headers on Firebase Hosting | Medium |
| No rate limiting on auth/sensitive Cloud Function | Medium |
