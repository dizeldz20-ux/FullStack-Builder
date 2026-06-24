# Merging Project Config Into `~/.hermes/config.yaml`

A `setup.sh` that adds a project's keys to the user's existing Hermes
config is not a "user wins on conflict" problem. The user has whatever
they had — including the wrong defaults. The project has required
values that must land or the agent won't work. A naive merge leaves
the install looking successful while doing nothing.

This document captures the **three-rule merge** pattern and the two
related environment-loading patterns that go with it.

## The three rules

For every top-level key in the project's `config/hermes-config.yaml`:

1. **User wins on conflict** for non-required keys (e.g. `tts.openai.*`,
   `stt.local.*`, `tts.edge.*` — anything the project doesn't need to
   control).
2. **Project wins** for a small whitelist of **required** keys. These
   are the keys the agent needs at specific values to function. Print
   every override as `was 'old' → 'new'` so the user sees what changed.
3. **New keys are added** (e.g. adding a new personality, a new
   `agent.personalities.<name>` block, a new `session_reset.idle_minutes`).

The required-key whitelist for a typical voice-agent project:

```python
RUBY_REQUIRED = {
    "tts": {
        "provider": "elevenlabs",
        "elevenlabs": {
            "voice_id": "<voice-id>",   # custom Hebrew voice
            "model_id": "eleven_v3",
        },
    },
    "session_reset": {
        "mode": "idle",
    },
    "agent": {
        "personality": "ruby",
    },
}
```

The merge output must print three lists so the user can audit:

```
added:   tts.output_format, agent.personality, agent.personalities.ruby
kept user's existing: tts.provider, tts.elevenlabs, stt.local
overrode: tts.provider (was 'edge'), tts.elevenlabs.voice_id (was 'pNInz6obpgDQGcFmaJgB'), ...
```

## The merge implementation (Python + PyYAML, no yq)

```python
"""Three-rule merge for ~/.hermes/config.yaml."""

import yaml


# Required keys that the project owns. These win on conflict, with a warning.
RUBY_REQUIRED = {
    "tts": {
        "provider": "elevenlabs",
        "elevenlabs": {
            "voice_id": "<voice-id>",
            "model_id": "eleven_v3",
        },
    },
    "session_reset": {"mode": "idle"},
    "agent": {"personality": "ruby"},
}

# Top-level keys where the project adds but does not own.
RUBY_TOP_KEYS = ["tts", "stt", "approvals", "session_reset"]

# Personalities are merged additively (user's list + project's entries).
RUBY_AGENT_KEYS = ["personality", "personalities"]


def _walk_required(d, prefix=()):
    for k, v in d.items():
        path = prefix + (k,)
        if isinstance(v, dict):
            yield from _walk_required(v, path)
        else:
            yield path, v


def _get_path(d, path):
    cur = d
    for k in path:
        if not isinstance(cur, dict) or k not in cur:
            return None
        cur = cur[k]
    return cur


def _deep_set(d, path, value):
    for k in path[:-1]:
        cur = d.get(k)
        if not isinstance(cur, dict):
            cur = {}
            d[k] = cur
        d = cur
    d[path[-1]] = value


def merge(repo_yaml_path, home_yaml_path):
    repo = yaml.safe_load(open(repo_yaml_path)) or {}
    home = yaml.safe_load(open(home_yaml_path)) or {} if __import__("os").path.exists(home_yaml_path) else {}

    merged = dict(home)
    added, skipped, overridden = [], [], []

    # Rule 1 & 3: shallow merge top-level keys (user wins on conflict, new keys added)
    for key in RUBY_TOP_KEYS:
        if key not in repo:
            continue
        if key not in home:
            merged[key] = repo[key]
            added.append(key)
            continue
        if isinstance(repo[key], dict) and isinstance(home[key], dict):
            before = set(home[key].keys())
            merged[key] = {**repo[key], **home[key]}
            new = set(merged[key].keys()) - before
            if new: added.append(f"{key}.{','.join(sorted(new))}")
            for k in repo[key]:
                if k in home[key] and home[key][k] != repo[key][k]:
                    skipped.append(f"{key}.{k}")

    # Rule 2: project wins on the required whitelist
    for top_key, required_sub in RUBY_REQUIRED.items():
        for sub_path, req_value in _walk_required(required_sub):
            current = _get_path(merged.get(top_key) or {}, sub_path)
            if current is None:
                _deep_set(merged.setdefault(top_key, {}), sub_path, req_value)
                added.append(f"{top_key}." + ".".join(sub_path))
            elif current != req_value:
                _deep_set(merged[top_key], sub_path, req_value)
                overridden.append(f"{top_key}." + ".".join(sub_path) + f"  (was {current!r})")

    # Personalities: additive merge. Never replace the user's existing list.
    if "agent" in repo:
        user_agent = merged.get("agent") or {}
        if not isinstance(user_agent, dict):
            user_agent = {}
        for k in RUBY_AGENT_KEYS:
            if k in (repo["agent"] or {}):
                if k not in user_agent:
                    user_agent[k] = repo["agent"][k]
                    added.append(f"agent.{k}")
                elif k == "personalities" and isinstance(user_agent[k], dict) and isinstance(repo["agent"][k], dict):
                    for pname, pdef in repo["agent"][k].items():
                        if pname not in user_agent[k]:
                            user_agent[k][pname] = pdef
                            added.append(f"agent.personalities.{pname}")
                        else:
                            skipped.append(f"agent.personalities.{pname}")
        merged["agent"] = user_agent

    yaml.safe_dump(merged, open(home_yaml_path, "w"), default_flow_style=False, sort_keys=False, allow_unicode=True)
    return added, skipped, overridden
```

