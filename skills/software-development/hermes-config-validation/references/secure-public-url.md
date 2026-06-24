# Secure public URL with password: localhost.run + auth proxy

When the user (or a reviewer, or a phone on a different network) needs to open a local dev server in a real browser, the chain is:

1. **Run the local dev server** (Vite, Flask, FastAPI, Jupyter, etc.) on `127.0.0.1:<port>`.
2. **Run `scripts/auth-proxy.py`** on `127.0.0.1:<proxy-port>`. It enforces HTTP Basic Auth and blocks paths under a hard-coded denylist. Stdlib only — no flask, no aiohttp. See the script header for the full threat model.
3. **Run an SSH reverse tunnel** to `nokey@localhost.run`, mapping the public HTTPS port to the auth-proxy port: `ssh -o StrictHostKeyChecking=accept-new -R 80:127.0.0.1:<proxy-port> nokey@localhost.run`.
4. **Wait 3-15 seconds** for the SSH handshake + cert provisioning + edge registration. localhost.run prints the public URL on stdout once ready.
5. **Send the URL + credentials** in one Telegram message. The URL is `https://<random-32-chars>.lhr.life`; the credentials are in `/tmp/auth_proxy_creds.txt` (mode 0600, random 16-byte token by default).

The browser opens the URL, gets a 401 + browser-native Basic Auth prompt, the user enters username + password, and the request flows: browser → localhost.run HTTPS → SSH tunnel → `127.0.0.1:<proxy>` → `127.0.0.1:<dev-server>`. End-to-end TLS happens at the localhost.run edge; auth is Basic, but Basic over HTTPS is fine.

## Why a separate auth proxy, not just CORS + a tunnel

A bare `ssh -R 80:127.0.0.1:5173 nokey@localhost.run` exposes the dev server to the world with no gate. For a Hermes voice frontend this is catastrophic: `frontend/.env.development.local` (where the Hermes bearer token lives) sits in the project root, and Vite's static handler will serve it to anyone who asks for `/frontend/.env.development.local` or `/.env.development.local`. The proxy is the only place you can deny those paths reliably — neither Vite nor Hermes will.

The denylist is hard-coded in `BLOCKED_PATH_PREFIXES`:

```python
BLOCKED_PATH_PREFIXES = (
    "/.env", "/.git", "/node_modules/", "/dist/",
    "/scripts/", "/.hermes/", "/.npm/", "/.next/", "/.cache/",
)
```

Extend the list for your project. The 404 (not 403) for blocked paths is intentional — it doesn't reveal which paths exist.

## How the user gets the credentials

