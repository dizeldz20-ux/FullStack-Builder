---
name: error-codes-catalog
description: Standard + custom error codes catalog. Reuse these codes consistently across all APIs so client code can handle errors uniformly.
---

# Error Codes Catalog

## קודים סטנדרטיים (לעשות שימוש חוזר)

### Authentication & Authorization (1xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `UNAUTHENTICATED` | 401 | חסר token / token לא תקין | בקשה דורשת auth אבל אין |
| `TOKEN_EXPIRED` | 401 | Token פג תוקף | צריך refresh |
| `INVALID_TOKEN` | 401 | Token לא תקין (bad signature) | refresh נכשל → re-login |
| `FORBIDDEN` | 403 | אין הרשאה לפעולה הזו | user authenticated אבל לא מורשה |
| `ACCOUNT_LOCKED` | 403 | חשבון נעול (אבטחה) | יותר מדי ניסיונות כושלים |

### Validation (2xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `VALIDATION_ERROR` | 400 | Input לא עבר validation | required field חסר, פורמט שגוי |
| `INVALID_FORMAT` | 400 | פורמט לא תקין (email, phone, etc.) | regex/format check failed |
| `OUT_OF_RANGE` | 400 | ערך מחוץ לטווח | min/max length, numeric range |
| `INVALID_STATE` | 409 | state transition לא חוקי | ניסיון לאשר הזמנה שכבר בוטלה |

### Resource (3xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `NOT_FOUND` | 404 | resource לא קיים | ID לא קיים, או לא נגיש למשתמש |
| `ALREADY_EXISTS` | 409 | resource כבר קיים | duplicate email, unique constraint |
| `CONFLICT` | 409 | conflict עם state נוכחי | version mismatch, locked resource |
| `GONE` | 410 | resource נמחק | soft-deleted resource |

### Rate Limiting & Quotas (4xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `RATE_LIMITED` | 429 | יותר מדי בקשות | חורג מ-quota |
| `QUOTA_EXCEEDED` | 429 | חריגה מ-quota יומי/חודשי | API plan limit |
| `CONCURRENT_LIMIT` | 429 | יותר מדי פעולות במקביל | long-running ops |

### Server (5xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `INTERNAL_ERROR` | 500 | שגיאת שרת לא צפויה | bug, exception |
| `NOT_IMPLEMENTED` | 501 | feature לא מומש | endpoint קיים אבל לא עובד עדיין |
| `SERVICE_UNAVAILABLE` | 503 | שירות לא זמין | maintenance, overload |
| `TIMEOUT` | 504 | timeout | upstream/downstream לא הגיב |

### Integration (6xxx)

| Code | HTTP | משמעות | מתי |
|------|------|--------|-----|
| `UPSTREAM_ERROR` | 502 | שגיאה בשירות חיצוני | Stripe, SendGrid, third-party API |
| `DATABASE_ERROR` | 500 | שגיאת DB | connection, query timeout |
| `EXTERNAL_API_ERROR` | 502 | external API החזיר שגיאה | not our fault, but we surface |

## קודים ספציפיים למוצר (7xxx+)

### Auth-specific (7000-7099)

| Code | HTTP | משמעות |
|------|------|---------|
| `EMAIL_ALREADY_REGISTERED` | 409 | אימייל כבר רשום |
| `WEAK_PASSWORD` | 400 | סיסמה לא עומדת בדרישות |
| `OAUTH_PROVIDER_ERROR` | 502 | Google/Apple החזיר שגיאה |
| `MAGIC_LINK_EXPIRED` | 400 | magic link פג תוקף |
| `MAGIC_LINK_INVALID` | 400 | magic link לא תקין |

### Billing-specific (7100-7199)

| Code | HTTP | משמעות |
|------|------|---------|
| `CARD_DECLINED` | 402 | כרטיס נדחה |
| `INSUFFICIENT_FUNDS` | 402 | אין מספיק כסף |
| `SUBSCRIPTION_CANCELLED` | 402 | מנוי בוטל |
| `PAYMENT_REQUIRED` | 402 | צריך לשלם (paywall) |

### Upload/File (7200-7299)

| Code | HTTP | משמעות |
|------|------|---------|
| `FILE_TOO_LARGE` | 413 | קובץ גדול מדי |
| `UNSUPPORTED_FILE_TYPE` | 415 | סוג קובץ לא נתמך |
| `UPLOAD_FAILED` | 500 | העלאה נכשלה |
| `QUARANTINED_FILE` | 422 | קובץ נחסם (virus scan) |

## Structure

```typescript
type ErrorCode =
  // Auth
  | 'UNAUTHENTICATED'
  | 'TOKEN_EXPIRED'
  // ...etc

interface ApiError {
  error: {
    code: ErrorCode;
    message: string;       // user-facing (translated)
    details?: unknown;     // structured details
    requestId: string;     // for support
    documentationUrl?: string;
  };
}
```

## Client-side handling

```typescript
async function apiCall<T>(input: RequestInfo): Promise<T> {
  const res = await fetch(input);
  if (!res.ok) {
    const err: ApiError = await res.json();
    switch (err.error.code) {
      case 'UNAUTHENTICATED':
      case 'TOKEN_EXPIRED':
        // redirect to login
        break;
      case 'RATE_LIMITED':
        // show "try again later"
        break;
      case 'VALIDATION_ERROR':
        // show field-level errors
        break;
      default:
        // generic error
        break;
    }
    throw err;
  }
  return res.json();
}
```

## verification

- [ ] כל endpoint משתמש בקוד מהקטלוג (לא ממציאים)
- [ ] HTTP status תואם לקוד
- [ ] messages בעברית למשתמש, באנגלית ל-developer
- [ ] requestId לכל error (ל-tracing)
- [ ] documentation URL לכל קוד ציבורי
- [ ] client code יכול לעבוד איתם typed (TypeScript union)

---

_footer: api-contract-designer/frameworks/error-codes-catalog.md · api-contract-designer v0.1.0_
