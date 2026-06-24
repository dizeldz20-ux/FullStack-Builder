# MCP Secure Setup Pattern

How to wire a third-party MCP server (Supabase, GitHub, Notion, etc.) into Hermes **without ever holding the token in memory, chat, or config files**.

This is the canonical pattern the user and Hermes converged on during the 2026-06-24 Supabase MCP install. Reuse it for any MCP that needs a long-lived credential.

## When to use this pattern

Use this whenever:
- A skill or workflow needs to talk to an external service (Supabase, GitHub, Linear, Notion, Stripe).
- The external service uses a Personal Access Token (PAT) or API key for auth.
- The token must outlive a single session.
- the user explicitly asked for an MCP install, OR the build-product task detected an MCP-shaped dependency gap.

Do NOT use this pattern for:
- OAuth flow tokens (those rotate, the setup is different — see [exceptions](#exceptions)).
- Local file system access (use `@modelcontextprotocol/server-filesystem` directly).
- Services that already provide OAuth via `hermes config set` (e.g. some cloud CLIs).

## The 4-step pattern

### Step 1 — Reject the token if pasted in chat

If the user pastes a raw token in chat (e.g. `<token-prefix><redacted>...`), do NOT echo it, store it, or reference its value. Reply:

> "לא לוקח את הטוקן בצ'אט. שמור אותו בקובץ בנתיב מאובטח (`chmod 600`) ותגיד לי את הנתיב."

Reasons:
1. Chat transcripts are persisted in the session DB and can be exported.
2. The token value cannot be revoked from Telegram retroactively — only by rotating it on the provider side.
3. Defense-in-depth is not about trust in the chat medium — it's about not having the secret in 5+ storage surfaces at once.

### Step 2 — Verify the token file (without reading it)

Once the user names a path:

```bash
# Path existence + tight permissions
ls -la /path/to/token.file                    # must show -rw------- (600) or 400
stat -c "%a %U:%G" /path/to/token.file        # numeric mode, owner, group

# Tighten if loose (typical: 644 → 600)
chmod 600 /path/to/token.file

# Sanity-check format without printing the value
head -c 10 /path/to/token.file && echo "..." && tail -c 5 /path/to/token.file
wc -c /path/to/token.file                     # size sanity (PATs are 30-50 bytes)
```

Never `cat` the file. The first-10 + last-5 characters are enough to confirm "this is a Supabase PAT" or "this is a GitHub PAT" without exposing the secret.

### Step 3 — Write a wrapper script under `scripts/`

The wrapper reads the token into env at runtime and `exec`s the MCP server. **The token never appears in Hermes config or in the wrapper's source after edit.**

```bash
#!/usr/bin/env bash
# ~/.config/hermes/scripts/<service>-mcp.sh
set -euo pipefail

TOKEN_FILE="${SERVICE_TOKEN_FILE:-~/projects/workspace/memory/.secrets/<service>.token}"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: $SERVICE_TOKEN_FILE not found at $TOKEN_FILE" >&2
  exit 1
fi

PERMS=$(stat -c "%a" "$TOKEN_FILE")
if [ "$PERMS" != "600" ] && [ "$PERMS" != "640" ]; then
  echo "WARNING: token file has loose permissions ($PERMS); expected 600" >&2
fi

# Load into env (never echo'd)
export SUPABASE_ACCESS_TOKEN=$(cat "$TOKEN_FILE")

# Spawn the MCP server
exec npx -y @supabase/mcp-server-supabase
```

Why this shape:
- `set -euo pipefail` — fail loud if the token file disappears between verification and exec.
- `stat -c "%a"` — defensive check at startup, not just at install time.
- `$()` capture without `echo` — the token enters the process env via `export`, never via stdout.
- `exec` — replaces the shell so the MCP process inherits the env directly, no extra layer.

Customize the wrapper for the service. For GitHub MCP, the env var is `GITHUB_TOKEN`. For Linear, `LINEAR_API_KEY`. Always check the package docs for the canonical env var name.

### Step 4 — Add the MCP block to `config.yaml` (manually)

The agent **cannot** edit `~/.hermes/config.yaml` directly — the security boundary rejects `patch` writes to it. Tell the user:

> "הוסף ל-`~/.hermes/config.yaml` תחת `mcp_servers:` את הבלוק:"
>
> ```yaml
>   supabase:
>     command: ~/.config/hermes/scripts/supabase-mcp.sh
>     enabled: true
> ```

the user runs `hermes config edit`, pastes, saves. Agent verifies with:

```bash
grep -A3 "^  supabase:" ~/.config/hermes/config.yaml
hermes config show | grep -i mcp   # should list 'supabase' as configured
```

## Validation (run after install)

```bash
# 1. Token file exists, tight perms
[ -f "$TOKEN_FILE" ] && [ "$(stat -c %a $TOKEN_FILE)" = "600" ] && echo "✅ token file OK" || echo "❌ token file missing or loose"

# 2. Wrapper is executable, syntax-valid
bash -n ~/.config/hermes/scripts/supabase-mcp.sh && echo "✅ wrapper syntax OK"

# 3. MCP package is reachable
timeout 5 npx -y @supabase/mcp-server-supabase --help 2>&1 | head -3

# 4. Hermes sees the MCP server
hermes config show | grep -i "supabase"
```

## Failure modes & recovery

| Failure | Likely cause | Fix |
|---|---|---|
| `Permission denied` on token file | `chmod 600` not run | `chmod 600 <path>` |
| `ERROR: token file not found` | Wrapper running in wrong env | `TOKEN_FILE=/full/path bash scripts/supabase-mcp.sh` |
| Hermes doesn't list the MCP after edit | `mcp_servers:` block mis-indented | Must be at exactly 2-space indent under top-level `mcp_servers:` |
| MCP server starts but exits silently | Token rotated on provider side | Get new PAT, overwrite file, `chmod 600`, retest |
| `npx` hangs on first run | Downloading package | Wait 30s, retry; second run is cached |

## Security invariants (do not violate)

1. **Token file path is the only thing stored** — never the value.
2. **Wrapper script contains no literal token** — only the path.
3. **`config.yaml` contains no token** — only the wrapper command path.
4. **Agent never `cat`s the token file** — only `head -c 10` + `tail -c 5` for format verification.
5. **Agent never logs the token** — including in error messages, debug output, or "for your reference" replies.

## Worked example (2026-06-24, Supabase MCP)

When an operator wants Supabase MCP installed and pastes a partial token in chat, the agent should refuse politely and ask for the file path. The standard storage pattern is `~/projects/<workspace>/<secrets-dir>/<token-file>`. The agent:

1. Verified file: `ls -la` showed 644 → tightened to 600.
2. Confirmed format: 44 bytes, starts `<token-prefix><redacted>`, ends `<redacted>` — looks like a Supabase PAT, no leak.
3. Created `~/.config/hermes/scripts/supabase-mcp.sh` — wrapper pattern from Step 3.
4. Confirmed `@supabase/mcp-server-supabase@0.8.2` exists on npm.
5. Tried `patch` on `config.yaml` → blocked by Hermes security boundary.
6. Told the user to run `hermes config edit` and paste the 3-line block.

End state: agent never held the token, Hermes can start the MCP on demand, token can be rotated by overwriting one file.

## When this pattern does NOT apply

- **OAuth-based MCP servers** (e.g. Notion OAuth, Linear OAuth): those use an MCP-issued URL flow, not a file-stored PAT. Different setup.
- **Local-only MCPs** (`server-filesystem`, `codegraph`, `playwright`): no token needed; just add to `mcp_servers:` block directly with the `command:` line.
- **Token-less services**: some MCP servers use environment-provided context (e.g. `MCP_RESOURCE_ROOT`). Skip Steps 1-3, go straight to Step 4.

## Related

- `references/state-machine-orchestration-pattern.md` — for the state.md + route.sh + state-update.sh trio, not for MCP setup.
- `user-defaults.md` — security rules section already says "Never put secrets in code"; this file is the **how** when the secret has to exist somewhere.
- `telegram-output-discipline` — same "no naked tokens in chat" principle applies to any long-lived secret, not just MCP.
</file_content>
</invoke>