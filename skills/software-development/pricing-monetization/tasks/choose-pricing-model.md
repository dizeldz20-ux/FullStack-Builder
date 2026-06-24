# Choose Pricing Model — Decision Matrix

## מטרה / Purpose

לבחור את מודל התמחור הנכון למוצר. כל מודל מתאים לקונטקסט אחר — בחירה לא נכונה יכולה לחסום growth לשנים.

## המודלים העיקריים / Core Models

### 1. Flat-Rate (מחיר אחיד)

**מתי:** מוצר פשוט, קהל קטן, אין וריאציה בשימוש.

```yaml
pros:
  - קל להסביר: "הכל ב-$49/mo"
  - אפס תלונות על חיובים מפתיעים
  - מתאים ל-PMF חדש שעוד לא יודע segments
cons:
  - עוזב כסף על השולחן (power users משלמים מעט מדי)
  - קושי לגדול ללא העלאת מחיר
examples:
  - Basecamp: $99/mo flat
  - Many indie SaaS at $19/mo
```

### 2. Tiered (3 דרגות — Good/Better/Best)

**מתי:** יש segments ברורים בקהל. הדרך הסטנדרטית ל-SaaS.

```typescript
const tiers = [
  {
    name: "Starter",
    monthly: 19,
    limits: { users: 3, projects: 5, api_calls: 1000 },
    target: "individuals, small teams",
  },
  {
    name: "Pro",
    monthly: 79,
    limits: { users: 15, projects: 50, api_calls: 50000 },
    target: "growing teams",
    highlight: true, // decoy effect — anchor ל-Enterprise
  },
  {
    name: "Enterprise",
    monthly: null, // Contact sales
    limits: "unlimited",
    target: "large orgs",
  },
];
```

**3-tier pattern (HBR "decoy pricing"):**
- Tier 1: זול — entry point
- Tier 2: ה-target שלך — *highlighted*
- Tier 3: יקר — עוזר ל-Tier 2 להיראות reasonable

### 3. Per-Seat (לפי משתמש)

**מתי:** הערך = כמה אנשים משתמשים. Slack, Notion, Linear.

```typescript
const pricing = {
  per_seat_monthly: 12,
  min_seats: 3,
  annual_discount: 0.20, // 20% off annual
  // Free viewer seats — רק paid editors
  viewer_free: true,
};
```

**Tradeoffs:**
- ✅ קל לחיזוי הכנסות (NRR / seat-based)
- ❌ מעודד "guest sprawl" (אנשים משתמשים בלי לשלם)
- ❌ ארגונים מצמצמים seats ברגע שמרגישים שהמחיר עלה

### 4. Usage-Based (Pay-as-you-go)

**מתי:** API, AI/LLM, data, compute. הערך = כמה צרך.

```typescript
const metering = {
  unit: "api_call",
  unit_price_cents: 1, // $0.01 per call
  free_tier: 1000, // first 1000 free
  // או tiered: 0-10K free, 10K-100K $0.005, 100K+ $0.002
};
```

**דוגמאות:**
- OpenAI: per 1K tokens
- AWS: per compute-hour
- Twilio: per SMS

**Best for:** מוצרים שה-unit cost variable מאוד. קל לעלות מ-0.

### 5. Freemium (Free tier + Paid tier)

**מתי:** network effects, self-serve, PLG motion.

```typescript
const freemium = {
  free: {
    users: 1,
    projects: 3,
    storage_gb: 0.5,
    // Must be useful, not crippled
  },
  paid_trigger: "team of 3+",  // when they hit paid trigger
  conversion_target: 0.04,      // 4% free → paid (Evernote benchmark)
};
```

**⚠️ סכנות:**
- אם ה-Free tier שימושי מדי — אף אחד לא ישלם
- אם הוא crippled — אין growth
- אין freemium בלי מדידת conversion

### 6. Hybrid (Tiered + Usage Overage)

**מתי:** Base tier + תשלום על overage. הכי נפוץ ב-SaaS בוגר.

```typescript
const hybrid = {
  pro_tier: { monthly: 79, included_api_calls: 50000 },
  overage: { per_1k_calls: 5 }, // $5 per additional 1K
  enterprise: { monthly: null, included: "unlimited" },
};
```

זה מה שרוב ה-SaaS B2B עושים. **Best of both worlds.**

## Decision Matrix

| Question | If yes → |
|---|---|
| Is the product an API / has variable unit cost? | Usage-based |
| Does value = # of users in the account? | Per-seat |
| Are there 3+ distinct customer segments? | Tiered |
| Are you pre-PMF / validating? | Flat-rate or Free |
| Is there viral/network effect? | Freemium |
| Selling to enterprise with custom contracts? | Hybrid + Enterprise tier |

## Revenue Math

**ARPU (Average Revenue Per User):**

```typescript
function arpu(totalMRR: number, payingUsers: number): number {
  return totalMRR / payingUsers;
}

// Tiered example:
// 100 users @ $19 = $1,900
// 30 users @ $79  = $2,370
// 5 users @ $499  = $2,495
// Total MRR: $6,765 / 135 paying users = $50 ARPU
```

**LTV (Lifetime Value):**

```typescript
function ltv(arpu: number, monthlyChurn: number): number {
  return arpu / monthlyChurn;
}
// ARPU $50, churn 5%/mo → LTV = $1,000
```

**CAC payback:**

```typescript
function cacPayback(cac: number, arpu: number, grossMargin: number): number {
  return cac / (arpu * grossMargin);
}
// CAC $500, ARPU $50, GM 80% → 12.5 months
// Rule of thumb: < 12 months is good, > 18 is bad
```

## Common mistakes

1. **Pricing מוקדם מדי** — עדיף לאסוף 10 לקוחות ב-$X ואז לבדוק, מאשר לעצב pricing לפני שיש מי שיקנה
2. **יותר מדי tiers** — 3, מקסימום 4
3. **חוסר anchor ל-Enterprise** — תמיד תיהיה tier "Custom" אפילו אם אף אחד לא קונה
4. **אין annual discount** — הכי קל לעלות LTV

## Output template

```markdown
## Pricing Model Recommendation

**Model:** [flat-rate | tiered | per-seat | usage-based | freemium | hybrid]
**Tiers:** [list]
**Why:** [reasoning tied to product / market]
**Test plan:** [how you'll validate in 30-90 days]
**Annual discount:** [e.g. 20%]
**Free tier:** [yes/no, with limits]
```

---

_footer: pricing-monetization/tasks/choose-pricing-model.md · v0.1.0_