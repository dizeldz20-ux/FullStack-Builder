#!/usr/bin/env python3
"""
Reverse proxy with HTTP Basic Auth for exposing a local dev server to an
external reviewer (e.g. the user, a QA tester, a contractor) over a
public HTTPS URL with a one-time password.

Sits between the public tunnel (localhost.run / ngrok / cloudflared) and
the local Vite / Flask / FastAPI / etc. dev server. It enforces Basic
Auth on every request, blocks direct access to .env* / dist / .git /
/root / scripts, and forwards everything else to the upstream
transparently.

Why this exists
---------------
localhost.run gives you a free `https://*.lhr.life` URL that
reverse-tunnels to localhost. That's enough to give the user a link,
but it's open — anyone with the URL can hit it. For a Hermes voice
frontend (or any app that ships .env* files in its project root) you
NEED a password gate AND a path filter, because the dev server will
happily serve `frontend/.env.development.local` (where the Hermes
bearer token lives) to anyone who asks.

This proxy is the answer. Three lines of property:
  - bound to 127.0.0.1 only (the tunnel is the only public surface)
  - HTTP Basic Auth (HTTPS at the tunnel edge, so the password is
    encrypted in transit; localhost.run / cloudflared terminates TLS for us)
  - hard-coded path denylist for secrets / source / build artifacts

Stdlib only — no flask, no aiohttp. Keeps the attack surface small
and the runbook trivial. If you need TLS termination yourself, put
Caddy or nginx in front instead of this proxy.

Usage
-----
    # Default: listen on 127.0.0.1:5273, forward to 127.0.0.1:5173
    python3 auth-proxy.py

    # Custom port / upstream
    python3 auth-proxy.py --listen-port 8080 --upstream-port 3000

    # Custom credentials (default: random 16-byte token, written to
    # /tmp/<script>_creds.txt with mode 0600)
    python3 auth-proxy.py --username alice --password 'correct-horse-battery'

The proxy prints where the credentials are written. Send the URL +
username + password to the user in a single Telegram message and
tear down the tunnel when done. The URL is alive as long as both
this proxy and the SSH tunnel are running.

What it does NOT do
-------------------
  - Not a TLS terminator. localhost.run / cloudflared / ngrok handles
    that at the edge. Run this proxy on 127.0.0.1 only.
  - Not a session manager. Every request is independently
    authenticated. That's fine for a 5-minute demo with a single
    user; for anything longer, use a real auth layer (OAuth, mTLS).
  - Not a CSP / CORS enforcer. The upstream dev server's CORS rules
    still apply. If you need wide CORS for the demo, configure it on
    the upstream, not here.
  - Not a request logger. `log_message` is suppressed on purpose —
    request paths and auth headers must not leak to stdout where
    they could be scraped by `journalctl`, `tmux capture-pane`, or
    terminal scrollback.
"""

import argparse
import base64
import http.client
import http.server
import os
import secrets
import sys
import urllib.parse

# Defaults — overridden by CLI flags
DEFAULT_LISTEN_PORT = 5273
DEFAULT_UPSTREAM_PORT = 5173
DEFAULT_USERNAME = "ruby"
CREDS_PATH = "/tmp/auth_proxy_creds.txt"

# Paths that must NEVER be served. Even with valid auth, the tunnel
# is a window into our local Vite project root, and we do not trust
# the user (or anyone who gets the password) to not poke at
# `frontend/.env.development.local` to grab the Hermes bearer token.
# If a project has additional secret-bearing paths, add them here.
#
# IMPORTANT: do NOT block `/node_modules/` wholesale. Vite's
# pre-bundled dependency cache lives at `/node_modules/.vite/deps/<pkg>.js`
# and the browser fetches these at runtime to load React, ReactDOM,
# lucide-react, etc. Blocking the entire `/node_modules/` tree yields
# HTTP 404 for every bundle request → React fails to mount → blank
# white page in the browser. The carve-out lives in `path_is_sensitive`
# below: block raw source under `/node_modules/<pkg>/` but allow the
# `.vite/deps/*` cache.
BLOCKED_PATH_PREFIXES = (
    "/.env",
    "/.git",
    "/dist/",
    "/scripts/",
    "/.hermes/",
    "/.npm/",
    "/.next/",
    "/.cache/",
    "/.ssh/",
    "/.cloudflared/",
    "/<frontend-project>/",  # project root walk via Vite static handler
)


def auth_ok(auth_header: str, username: str, password: str) -> bool:
    """Constant-time Basic Auth check."""
    if not auth_header.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(auth_header[6:]).decode("utf-8")
        user, pwd = decoded.split(":", 1)
        return (
            secrets.compare_digest(user.encode(), username.encode())
            and secrets.compare_digest(pwd.encode(), password.encode())
        )
    except Exception:
        return False