Call from bash with a heredoc:

```bash
python3 - "$REPO/config/hermes-config.yaml" "$HOME/.hermes/config.yaml" <<'PYEOF'
# ... (the merge function above, called as merge(sys.argv[1], sys.argv[2]))
PYEOF
```

## Why Python + PyYAML and not `yq`

`yq` is fine for read-only queries. For merges with custom conflict
rules, `yq`'s semantics diverge:

- `yq merge` is a deep merge — it does not let you express "user wins
  on this key, project wins on that key". You would have to split
  the config into two files and merge them with different `yq` calls.
- `yq -i` is in-place edit, but it does not preserve comments or
  formatting. The user's carefully curated `~/.hermes/config.yaml`
  comes out reordered, key-quoting changed, blank lines lost.
- PyYAML with `default_flow_style=False, sort_keys=False` preserves
  the user's structure: existing keys keep their position, the YAML
  looks the same as the user's input, comments are dropped (a
  limitation) but the rest is intact.

If preserving user comments matters, switch to `ruamel.yaml` (drop-in
PyYAML replacement) — it preserves comments, key order, and quoting.

## The environment loading companion: gateway env inheritance

The merge above writes config. The smoke test (or any script the user
runs) needs to load the right env vars. The naive approach is to
source `~/.hermes/.env` and stop. That misses keys that the gateway
process has in its environment but the file doesn't.

The robust loader (in bash, callable from `smoke-test.sh`):

```bash
load_env() {
    # 1. ~/.hermes/.env (Hermes-canonical)
    [ -f "$HERMES_HOME/.env" ] && { set -a; . "$HERMES_HOME/.env"; set +a; }

    # 2. /root/.tokens (personal-use shortcut)
    [ -f /root/.tokens ] && { set -a; . /root/.tokens; set +a; }

    # 3. Inherit from gateway process env if a required key is still missing
    for var in ELEVENLABS_API_KEY MINIMAX_API_KEY OPENROUTER_API_KEY GROQ_API_KEY; do
        if [ -z "${!var:-}" ]; then
            GW_PID=$(pgrep -f "hermes-agent/venv/bin/hermes gateway" | head -1)
            if [ -n "$GW_PID" ] && [ -r "/proc/$GW_PID/environ" ]; then
                val=$(tr '\0' '\n' < "/proc/$GW_PID/environ" | grep -E "^${var}=" | head -1 | cut -d= -f2-)
                if [ -n "$val" ]; then
                    export "$var=$val"
                    echo "  inherited $var from gateway process env (PID $GW_PID)"
                fi
            fi
        fi
    done
}
```

The third branch is what makes smoke tests work in environments where
the gateway is started as a service with `Environment=` directives
but `~/.hermes/.env` is stale or incomplete. Without it, the smoke
test reports `ELEVENLABS_API_KEY: MISSING` even though the gateway is
using the key successfully (you can confirm via `hermes status`).

The pattern is also useful for any time you need a credential that's
in a long-running process but not in any file. The two-step
diagnostic is:

1. `hermes status` shows the key as `✓` → the key is in some process
   env. Find the PID with `pgrep` and read `/proc/<PID>/environ`.
2. If the same key is `MISSING` in a fresh shell → your script is
   only loading from the file. Add the third branch.

## What to NOT do in the merge

- **Do not blindly write `tts.provider: elevenlabs` on every install.**
  The user may have a working OpenAI TTS setup they want to keep.
  The required whitelist should be limited to keys the project
  cannot run without. If the project can degrade gracefully to a
  different provider, it shouldn't be on the whitelist.
- **Do not preserve comments** with `ruamel.yaml` without testing the
  round-trip. `ruamel.yaml` preserves comments in most cases, but
  not all (e.g. key reordering, multi-line scalar formatting). If
  the user has hand-edited comments, back up their file first
  regardless.
- **Do not run the merge in a `set -e` script before testing the
  Python.** A syntax error in the heredoc kills the install mid-way,
  after the backup, with the user's config still pointing at the
  old values. Either run `python3 -c "import yaml; print('ok')"`
  first, or use a `python3` shebang script and check the exit code
  before declaring success.

## Verifying the merge

After the merge, run a `verify-<project>.sh` that:

1. Reads the merged `~/.hermes/config.yaml` with Python.
2. Asserts each required key is at the expected value.
3. Asserts each non-required key the project cares about is **not**
   set to a value that would break the agent (e.g. `tts.provider`
   is `elevenlabs`, not `edge`).
4. Asserts the personality file is at the expected path with sane
   permissions (644 or 600, not world-writable).

A passing verify script is the proof that the merge did what it
claimed. The user's `hermes status` will not catch most merge bugs
because Hermes is permissive about missing keys and will fall back
to provider defaults.
