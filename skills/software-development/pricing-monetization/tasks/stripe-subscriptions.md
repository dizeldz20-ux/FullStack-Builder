# Stripe Subscriptions — Recurring Billing Setup

## מטרה / Purpose

להטמיע recurring subscriptions ב-Stripe: customer creation, checkout, webhooks לטיפול ב-renewals / cancellations / failed payments.

## When to use

- Tiered SaaS (Starter / Pro / Enterprise)
- Per-seat pricing (Notion, Slack style)
- Annual + monthly plans
- Free trials → auto-convert

## Core architecture

```
┌─────────┐      ┌─────────────┐      ┌─────────┐
│ Client  │─────▶│ Your API    │─────▶│ Stripe  │
│         │◀─────│ (checkout)  │◀─────│         │
└─────────┘      └─────────────┘      └─────────┘
                       │                     │
                       │   webhooks          │
                       ◀─────────────────────┘
                       ▼
                 ┌───────────┐
                 │ DB (sync) │
                 └───────────┘
```

**עיקרון חשוב:** לעולם אל תסמוך על ה-frontend. כל מה שמגיע מ-Stripe חייב לעבור דרך webhook.

## 1. Create products + prices (Stripe dashboard OR API)

```typescript
// One-time setup via Stripe CLI or dashboard
// Or programmatically:
import Stripe from "stripe";
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

const product = await stripe.products.create({
  name: "Pro Plan",
  description: "For growing teams",
});

const monthlyPrice = await stripe.prices.create({
  product: product.id,
  unit_amount: 7900,        // $79.00 in cents
  currency: "usd",
  recurring: { interval: "month" },
});

const annualPrice = await stripe.prices.create({
  product: product.id,
  unit_amount: 75840,       // $79 * 12 * 0.80 = $758.40
  currency: "usd",
  recurring: { interval: "year" },
});
```

**⚠️ Don't recreate prices every deploy** — use `lookup_key`:

```typescript
const price = await stripe.prices.create({
  product: product.id,
  unit_amount: 7900,
  currency: "usd",
  recurring: { interval: "month" },
  lookup_key: "pro_monthly", // stable identifier
});

// Later:
const price = await stripe.prices.list({
  lookup_keys: ["pro_monthly"],
  active: true,
  limit: 1,
});
```

## 2. Checkout session

```typescript
// POST /api/checkout
app.post("/api/checkout", async (req, res) => {
  const { userId, priceLookupKey } = req.body;

  // Validate user, check idempotency, etc.
  const price = (await stripe.prices.list({
    lookup_keys: [priceLookupKey],
    active: true,
    limit: 1,
  })).data[0];

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: price.id, quantity: 1 }],
    customer_email: req.body.email, // or pre-existing customer ID
    success_url: `${BASE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${BASE_URL}/pricing`,
    metadata: { userId }, // CRITICAL — flows into subscription
    subscription_data: {
      metadata: { userId }, // also on subscription itself
      trial_period_days: 14,
    },
    allow_promotion_codes: true,
  });

  res.json({ url: session.url });
});
```

## 3. Customer Portal (cancellations, plan changes, invoice history)

```typescript
app.post("/api/billing-portal", async (req, res) => {
  const { customerId } = req.body; // from your DB

  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${BASE_URL}/settings/billing`,
  });

  res.json({ url: session.url });
});
```

This handles 90% of billing questions ("how do I cancel?", "where's my invoice?") without you writing code.

## 4. Webhooks — the critical part

```typescript
// POST /api/webhooks/stripe
// CRITICAL: needs raw body for signature verification
app.post(
  "/api/webhooks/stripe",
  express.raw({ type: "application/json" }),
  async (req, res) => {
    const sig = req.headers["stripe-signature"]!;
    let event: Stripe.Event;

    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET!
      );
    } catch (err) {
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        await handleCheckoutComplete(session);
        break;
      }
      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const sub = event.data.object as Stripe.Subscription;
        await syncSubscription(sub);
        break;
      }
      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        await cancelSubscription(sub);
        break;
      }
      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;
        await handleFailedPayment(invoice);
        break;
      }
      case "invoice.paid": {
        const invoice = event.data.object as Stripe.Invoice;
        await handlePaidInvoice(invoice);
        break;
      }
      default:
        // ignore
    }

    res.json({ received: true });
  }
);
```

## 5. Sync to your DB

```typescript
// subscriptions table mirrors Stripe state
async function syncSubscription(sub: Stripe.Subscription) {
  const userId = sub.metadata.userId;
  if (!userId) throw new Error("Missing userId metadata");

  await db.subscriptions.upsert({
    userId,
    stripeCustomerId: sub.customer as string,
    stripeSubscriptionId: sub.id,
    status: sub.status, // active, trialing, past_due, canceled, unpaid
    priceId: sub.items.data[0].price.id,
    currentPeriodEnd: new Date(sub.current_period_end * 1000),
    cancelAtPeriodEnd: sub.cancel_at_period_end,
  });
}

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  // Used for one-time setup after first checkout
  const userId = session.metadata?.userId;
  const subscriptionId = session.subscription as string;

  if (userId && subscriptionId) {
    const sub = await stripe.subscriptions.retrieve(subscriptionId);
    await syncSubscription(sub);
  }
}

async function handleFailedPayment(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string;
  // 1. Email user
  // 2. Optionally downgrade after N days (Stripe Smart Retries handle this)
  // 3. Update DB status to "past_due"
  await db.users.updateByCustomerId(customerId, {
    paymentStatus: "past_due",
  });
  await sendEmail(customerId, "payment_failed");
}
```

## 6. Gating access

```typescript
// Middleware: require active subscription
async function requireActiveSubscription(req, res, next) {
  const userId = req.user.id;
  const sub = await db.subscriptions.findByUserId(userId);

  if (!sub || !["active", "trialing"].includes(sub.status)) {
    return res.status(402).json({
      error: "subscription_required",
      upgradeUrl: "/pricing",
    });
  }
  next();
}
```

## 7. Local testing

```bash
# Forward webhooks to localhost
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Get signing secret
# Use the `whsec_...` from output in STRIPE_WEBHOOK_SECRET

# Trigger events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
stripe trigger invoice.payment_failed
```

## 8. Failure modes & defenses

| Risk | Mitigation |
|---|---|
| Webhook dropped → DB out of sync | Use Stripe webhooks retry; idempotent handlers; daily reconciliation job |
| Customer switches plans but DB stale | Always sync from `customer.subscription.updated` event |
| Trial abuse (same card, multiple trials) | Block on `customer.email` or use Stripe Radar |
| Failed payments → user stays on plan | Stripe Smart Retries; downgrade on `subscription.deleted` |

## Reconciliation cron

```typescript
// Run nightly: pull all active subs from Stripe, compare to DB
async function reconcile() {
  const subs = await stripe.subscriptions.list({ status: "active", limit: 100 });
  for (const sub of subs.data) {
    await syncSubscription(sub); // upsert is idempotent
  }
}
```

## Done checklist

- [ ] Products + prices created in Stripe (with lookup_keys)
- [ ] Checkout session endpoint
- [ ] Billing portal endpoint
- [ ] Webhook endpoint with signature verification
- [ ] DB table mirroring subscription state
- [ ] Gating middleware on protected routes
- [ ] Local test via `stripe listen`
- [ ] Reconciliation cron
- [ ] Failed payment email flow
- [ ] Customer success flow (cancel confirmation, down-sell)

---

_footer: pricing-monetization/tasks/stripe-subscriptions.md · v0.1.0_