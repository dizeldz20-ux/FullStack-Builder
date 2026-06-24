# Research Fetch Recipe — How to Read Supabase Docs Without Hitting the Vercel Wall

> **Validated**: 2026-06-24 during the Supabase Auth research that fed `supabase-auth-patterns` v0.1.0.
> **Use when**: you need to read Supabase docs (or any modern docs site behind Vercel/Cloudflare) into your own context as clean Markdown.

---

## § The problem

`curl https://supabase.com/docs/...` returns this:

```html
<p id="header-text" data-astro-cid-nbv56vs3>We're verifying your browser</p>
<p data-astro-cid-nbv56vs3>fra1::1782297016-RzxWEOrm2u6Q4PyoqzV1gOIfDErgI3MH</p>
```

A Vercel Security Checkpoint challenge. No article, no h1, no real content. Wastes 5 minutes of debugging before you realize what's happening.

## § The fix — `r.jina.ai/<url>` proxy

`curl https://r.jina.ai/https://supabase.com/docs/...` returns the same page as clean Markdown. It works because jina.ai runs a real browser under the hood and serves the rendered text.

```bash
curl -sL "https://r.jina.ai/https://supabase.com/docs/guides/auth/social-login/auth-google"
```

Output starts with:

```text
Title: Login with Google | Supabase Docs
URL Source: https://supabase.com/docs/guides/auth/social-login/auth-google
Published Time: 2026-06-24T09:59:18.420Z
Markdown Content:
* * *

Supabase Auth supports Sign in with Google for the web ...
```

Code blocks are preserved as fenced ` ``` ` blocks with the original code inline (the curl output sometimes prepends `1` to each line, which is jina's line-numbering artifact — strip with `sed 's/^ *[0-9]*//'` if it bothers you).

## § Bulk fetch loop — get a whole research corpus in 15 seconds

```bash
mkdir -p /tmp/supabase-docs
cd /tmp/supabase-docs

for url in \
  "https://supabase.com/docs/guides/auth" \
  "https://supabase.com/docs/guides/auth/social-login/auth-google" \
  "https://supabase.com/docs/guides/auth/social-login/auth-apple" \
  "https://supabase.com/docs/guides/auth/sessions" \
  "https://supabase.com/docs/guides/auth/sessions/pkce-flow" \
  "https://supabase.com/docs/guides/auth/row-level-security" \
  "https://supabase.com/docs/guides/auth/server-side/nextjs" \
  "https://supabase.com/docs/guides/auth/redirect-urls" \
  "https://supabase.com/docs/guides/auth/rate-limits" \
  "https://supabase.com/docs/guides/getting-started/quickstarts/nextjs" \
  "https://supabase.com/docs/guides/api/rest/client-libs" \
  ; do
  name=$(echo "$url" | sed -E 's|https?://||;s|/|_|g;s|\.|_|g')
  curl -sL --max-time 30 "https://r.jina.ai/$url" > "${name}.md"
  echo "fetched: $name ($(wc -c < "${name}.md") bytes)"
done

ls -la
# All files now exist as readable Markdown, total ~150-300KB depending on doc length.
```

Then read them in your own context with `read_file` (offset/limit for big ones), or `grep`/`search_files` to find specific terms.

## § What works / what doesn't

| Site | Works via jina? | Notes |
|---|---|---|
| `supabase.com/docs/...` | ✅ | Clean Markdown, code blocks preserved |
| `vercel.com/docs/...` | ✅ | Same Vercel-host family, same fix |
| `nextjs.org/docs/...` | ✅ | Tested 2026-06-24 |
| `github.com/<user>/<repo>` | ✅ | README + file contents work |
| `r.jina.ai/r/<subreddit>` | ❌ | Reddit blocks jina in some regions; use `old.reddit.com` curl |
| `signals.forwardfuture.com/` | ⚠️ | Works for prose, but loses table structure → use `html-structured-extract` for tables |
| Auth-walled docs sites | ❌ | jina can't bypass login; use `playwright-mcp` with creds |

## § Why NOT to use `delegate_task` for this

`delegate_task` with a research-heavy prompt times out at 600s because the subagent:

1. Hits the same Vercel wall
2. Tries to use `browser_navigate` to bypass (slow)
3. Gets tangled in browser automation troubleshooting
4. Never finishes the synthesis
5. Returns with a partial corpus + a long error trace

The 3-line curl loop above runs in **~15 seconds total** and gives you the same content. Save `delegate_task` for the *synthesis* step ("here's a 200KB corpus, extract the 8 patterns"), not the fetch.

## § One-liner for one specific page

```bash
curl -sL "https://r.jina.ai/<URL>" | head -100  # first 100 lines of any doc page
```

Useful when debugging a single API or config issue — fast enough to use mid-conversation.

## § When to use browser tools instead

jina returns the rendered text, but it can't:

- Click buttons (e.g., expand a collapsed section in MDX)
- Fill forms
- Execute JavaScript and report the result
- Capture console errors

For those, fall back to `browser_navigate` + `browser_snapshot` from the main thread (or `playwright-mcp` for scripted interactions).

## § Related

- `html-structured-extract` — for table-shaped data where jina collapses the structure
- `competitor-product-research-to-build` — primary skill for research deliverables; the pitfall there documents the same pattern
- `agent-reach` + `agent-reach/references/web.md` — for prose reads via jina when you don't want to write your own loop