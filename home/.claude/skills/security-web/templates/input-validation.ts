// Boundary input-validation pattern.
//
// Rule: external input is *parsed into a typed value at the boundary*,
// never cast, never spread raw into a query/model. The schema is an
// allowlist — fields not in it cannot reach your domain (this is also the
// mass-assignment fix). Read the parsed value, never the raw request again.

import { z } from "zod";

// 1. One schema per input shape. List exactly the fields the server
//    accepts. No `.passthrough()`. Constrain types/lengths/enums tightly.
export const UpdateProfile = z
  .object({
    name: z.string().trim().min(1).max(80),
    bio: z.string().max(500).optional(),
    // privilege fields (role, isAdmin, ownerId, balance) are deliberately
    // ABSENT — they are set by server logic, never bindable from input.
  })
  .strict(); // reject unknown keys instead of silently dropping them

export type UpdateProfile = z.infer<typeof UpdateProfile>;

// 2. Parse at the boundary. Throw a generic error on failure; log the
//    detail server-side only (no schema/internal echo to the client).
export function parseInput<T>(schema: z.ZodType<T>, raw: unknown): T {
  const r = schema.safeParse(raw);
  if (!r.success) {
    // server-side structured log:
    // console.error("input validation failed", r.error.issues);
    throw { status: 400, message: "Bad Request" };
  }
  return r.data;
}

// 3. In a Cloud Function (onRequest):
//
//   const dto = parseInput(UpdateProfile, req.body);
//   await db.execute(
//     "UPDATE users SET name = ?, bio = ? WHERE id = ?",
//     [dto.name, dto.bio, session.userId]   // authz: session-scoped, not dto.id
//   );
//
// 4. In a Cloud Function (onCall):
//
//   const dto = parseInput(UpdateProfile, data);
//   // context.auth.uid is already server-verified
//
// Numbers/ids from path/query are strings — coerce + constrain:
//   z.coerce.number().int().positive()
// so type confusion can't sneak through.
