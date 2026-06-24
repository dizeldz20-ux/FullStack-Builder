# Stacks Guide — מתי לבחור מה

> מתוך super-builder של peer agent. מועתק ומותאם לפי skillsmith.

## Node.js

**מתי:**
- בוטים (WhatsApp, Telegram, Discord)
- API עם JSON
- סקריפטים עם תלות ב-npm
- מהירות פיתוח חשובה

**לא מתי:**
- משימות CPU כבדות (השתמש ב-Python)
- ML/AI מורכב (השתמש ב-Python)

**חבילות נפוצות:**
- API: `express`, `fastify`
- WhatsApp: `greenapi` / `whatsapp-web.js`
- Cron/Schedule: `node-cron`
- HTTP: `axios`, `node-fetch`

---

## Python

**מתי:**
- אוטומציה, קלסרים
- ML/AI (PyTorch, TensorFlow)
- עיבוד תמונה/קול
- סקריפטים עם תלות ב-Python

**לא מתי:**
- ממשק משתמש אינטראקטיבי (השתמש ב-React)
- דברים שצריכים לרוץ בדפדפן

**חבילות נפוצות:**
- HTTP: `requests`, `httpx`
- CLI: `typer`, `click`
- Cron: `schedule`
- Audio: `pydub`, `gtts`
- Web scraping: `playwright`, `beautifulsoup4`

---

## React / Next.js

**מתי:**
- ממשק משתמש ווב
- Dashboard / ניהול
- PWA
- SEO חשוב (→ Next.js)

**Next.js vs Vite:**
- Next.js = SSR, API routes, SEO, multi-page
- Vite = SPA פשוט, מהיר, single-page

**לא מתי:**
- API בלבד (השתמש ב-Node/Python)
- סקריפטים (השתמש ב-Bash)
- מוצר שצריך Supabase + Cloudflare + users → `build-product` במקום

---

## Docker

**מתי:**
- סביבה קבועה נדרשת
- תלות מורכבות (כמה שפות/כלים)
- העלאה לשרת

**לא מתי:**
- סקריפט חד-פעמי
- פיתוח מהיר בלוקלי
- Cloudflare Workers (לא צריך Docker — V8 isolate)

---

## Hyperframes

**מתי:**
- ממשק קולי / ווקלי
- WebRTC / שיחות
- Prototyping מהיר של UI ווקלי

**לא מתי:**
- Dashboard מורכב
- אפליקציה עם הרבה state

---

## Tailscale SSH

**מתי:**
- גישה לשרת/דסקטופ מרחוק
- ללא חשיפת פורטים

**לא מתי:**
- הכל רץ על אותו מכונה

---

## GreenAPI (WhatsApp)

**מתי:**
- בוט וואטסאפ
- תקשורת עם לקוחות דרך WhatsApp
- צריך גם read receipts, media support

**לא מתי:**
- רק Telegram (השתמש ב-python-telegram-bot)
- רק Discord (השתמש ב-discord.js)

---

## ElevenLabs / Deepgram

**מתי:**
- TTS (text-to-speech) — ElevenLabs
- STT (speech-to-text) — Deepgram
- Voice products / bots

**לא מתי:**
- רק text chat

---

## Decision Tree המקוצר

```
Start
├── Has UI?
│   ├── Yes
│   │   ├── Simple page? → React + Vite
│   │   ├── Full app with auth/DB? → Next.js (use build-product)
│   │   ├── Voice/WebRTC? → Hyperframes
│   │   └── Mobile? → Capacitor/Tauri + React
│   └── No
│       ├── Runs forever / bot? → Node + Express
│       ├── One-time script? → Python
│       ├── Heavy compute/ML? → Python
│       └── WhatsApp/Telegram? → Node + GreenAPI / python-telegram-bot
```
</content>