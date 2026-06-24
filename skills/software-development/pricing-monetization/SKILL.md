---
name: pricing-monetization
type: skill
version: 1.0.0
description: |
  עזרה בתכנון מודל תמחור ומונטיזציה למוצר SaaS — בחירת מודל תמחור, אינטגרציית Stripe (subscriptions / metered / one-time), דפוסי Paywall UX, חישובי הכנסות, מיצוב B2B מול B2C, ופסיכולוגיית תמחור (anchoring, decoy, charm).
  Help design pricing for a SaaS: pricing models catalog (freemium, usage-based, tiered, per-seat), Stripe integration patterns, paywall UX patterns, revenue calculations, B2B vs B2C positioning, and pricing psychology.

related_skills:
  - build-product
  - api-contract-designer
  - supabase-auth-patterns
  - prd-generator
---

# Pricing & Monetization Skill

## מטרה / Purpose

לעזור לסגור דילים עם ארגונים כמומחה AI — באמצעות תמחור שמתאים לקהל, מתועד בצורה ברורה, וניתן להטמעה מהר.

## מתי להשתמש / When to use

- הקמת מוצר SaaS חדש — צריך לבחור איך לגבות כסף
- סקייל מ-0 ל-1000 לקוחות — צריך אופטימיזציה של conversion
- מעבר בין מודלים (freemium → paid, tiered → usage-based)
- משא ומתן ארגוני — צריך להבין B2B pricing dynamics
- A/B test של pricing pages

## Structure

```
pricing-monetization/
├── SKILL.md                                    # This file
├── tasks/
│   ├── choose-pricing-model.md                 # Decision matrix
│   ├── stripe-subscriptions.md                 # Recurring billing setup
│   ├── stripe-metered-billing.md               # Usage-based pricing
│   └── paywall-ux-patterns.md                  # Modal / page / hard-stop
├── frameworks/
│   └── b2b-vs-b2c-pricing.md                   # Enterprise vs consumer
└── references/
    └── pricing-psychology.md                   # Anchoring, decoy, charm
```

## Quick decision guide

| Situation | Use |
|---|---|
| API / AI inference priced per call | `tasks/stripe-metered-billing.md` |
| SaaS dashboard / per-seat tool | `tasks/stripe-subscriptions.md` |
| Product-market fit חדש | `tasks/choose-pricing-model.md` first |
| Selling to enterprise | `frameworks/b2b-vs-b2c-pricing.md` |
| Pricing page conversion נמוך | `tasks/paywall-ux-patterns.md` + `references/pricing-psychology.md` |

## Core principles

1. **Charge by value, not cost** — price on what the customer gets, not what it costs you
2. **Simple > clever** — 3 tiers beats 7 add-ons
3. **Annual > monthly** — push annual (LTV win, cash flow, retention)
4. **Free tier is marketing** — but only if it converts to paid within 30 days
5. **B2B ≠ B2C** — enterprise sales cycles, procurement, custom pricing

## Related skills

- `build-product` — לפני שמחליטים על pricing צריך להבין את ה-product
- `api-contract-designer` — usage-based pricing דורש חשיבה על metering endpoints
- `supabase-auth-patterns` — auth tiers / role-based paywalls
- `prd-generator` — pricing הוא חלק מ-PRD, לא בנפרד

---

_footer: pricing-monetization/SKILL.md · v0.1.0_