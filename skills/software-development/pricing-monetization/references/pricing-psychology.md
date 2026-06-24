# Pricing Psychology

## מטרה / Purpose

עקרונות קוגניטיביים שמשפיעים על החלטת רכישה. רוב ההחלטות הן לא רציונליות — אלא אינטואיטיביות, ואז משכנעים את עצמנו שהן רציונליות. נשתמש בזה באחריות.

## ⚠️ Ethics note

העקרונות כאן הם כלים. **Dark patterns** (הסתרת cancel, confirmshaming, וכו') יפגעו ב-brand שלך לטווח ארוך. השתמש בעקרונות האלה כדי לעזור ללקוח לקבל החלטה טובה יותר, לא כדי לנצל אותו.

---

## 1. Anchoring (עיגון)

**עיקרון:** המספר הראשון שאדם רואה הופך לנקודת הייחוס. כל מספר אחר מושווה אליו.

**ב-pricing:**
- Tier יקר מאוד (Enterprise / Custom) גורם ל-Tier האמצעי להיראות reasonable
- מחיר ראשוני גבוה שמוזילים ("$79 → $63") נתפס כדיל

**דוגמה:**

```typescript
// תמחור לא יעיל: 3 דרגות דומות
const bad = [
  { name: "Starter", monthly: 49 },
  { name: "Pro",     monthly: 79 },
  { name: "Premium", monthly: 99 },
];
// כל הדרגות נראות דומות. אין anchor.

const good = [
  { name: "Starter",    monthly: 19,  limits: "basic" },
  { name: "Pro",        monthly: 79,  limits: "most teams", highlight: true },
  { name: "Enterprise", monthly: null, limits: "unlimited", cta: "Contact sales" },
];
// $19 גורם ל-$79 להיראות הגיוני. "Contact sales" מרמז שיש deal גדול.
```

**ב-negotiation:**
- תמיד תן מחיר גבוה קודם. גם אם הלקוח יוריד אותו, הוא ירגיש ש-"ניצח".

## 2. Decoy Effect (אפקט הפיתיון)

**עיקרון:** אופציה שלישית לא-הגיונית גורמת לאופציה השנייה להיראות הגיונית.

**Classic example — Economist subscription:**

```
┌──────────────────────────────────────┐
│ Web only         $59              │
│ Print only       $125             │  ← decoy (looks bad vs combo)
│ Web + Print      $125             │  ← most pick this
└──────────────────────────────────────┘
```

ה-Print only לא רלוונטי — אבל הוא גורם ל-Web+Print להיראות הצעה.

**ב-SaaS:**

```typescript
const tiers = [
  {
    name: "Basic",
    monthly: 29,
    features: ["feature A", "feature B"],
    // Bad value — too restrictive
  },
  {
    name: "Pro",
    monthly: 79,
    features: ["feature A", "feature B", "feature C", "feature D", "feature E"],
    highlight: true, // ← this is what you want them to pick
  },
  {
    name: "Enterprise",
    monthly: 499,
    features: ["everything in Pro", "white-glove"],
    cta: "Contact sales",
  },
];

// Pro at $79 looks like a steal vs. Enterprise at $499.
```

**⚠️ Don't make Basic terrible** — customers will resent it. Make it... just less valuable than Pro.

## 3. Charm Pricing ($X.99)

**עיקרון:** $19 נתפס זול משמעותית מ-$20. אפקט ידוע (Schindler & Al TIMES, 1996).

```
$19  vs  $20   ← 19 wins by far
$199 vs $200   ← 199 wins
$19.99 vs $20  ← 19.99 wins, but barely better than $19
```

**ב-B2B:** charm pricing פחות אפקטיבי. Enterprise buyers think in thousands, not units.

**Best practice:**
- SMB: charm pricing ($19, $79)
- Mid-market: round numbers ($99, $299)
- Enterprise: round thousands ($25K, $50K)

## 4. Social Proof (הוכחה חברתית)

**עיקרון:** אנשים מסתכלים על מה שאחרים עושים כדי להחליט מה לעשות.

**ב-pricing:**

```tsx
<PricingCard>
  <h3>Pro — $79/mo</h3>
  <p className="text-sm text-gray-500">
    Trusted by 12,000+ teams worldwide
  </p>
  <p className="text-sm text-gray-500">
    Most popular plan
  </p>
</PricingCard>
```

**Variants:**
- "X customers in your industry use this"
- "Most popular" badge on target tier
- Logos of recognizable customers
- Testimonials near pricing
- "As featured in" press logos
- Live counter: "47 teams signed up this week"

**Don't fake it.** Inflated numbers destroy trust.

## 5. Loss Aversion (הימנעות מהפסד)

**עיקרון:** להפסיד $100 כואב פי 2 מלהרוויח $100 (Kahneman & Tversky).

**ב-pricing:**

- "Don't lose your data" (annual plan)
- "Limited: this price ends Friday"
- "Your trial ends in 3 days"
- "X features you'll lose" (when cancelling)

**דוגמה — Stripe-style:**

```tsx
// On cancel flow
function CancelDialog({ features }) {
  return (
    <Modal>
      <h2>Are you sure you want to cancel?</h2>
      <p>You'll lose access to:</p>
      <ul>
        {features.map(f => <li key={f}>✓ {f}</li>)}
      </ul>
      <button>Keep my plan</button>
      <button>Cancel anyway</button>
    </Modal>
  );
}
```

## 6. Urgency / Scarcity

**עיקרון:** מוצר נדיר / בזמן מוגבל נתפס כערך יותר.

**ב-pricing:**

- "Limited time: 50% off for the next 3 days"
- "Only 5 seats left at this price"
- "Founders' pricing — locked forever"
- "Beta pricing — going up at launch"

**⚠️ אזהרה:** אם זה לא אמיתי — זה dark pattern.

```tsx
// ❌ Fake urgency
const fakeTimer = "23:45:12"; // Resets on page load
// User finds out, loses trust forever.

// ✅ Real urgency (e.g. real launch promo)
const realTimer = computeTimeUntilLaunch(); // Actual countdown
// Once per quarter — feels real.
```

## 7. Reciprocity (הדדיות)

**עיקרון:** אם נתת משהו, הצד השני רוצה להחזיר.

**ב-pricing:**

- Free trial (נתת → רוצה לשלם)
- Free content / tools (ebook, calculator)
- Free tier (עם value אמיתי)
- Personalized demo (זמן שלך → רוצה לקנות)

## 8. Risk Reversal (הסרת סיכון)

**עיקרון:** ככל שהסיכון ללקוח קטן יותר, כך קל יותר לקנות.

**טכניקות:**

```typescript
const riskReversals = [
  "30-day money-back guarantee",
  "No credit card required for trial",
  "Cancel anytime, no questions asked",
  "Free pilot / proof of concept (B2B)",
  "Onboarding included",
  "Migration assistance included",
];
```

**Best placement:** right next to the CTA button.

## 9. Choice Architecture

**עיקרון:** איך שמציגים את האופציות משפיע על הבחירה.

**Do:**
- 3 tiers (not 7)
- One tier marked "Most popular" / highlighted
- Annual toggle default-on
- Annual savings shown clearly

**Don't:**
- 4+ tiers (decision paralysis)
- Equal visual weight for all options
- Hidden fees / surprise charges
- Confusing feature names

```tsx
// Best practice toggle
function PricingToggle({ billing, setBilling }) {
  return (
    <div className="toggle">
      <button
        onClick={() => setBilling("monthly")}
        className={billing === "monthly" ? "active" : ""}
      >
        Monthly
      </button>
      <button
        onClick={() => setBilling("annual")}
        className={billing === "annual" ? "active" : ""}
      >
        Annual
        <span className="badge-save">Save 20%</span>
      </button>
    </div>
  );
}
```

## 10. Mental Accounting

**עיקרון:** אנשים מסווגים כסף לקטגוריות, ומחליטים לפי קטגוריה.

**ב-pricing:**

- "$1/day" feels cheaper than "$30/month"
- "$365/year" feels expensive, but "$30/month × 12" same
- Frame as "$X per [outcome]" not "$X per month"

```tsx
// Reframe expensive SaaS as cheap
function reframe(pricePerMonth: number) {
  return {
    perDay: (pricePerMonth / 30).toFixed(2),
    perHour: (pricePerMonth / 30 / 24).toFixed(2),
    perCoffee: (pricePerMonth / 30 / 4).toFixed(2), // 4 cups/day
  };
}

// $79/mo = $2.63/day = less than a coffee
```

## 11. Endowment Effect

**עיקרון:** אנשים מעריכים דברים יותר אחרי שיש להם אותם.

**ב-pricing:**
- Free trial (let them build muscle memory)
- Personalization (their data, their workspace)
- Then charge for keeping it

## 12. Status / Identity

**עיקרון:** אנשים קונים דברים שמגדירים אותם.

**ב-B2B:**

- "Built for Fortune 500"
- "Enterprise-grade"
- "Trusted by industry leaders"
- Logos of premium brands

**ב-B2C:**

- "Join 100K+ creators"
- "Pro tools for pros"

## Summary table

| Principle | Use case | Risk |
|---|---|---|
| Anchoring | Set tier structure | Over-anchor too high → ignored |
| Decoy effect | Make target tier look good | Decoy too obviously bad → distrust |
| Charm pricing | SMB, B2C | Look unprofessional in B2B |
| Social proof | All pricing | Fake it = lose trust |
| Loss aversion | Cancel flows, urgency | Manipulative if fake |
| Urgency / scarcity | Promos | Fakeness destroys brand |
| Reciprocity | Free trials, content | Free tier too generous |
| Risk reversal | Conversion boost | Cost of refunds |
| Choice architecture | Tier structure | Too few or too many |
| Mental accounting | Reframe price | Only works in messaging |
| Endowment | Free trial | Trial too short to attach |
| Status / identity | Premium tiers | Backfire if positioning off |

## Ethical checklist before applying

Before adding any pricing trick, ask:

1. **Is the customer better off for having bought?** (if no, don't)
2. **Is the claim true?** (fake urgency destroys trust)
3. **Will they discover the trick later?** (if yes, don't)
4. **Does this respect their time/attention?** (dark patterns waste both)
5. **Would I respect a company that did this to me?** (if no, don't)

The best pricing is the one where the customer feels smart after buying, not the one where they feel tricked.

---

_footer: pricing-monetization/references/pricing-psychology.md · v0.1.0_