The proxy writes a creds file at startup with `chmod 0600`. You read the file (never the running process's env), and send the URL + username + password to the user. Do NOT echo the password in the same channel as the URL if the channel is logged (e.g. a shared chat, a public Slack). Telegram DMs are fine; a public GitHub issue is not.

A runnable sequence:

```bash
# 1. Start the proxy. It writes /tmp/auth_proxy_creds.txt and prints listen URL.
python3 ~/.config/hermes/skills/software-development/hermes-config-validation/scripts/auth-proxy.py \
    --listen-port 5273 --upstream-port 5173

# 2. Start the tunnel. Use a background process; it stays alive as long
#    as the SSH connection is up. Tail the log for the public URL.
ssh -o StrictHostKeyChecking=accept-new -R 80:127.0.0.1:5273 nokey@localhost.run \
    > /tmp/tunnel.stdout 2> /tmp/tunnel.log

# 3. After 5-10s, the public URL appears in /tmp/tunnel.stdout.
#    Format: "https://<random-32-chars>.lhr.life tunneled with tls termination"
sleep 6 && grep "lhr.life" /tmp/tunnel.stdout

# 4. Verify the auth path: no auth → 401, with auth → 200.
URL=$(grep -oE "https://[a-f0-9]+\.lhr\.life" /tmp/tunnel.stdout | head -1)
USER=$(awk -F= '/^USERNAME/ {print $2}' /tmp/auth_proxy_creds.txt)
PASS=$(awk -F= '/^PASSWORD/ {print $2}' /tmp/auth_proxy_creds.txt)
echo "no auth:" && curl -sS -o /dev/null -w "  HTTP %{http_code}\n" "$URL/"
echo "with auth:" && curl -sS -o /dev/null -w "  HTTP %{http_code}\n" -u "$USER:$PASS" "$URL/"
echo "blocked path:" && curl -sS -o /dev/null -w "  HTTP %{http_code}\n" -u "$USER:$PASS" "$URL/.env.development.local"
# Expect: 401, 200, 404
```

## Pitfalls specific to this stack

- **No API key in the tunnel URL.** The Hermes `API_SERVER_KEY` lives in the gateway's process env, not the tunnel. The frontend already has it baked in via `VITE_HERMES_API_KEY` in `frontend/.env.development.local` (which the dev server reads at startup and injects into the bundle). The user's browser never sees it; the auth proxy never sees it; the tunnel never sees it. If you accidentally include the key in the URL or in chat, rotate it at Hermes.

- **The URL is alive only as long as the SSH process is alive.** localhost.run is a free anonymous tunnel — no account, no reservation, no persistence. When the user is done, kill the SSH process (find it with `pgrep -f "ssh.*localhost.run"`). The URL stops working immediately, and there is no way to recover the URL after the process exits. If the user needs persistence, use ngrok (`ngrok http 5273`, requires a free account) or Cloudflare Tunnel (`cloudflared tunnel --url http://127.0.0.1:5273`).

- **HTTPS is required for voice UI.** Browsers refuse to grant microphone access over plain HTTP, even for `localhost`. localhost.run terminates TLS at their edge, so the URL the user visits is `https://`, and `getUserMedia` works. A plain HTTP tunnel (e.g. a self-hosted `ssh -R` without cert) will load the page but the mic button will silently fail. The `Accept: getUserMedia` permission is granted to `https://` origins and `localhost` / `127.0.0.1` only — not to `http://*.example.com`.

- **CORS is not relevant when you use the auth-proxy + Vite pattern.** The browser sees only one origin (the tunnel). Vite's dev server forwards `/api/*` and `/v1/*` to Hermes on the same VM. The browser does not make cross-origin requests, so CORS does not fire. If you ever skip the auth-proxy and tunnel directly to Vite, AND the frontend calls Hermes on a different host, CORS will bite you and you will need `API_SERVER_CORS_ORIGINS` on Hermes.

- **CORS IS relevant the moment the frontend is the built `dist/`, not Vite.** The reference above is correct for `npm run dev` (Vite proxies `/api/*` to Hermes on the same origin). But the moment you switch to `npm run build` and serve the `dist/` bundle directly (no Vite), the browser sees a single origin (the tunnel) and POSTs to `/api/sessions` with `Origin: https://<tunnel>.trycloudflare.com`. Hermes's `cors_middleware` (`gateway/platforms/api_server.py`, `_origin_allowed` at line ~789) reads that `Origin` header and rejects it with 403 unless the origin is in `API_SERVER_CORS_ORIGINS`. This bit twice in production sessions and was the silent cause of `createSession: HTTP 403` in the frontend.
  - **Symptom**: `/v1/health` returns 200 (auth-free, no Origin check), but `POST /api/sessions` returns 403 with no body. The browser DevTools Network tab shows the 403 on the preflight or on the actual request.
  - **Fix**: add `API_SERVER_CORS_ORIGINS=<your-tunnel-host>` (or `*` for a demo) to `~/.config/hermes/.env`, then restart the gateway. `os.getenv("API_SERVER_CORS_ORIGINS")` is read once at adapter init in `__init__`; there is no hot reload. A gateway restart will drop the active Telegram session — confirm with the user before doing it.
  - **Reading the value live**: `tr '\0' '\n' < /proc/<gateway-pid>/environ | grep ^API_SERVER_CORS_ORIGINS=` — if it returns nothing, the gateway was started before the env var existed and a restart is mandatory.

- **`StrictHostKeyChecking=accept-new` is the difference between "tunnel works" and "tunnel hangs forever."** localhost.run's host key changes over time; without `accept-new` (or `yes` from a known_hosts entry), SSH will prompt for the key and the tunnel never comes up. Same for ngrok's edge.

- **The proxy suppresses all request logging on purpose.** `log_message` is a no-op. Request paths and Authorization headers must not land in stdout (which gets scraped by journalctl, tmux scrollback, or terminal sharing). If you need debugging, temporarily add `print(self.path, self.command)` to `log_message`, but never leave it on for a production demo.

- **Do NOT bind the proxy to `0.0.0.0`.** `--listen-host 0.0.0.0` exposes the proxy on the LAN, not just to the tunnel. The tunnel binds to 127.0.0.1 anyway, so the only thing LAN exposure gives you is a free path past the tunnel's HTTPS. Default is 127.0.0.1 for a reason. The `--listen-host` flag exists for the case where you're putting the proxy behind a different reverse proxy on a different host — almost never.

- **The 401 challenge must use `WWW-Authenticate: Basic realm="..."` with `charset="UTF-8"`.** Without `charset="UTF-8"`, some browsers (older Chrome, Firefox on Linux) don't display the realm correctly when the project name has Hebrew or emoji. With it, the browser-native prompt renders properly. The `realm` value is also shown to the user as "Sign in to <realm>" — make it the project name, not a generic "Restricted Area".

- **Constant-time comparison is mandatory, not optional.** `secrets.compare_digest` is in the stdlib. `==` is timing-attack-vulnerable even though in practice the attack is over-engineering for a 5-minute demo. Use `compare_digest` because the cost is one extra import.

## What to verify before sending the URL to the user

| Check | How | Expected |
|---|---|---|
| No auth → 401 | `curl -o/dev/null -w "%{http_code}\n" "$URL/"` | 401 |
| With auth → 200 | `curl -u user:pass -o/dev/null -w "%{http_code}\n" "$URL/"` | 200 |
| Blocked path → 404 | `curl -u user:pass -o/dev/null -w "%{http_code}\n" "$URL/.env.development.local"` | 404 (NOT 403) |
| Hermes chat works | `curl -u user:pass -X POST -d '{...}' "$URL/api/sessions"` | 201 with `body.session.id` |
| Streaming works | `curl -u user:pass -X POST -d '{...}' "$URL/api/sessions/<id>/chat/stream"` | SSE stream with `event: assistant.delta` |

If any of these fail, the issue is almost always: (a) creds file was read before proxy finished writing (race), (b) `StrictHostKeyChecking` prompt is hanging the tunnel, (c) the proxy crashed and the SSH tunnel is forwarding to a dead port.

## When NOT to use this pattern

- For a permanent public demo, use a real auth layer (OAuth, mTLS) and a real TLS cert (Caddy, nginx, Cloudflare). The proxy is a 5-minute demo gate, not a production auth wall.
- For a multi-tenant SaaS, never. The proxy has no concept of users beyond a single shared password.
- For a localhost-only demo, the proxy is overhead — just open `http://localhost:5173/` directly.
- For a security-sensitive action (e.g. sending real WhatsApp messages, real money), this is a soft gate. The password is sent on every request; anyone who sniffs the URL+password combo can use it until you change the password.
