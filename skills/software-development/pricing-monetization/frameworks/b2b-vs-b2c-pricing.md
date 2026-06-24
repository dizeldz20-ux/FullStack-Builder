# B2B vs B2C Pricing

## מטרה / Purpose

להבין איך pricing שונה באופן מהותי כשמוכרים לארגונים (B2B) מול צרכנים (B2C). קונטקסט זה מיועד למוכר לארגונים כ-AI expert — זה אומר enterprise dynamics.

## ההבדל הבסיסי / Core difference

| | B2C | B2B |
|---|---|---|
| Buyer | Individual | Committee / department / company |
| Decision time | Minutes to days | Weeks to quarters |
| Price sensitivity | Elastic | Inelastic (within budget) |
| Sales cycle | Self-serve | Sales-led (often) |
| Payment | Credit card | PO / invoice / annual contract |
| Churn drivers | Convenience, price | Switching cost, integration |
| Average contract value | $10-$100/mo | $5K-$500K/yr |
| Sales rep involvement | None | Heavy |

## B2B specifics — איך לחשוב

### 1. Multiple stakeholders

כל ארגון יש 4-7 stakeholders בקניית SaaS:

```
Economic Buyer (מי שמאשר תקציב)
  ├── Technical Buyer (מי שמעריך)
  ├── User Buyer (מי שישתמש)
  ├── Champion (מי שדוחף)
  └── Blockers (אבטחת מידע, procurement, legal)
```

**Pricing צריך לעבוד לכולם:**
- Economic buyer: ROI, TCO, cost-per-seat
- Technical buyer: features, integrations, security
- User buyer: UX, learning curve
- Procurement: contract terms, payment terms, vendor risk

### 2. Pricing models that work in B2B

✅ **Per-seat** — most common (Slack, Notion, Asana)
✅ **Tiered** — Starter / Pro / Enterprise
✅ **Usage-based** — works for API / AI products (OpenAI, AWS)
✅ **Custom / quote-based** — for >$50K ACV
✅ **Annual contract** — drives retention

❌ **Freemium alone** — rarely works in pure B2B (decision is at company level)
❌ **Pure usage-based without floor** — buyers hate variable costs

### 3. Enterprise pricing playbook

**Step 1: Set list price with annual anchor**

```typescript
const enterprise = {
  // List price (visible on website)
  listPrice: 50_000, // $/year

  // Floor (lowest we'll accept)
  floor: 30_000,

  // Target (where we want to land)
  target: 42_000,

  // For 3-year commit: 15% discount
  multiYearDiscount: 0.15,

  // Annual prepay: 5% discount
  annualPrepayDiscount: 0.05,
};
```

**Step 2: Negotiate from above-anchor**

Always start with a high anchor so customer feels they "won":
- List: $50K
- First offer: $42K (20% off list)
- Customer offers $35K
- Final: $38K with 2-year commit

**Step 3: Trade discounts for commitments**

| Customer wants | You give | In exchange |
|---|---|---|
| Lower price | Annual prepay | Cash flow win |
| More features | Custom feature | Multi-year commit |
| Custom contract | Terms | Case study + reference |
| Discount | X% off | Multi-year, larger seat count |

### 4. Land-and-expand (B2B SaaS growth motion)

```typescript
// Phase 1: Land small (1 team, $5K/yr)
const initialDeal = {
  seats: 10,
  annualValue: 5_000,
  useCase: "one team",
};

// Phase 2: Expand within company
// After 6 months: champion moves to bigger role, expands to 3 teams
const expandedDeal = {
  seats: 75,
  annualValue: 37_500,
  useCase: "department-wide",
};

// Phase 3: Land at parent (M&A, multi-biz unit)
const enterpriseDeal = {
  seats: 500,
  annualValue: 250_000,
  useCase: "company-wide",
  customContract: true,
};

// LTV of account can grow 10-50x from initial deal.
```

**Enable this with:**
- Department-scoped onboarding (not company-wide required)
- Usage analytics surfaced to admin
- SSO + SCIM (so IT can roll out without friction)
- Multi-workspace architecture

### 5. Procurement realities

Large orgs have:
- **Vendor onboarding:** weeks of paperwork
- **Security review:** SOC 2, ISO 27001, pen test
- **Legal review:** DPA, MSA, ToS
- **Payment terms:** Net 30/60, PO required

**What this means for your pricing page:**

```markdown
## Enterprise Plan — $50,000/year

Includes:
- [ ] SSO + SCIM
- [ ] Audit logs
- [ ] Custom DPA / MSA
- [ ] Dedicated CSM
- [ ] 99.95% SLA
- [ ] Onboarding & training
- [ ] Net 60 payment terms
```

**Tip:** offer to provide these BEFORE the customer asks. It's a trust signal.

