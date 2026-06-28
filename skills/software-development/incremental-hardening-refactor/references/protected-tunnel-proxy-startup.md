# Protected tunnel/proxy startup hardening for browser voice apps

Use this when a live browser/mobile feature works locally but hangs behind a public tunnel, auth wrapper, reverse proxy, or cookie-login preview server.

## Durable lesson

A provider startup symptom can be caused by the preview/proxy layer, not the provider. In a Ruby voice Deepgram case, the UI stayed around `connecting` because the Cloudflare + cookie-auth proxy mishandled `Transfer-Encoding: chunked` for `POST /api/deepgram/session-token`; the backend waited for a body that never completed.

## Safe debug order

1. Verify the exact live URL and kill/ignore stale preview servers or old tabs.
2. Test the failing endpoint through the public tunnel, not only localhost.
3. Compare local vs tunnel behavior before changing provider integration code.
4. Inspect whether the proxy forwards hop-by-hop headers (`Transfer-Encoding`, `Connection`, etc.) or leaves body framing inconsistent.
5. Add debug stages that distinguish auth/token, microphone/device, and provider WebSocket startup.

## Proxy hardening pattern

- Materialize/decode request bodies before forwarding when the proxy stack does not do it automatically.
- Strip hop-by-hop/framing headers that no longer apply, especially `Transfer-Encoding`.
- Set a correct `Content-Length` for the forwarded body.
- Keep backend Authorization/session injection server-side; never surface provider secrets in frontend preview code.
- For protected demos, remove visible login credentials from the page copy even if credentials remain simple/private.

## Verification

- Public tunnel endpoint returns the expected status/body.
- Browser console has no JS errors.
- UI advances beyond the previously stuck startup stage.
- Headless QA may legitimately stop at microphone-device errors; that still proves token/proxy progress, but phone QA is required for the real mic path.
