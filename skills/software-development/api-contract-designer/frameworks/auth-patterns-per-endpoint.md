---
name: auth-patterns-per-endpoint
description: Auth requirements per endpoint type — public, user, admin, service-to-service. Use this to mark which endpoints need which level of auth.
---

# Auth Patterns Per Endpoint

## 4 רמות auth

### 1. Public (אין auth)

```http
GET /health
GET /api/v1/public/projects/featured
POST /auth/login
POST /auth/signup
POST /auth/forgot-password
GET /auth/verify-email?token=***
```

**מתי**: המידע לא רגיש, צריך להיות נגיש בלי חשבון.

**שימוש**: landing pages, marketing, health checks, public catalog.

### 2. User (JWT/session של משתמש רגיל)

```http
GET /api/v1/me
GET /api/v1/me/projects
POST /api/v1/projects
PUT /api/v1/projects/{id}
DELETE /api/v1/projects/{id}
```

**מתי**: המשתמש פועל על המשאבים שלו.

**דרישות**:
- ✅ valid session/JWT
- ✅ user.id matches resource.ownerId (או חבר צוות)
- ❌ לא admin

### 3. Admin (role-based, server-only)

```http
GET /api/v1/admin/users
POST /api/v1/admin/users/{id}/ban
PUT /api/v1/admin/config
GET /api/v1/admin/audit-log
```

**מתי**: גישה לכל המשאבים, לא רק של המשתמש.

**דרישות**:
- ✅ valid session/JWT
- ✅ role === 'admin' (verified server-side)
- ✅ logged to audit log
- ❌ never accessible from client bundle

### 4. Service-to-service (machine-to-machine)

```http
POST /internal/jobs/process
POST /internal/webhooks/stripe
GET /internal/metrics
```

**מתי**: תקשורת בין services בתוך התשתית.

**דרישות**:
- ✅ API key / mTLS / service token
- ✅ rate limit per service
- ✅ allowed only from internal IPs / VPC
- ❌ never accessible from public internet

## implementation

### Express middleware stack

```typescript
import { auth, requireRole, requireService } from './middleware';

// Public
app.get('/health', healthHandler);
app.post('/auth/login', loginHandler);

// User (auth required)
app.get('/api/v1/me', auth(), getMeHandler);
app.post('/api/v1/projects', auth(), createProjectHandler);

// Admin
app.get('/api/v1/admin/users', auth(), requireRole('admin'), listUsersHandler);

// Service-to-service
app.post('/internal/jobs', requireService(['worker', 'scheduler']), processJobHandler);
```

### Supabase RLS (Postgres-level auth)

```sql
-- Public: anyone can read
create policy "Public can read featured projects"
  on projects for select
  using (is_featured = true);

-- User: only own data
create policy "Users can read own projects"
  on projects for select
  using (auth.uid() = owner_id);

-- Admin: server-only, bypasses RLS with service_role key
-- (use carefully, only in trusted server code)
```

### Next.js middleware (edge-level auth)

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const path = request.nextUrl.pathname;
  
  // Public paths
  if (path.startsWith('/_next') || path === '/login' || path === '/') {
    return NextResponse.next();
  }
  
  // Admin paths - require admin role
  if (path.startsWith('/admin')) {
    const role = request.cookies.get('role')?.value;
    if (role !== 'admin') {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }
  
  // Protected paths - require any user
  if (path.startsWith('/dashboard')) {
    const token = request.cookies.get('session')?.value;
    if (!token) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }
  
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
```

## Service-to-service patterns

### Webhook signatures (incoming)

```typescript
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

// Stripe signs every webhook - verify signature
app.post('/webhooks/stripe', 
  express.raw({ type: 'application/json' }),
  (req, res) => {
    const sig = req.headers['stripe-signature']!;
    try {
      const event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET!
      );
      // Handle verified event
      handleStripeEvent(event);
      res.json({ received: true });
    } catch (err) {
      res.status(400).send(`Webhook Error: ${err.message}`);
    }
  }
);
```

### Outbound service tokens

```typescript
// Use short-lived tokens for service-to-service
const serviceToken = await issueServiceToken({
  service: 'worker',
  scope: ['jobs:read', 'jobs:write'],
  expiresIn: '5m',
});

await fetch('https://api.internal/jobs', {
  headers: {
    'Authorization': `Bearer ${serviceToken}`,
    'X-Service-Name': 'worker-1',
  },
});
```

## Decision matrix

| Endpoint | Public | User | Admin | Service |
|----------|--------|------|-------|---------|
| `/health` | ✅ | | | |
| `/auth/login` | ✅ | | | |
| `/api/me/*` | | ✅ | | |
| `/api/projects/*` (own) | | ✅ | | |
| `/api/projects/*` (any) | | | ✅ | |
| `/admin/*` | | | ✅ | |
| `/internal/jobs` | | | | ✅ |
| `/webhooks/*` | | | | ✅ (verify sig) |

## verification

- [ ] כל endpoint מסומן ברמה הנכונה
- [ ] middleware/auth נבדק בכל endpoint
- [ ] אין admin endpoints חשופים ב-client bundle
- [ ] service-to-service tokens קצרי-מועד
- [ ] webhooks עם signature verification
- [ ] audit log לכל admin action
- [ ] RLS policies מקיפות (Supabase)

---

_footer: api-contract-designer/frameworks/auth-patterns-per-endpoint.md · api-contract-designer v0.1.0_
