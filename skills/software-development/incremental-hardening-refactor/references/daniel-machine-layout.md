# the user's Machine Layout — Operational Reference

**Source of truth**: `[hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md`. This file is the *operational* view — what to do, when, and how. The Vault file is the canonical inventory.

Last validated: 2026-06-24. If anything in this file conflicts with the Vault file, the Vault file wins (update both).

## § TL;DR

Two machines on Tailscale. You (Hermes) run on the **server**. the user uses the **laptop**. The laptop Hermes is a thin client that talks to a bridge on the server. SSH from server to laptop works via a pre-installed key — **permanent, no re-setup**.

| | Server (you) | Laptop (the user) |
|---|---|---|
| Hostname | `[vm-hostname]` | `laptop` |
| Tailscale IP | `[agent-vm-ip]` | `[agent-vm-ip]` |
| Magic DNS | (none) | `laptop.tailce2378.ts.net` |
| OS | Linux | Windows |
| User | `root` | `User` (username as it appears on the machine) |
| Path prefix | `/root/...` | `C:\...` or `C:/...` |
| Hermes | runs here, port `8642` | CLI client, mode=`bridge` |
| Bridge target | listens `:27873` | connects to `http://[agent-vm-ip]:27873` |

## § The Three Rules (apply to ANY work touching files or infrastructure)

### Rule 1: Search before you ask

Don't ask "where is X?" until you have actually searched:

```bash
# 1. Check the Vault machine-layout doc first
test -f [hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md && echo "vault exists"

# 2. Check Ruby's MEMORY.md
grep -i "laptop\|bridge\|ssh\|tailscale" [vault-workspace]/MEMORY.md

# 3. Check the canonical laptop config (if it exists locally)
test -f [vault-workspace]/[your-product-repo]/[your-product].config.json && cat [vault-workspace]/[your-product-repo]/[your-product].config.json

# 4. Check tailscale status to see what's actually reachable
tailscale status
```

Only after all four return nothing should you ask the user. When you do ask, say what you searched — the user will move faster.

### Rule 2: Know which machine you're on BEFORE touching a file

```bash
# Quick "where am I" check (run this FIRST in any cross-machine task)
echo "hostname=$(hostname)"
echo "tty=$(tty 2>/dev/null || echo 'no-tty')"
echo "cwd=$(pwd)"
tailscale status | head -3
```

Path prefix classification:

| Path starts with | Machine | Action |
|---|---|---|
| `/root/`, `/tmp/`, `/home/`, `/var/` | Server | Touch freely |
| `C:\`, `C:/`, `/c/`, `D:\` | Laptop | **Do not touch from here** — surface to the user or SSH first |
| Anything else | Unknown | Run the where-am-I check above before touching |

**Why this rule exists**: in the 2026-06-24 session, Hermes opened a Windows path with `read_file` without thinking — got "Path not found", retried, retried, only THEN ran `hostname` and `tailscale status`. The laptop was offline. The file was never going to load. Three turns wasted on a check that should have been turn zero.

### Rule 3: Confirm understanding for non-trivial work

For any task beyond a single grep/read/one-liner, restate what you understood in ONE sentence and ask the user:

> "If I understand correctly: you want [X]. Right?"

Trivial work (skip this rule):
- Single grep / single read / single bash one-liner
- Fixing a typo
- Answering a direct question
- Following an explicit numbered instruction

Non-trivial work (use this rule):
- Anything involving multiple files
- Anything that spawns subagents
- Anything that touches infrastructure / config / secrets
- Anything where you are about to commit or push
- Anything where "what to do" is ambiguous between two reasonable interpretations

## § SSH from server to laptop

```bash
# The one-liner that works. PRE-INSTALLED key, no setup needed.
ssh -i /root/.ssh/id_ed25519 User@[agent-vm-ip] "echo connected"
```

If it fails, the laptop is probably offline. Check first:

```bash
tailscale status | grep -E "[agent-vm-ip]|laptop"
# Look for "offline" or "last seen" — if offline, surface to the user immediately.
```

## § Bridge to laptop's Hermes

The laptop doesn't run Hermes locally. Its Hermes CLI is a thin client that POSTs to a Python bridge on the server.

| Aspect | Value |
|---|---|
| Bridge URL | `http://[agent-vm-ip]:27873` |
| Bridge token | **Always `jarvis-fc5d63`** — stable, do not regenerate |
| Token location (server) | `/root/.[your-product]/secrets.json` key `HERMES_BRIDGE_TOKEN` |
| Token location (laptop) | `HERMES_BRIDGE_TOKEN` env var |
| Bridge process | `python3` listener — `netstat -tlnp \| grep 27873` to verify |

When a task involves the laptop's Hermes (e.g. "run X on my laptop"), you're not actually SSHing into the laptop — you're calling the bridge from the server. The bridge handles the laptop-side Hermes invocation.

## § Common mistakes from this skill's history

- **Asking "what's your username?" when MEMORY.md already says `User`** — search first.
- **Trying to `read_file` a Windows path on the server** — wrong scope, use SSH or surface to the user.
- **Retrying SSH three times when `tailscale status` shows the laptop offline** — surface once, don't loop.
- **Writing a script "for the user to run" when the user has opted out** — see the "תעשה את זה אתה" rule in `incremental-hardening-refactor` main SKILL.md.
- **Ignoring the `HERMES_BRIDGE_TOKEN` "stable" rule and regenerating it** — breaks the laptop-side Hermes until the user manually updates the env var.

## § Verification recipe (when re-validating this reference)

```bash
# 1. Vault doc exists
test -f [hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md && echo "vault: OK"

# 2. Tailscale reachable
tailscale status | head -3

# 3. Bridge listening
netstat -tlnp 2>/dev/null | grep 27873 || ss -tlnp | grep 27873

# 4. SSH key exists
test -f /root/.ssh/id_ed25519 && echo "key: OK"

# 5. Laptop reachable (will fail if offline — that's OK, surface it)
ssh -o ConnectTimeout=5 -i /root/.ssh/id_ed25519 User@[agent-vm-ip] "echo connected" 2>&1 | head -3

# 6. Token file exists (read keys only)
python3 -c "import json; print('keys:', list(json.load(open('/root/.[your-product]/secrets.json')).keys()))" 2>/dev/null
```

If any check fails, **fix the Vault file first**, then update this reference.

## § Cross-references

- `incremental-hardening-refactor` SKILL.md, "⛔ The Three Rules for any cross-machine work" section — the canonical version of these rules
- `incremental-hardening-refactor` SKILL.md, "Local-host vs SSH-target tool scoping" — the tool-level scope pitfalls
- `incremental-hardening-refactor` SKILL.md, "Don't moralize, just do the work" — anti-pattern for stalling on safety lectures
- `[hermes-config-dir]/memories/Hermes/Brain/your-name-machine-layout.md` — the canonical inventory
- `[vault-workspace]/MEMORY.md` — Ruby's curated memory (sync target)
- `[vault-workspace]/[your-product-repo]/[your-product].config.json` — laptop-side canonical config