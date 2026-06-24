---
name: openapi-vs-graphql-decision
description: Decision guide for choosing between OpenAPI (REST) and GraphQL. Use when starting a new API or considering migration.
---

# OpenAPI vs GraphQL — Decision Guide

איך לבחור בין REST/OpenAPI ל-GraphQL ל-API הבא שלך.

## TL;DR

**ברירת מחדל: REST + OpenAPI.** רק לעבור ל-GraphQL אם יש סיבה ספציפית.

## מתי REST/OpenAPI עדיף

✅ **CRUD פשוט** — resources בודדים, operations סטנדרטיות
✅ **Public API לצד שלישי** — SDK generation, caching ב-CDN
✅ **File uploads / binary** — GraphQL לא טוב בזה
✅ **Server-Sent Events / streaming פשוט** — REST קל יותר
✅ **Mobile + Web עם אותם data** — אין בעיית over-fetching
✅ **Team קטן, צריך מהר** — REST מהיר יותר ל-bootstrap
✅ **HTTP caching** — REST caches נהדר, GraphQL לא

## מתי GraphQL עדיף

✅ **Relations מורכבות** — 3+ levels deep joining
✅ **Clients הטרוגניים** — mobile רוצה 5 fields, web רוצה 20
✅ **Rapid frontend iteration** — UI משתנה הרבה, schema stable
✅ **Real-time / subscriptions** — native ב-GraphQL
✅ **Aggregation מ-multiple sources** — stitch services
✅ **Internal API** — graph של microservices

## השוואה מפורטת

| קריטריון | REST + OpenAPI | GraphQL |
|----------|---------------|---------|
| **Learning curve** | קל (HTTP בסיסי) | בינוני (schema, resolvers) |
| **Tooling** | בשל מאוד | בשל אבל מורכב יותר |
| **Caching** | native (HTTP cache, CDN) | custom (Apollo, persisted queries) |
| **File uploads** | trivial (`multipart/form-data`) | awkward (need separate REST) |
| **Versioning** | URL-based (`/v1`, `/v2`) | schema evolution (deprecate) |
| **N+1 queries** | control ידני | DataLoader patterns required |
| **Auth** | per-endpoint (middleware) | per-field (directives) |
| **Rate limiting** | per-endpoint | complexity-based |
| **Docs** | Swagger/Redoc auto-generated | GraphiQL/Apollo Studio built-in |
| **Errors** | HTTP status codes standard | custom (userErrors pattern) |
| **Performance** | predictable | can be unpredictable (complex queries) |
| **Bundle size** | trivial | Apollo Client 30KB+ |
| **TypeScript** | openapi-typescript (easy) | graphql-codegen (easy) |
| **Webhooks** | natural (POST endpoints) | subscriptions (more complex) |
| **Cost analysis** | request = cost unit | request = arbitrary cost |

## דוגמאות מעשיות

### Use case: SaaS לניהול משלוחים

**REST** כי:
- resources ברורים (Order, Driver, Customer)
- operations פשוטות (CRUD + status updates)
- צריך file upload (תמונת מוצר)
- mobile + web עם אותו UI

### Use case: Dashboard אנליטיקה

**GraphQL** כי:
- 10+ entities (User, Session, Event, Cohort, Funnel...)
- web dashboard רוצה aggregations שונים
- mobile רוצה רק key metrics
- real-time event stream

### Use case: Stripe-like payment API

**REST** כי:
- SDK generation ל-100+ languages
- webhooks קריטיים
- HTTP caching חשוב
- versioning קל

### Use case: Facebook-like social graph

**GraphQL** כי:
- infinite relations (posts, comments, likes, shares)
- mobile vs web UI שונה מאוד
- real-time feed

## hybrid approach

לפעמים **שילוב** הוא הפתרון:

```
REST API → webhooks, file uploads, public integrations, billing
GraphQL  → internal aggregation, complex relations, real-time
```

דוגמה: Shopify משתמש ב-REST ל-Admin API + GraphQL חדש ל-storefront.

## migration path

### REST → GraphQL

1. הוסף GraphQL gateway מעל ה-REST API
2. Resolvers קוראים לקיים REST endpoints
3. clients חדשים מתחילים ב-GraphQL
4. legacy clients ממשיכים ב-REST
5. אחרי שנה: deprecate REST לפי service

### GraphQL → REST

1. זהה resolvers פשוטים (queries בודדות, no joins)
2. חשוף אותם גם כ-REST endpoints
3. העבר clients שלא צריכים GraphQL features
4. שמור GraphQL לפעולות מורכבות

## verification

- [ ] החלטה מתועדת ב-PRD/ADR (Architecture Decision Record)
- [ ] הסיבות לבחירה ברורות (לא "GraphQL כי זה האופנה")
- [ ] tradeoffs הובנו לכל חבר צוות
- [ ] migration plan אם מחליפים בעתיד

---

_footer: api-contract-designer/references/openapi-vs-graphql-decision.md · api-contract-designer v0.1.0_
