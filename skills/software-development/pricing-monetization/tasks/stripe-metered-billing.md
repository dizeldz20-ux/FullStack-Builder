# Stripe Metered Billing — Usage-Based Pricing

## מטרה / Purpose

להטמיע usage-based pricing: גבייה לפי צריכה (API calls, tokens, GB, compute-time). מתאים ל-API products, AI/LLM, data pipelines.

## When to use

- AI / LLM APIs (per token)
- API products (per call)
- Storage / bandwidth (per GB)
- Compute (per second)
- Triggers (per event)

## Why metered > flat for AI products

1. **Variable cost** — your cost scales with usage; flat pricing eats margin
2. **Land-and-expand** — easy to start, grows with customer value
3. **Self-serve** — no sales call needed for low-volume users
4. **Predictable for customer** — they see usage, not surprised invoice

## Architecture

```
Client ──▶ Your API ──▶ Do the work ──▶ Report usage ──▶ Stripe
                           │                                  │
                           ▼                                  │
                     Usage counter ◀────────── Webhook ◀─────┘
                     (your DB)
```

**Two Stripe approaches:**

1. **Metered subscriptions** — usage aggregated, billed at end of period
2. **Usage records API** — explicit `subscription_items.create_usage_record` calls

Use **Metered subscriptions** — simpler, automatic.

## 1. Setup: metered price

```typescript
const product = await stripe.products.create({
  name: "API Calls",
});

const meteredPrice = await stripe.prices.create({
  product: product.id,
  currency: "usd",
  recurring: {
    interval: "month",
    usage_type: "metered",
    aggregate_usage: "sum", // sum all usage in period
  },
  billing_scheme: "per_unit",
  unit_amount: 1, // $0.01 per call
  lookup_key: "api_calls_metered",
});
```

**Tiers (volume discount):**

```typescript
const tieredPrice = await stripe.prices.create({
  product: product.id,
  currency: "usd",
  recurring: {
    interval: "month",
    usage_type: "metered",
    aggregate_usage: "sum",
  },
  billing_scheme: "tiered",
  tiers_mode: "graduated", // or "volume"
  tiers: [
    { up_to: 10000,    unit_amount: 0    },  // first 10K free
    { up_to: 100000,   unit_amount: 1    },  // 10K-100K: $0.01
    { up_to: 1000000,  unit_amount_decimal: "0.005" }, // 100K-1M: $0.005
    {                       unit_amount_decimal: "0.002" }, // 1M+: $0.002
  ],
  lookup_key: "api_calls_tiered",
});
```

`graduated` = charge per tier the usage falls into (Progressive).
`volume` = single rate based on total volume (simpler for customer).

## 2. Subscribe customer to metered plan

```typescript
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: meteredPrice.id }],
  metadata: { userId },
});

// Customer now has a subscription. Usage will be reported and billed.
```

For hybrid (base fee + metered overage):

```typescript
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [
    { price: basePrice.id },        // $79/mo base
    { price: meteredPrice.id },     // $0.01/call overage
  ],
  metadata: { userId },
});
```

## 3. Report usage (the core flow)

Two ways:

### a. Manual reporting — explicit `createUsageRecord`

```typescript
// After each API call (or batched)
async function reportUsage(
  subscriptionItemId: string,
  quantity: number
) {
  await stripe.subscriptionItems.createUsageRecord(
    subscriptionItemId,
    {
      quantity,
      timestamp: Math.floor(Date.now() / 1000),
      action: "increment", // or "set"
    }
  );
}
```

**When to call:** After each billable event, OR batched (every 1-5 min). Batching reduces API calls.

### b. Stripe SDK auto-reporting (simpler)

```typescript
// Stripe doesn't auto-report — you must send events.
// But you can wrap it in middleware:
app.use("/api/llm", async (req, res, next) => {
  const start = Date.now();
  res.on("finish", async () => {
    const tokensUsed = res.locals.tokensUsed || 0;
    if (tokensUsed > 0) {
      await reportUsage(req.user.subscriptionItemId, tokensUsed);
    }
  });
  next();
});
```

## 4. Persist usage in your DB (recommended)

