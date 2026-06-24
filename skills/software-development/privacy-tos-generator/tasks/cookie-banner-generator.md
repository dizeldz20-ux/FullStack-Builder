# Cookie Banner Generator · v0.1.0

> ⚠️ **DISCLAIMER / כתב ויתור**
> **This is template boilerplate, not legal advice. Consult a lawyer before going to production.**
> זהו תבנית בסיסית (boilerplate), לא ייעוץ משפטי. התייעץ עם עורך דין לפני הפעלה בפרודקשן.

## מה זה / What is this

Cookie banner — החלון הקופץ שמבקש רשות לעקוב. חובה באירופה, חובה (גרסה מסוימת) בקליפורניה, מומלץ בכל מקום.
The pop-up asking permission to track. Mandatory in EU, mandatory (some version) in California, recommended everywhere.

זהו **לא** consent management platform מלא (OneTrust / Cookiebot). זה baseline שעובד ל-MVP.
This is **not** a full consent management platform (OneTrust / Cookiebot). This is MVP-grade baseline.

---

## Choose your region / בחר אזור

| אזור / Region | חוק / Law | מה צריך / Required |
|---|---|---|
| **EU/EEA + UK** | GDPR + ePrivacy Directive | Opt-in **לפני** non-essential cookies. Reject must be as easy as Accept. |
| **California** | CCPA/CPRA | "Do Not Sell or Share" link. Opt-out for sale/sharing. |
| **Israel** | Privacy Protection Law + amendment | Reasonable notice; opt-out for marketing cookies. |
| **Global / Other** | Mixed | Default to strictest (EU-style opt-in). Safer for now. |

---

## Region 1 — EU/EEA + UK (Strictest)

### Banner copy — Hebrew / עברית

```
אנו משתמשים בעוגיות (cookies) כדי לשפר את החוויה שלך, לנתח שימוש ולתמוך בפעולת
האתר. עוגיות חיוניות תמיד פעילות. עוגיות אנליטיקס ושיווק יופעלו רק באישורך.

[ קבל הכל ]  [ דחה הכל ]  [ הגדר העדפות ]

ניתן לשנות את הבחירה בכל עת דרך [קישור לעמוד הגדרות cookies].
מידע נוסף ב[מדיניות הפרטיות] שלנו.
```

### Banner copy — English

```
We use cookies to improve your experience, analyze usage, and support the
website's operation. Essential cookies are always active. Analytics and
marketing cookies will only run with your consent.

[ Accept all ]  [ Reject all ]  [ Preferences ]

You can change your choice at any time via [link to cookie preferences].
See our [Privacy Policy] for details.
```

### Implementation requirements

- ❌ **No pre-ticked boxes** for non-essential categories.
- ❌ **No "X" close button = consent.** Closing = rejection.
- ❌ **No cookie wall** (block access until consent) without explicit "reject" path.
- ✅ "Reject all" button must be **as prominent** as "Accept all."
- ✅ Consent must be **granular** (per category).
- ✅ Must record proof of consent (timestamp, version, choice).
- ✅ Must allow withdrawal as easily as consent was given.

### Minimal vanilla JS implementation

```html
<!-- Drop into <body>, before scripts that set cookies -->
<div id="cookie-banner" hidden style="position:fixed;bottom:0;left:0;right:0;
  background:#000;color:#fff;padding:1rem;z-index:9999;font-family:sans-serif;">
  <p>We use cookies. <a href="/privacy" style="color:#fff;underline">Privacy policy</a>.</p>
  <button id="cookie-accept">Accept all</button>
  <button id="cookie-reject">Reject all</button>
  <button id="cookie-prefs">Preferences</button>
</div>

<div id="cookie-prefs-modal" hidden>
  <h2>Cookie preferences</h2>
  <label><input type="checkbox" checked disabled> Essential (required)</label>
  <label><input type="checkbox" id="cat-analytics"> Analytics</label>
  <label><input type="checkbox" id="cat-marketing"> Marketing</label>
  <button id="cookie-save">Save preferences</button>
</div>

<script>
const KEY = 'cookie-consent-v1';

function showBanner() {
  if (!localStorage.getItem(KEY)) {
    document.getElementById('cookie-banner').hidden = false;
  }
}

function saveConsent(choice) {
  localStorage.setItem(KEY, JSON.stringify({
    ...choice,
    timestamp: new Date().toISOString(),
    version: 'v1'
  }));
  document.getElementById('cookie-banner').hidden = true;
  document.getElementById('cookie-prefs-modal').hidden = true;
  loadScripts(choice);
}

function loadScripts(choice) {
  if (choice.analytics) {
    // load Mixpanel / Plausible / GA only after consent
    const s = document.createElement('script');
    s.src = 'https://your-analytics-cdn.com/loader.js';
    document.body.appendChild(s);
  }
  if (choice.marketing) {
    // load Meta Pixel, Google Ads, etc.
  }
}

document.getElementById('cookie-accept').onclick = () =>
  saveConsent({essential: true, analytics: true, marketing: true});
document.getElementById('cookie-reject').onclick = () =>
  saveConsent({essential: true, analytics: false, marketing: false});
document.getElementById('cookie-prefs').onclick = () =>
  document.getElementById('cookie-prefs-modal').hidden = false;
document.getElementById('cookie-save').onclick = () =>
  saveConsent({
    essential: true,
    analytics: document.getElementById('cat-analytics').checked,
    marketing: document.getElementById('cat-marketing').checked
  });

// CRITICAL: load non-essential scripts ONLY after consent.
// Move analytics script tags out of <head> into this loader.
showBanner();
</script>
```

