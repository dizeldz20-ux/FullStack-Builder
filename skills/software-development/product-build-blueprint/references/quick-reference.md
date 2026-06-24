# Quick Reference — Product Build Blueprint

> copy-paste snippets and quick commands

## Scaffold a new project

```bash
# Node.js (with Express)
bash scripts/scaffold-node.sh my-project
cd my-project && npm install express && npm start

# Python (with Flask)
bash scripts/scaffold-python.sh my-project
cd my-project
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/main.py
```

## Quick test

```bash
# Server health
curl http://localhost:3000/health

# Watch logs
tail -f logs/server.log  # if you have logs

# Restart
pkill -f "node src/index.js" && npm start &
```

## The 7 Steps in 1 Line Each

1. **הבנה** — 5 שאלות + scope template
2. **Stack** — decision tree ב-`@frameworks/stacks.md`
3. **תכנון** — מבנה + API + סיכונים
4. **בנייה** — scaffold → start → logic → integrations → errors → tests → cleanup
5. **בדיקות** — `curl /health` + smoke test של המקרה המרכזי
6. **העלאה** — Cloudflare / Docker / Railway (תלוי ב-stack)
7. **תיעוד** — README + .env.example + .gitignore

## When to Use build-product Instead

| Trigger | Route to |
|---|---|
| Has Supabase auth | `build-product` |
| Needs Cloudflare Access | `build-product` |
| Next.js 15 + App Router | `build-product` |
| Multi-session state | `build-product` |
| TDD strict required | `build-product` |

---

*From a peer agent's super-builder, structured for skillsmith.*
