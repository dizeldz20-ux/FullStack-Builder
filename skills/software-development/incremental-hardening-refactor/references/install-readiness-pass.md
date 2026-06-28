# Pre-handoff install-readiness pass

**Trigger:** End of a project, just before handing the repo to another person
or AI agent (new employer, contractor, Claude/Codex in another session). The
repo must be installable from a fresh clone with zero tribal knowledge.

This is the pass that catches bugs "I assumed everyone knew that" — which
silently break first-day installs. The user's own rule:

> **Never declare "100% ready" or "all good" after one review pass. Always do
> the fresh-clone simulation. If you can't reproduce the install from scratch
> as a stranger, the repo isn't ready, no matter how many tests pass.**

## When to load this

- Project is about to be handed off to anyone else (human or AI)
- User says "ready", "done", "ship it", "hand to Tomer", "clone this"
- After running `requesting-code-review` once and getting it green
- After a "I'm sure" claim — that's the trigger to do this, not to stop

## Step-by-step

### 1. Fresh-clone simulation — the core technique

```bash
FRESH=$(mktemp -d)
cp -r . "$FRESH/repo-name"
cd "$FRESH/repo-name"
rm -rf .venv .pytest_cache __pycache__ src/__pycache__ tests/__pycache__
rm -f .env .env.local
# Now you ARE the stranger. Run the documented quick-start verbatim.
```

Do NOT skip the .venv removal — the whole point is to catch "works on my
machine because I have a leftover venv" bugs.

### 2. Walk the documented path verbatim

Read README.md / Quick Start and execute each command as written. If the doc
says `bash scripts/setup.sh`, run exactly that. If it requires running
`cp .env.example .env && nano .env` first, do that too. Catch every missing
step.

### 3. Verify each make target works on a real fresh clone

- `make help` shows expected targets
- `make setup` (with empty .env) gives actionable instructions, not a crash
- `make verify` (with fake keys) returns non-zero and clearly names the bad key
- `make verify` (with real keys) returns 0
- `make test` runs (does NOT need to pass on no-key secrets — but must not
  error on missing imports)
- `make run` actually produces the promised output file

### 4. The "auto-create .env" pattern

Never crash on missing .env. If the install script requires a .env, it should:

- Check if `.env.example` exists; if not, fail with a clear "did you clone
  the full repo?" message.
- Otherwise `cp .env.example .env` automatically.
- Print a clear call-to-action box with:
  - The exact command to edit (`nano .env`)
  - Direct signup links for any required service accounts
  - A pointer to the longer setup guide
- Then `exit 1` with a message telling them to re-run after editing.

**Anti-pattern:** `fail ".env not found. Run: cp .env.example .env && nano .env"`

This is technically correct but gives zero context. The user already knows
they need to copy the file; they don't know what the keys are for or where
to get them.

### 5. The shell-env precedence trap in verification scripts

This is the single most common "silent failure" bug in any env-loading code:

```python
# ❌ WRONG — uses shell env if it exists, IGNORES .env value
from dotenv import load_dotenv
load_dotenv()  # default: does NOT override existing env vars
key = os.getenv("MY_API_KEY")

# ✅ RIGHT — reads ONLY the file, ignores shell env
from dotenv import dotenv_values
file_vars = dotenv_values(".env")
key = file_vars.get("MY_API_KEY", "")
```

**Why this matters:** a verification script using the wrong pattern will
falsely report "all keys OK" when the user's `.env` has placeholder text,
if their shell happens to have real keys from another project. The user
will believe they're ready to ship and discover on first run that nothing
works. **This is a confidence-eroder, not just a bug.**

**Rule of thumb:** any "verify my config" script must read the config file
directly, never via `load_dotenv()`. `dotenv_values()` is the right tool.

### 6. Validate the install in CI

Smoke-test what can be tested without real secrets:

- `pip install -e ".[dev]"` works
- `python -c "from <package> import main"` succeeds
- `pytest` with mock keys passes (10/10 minimum)
- Shell script syntax: `bash -n scripts/setup.sh`
- YAML validity: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"`
- Docker build smoke: `docker build -t test .` (only if Docker is available)

### 7. Cross-check the doc against the actual repo

Read the README from the perspective of someone who has never seen the
project. Check for:

- References to deleted files (grep for old filenames after deleting them)
- Commands that don't work on a fresh clone
- "Setup" instructions that assume knowledge not in the doc
- Missing error messages when something fails

Run `git ls-files` and grep the README for every filename — every one must
still exist.

## Reference: install-readiness bug checklist

When you say "the repo is ready", verify ALL of these:

- [ ] Every file referenced in README/QUICK_START actually exists in the repo
- [ ] Every shell script passes `bash -n`
- [ ] Every Python file passes `python3 -c "import ast; ast.parse(open(f).read())"`
- [ ] Every YAML file passes `python3 -c "import yaml; yaml.safe_load(...)"`
- [ ] `pip install -e .` works in a fresh venv
- [ ] Every entry point in `pyproject.toml [project.scripts]` actually has the
      named function in the referenced module
- [ ] Dockerfile copies EVERY file the container needs (`make`, docs, fixtures)
- [ ] CI secrets scan checks `git ls-files`, not just `grep -r` with extensions
- [ ] CI lint failure does NOT block test execution (separate jobs)
- [ ] `.env` verification script reads .env directly, NOT via `load_dotenv()`
- [ ] `make setup` with no .env gives actionable instructions, not a crash
- [ ] `make verify` with fake keys in .env reports them as invalid (not OK)
- [ ] `make test` passes with mock keys (`test_dg_key`, `test_groq_key`, etc.)
- [ ] 0 secrets in `git diff` (real values, not placeholders)

If any item is unchecked, the repo is NOT ready.

## Pitfalls specific to this pass

- **Skipping the .venv removal** — the install "works" because your leftover
  venv has all the deps already. Fresh user has nothing. Always delete.
- **Trusting `make verify` output without checking which file it read** —
  if the script uses `load_dotenv()` instead of `dotenv_values()`, the user
  can pass verification with a broken `.env` as long as their shell has keys.
- **Confusing "tests pass" with "install works"** — tests run in a venv you
  built. Install is about getting to that venv from zero.
- **"I'll add the missing entry-point later"** — if `pyproject.toml` says
  `package = "module:main"` but `main` doesn't exist, `pip install -e .` fails.
  Don't ship a broken entry-point even if the script doesn't use it today.
- **Declaring "100% ready" after one round** — that's the signal to start
  this pass, not to stop. The user has explicitly pushed back on premature
  confidence claims.