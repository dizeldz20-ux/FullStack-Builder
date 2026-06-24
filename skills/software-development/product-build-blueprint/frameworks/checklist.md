# End-to-End Checklist — לפני שמעלים

> מתוך super-builder של peer agent.

## קוד

- [ ] קוד נקי — אין debug, console.log מיותר
- [ ] שמות משתנים/פונקציות ברורים
- [ ] שגיאות מטופלות (try/catch)
- [ ] אין hardcoded credentials/secrets בקוד

## בדיקות

- [ ] `npm start` / `python main.py` עובד
- [ ] `GET /health` מחזיר 200
- [ ] המקרה המרכזי נבדק ועובד
- [ ] שגיאות מחזירות תשובה ברורה

## אבטחה

- [ ] credentials ב-`.env` בלבד, לא בקוד
- [ ] `.env` ב-`.gitignore`
- [ ] `.env.example` קיים (עם placeholderים)
- [ ] לא חושפים פורטים לא נחוצים
- [ ] **אם יש Supabase**: RLS מופעל על כל הטבלאות (→ `supabase-auth-patterns`)
- [ ] **אם יש deploy**: Cloudflare Access על URL זמני (→ `cloudflare-deploy`)

## תיעוד

- [ ] `README.md` עם התחלה מהירה (3-5 פקודות)
- [ ] `scripts/` עם כל מה שצריך להריץ
- [ ] API endpoints מתועדים

## Git

- [ ] `git init` (אם צריך)
- [ ] `.gitignore` מתאים (node_modules, .venv, .env)
- [ ] commit ראשון: "initial commit"

## Deployment

- [ ] יודע איפה זה ירוץ
- [ ] יודע איך מתחילים (docker / npm start / etc.)
- [ ] health check עובד
- [ ] **אם זה deploy ל-Cloudflare**: → `cloudflare-deploy` (לא לעשות ידני)
- [ ] **אם זה deploy ל-Docker**: → `docker-essentials`
- [ ] **אם זה deploy אחר**: `pm2` / `systemd` / Railway / Fly.io
</content>