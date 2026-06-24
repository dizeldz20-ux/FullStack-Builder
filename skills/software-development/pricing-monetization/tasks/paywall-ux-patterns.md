# Paywall UX Patterns

## מטרה / Purpose

איפה ואיך לחסום משתמשים — modal vs page vs hard-stop. דפוסים מוכחים, A/B test ideas, ומתי כל אחד מתאים.

## העיקרון: friction מתאים לערך

- **Soft wall** (toast, modal) — לפיצ'רים שלא קריטיים, משתמש יכול להמשיך בערך גם בלעדיהם
- **Hard wall** (full page) — לפיצ'רים שבלעדיהם אין ערך בכלל

## הדפוסים העיקריים / Core patterns

### 1. Inline upsell (lowest friction)

**מתי:** freemium tier, soft feature gates.

```tsx
// Show upgrade CTA inside an existing UI element
function ExportButton({ plan }: { plan: "free" | "pro" }) {
  if (plan === "free") {
    return (
      <div className="relative">
        <button className="btn-primary opacity-50 cursor-not-allowed"
                title="Upgrade to export">
          Export
        </button>
        <span className="absolute -top-2 -right-2 bg-yellow-400 text-xs px-1 rounded">
          PRO
        </span>
      </div>
    );
  }
  return <button className="btn-primary">Export</button>;
}
```

✅ Conversion rate: medium (5-10%)
✅ Doesn't break flow
❌ Easy to ignore

### 2. Modal paywall (medium friction)

**מתי:** hit a usage limit, want to convert before user leaves.

```tsx
// Trigger when: quota reached, premium feature clicked
function UsageLimitModal({ onClose, onUpgrade }: Props) {
  return (
    <Modal onClose={onClose}>
      <h2>You've used all 10 free exports</h2>
      <p>Upgrade to Pro for unlimited exports.</p>
      <div className="flex gap-2">
        <button onClick={onClose} className="btn-ghost">
          Maybe later
        </button>
        <button onClick={onUpgrade} className="btn-primary">
          Upgrade — $19/mo
        </button>
      </div>
      <p className="text-xs text-gray-500">
        Used by 12,000+ teams · Cancel anytime
      </p>
    </Modal>
  );
}
```

✅ Higher conversion (15-25%)
❌ Interrupts flow — use sparingly

**Don't show on first use.** Wait until user has experienced value.

### 3. Full-page paywall (high friction)

**מתי:** user exhausted free tier, end of trial.

```tsx
// /pricing or /upgrade
function PaywallPage() {
  return (
    <div className="max-w-4xl mx-auto py-16">
      <h1 className="text-4xl font-bold text-center">
        Your free trial ended
      </h1>
      <p className="text-xl text-center mt-4">
        Choose a plan to continue using [Product].
      </p>

      <PricingTable />
      {/* ... */}
    </div>
  );
}
```

✅ Highest conversion (30-50% of those who reach this)
❌ User cannot proceed without paying — risk of churn

**⚠️ Don't block mid-task.** Always let user finish what they started, then block.

### 4. Hard-stop paywall (extreme friction)

**מתי:** storage full, account suspended, payment failed.

```tsx
function AccountSuspended() {
  return (
    <div className="full-page-error">
      <h1>Account suspended</h1>
      <p>Update payment method to restore access.</p>
      <button>Update payment →</button>
      <p className="text-sm text-gray-500">
        Need help? <a href="mailto:support@...">Contact us</a>
      </p>
    </div>
  );
}
```

Use only for: payment failed > 7 days, ToS violation. **Never on free tier limits.**

## Decision matrix

| Situation | Pattern | Why |
|---|---|---|
| Free user clicks Pro feature | Inline upsell | Soft, doesn't kill flow |
| Free user hits usage limit | Modal | Pre-empts churn at moment of need |
| Trial ended | Full-page | They've seen value, time to commit |
| Payment failed | Modal + email | Don't lock out immediately |
| Payment failed > 7 days | Hard-stop | Stripe Smart Retries already tried |
| Enterprise-only feature | Full-page | "Contact sales" path |
| Power-user nudge (50% of quota) | Toast | Just informational |

