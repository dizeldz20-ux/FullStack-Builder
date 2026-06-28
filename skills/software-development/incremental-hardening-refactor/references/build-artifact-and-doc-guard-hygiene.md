# Build Artifact and Product-Docs Guard Hygiene

Session-derived pattern for incremental hardening in product repos with generated frontend builds and active architecture docs.

## Build artifact hygiene

When a build command dirties tracked generated output (for example hashed Vite assets under an admin app `dist/`):

1. Reproduce the churn with the exact build command.
2. Decide whether generated output is supposed to be tracked. If project convention says not to commit it, do not keep cleaning it manually forever.
3. Add the generated directory to `.gitignore`.
4. Remove existing generated files from the git index with `git rm -r --cached <generated-dir>`.
5. Add/adjust a regression test that proves the directory is not tracked, e.g. `git ls-files <generated-dir>` is empty.
6. Strengthen the aggregate audit script so it fails on dirty output, not just prints `git status`:
   - `git diff --exit-code`
   - `git diff --cached --exit-code`
   - fail if `git ls-files --others --exclude-standard` returns unexpected files.
7. Run the full audit command once on a clean HEAD to prove the gate passes and leaves the tree clean.

## Product-doc guard hygiene

When architecture/product direction changes, stale active docs can undermine runtime hardening. Treat them as testable product invariants:

- Add forbidden-phrase guards for stale directions (examples: user-facing BYOK, email-only ownership, Supabase-first wording when Neon/app-owned is canonical).
- Add positive assertions for the canonical invariant (examples: provider keys stay server-side, ownership resolves by `(provider, provider_subject)` or server-owned `account_id`, email is metadata only).
- Update older doc tests that still assert obsolete wording; do not restore stale text just to satisfy old tests.

## CSP callback coverage

For HTML auth handoff pages, cover both success and error paths:

- Success callback scripts should use a per-response nonce and CSP `script-src 'self' 'nonce-...'`.
- Error callback pages that inject an error message into the DOM need the same nonce treatment; otherwise default CSP may block the error script and silently break UX.
- Keep `Cache-Control: no-store` on callback responses.
- Escape JSON-injected strings so `<` becomes `\u003c`, preventing `</script>` breakout.