---

## Region 2 — California (CCPA/CPRA)

California doesn't require opt-in like the EU. They require:
- "Do Not Sell or Share My Personal Information" link in footer
- Honoring opt-out signals (Global Privacy Control)
- Privacy policy disclosures (covered in privacy-policy-from-questionnaire.md)

### Banner copy

```
We use cookies and similar technologies. California residents have the right
to opt out of the sale or sharing of their personal information.

[ Do Not Sell or Share My Personal Information ]
[ Privacy Policy ]
```

You can keep analytics cookies active by default in CA (unlike EU), as long as:
- You disclose what you collect
- You honor opt-out
- You don't sell the data

### Footer link

```html
<a href="/do-not-sell">Do Not Sell or Share My Personal Information</a>
```

The `/do-not-sell` page should:
- Allow email submission
- Confirm opt-out within 15 business days
- Provide a confirmation mechanism

---

## Region 3 — Israel

Israel Privacy Protection Law (חוק הגנת הפרטיות) requires:
- Notice of cookies
- Opt-out for non-essential cookies (unlike EU's opt-in, but trending toward opt-in after 2024 amendments)

### Banner copy — Hebrew

```
האתר משתמש בעוגיות (Cookies). ניתן להתאים העדפות בכל עת.
[ אישור ]  [ הגדרות ]  [ מדיניות פרטיות ]
```

### English

```
This site uses cookies. You can adjust preferences at any time.
[ Accept ]  [ Preferences ]  [ Privacy Policy ]
```

In practice, many Israeli sites default to EU-style opt-in to be safe.

---

## Region 4 — Global (safe default)

If you can't geofence, use EU rules everywhere. Worst case: you annoy non-EU
users with one extra click. Best case: you're compliant globally.

---

## What about "legitimate interest"?

Some analytics vendors (Mixpanel, PostHog self-hosted) let you rely on
"legitimate interest" instead of consent in the EU. **We do not recommend
this for MVP.** Get consent first. Switch to legitimate-interest later
with a proper LIA (Legitimate Interest Assessment) on file.

---

## Categories explained

| Category | Examples | Default |
|---|---|---|
| Essential | Session, CSRF token, auth | Always on |
| Functional | Language preference, theme | Usually consent, but tied to service |
| Analytics | Mixpanel, Plausible, GA | Consent |
| Marketing | Meta Pixel, Google Ads, LinkedIn | Consent |
| Advertising | Cross-site tracking | Consent |

---

## Geo-routing — show different banner by region

```javascript
// Pseudo: detect region from Cloudflare header (CF-IPCountry) or IP geolocation
async function getRegion() {
  try {
    const r = await fetch('https://your-worker.example.com/region');
    return (await r.json()).country; // "DE", "US", "IL", ...
  } catch { return 'OTHER'; }
}

async function initBanner() {
  const region = await getRegion();
  if (['EU', 'EEA', 'UK'].includes(region)) {
    // strict EU mode
  } else if (region === 'US-CA') {
    // CCPA mode
  } else if (region === 'IL') {
    // IL mode
  } else {
    // global default = EU strict
  }
}
initBanner();
```

For Cloudflare: pass `CF-IPCountry` from the Worker to your front-end.

---

## Checklist / רשימת בדיקה

- [ ] בחרת אזור / chose region
- [ ] banner מופיע לפני non-essential scripts / banner shown before non-essential scripts
- [ ] "Reject" קל כמו "Accept" / reject as easy as accept (EU)
- [ ] רושמים timestamp + version של consent / record timestamp + consent version
- [ ] קישור ל-Privacy Policy / privacy policy linked
- [ ] California: "Do Not Sell" link / CA: do-not-sell link present
- [ ] **שלחת לעורך דין / sent to a lawyer** ← חובה / mandatory

---

_footer: privacy-tos-generator/tasks/cookie-banner-generator.md · v0.1.0_