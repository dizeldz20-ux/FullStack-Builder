# jina.ai Reader as Anti-Bot Fetch Proxy

> **Validated**: 2026-06-24 during Supabase Auth research that fed `supabase-auth-patterns` v0.1.0.
> **Use when**: a research target is a modern docs site that returns a "verifying your browser" challenge page to direct curl (Vercel, Cloudflare, Netlify docs typically).

---

## § The problem

`curl -sL https://supabase.com/docs/...` returns this:

```html
<p id="header-text" data-astro-cid-nbv56vs3>We're verifying your browser</p>
<p data-astro-cid-nbv56vs3>fra1::1782297016-RzxWEOrm2u6Q4PyoqzV1gOIfDErgI3MH</p>
```

A Vercel Security Checkpoint challenge. No `<article>`, no `<h1>`, no real content — just a JavaScript challenge page. This is the recurring failure mode for any modern docs site hosted on Vercel or behind Cloudflare's "I'm human" gate.

## § The fix — `r.jina.ai/<url>` proxy

`r.jina.ai` is a reader-as-a-service that runs a real browser under the hood and returns the rendered text as clean Markdown. No JS challenge, no headless browser setup.

```bash
# ❌ Returns Vercel challenge page (not docs)
curl -sL "https://supabase.com/docs/guides/auth/social-login/auth-google"

# ✅ Returns clean Markdown of the same page
curl -sL "https://r.jina.ai/https://supabase.com/docs/guides/auth/social-login/auth-google"
```

Output starts with metadata, then `Markdown Content:` followed by the page as Markdown with code blocks preserved (the curl output sometimes prepends `1` to each line of code blocks — that's jina's line-numbering artifact; strip with `sed 's/^ *[0-9]*//'` if it bothers you).

## § Bulk fetch loop — get a whole research corpus in 15 seconds

```bash
mkdir -p /tmp/research-corpus
cd /tmp/research-corpus

for url in \
  "https://supabase.com/docs/guides/auth" \
  "https://supabase.com/docs/guides/auth/social-login/auth-google" \
  "https://supabase.com/docs/guides/auth/social-login/auth-apple" \
  "https://supabase.com/docs/guides/auth/sessions" \
  "https://supabase.com/docs/guides/auth/row-level-security" \
  "https://supabase.com/docs/guides/auth/server-side/nextjs" \
  ; do
  name=$(echo "$url" | sed -E 's|https?://||;s|/|_|g;s|\.|_|g')
  curl -sL --max-time 30 "https://r.jina.ai/$url" > "${name}.md"
  echo "fetched: $name ($(wc -c < "${name}.md") bytes)"
done
```

Then read the corpus into your own context with `read_file` (offset/limit for big ones), or `grep` / `search_files` to find specific terms.

## § What works / what doesn't

| Site family | Works via jina? | Notes |
|---|---|---|
| `supabase.com/docs/...` | ✅ | Clean Markdown, code blocks preserved |
| `vercel.com/docs/...` | ✅ | Same Vercel-host family, same fix |
| `nextjs.org/docs/...` | ✅ | Tested 2026-06-24 |
| `github.com/<user>/<repo>` (README + files) | ✅ | Same jina proxy works |
| Reddit (`r.jina.ai/r/<subreddit>`) | ⚠️ | Some regions are blocked; use `old.reddit.com` direct curl |
| Table-shaped HTML pages | ⚠️ | Jina collapses tables to prose. Use `html-structured-extract` for tables |
| Auth-walled pages | ❌ | jina can't bypass login. Use `playwright-mcp` with credentials |
| JS-required interactions (click, fill, scroll) | ❌ | jina returns static rendered text only. Use browser tools |

## § Why NOT to use `delegate_task` for this

`delegate_task` with a research-heavy prompt times out at 600s because the subagent:

1. Hits the same Vercel wall
2. Tries `browser_navigate` to bypass (slow)
3. Gets tangled in browser automation troubleshooting
4. Never finishes the synthesis
5. Returns with a partial corpus + a long error trace

A 3-line curl loop above runs in **~15 seconds total** and gives you the same content. Save `delegate_task` for *synthesis* ("here's a 200KB corpus, extract the X pattern"), not fetch.

This was empirically validated 2026-06-24: 6 Supabase docs pages fetched in ~12 seconds total via the jina loop. Same goal via `delegate_task` (twice) timed out at 600s with partial results.

## § One-liner for one specific page

```bash
curl -sL "https://r.jina.ai/<URL>" | head -100
```

Useful mid-conversation when debugging a single API or config issue — fast enough that the user doesn't wait.

## § When to escalate to browser tools

jina returns the rendered *text*, but it can't:

- Click buttons (e.g., expand a collapsed section in MDX)
- Fill forms
- Execute JavaScript and report the result
- Capture console errors
- Take screenshots

For those, fall back to `browser_navigate` + `browser_snapshot` from the main thread (or `playwright-mcp` for scripted interactions).

## § Related

- `html-structured-extract` — for table-shaped data where jina collapses the structure
- `supabase-auth-patterns/references/research-fetch-recipe.md` — same recipe in a Supabase-specific context, with verified Supabase doc URL list
- `agent-reach` + `agent-reach/references/web.md` — alternative prose-read path via jina, with more routing options