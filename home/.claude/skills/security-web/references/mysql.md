# MySQL — Security Reference

Covers parameterized queries and injection prevention for mysql2 (raw) and
Drizzle ORM. The fundamental rule: **never concatenate user input into SQL**.

---

## §injection — SQL injection patterns

**Threat:** input reaches a MySQL interpreter as code. SQLi on a reachable
path is Critical — data exfiltration, auth bypass, data destruction.

### mysql2 (raw driver)

```ts
import mysql from "mysql2/promise";

// ❌ string interpolation — Classic SQLi
const rows = await conn.query(
  `SELECT * FROM users WHERE email = '${email}'`
);

// ❌ template literal — same problem
const rows = await conn.execute(
  `SELECT * FROM users WHERE id = ${req.params.id}`
);
```

```ts
// ✅ parameterized with ? placeholders — the driver handles escaping
const [rows] = await conn.execute(
  "SELECT * FROM users WHERE email = ?",
  [email]
);

// ✅ multiple params
const [rows] = await conn.execute(
  "SELECT * FROM orders WHERE user_id = ? AND status = ?",
  [userId, status]
);
```

**Important:** use `execute()` not `query()` for parameterized statements.
`execute()` uses prepared statements; `query()` does not.

### Drizzle ORM

Drizzle parameterizes by default through its query builder — the safe path.
The danger is `sql` tagged template literal and `drizzle.$with` / `execute`
with raw strings.

```ts
import { eq, and } from "drizzle-orm";
import { sql } from "drizzle-orm";

// ✅ query builder — parameterized automatically
const user = await db.query.users.findFirst({
  where: eq(users.email, email),
});

// ✅ multiple conditions
const orders = await db.query.orders.findMany({
  where: and(eq(orders.userId, userId), eq(orders.status, "active")),
});

// ❌ raw sql tagged template with interpolation — NOT safe
const rows = await db.execute(
  sql`SELECT * FROM users WHERE email = '${email}'`   // string interp inside sql`` is raw
);

// ✅ sql tagged template with placeholder — safe
const rows = await db.execute(
  sql`SELECT * FROM users WHERE email = ${email}`     // value, not string interp — Drizzle parameterizes this
);
```

**Review notes:** In Drizzle's `sql` tag, `${value}` is a parameter (safe);
`${'string literal with ' + value}` would be a raw string (unsafe). The
distinction is easy to miss. Prefer the query builder over `sql` tagged
templates whenever possible.

### Dynamic identifiers (table/column names)

Parameterization works for *values*, not for identifiers (table names, column
names, ORDER BY columns). These must be allowlisted.

```ts
// ❌ user-controlled column name in ORDER BY
const col = req.query.sortBy;
const [rows] = await conn.execute(`SELECT * FROM posts ORDER BY ${col}`);

// ✅ allowlist the column name
const ALLOWED_SORT_COLUMNS = new Set(["created_at", "title", "views"]);
const col = ALLOWED_SORT_COLUMNS.has(req.query.sortBy)
  ? req.query.sortBy
  : "created_at";  // safe default
const [rows] = await conn.execute(`SELECT * FROM posts ORDER BY ${col}`);
```

---

## §connection — Connection security

```ts
// mysql2 connection config
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: {
    // require TLS for connections (especially to cloud MySQL)
    rejectUnauthorized: true,
  },
  // connection limits
  connectionLimit: 10,
  waitForConnections: true,
  queueLimit: 0,
});
```

**Review checklist:**
- DB credentials in environment variables, never hardcoded or in source
- SSL enabled for any non-localhost MySQL connection
- DB user has minimum required permissions — not `root`, not `ALL PRIVILEGES`
  on all databases
- Connection pool, not a new connection per request

---

## §idor-mysql — Object-level authorization with MySQL

Same rule as any backend: scope every query to the principal. An id from
the request is untrusted — it could be any row in the table.

```ts
// ❌ any user can read any invoice by changing the id
const [rows] = await conn.execute(
  "SELECT * FROM invoices WHERE id = ?",
  [req.params.id]
);

// ✅ scope to the authenticated user's org/ownership
const [rows] = await conn.execute(
  "SELECT * FROM invoices WHERE id = ? AND user_id = ?",
  [req.params.id, session.userId]
);
if (rows.length === 0) {
  res.status(404).json({ error: "Not found" });  // 404, not 403 — don't confirm existence
  return;
}
```

---

## Quick triage

| Pattern | Default severity |
|---|---|
| String interpolation into a SQL query | Critical |
| `query()` used instead of `execute()` for parameterized SQL | High |
| Dynamic column/table name from user input without allowlist | High |
| Missing ownership scope in a query (`WHERE id = ?` only) | High |
| DB credentials hardcoded in source | Critical |
| No SSL on non-localhost DB connection | Medium |
| DB user has excessive permissions | Medium |