### 6. Annual contracts and discount strategy

```typescript
function calculateAnnualPrice(monthlyPrice: number, prepayDiscount: number) {
  const fullYear = monthlyPrice * 12;
  const withDiscount = fullYear * (1 - prepayDiscount);
  return {
    monthly_equivalent: withDiscount / 12,
    discount_pct: (prepayDiscount * 100).toFixed(0),
    annual_total: withDiscount,
  };
}

// Example: $79/mo with 20% annual discount
// Monthly equivalent: $63.20 (still rounds to $63)
```

**Discount ranges (industry norms):**
- Annual prepay: 15-20%
- 2-year commit: 5-10% additional
- 3-year commit: 10-20% additional (rare)
- Volume discount: starts at 100+ seats

## B2C specifics — איך לחשוב

### 1. Self-serve is king

- No sales call required
- Stripe Checkout > enterprise contracts
- Free tier to drive top-of-funnel
- Conversion: 2-5% free → paid

### 2. Consumer psychology

- Charm pricing ($19 vs $20) works
- Anchoring works (3 tiers)
- Annual vs monthly toggle — annual by default
- Loss aversion: "Don't lose your data" on cancel

### 3. Payment methods

- Credit card primary
- Apple Pay / Google Pay for mobile
- PayPal for trust (some markets)
- Local payment methods (iDEAL, Klarna, etc.)

### 4. Pricing patterns that work in B2C

✅ **Freemium** — Dropbox, Spotify, Evernote
✅ **Reverse trial** — high conversion (see paywall-ux-patterns.md)
✅ **Subscription + usage hybrid** — Peloton, AWS
✅ **One-time purchase + subscriptions** — mobile apps

❌ Per-seat (irrelevant)
❌ Custom contracts
❌ Long sales cycle

## When B2B and B2C mix (PLG with enterprise tier)

Most modern SaaS does both:

```
┌──────────────────────────────────────────────────────┐
│  Self-serve (B2C / SMB)     │ Sales-led (B2B Ent)    │
├──────────────────────────────┼────────────────────────┤
│  Free tier                  │ Enterprise: call sales │
│  $19/mo self-serve          │ $50K+/yr contracts     │
│  Stripe Checkout            │ PO / invoice           │
│  Monthly + annual           │ Annual + multi-year    │
│  Chat support               │ Dedicated CSM          │
│  Documentation + community  │ Custom onboarding      │
└──────────────────────────────┴────────────────────────┘
                          │
                          ▼
                  Same product, different GTM
```

**Example:**
- Notion: free + $10/mo personal / $15/mo team / Enterprise custom
- Linear: free + $8/mo standard / $16/mo plus / Enterprise custom
- Figma: free + $12/mo pro / $45/mo org / Enterprise custom

## Pricing page for B2B vs B2C

### B2C pricing page

- Bright colors, friendly copy
- Big CTA buttons ("Get started")
- Toggle monthly/annual
- Trust badges (logos of customers)
- FAQ below

### B2B pricing page

- Professional colors
- ROI calculator or "Talk to sales" CTA
- Tier comparison table (extensive)
- "Custom" tier always at the end (anchor)
- Case studies, customer logos
- Compliance badges (SOC 2, GDPR)
- Demo video
- "Schedule demo" form

## When you (the user) talk to orgs

**Talk their language:**

| Don't say | Say instead |
|---|---|
| "$79/month per seat" | "Annual contract starts at $50K for a 50-seat team" |
| "Usage-based" | "Consumption-based — predictable within band" |
| "Free tier" | "Pilot / Proof of Concept available" |
| "Stripe checkout" | "PO, Net 30, or annual prepay" |
| "Trial" | "30-day evaluation with full feature access" |

**Lead with ROI, not features.**

```
"We typically help [role] save [X hours / $Y cost] per month
 by [outcome]. Most customers see payback in [N months]."
```

## Sales-assistive artifacts (B2B)

1. **ROI Calculator** — input seats, current cost → output savings
2. **TCO comparison** — us vs. building in-house
3. **Security pack** — SOC 2, pen test summary, DPA template
4. **Customer references** — relevant to industry
5. **Pricing matrix** — seats × tier × annual

## Done checklist for B2B pricing

- [ ] Enterprise tier with "Contact sales" path
- [ ] Annual prepay discount (15-20%)
- [ ] Volume discount tier (>100 seats)
- [ ] Custom contract template ready (MSA, DPA)
- [ ] SOC 2 (or path to it) — table stakes
- [ ] ROI calculator on website
- [ ] Security pack / trust page
- [ ] Customer references in target industry
- [ ] Net 30/60 payment terms available
- [ ] Pricing accommodates procurement realities

---

_footer: pricing-monetization/frameworks/b2b-vs-b2c-pricing.md · v0.1.0_