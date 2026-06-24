# Task: /api-contract rest — Design REST endpoints + OpenAPI 3.1 from user stories

<purpose>
Take a list of user stories (from PRD or directly from the user) and produce a complete REST API design: resource model, endpoint list with HTTP semantics, status codes, auth, rate limits, then the OpenAPI 3.1 YAML spec ready to commit.

This is the **discovery + design + spec-writing** task. After this runs, you have:
- A resource model (nouns → URL paths)
- An endpoint list (verbs, status codes, errors)
- An OpenAPI 3.1 `openapi.yaml` at `contracts/openapi.yaml`
- The auth matrix per endpoint
- The rate limit spec per endpoint

The next step (`/api-contract types` then `/api-contract zod`) generates TypeScript types and Zod schemas *from this spec*.
</purpose>

<when-to-use>
- After the PRD has user stories written
- Before implementing any HTTP endpoint
- When you have a green-field backend and need the URL contract first
- When migrating a no-spec codebase to a documented REST API
- Triggered by `/api-contract rest`

<prerequisites>
- User stories exist (even 3 stories is enough; the design grows with them)
- Stack chosen (TypeScript / Node / Cloudflare Workers / etc. — affects where the spec lives)
- Auth model decided (Supabase Auth? Clerk? custom JWT? — affects security schemes in OpenAPI)
- This skill is loaded — start by reading `@frameworks/rest-best-practices.md` and `@frameworks/auth-patterns-per-endpoint.md`

</prerequisites>

