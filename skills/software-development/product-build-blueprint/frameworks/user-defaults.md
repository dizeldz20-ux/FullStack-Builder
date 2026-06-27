# user-defaults.md (stub)

> **[stub]** — This file is referenced from `product-build-blueprint/tasks/new-product.md` and `supabase-auth-patterns/tasks/setup-google-oauth.md` but is not yet implemented in this skill. It should provide user-stack defaults for `product-build-blueprint`.

The `build-product` skill has its own `frameworks/user-defaults.md` (with Three Rules + stack preferences). For `product-build-blueprint` (the lightweight 7-step flow), a simpler version is needed.

This file should cover:
- Default stack assumption (Node.js + Express unless user says otherwise)
- Default language (Hebrew-first responses; English for code comments)
- Default deployment target (none — user can choose Cloudflare or skip)
- Default database (SQLite for scripts/bots; PostgreSQL only if user asks)

**To fill this stub**, copy the developer's local Vault version (if present) or implement from scratch.