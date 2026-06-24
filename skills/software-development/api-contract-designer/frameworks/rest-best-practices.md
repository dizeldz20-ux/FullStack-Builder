---
name: rest-best-practices
description: Production-grade REST API patterns — pagination, filtering, sorting, idempotency, ETags, rate limiting, versioning. Apply to every API we ship.
---

# REST Best Practices

כללי ברזל ל-REST API שעובד בפרודקשן. אל תדלג על אלה.

## URL Structure

```
# Resources (plural nouns)
/projects
/projects/{id}
/projects/{id}/tasks
/projects/{id}/tasks/{taskId}

# Actions (verb in URL only when RPC-style)
/projects/{id}/archive
/auth/login
/auth/refresh

# Filter/query params (not in URL path)
/projects?status=active&owner=me
```

### Versioning

```
# Path versioning - הכי ברור
/api/v1/projects
/api/v2/projects

# Header versioning - נקי יותר
Accept: application/vnd.acme.v2+json

# תמיד תתמוך ב-v1 לפחות 6 חודשים אחרי v2
```

## Pagination

### Cursor-based (מומלץ לרוב המקרים)

```http
GET /projects?cursor=eyJpZCI6IjEyMyJ9&limit=20

Response:
{
  "items": [...],
  "nextCursor": "eyJpZCI6IjE0MyJ9",
  "hasMore": true
}
```

✅ יתרונות: consistent גם כשמוסיפים items, אין skip overhead
❌ חסרון: אי אפשר לקפוץ לעמוד 5

### Offset-based (legacy/admin)

```http
GET /projects?offset=40&limit=20
```

✅ יתרון: page numbers
❌ חסרון: inconsistent כשמוסיפים items, איטי ב-DB

### הכלל

**Cursor לכל API ציבורי. Offset רק ל-admin/internal.**

## Filtering

```http
# Single field
GET /projects?status=active

# Multiple values
GET /projects?status=active,draft

# Range
GET /projects?createdAfter=2024-01-01&createdBefore=2024-12-31

# Combined
GET /projects?status=active&owner=me&sort=-createdAt
```

### Operator prefix (לשדות מספריים/תאריכים)

```http
GET /projects?viewCount_gte=100&viewCount_lt=1000
# _gte = greater than or equal
# _gt, _lte, _lt, _ne
```

## Sorting

```http
# Single field, ascending
GET /projects?sort=createdAt

# Descending (prefix -)
GET /projects?sort=-createdAt

# Multiple fields
GET /projects?sort=-priority,createdAt
```

## Idempotency

### POST עם Idempotency Key

```http
POST /payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000

{
  "amount": 1000,
  "currency": "USD",
  "customerId": "cus_123"
}
```

- אותו key + body → אותה תשובה (לא duplicate charge)
- שמור את התוצאה לפחות 24 שעות
- 409 אם body שונה עם אותו key

### PUT = idempotent מעצם ההגדרה

```http
PUT /projects/123
{ "name": "New name" }
# קריאה חוזרת = אותה תוצאה
```

## ETags (caching)

```http
GET /projects/123

Response:
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
```

```http
GET /projects/123
If-None-Match: "33a64df551425fcc55e4d42a148795d9f25f89d4"

Response:
304 Not Modified
```

✅ חוסך bandwidth
✅ תומך ב-optimistic concurrency control

## Rate Limiting

### Headers

```http
Response headers (כל תגובה):
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 743
X-RateLimit-Reset: 1640995200

כשחורג:
HTTP 429 Too Many Requests
Retry-After: 60
```

### Strategy

- **Per-IP**: anti-abuse
- **Per-user**: fair usage
- **Per-API-key**: B2B quotas
- **Global**: anti-DDoS

### Bucket algorithms

- **Fixed window**: פשוט, bursty בגבולות
- **Sliding window**: חלק יותר
- **Token bucket**: הכי טוב ל-API (refills over time)

## HTTP Status Codes

| Code | מתי |
|------|-----|
| 200 | OK (GET, PUT, PATCH) |
| 201 | Created (POST שיוצר) |
| 204 | No Content (DELETE) |
| 400 | Validation error |
| 401 | Not authenticated |
| 403 | Authenticated but not allowed |
| 404 | Resource not found |
| 409 | Conflict (duplicate, version mismatch) |
| 422 | Semantic validation failed |
| 429 | Rate limited |
| 500 | Server error |
| 503 | Service unavailable (maintenance) |

### Error response format (consistent)

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": { "field": ["error details"] },
    "requestId": "req_abc123",
    "documentationUrl": "https://docs.acme.com/errors/VALIDATION_ERROR"
  }
}
```

## Caching

```http
Cache-Control: public, max-age=3600
Cache-Control: private, max-age=300, must-revalidate
Cache-Control: no-store
```

- **public**: יכול להישמר ב-CDN
- **private**: רק ב-browser cache
- **max-age**: כמה זמן תוצאה טריה (seconds)
- **must-revalidate**: אל תציג מ-stale cache בלי לבדוק
- **no-store**: אל תשמור (sensitive data)

## CORS

```
Access-Control-Allow-Origin: https://app.acme.example
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

⚠️ לעולם לא `Allow-Origin: *` עם credentials.

## verification checklist

- [ ] כל endpoint עם pagination עקבי
- [ ] כל POST/PUT idempotent
- [ ] ETags על resources בודדים
- [ ] Rate limiting על כל endpoint ציבורי
- [ ] Error format עקבי
- [ ] CORS מוגדר נכון
- [ ] docs מתעדכנים (OpenAPI)
- [ ] integration tests לכל pattern

---

_footer: api-contract-designer/frameworks/rest-best-practices.md · api-contract-designer v0.1.0_