**Don't trust Stripe as source of truth** — your DB should mirror:

```typescript
// usage_events table
{
  id: uuid,
  userId: uuid,
  subscriptionItemId: string,
  quantity: number,
  metric: "api_calls" | "tokens" | "compute_seconds",
  timestamp: timestamptz,
  reportedToStripe: boolean,
  stripeReportedAt: timestamptz,
}
```

This gives you:
- Customer-facing usage dashboard (real-time)
- Dispute resolution
- Forecasting
- Anomaly detection

## 5. Customer-facing usage dashboard

```typescript
// GET /api/usage/current
async function getCurrentUsage(userId: string) {
  const user = await db.users.findById(userId);
  const sub = await stripe.subscriptions.retrieve(user.stripeSubscriptionId);

  const item = sub.items.data.find(
    (i) => i.price.lookup_key === "api_calls_metered"
  );

  // Stripe gives you usage records in current period
  const usage = await stripe.subscriptionItems.listUsageRecordSummaries(
    item.id,
    { limit: 1 }
  );

  const currentPeriodTotal = usage.data[0]?.total_usage || 0;
  const periodEnd = new Date(item.current_period_end * 1000);

  return {
    usage: currentPeriodTotal,
    limit: user.tier === "free" ? 1000 : Infinity,
    projectedCost: estimateCost(currentPeriodTotal),
    periodEnd,
  };
}
```

## 6. Enforce limits (don't let unpaid users run wild)

```typescript
async function checkQuota(userId: string): Promise<boolean> {
  const usage = await getCurrentUsage(userId);
  const limits = {
    free: 1000,
    pro: 100000,
    enterprise: Infinity,
  };

  return usage.usage < (limits[user.tier] ?? 0);
}

// In API route:
app.post("/api/llm/chat", async (req, res) => {
  if (!(await checkQuota(req.user.id))) {
    return res.status(429).json({
      error: "quota_exceeded",
      upgradeUrl: "/pricing",
    });
  }
  // ... do work
  // Report usage after
});
```

## 7. Aggregation strategy — when to send to Stripe

| Strategy | When | Tradeoff |
|---|---|---|
| Per-request | Low QPS (<100 req/min) | Simple, real-time cost |
| Batched (1-5 min) | Medium QPS | Balance of accuracy and API call count |
| End-of-period | High QPS (>10K req/min) | Cheap, but customer can't see real-time |

For most startups: **batched every 1 minute** is the sweet spot.

```typescript
// In-memory buffer
const usageBuffer = new Map<string, number>(); // key: subItemId

async function track(subItemId: string, qty: number) {
  usageBuffer.set(subItemId, (usageBuffer.get(subItemId) || 0) + qty);
}

// Flush every 60s
setInterval(async () => {
  for (const [subItemId, qty] of usageBuffer) {
    if (qty > 0) {
      await stripe.subscriptionItems.createUsageRecord(subItemId, {
        quantity: qty,
        timestamp: Math.floor(Date.now() / 1000),
        action: "increment",
      });
      usageBuffer.set(subItemId, 0);
    }
  }
}, 60_000);
```

## 8. Tax (Stripe Tax)

For usage-based with tax:

```typescript
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: meteredPrice.id }],
  automatic_tax: { enabled: true },
});
```

Stripe will calculate tax on metered usage at the end of period.

## Failure modes

| Risk | Mitigation |
|---|---|
| Stripe usage report fails | Local DB has buffer; retry queue |
| Customer disputes bill | Your `usage_events` table is source of truth |
| Massive overage attack | Pre-check quota, hard cap |
| Reporting wrong quantity | Always store locally FIRST, then report |

## Done checklist

- [ ] Metered price created with lookup_key
- [ ] Customer subscribed to metered plan
- [ ] Usage reporting endpoint or middleware
- [ ] Local `usage_events` table
- [ ] Quota enforcement on protected endpoints
- [ ] Customer-facing usage dashboard
- [ ] Reconciliation: daily job pulls Stripe usage, compares to DB
- [ ] Hard cap on runaway usage
- [ ] Tax enabled if needed

---

_footer: pricing-monetization/tasks/stripe-metered-billing.md · v0.1.0_