## Trial patterns

### Reverse trial (less common, high conversion)

User gets full Pro access. After 14 days, downgrades to free unless they pick a paid plan.

```typescript
// At signup: give them a Pro subscription with trial
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: proPrice.id }],
  trial_period_days: 14,
  trial_settings: {
    end_behavior: { missing_payment_method: "cancel" },
  },
});
```

### Opt-in trial (more common)

User starts on free, clicks "Start trial" to get 14 days of Pro.

```typescript
// User clicks "Start Trial"
await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: proPrice.id }],
  trial_period_days: 14,
  payment_method: cardId,
  // Will charge on day 14 unless cancelled
});
```

**Reverse > opt-in** because:
- User experiences full value before being asked
- Higher conversion to paid (60-80% vs 15-25%)
- Less sticker shock

## A/B test ideas

### Test 1: Price display

- A: "$19/month"
- B: "$190/year (save 20%)" with monthly as secondary

Hypothesis: B increases annual conversion by 30%+.

### Test 2: Trial length

- A: 14 days
- B: 30 days

Hypothesis: B increases trial-to-paid by 10%, even if revenue/month is lower.

### Test 3: CTA copy

- A: "Upgrade now"
- B: "Get more done"
- C: "Start your free trial"

Hypothesis: C wins (free dominates upgrade).

### Test 4: Anchor tier

- A: 3 tiers ($19 / $79 / $499)
- B: 3 tiers ($49 / $79 / $499) — change anchor

Hypothesis: B increases $79 conversion because $49 makes it look better value.

### Test 5: Urgency

- A: no urgency
- B: "Offer ends in 24 hours" (real timer)

Hypothesis: B +20% short-term, -10% trust long-term. Test carefully.

### Test 6: Social proof

- A: just feature list
- B: feature list + "Used by 12,000+ teams"

Hypothesis: B +5-10% conversion.

## Pre-paywall messaging

**Always tell users what's coming BEFORE they hit the wall.**

```tsx
// When user is at 80% of quota
function QuotaWarning({ used, limit }: Props) {
  return (
    <Toast type="warning">
      You've used {used} of {limit} API calls this month.
      <a href="/pricing">Upgrade for more →</a>
    </Toast>
  );
}
```

Toast > email > modal in terms of capture rate.

## Anti-patterns

❌ **Dark patterns:** hiding cancel, forced opt-in to add-ons
❌ **Confirmshaming:** "No, I hate saving money"
❌ **Roach motel:** easy in, hard out (you'll regret this on social media)
❌ **Show paywall on first visit:** user hasn't experienced value yet
❌ **Block mid-task:** always let user finish what they started

## Metrics to track

| Metric | Definition | Target |
|---|---|---|
| Free → trial conversion | % of free users who start trial | 8-15% |
| Trial → paid conversion | % of trials that convert | 15-25% (opt-in), 60-80% (reverse) |
| Paywall → upgrade (when shown) | % of users who see paywall and upgrade | 30-50% |
| Quota-hit → upgrade | % of users who upgrade after hitting limit | 10-20% |
| Time-to-paywall | Average time from signup to first paywall | > 7 days for trial, > 14 for quota |

## Implementation checklist

- [ ] Choose pattern per use case (inline/modal/page/hard-stop)
- [ ] Track all paywall events (impressions, clicks, conversions)
- [ ] Quota warnings at 80% and 95% (not just 100%)
- [ ] A/B test CTA copy and trial length
- [ ] Customer success email at trial-day-7, day-12
- [ ] Cancel flow: easy, no friction, down-sell optional
- [ ] No dark patterns (you'll be called out)

---

_footer: pricing-monetization/tasks/paywall-ux-patterns.md · v0.1.0_