def path_is_sensitive(path: str) -> bool:
    """Normalize and check the path against the denylist.

    Carve-out: `/node_modules/.vite/*` is the Vite pre-bundled
    dependency cache and MUST be served — the browser fetches
    `/node_modules/.vite/deps/<pkg>.js` at runtime to load every
    third-party package. Without this carve-out, the user sees a
    blank white page (React never mounts) and the only diagnostic
    is "Vite logs are clean, the HTML loads, the JS 404s."
    """
    path = path.lstrip("/")
    for prefix in BLOCKED_PATH_PREFIXES:
        if path.startswith(prefix.lstrip("/")):
            return True
    if path.startswith("node_modules/") and not path.startswith("node_modules/.vite/"):
        return True
    return False


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *args, username="", password="", upstream_host="", upstream_port=0, **kwargs):
        self._username = username
        self._password = password
        self._upstream_host = upstream_host
        self._upstream_port = upstream_port
        super().__init__(*args, **kwargs)

    def _send_auth_required(self) -> None:
        body = b"Authentication required.\n"
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="<protected-app>", charset="UTF-8"')
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _send_blocked(self) -> None:
        """Return 404 for sensitive paths, even with valid auth.
        404 (not 403) so probing the denylist doesn't reveal which
        paths exist."""
        body = b"Not found\n"
        self.send_response(404)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _send_bad_gateway(self, msg: str) -> None:
        body = f"Proxy error: {msg}\n".encode("utf-8")
        self.send_response(502)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _proxy(self, method: str) -> None:
        # 1. Auth
        if not auth_ok(self.headers.get("Authorization", ""), self._username, self._password):
            self._send_auth_required()
            return

        # 2. Path filter
        parsed = urllib.parse.urlparse(self.path)
        if path_is_sensitive(parsed.path):
            self._send_blocked()
            return

        # 3. Read body
        content_length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(content_length) if content_length else b""

        # 4. Forward. Strip hop-by-hop and the user's Basic Auth header
        #    (we don't want the upstream seeing it). The frontend
        #    should attach its OWN Authorization header to the
        #    upstream call.
        hop_by_hop = {
            "connection", "keep-alive", "proxy-authenticate",
            "proxy-authorization", "te", "trailers",
            "transfer-encoding", "upgrade", "host", "authorization",
        }
        fwd_headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in hop_by_hop
        }
        fwd_headers["Host"] = f"{self._upstream_host}:{self._upstream_port}"
        fwd_headers["Connection"] = "close"

        try:
            conn = http.client.HTTPConnection(
                self._upstream_host, self._upstream_port, timeout=120,
            )
            conn.request(method, self.path, body=body, headers=fwd_headers)
            resp = conn.getresponse()
            resp_body = resp.read()
        except Exception as e:
            self._send_bad_gateway(str(e))
            return

        self.send_response(resp.status)
        for k, v in resp.getheaders():
            if k.lower() in hop_by_hop:
                continue
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(resp_body)
        try:
            conn.close()
        except Exception:
            pass

    def do_GET(self): self._proxy("GET")
    def do_POST(self): self._proxy("POST")
    def do_PUT(self): self._proxy("PUT")
    def do_PATCH(self): self._proxy("PATCH")
    def do_DELETE(self): self._proxy("DELETE")
    def do_OPTIONS(self): self._proxy("OPTIONS")
    def do_HEAD(self): self._proxy("HEAD")

    def log_message(self, fmt, *args):
        # Quiet — never log request paths or auth headers.
        pass


def make_handler(username, password, upstream_host, upstream_port):
    """Closure capture for the per-request handler."""
    class _BoundHandler(ProxyHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(
                *args,
                username=username,
                password=password,
                upstream_host=upstream_host,
                upstream_port=upstream_port,
                **kwargs,
            )
    return _BoundHandler


def main() -> int:
    p = argparse.ArgumentParser(description="HTTP Basic Auth reverse proxy for localhost.run / cloudflared tunnels")
    p.add_argument("--listen-host", default="127.0.0.1", help="(default 127.0.0.1 — do NOT change)")
    p.add_argument("--listen-port", type=int, default=DEFAULT_LISTEN_PORT)
    p.add_argument("--upstream-host", default="127.0.0.1")
    p.add_argument("--upstream-port", type=int, default=DEFAULT_UPSTREAM_PORT)
    p.add_argument("--username", default=DEFAULT_USERNAME)
    p.add_argument("--password", default=None,
                   help="If omitted, a random 16-byte URL-safe token is generated")
    p.add_argument("--creds-path", default=CREDS_PATH,
                   help="Where to write the username:password (default /tmp/auth_proxy_creds.txt, mode 0600)")
    args = p.parse_args()

    password = args.password or secrets.token_urlsafe(16)

    # Write credentials file with 0600. Never echo them to stdout in
    # production usage; the operator reads them from this file.
    with open(args.creds_path, "w") as f:
        f.write(f"USERNAME={args.username}\n")
        f.write(f"PASSWORD={password}\n")
        f.write(f"LISTEN_URL=http://{args.listen_host}:{args.listen_port}\n")
        f.write(f"UPSTREAM_URL=http://{args.upstream_host}:{args.upstream_port}\n")
    os.chmod(args.creds_path, 0o600)

    print(f"auth-proxy listening on http://{args.listen_host}:{args.listen_port}", flush=True)
    print(f"  upstream: http://{args.upstream_host}:{args.upstream_port}", flush=True)
    print(f"  credentials written to: {args.creds_path}", flush=True)
    print(f"  blocked paths: {', '.join(BLOCKED_PATH_PREFIXES)}", flush=True)
    print(f"  carve-out: /node_modules/.vite/* is allowed (Vite pre-bundled deps)", flush=True)

    server = http.server.ThreadingHTTPServer(
        (args.listen_host, args.listen_port),
        make_handler(args.username, password, args.upstream_host, args.upstream_port),
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