<references>
@../SKILL.md (entry point)
@../frameworks/rest-best-practices.md (the rules every endpoint must obey — load FIRST)
@../frameworks/error-codes-catalog.md (the error envelope + codes — load FIRST)
@../frameworks/auth-patterns-per-endpoint.md (auth matrix per endpoint — load FIRST)
@./generate-openapi-spec.md (next step — turns this design into the OpenAPI YAML)
@./typescript-types-from-contract.md (after spec — generates TS types)
@./zod-validation-patterns.md (after types — generates Zod schemas)
@../references/openapi-vs-graphql-decision.md (load if there's any doubt REST is right)
</references>

---

## Phase 0 — Read the inputs (1 min)

Before designing, gather:

1. **User stories** — paste the story list (or read from the PRD markdown). Each story should have:
   - Actor (who)
   - Action (verb)
   - Object (noun)
   - Acceptance criteria (what success looks like)
2. **Stack** — TypeScript? Which runtime (Node / Bun / Deno / Workers)?
3. **Auth provider** — Supabase Auth? Clerk? Custom? (Affects `securitySchemes` in OpenAPI.)
4. **Hosting** — Cloudflare Workers? Vercel? Self-hosted? (Affects `servers` block + CORS.)
5. **Database** — Supabase / Postgres / D1 / Firestore? (Doesn't directly affect the HTTP contract but affects what's queryable.)

If any are missing, ask **one focused question** (not five). Default assumptions documented inline.

---

## Phase 1 — Extract nouns (resource model) (5 min)

A REST API is a set of **resources** (nouns) connected by **relations**, acted on by **methods** (verbs). Read every story and extract:

### Step 1.1 — Noun harvest

For each user story, write down the **object being acted on**:

| Story verb | Object | Becomes resource |
|-----------|--------|------------------|
| "user creates a project" | project | `Project` |
| "user adds a member to a project" | (project, member) | `Member` (sub-resource of project) |
| "user uploads an avatar" | avatar | `Avatar` (sub-resource of user) |
| "system sends an invoice" | invoice | `Invoice` |

### Step 1.2 — Sub-resources vs top-level

| If the story says... | Then it's a... | Path |
|---------------------|----------------|------|
| "user views **their** invoices" | Top-level resource scoped to user | `/users/{userId}/invoices` |
| "user views **invoice #42**" | Sub-resource | `/invoices/{invoiceId}` |
| "user views **a comment on a post**" | Nested sub-resource | `/posts/{postId}/comments/{commentId}` |

**Rule:** If clients ever need to fetch it without the parent context, make it top-level. If it's only meaningful with the parent, make it nested. Don't nest more than 2 levels (a/b/c is the max — beyond that, make `c` top-level and add a `parentId`).

### Step 1.3 — Relations vs actions

| What the story says | REST interpretation |
|---------------------|---------------------|
| "user posts a comment on a post" | Comment is a resource; POST `/posts/{postId}/comments` |
| "user likes a post" | **Don't** create a `Like` resource. Use `POST /posts/{postId}/likes` (action) and `DELETE /posts/{postId}/likes` (unlike). The relationship is implied by auth. |
| "user tags a post" | Tag is a resource; `POST /posts/{postId}/tags` with `{tagId}` body. |
| "user reports a post" | Action endpoint: `POST /posts/{postId}/reports` with `{reason}` body. Returns the report ID. |

**Rule:** If the relationship carries data (comment body, rating value, message), it's a resource. If the relationship is binary (like/follow/save), it's an action.

### Step 1.4 — Resource Model Table

Output this table before designing endpoints:

```markdown
## Resource Model

| Resource | Top-level path | Parent (if nested) | Notes |
|----------|---------------|--------------------|-------|
| User | `/users` | — | The authenticated actor |
| Project | `/projects` | — | Owned by user |
| Member | `/projects/{projectId}/members` | Project | Has role |
| Invoice | `/invoices` | — | Cross-user (system-generated) |
| Avatar | `/users/{userId}/avatar` | User | 1:1 sub-resource |
```

---

## Phase 2 — Map stories to endpoints (10 min)

For each story, write the HTTP contract:

### Step 2.1 — HTTP method selection

| Story intent | Method | Path | Notes |
|-------------|--------|------|-------|
| "view X" / "list X" | `GET` | `/x` or `/x/{id}` | Safe, cacheable, idempotent |
| "create X" | `POST` | `/x` | Not idempotent (use Idempotency-Key for money) |
| "replace X entirely" | `PUT` | `/x/{id}` | Idempotent, full body required |
| "update some fields of X" | `PATCH` | `/x/{id}` | With JSON Patch or JSON Merge Patch |
| "delete X" | `DELETE` | `/x/{id}` | Idempotent (returns 204 or 200 with body) |
| "do action on X" | `POST` | `/x/{id}/{action}` | For likes, sends, exports |

### Step 2.2 — Status codes

Every endpoint documents its response status codes. Default table:

| Code | Meaning | When to use |
|------|---------|-------------|
| 200 | OK | Success with body (GET, PATCH, PUT) |
| 201 | Created | Success with new resource (POST create) |
| 204 | No Content | Success with no body (DELETE) |
| 301 | Moved Permanently | Resource renamed; clients must update |
| 304 | Not Modified | `If-None-Match` ETag matched; cached body still valid |
| 400 | Bad Request | Malformed JSON / missing required field / wrong type |
| 401 | Unauthorized | No valid auth credential |
| 403 | Forbidden | Auth present but lacks permission |
| 404 | Not Found | Resource doesn't exist OR caller can't see it (see below) |
| 409 | Conflict | Uniqueness violation, state conflict (e.g., trying to delete a paid invoice) |
| 410 | Gone | Resource permanently deleted (use for GDPR erasure flows) |
| 412 | Precondition Failed | `If-Match` ETag didn't match (optimistic concurrency failure) |
| 422 | Unprocessable Entity | Schema valid but business rules failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected failure (retry with backoff) |
| 503 | Service Unavailable | Maintenance / overload |

**Pitfall: 404 vs 403 vs 410**
- `404 Not Found` — resource doesn't exist, OR caller doesn't have read access (security: don't leak existence)
- `403 Forbidden` — caller authenticated, resource exists, but no permission (e.g., trying to view another user's draft)
- `410 Gone` — resource is permanently deleted and won't come back (GDPR right-to-erasure, deprecated API sunset)

### Step 2.3 — Per-endpoint table

For every endpoint, document:

```markdown
### `POST /v1/projects`
**Story:** "creator creates a new project"
**Auth:** user (creator role required)
**Rate limit:** 30 req / 5 min / user
**Idempotency:** required for paid-tier (use `Idempotency-Key` header)
**Request body:**
```json
{
  "name": "string (1..80)",
  "visibility": "private | public",
  "templateId": "uuid | null"
}
```
**Responses:**
- `201 Created` → returns full `Project` resource with `id`, `createdAt`, `ownerId`
- `400 Bad Request` → `validation_error` — name too long, visibility invalid
- `401 Unauthorized` → `auth_missing`
- `403 Forbidden` → `tier_required` — user not on creator tier
- `409 Conflict` → `name_taken` — user already has a project with this name
- `429 Too Many Requests` → `rate_limited`

**Headers (request):**
- `Idempotency-Key: <uuid>` (recommended; required for paid)
- `Authorization: Bearer <jwt>` (required)
**Headers (response):**
- `Location: /v1/projects/{id}` (on 201)
- `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset` (RFC 9239)
- `ETag: "<sha256>"` (on 200, for conditional GET)
```

---

## Phase 3 — Naming and versioning (3 min)

### Step 3.1 — Resource naming

| Do | Don't |
|----|-------|
| `GET /projects` | `GET /getProjects` |
| `GET /projects/{id}` | `GET /project/{id}` (singular) |
| `POST /projects` | `POST /createProject` |
| `DELETE /projects/{id}` | `GET /deleteProject?id=...` |
| `POST /projects/{id}/members` | `POST /addMemberToProject` |

**Rules:**
- Plural nouns (`/projects`, `/users`), always.
- Lowercase, kebab-case for multi-word (`/api-keys`, not `/apiKeys`).
- IDs are opaque strings (`uuid` or `nanoid`); don't expose DB autoincrement integers.
- No verbs in the path; the HTTP method IS the verb.
- No file extensions (`.json`, `.xml`); use `Accept` header.

### Step 3.2 — Versioning

**Rule:** URI path versioning for public APIs.

```
/v1/projects
/v2/projects
```

**Why URI and not header?**
- Discoverable (you can guess the URL)
- Cacheable (CDNs can route by path)
- Easy to document (each version is a separate `openapi.yaml`)
- The header-versioning crowd is wrong for browser-mobile-server mixes

**Rules:**
- Major version in path. Minor and patch are silent.
- New endpoint → add to current major.
- Breaking change to existing endpoint → new major (`/v2/projects`), keep `/v1/projects` running with `Sunset` header.
- A breaking change = removing a field, changing a type, changing semantics, removing an endpoint, changing auth requirements.

### Step 3.3 — Deprecation

When sunsetting an endpoint:

```yaml
paths:
  /v1/projects/{id}:
    get:
      deprecated: true
      description: |
        **DEPRECATED.** Use `GET /v2/projects/{id}`. 
        Sunset date: 2027-01-01.
```

Response headers on every deprecated response:
- `Deprecation: true` (RFC 8594)
- `Sunset: Sat, 01 Jan 2027 00:00:00 GMT` (RFC 8288)
- `Link: </v2/projects/{id}>; rel="successor-version"` (RFC 5988)

---

## Phase 4 — Output (5 min)

After Phases 1-3, you have everything to:

1. **Write the resource model** as a markdown table in `contracts/RESOURCES.md`
2. **Write the endpoint list** as a markdown table in `contracts/ENDPOINTS.md`
3. **Write the auth matrix** in `contracts/AUTH.md` (using `@frameworks/auth-patterns-per-endpoint.md`)
4. **Write the rate limit spec** in `contracts/RATE-LIMITS.md` (using `@frameworks/rest-best-practices.md`)
5. **Hand off to `@tasks/generate-openapi-spec.md`** to turn it all into `openapi.yaml`

The hand-off package:

```
contracts/
├── RESOURCES.md        # Noun model (from Phase 1.4)
├── ENDPOINTS.md        # Per-endpoint table (from Phase 2.3)
├── AUTH.md             # Auth matrix per endpoint
├── RATE-LIMITS.md      # Rate limits per endpoint
└── openapi.yaml        # (generated in next task)
```

---

## Pitfalls (load this before writing the spec)

### Pitfall 1: Don't mix collection and singleton in one path

```
❌ /projects (GET = list, GET /projects/{id} = item) — confusing but standard
✅ /projects (GET = list)
✅ /projects/{id} (GET = item)
```

This IS the standard. The pitfall is the opposite — using the same path for both with different semantics, e.g., `GET /projects` returns either a list OR an item based on `Accept` headers. Don't.

### Pitfall 2: Don't use 200 for everything

`200 OK` for a failure (because "the request reached the server") is a crime. Clients switch on status codes. Use `4xx` and `5xx` correctly.

### Pitfall 3: Don't return different shapes on success vs error

Pick ONE envelope and use it everywhere:

**Recommended envelope (RFC 7807 + extension):**

```json
// Success
{
  "data": { ... resource ... },
  "meta": { "requestId": "...", "pagination": { ... } }
}

// Error
{
  "error": {
    "code": "validation_error",
    "message": "Name must be 1-80 characters",
    "details": [
      { "path": "name", "code": "string_too_long", "max": 80 }
    ],
    "requestId": "...",
    "documentationUrl": "https://docs.example.com/errors/validation_error"
  }
}
```

The full catalog is in `@frameworks/error-codes-catalog.md`. **Do not invent new shapes per endpoint.**

### Pitfall 4: PUT is not POST

`PUT /projects/{id}` REPLACES the entire resource. If you omit a field, it gets nulled. For partial updates, use `PATCH /projects/{id}` with JSON Merge Patch (`application/merge-patch+json`) or JSON Patch (`application/json-patch+json`).

If your team keeps getting this wrong, **only ship PATCH**. Don't ship PUT. Less footgun, same power.

### Pitfall 5: POST for "delete this specific resource" is wrong

```
❌ POST /projects/{id}/delete
✅ DELETE /projects/{id}
```

POST is for creates and actions (where the verb isn't standard). DELETE is for delete.

### Pitfall 6: Trailing slashes and dots

Pick one (no trailing slash, no dots in paths) and stick with it. `/projects` and `/projects/` are NOT the same resource to a strict router. Pick `/projects/{id}`, never `/projects/{id}/`.

---

## Anti-patterns (load this before committing the design)

- ❌ **CRUD-blind design** — every resource gets GET / POST / PUT / DELETE whether or not the story needs them. DELETE on `Invoice`? Will a user ever delete an invoice? Probably not (compliance). Skip it.
- ❌ **Singular resource names** — `/project`, `/user`. Always plural.
- ❌ **Verb-in-path** — `/createProject`, `/getUserById`. The HTTP method IS the verb.
- ❌ **Nested 3+ levels** — `/orgs/{orgId}/teams/{teamId}/projects/{projectId}/tasks/{taskId}`. Flatten with `?projectId=`.
- ❌ **Different error envelopes per endpoint** — pick one (see Pitfall 3).
- ❌ **Returning the full DB row** — strip server-only fields (`passwordHash`, `internalNotes`).
- ❌ **Date strings without timezone** — `"createdAt": "2026-06-24"` (no Z, no offset). Always RFC 3339 with `Z`: `"2026-06-24T10:30:00Z"`.
- ❌ **Integer IDs** — `12345` leaks business volume. Use UUID v4 or ULID. If you must expose int IDs, treat them as opaque strings in the spec.
- ❌ **`/api` prefix** — `/api/v1/projects` is redundant. The `/v1/...` IS the API. (Exception: reverse-proxied mix of API + frontend, where the prefix disambiguates.)
- ❌ **Inconsistent pagination** — `/users?cursor=...` on one endpoint, `/users?page=2` on another. Pick one (cursor for everything that grows, offset for stable admin lists). Document it once.

---

## Acceptance criteria

A complete `/api-contract rest` task produces:

- [ ] `contracts/RESOURCES.md` with the resource model table
- [ ] `contracts/ENDPOINTS.md` with one section per endpoint (verb, path, story, auth, rate limit, request, responses)
- [ ] `contracts/AUTH.md` with auth matrix
- [ ] `contracts/RATE-LIMITS.md` with per-endpoint rate limits
- [ ] All endpoints use plural nouns, kebab-case, no verbs in path
- [ ] All endpoints have documented status codes (no missing 4xx cases)
- [ ] All write endpoints have idempotency story documented (required for money, optional for rest)
- [ ] Error envelope shape is one consistent format (referenced from `@frameworks/error-codes-catalog.md`)
- [ ] Versioning strategy decided and documented (URI path: `/v1/...`)
- [ ] Hand-off ready for `@tasks/generate-openapi-spec.md`