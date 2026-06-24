# Agent Host Layout — Server ↔ Laptop machine map (generic)

Load this BEFORE any file op on a path that wasn't written in the current session. The agent and the user typically have two machines; paths and SSH targets are NOT interchangeable.

<references>
@../SKILL.md (Rule 2 — Know which machine you're on)
@../user-defaults.md (the Three Rules, Rule 2)
</references>

---

## The two machines

| Machine | Role | User | Path prefix | Reachable from here? |
|---------|------|------|-------------|---------------------|
| **Agent server** | Where the agent runs | root (Linux) | `/root/...`, `/tmp/...`, `/home/...` | ✅ Always (you are here) |
| **User's laptop** | Daily driver (Windows or Mac) | the user | `C:\Users\<username>\...` (Windows) or `/Users/<username>/...` (Mac) | ⚠️ Only if reachable via Tailscale / SSH |

**The default for most builds is the agent server.** The laptop only matters when:
- The user is running a tool locally (e.g. `npm run dev` on their laptop)
- The repo lives on the laptop (not the server)
- A file is on the laptop and the user pasted it for context

---

## How to detect which machine you're on

```bash
hostname              # e.g. "laptop" or "<agent-vm-hostname>" or "macbook.local"
uname -s              # Linux / Darwin
pwd                   # current working directory
tailscale status      # who is online
```

If `uname -s` is `Linux` and `hostname` looks like `vmi*` or `ip-*` → server.
If `uname -s` is `Darwin` or `Windows` → laptop.
If unsure → ask the user.

---

## The path-prefix rule

| Path starts with | Machine | Touch from here? |
|------------------|---------|------------------|
| `/root/`, `/tmp/`, `/home/`, `/var/` | Server | ✅ Yes |
| `~/projects/...`, `~/.config/...` | Server (your own home) | ✅ Yes |
| `C:\`, `C:/`, `/c/`, `D:\` (Windows) | Laptop | ❌ No — user must run it |
| `/Users/<name>/...` (Mac) | Laptop | ❌ No — user must run it |
| `/mnt/`, `/Volumes/` | Mounted drive | ⚠️ Check if mounted from laptop |

**If a path is on the laptop and the laptop is online via Tailscale**, you CAN access it via SSH — but only after explicit user approval.

---

## When in doubt

Three escape hatches:

1. **Ask the user.** One sentence: "Is this path on the server (where I run) or on your laptop?"
2. **Use `tailscale status`.** If the laptop hostname shows "online", SSH is possible.
3. **Default to server.** If you don't know, assume server. The server is your own home — safe to touch.

---

## Example — typical multi-machine build

```text
Server (where you run):
  ~/.config/hermes/skills/software-development/build-product/SKILL.md
  ~/projects/workspace/MEMORY.md (the user's shared workspace)
  ~/.config/<service>/<key-name> (sensitive keys, chmod 600)

User's laptop (via Tailscale):
  C:\Users\<username>\OneDrive\Desktop\projects\<my-app>\ (a repo they're building)
  C:\Users\<username>\.ssh\id_ed25519 (their SSH key)

Bridge (HTTP, if the user has one):
  http://<agent-vm-ip>:<bridge-port> (a tunneled endpoint for the agent to call home)
```

**The user's project repos can live on either machine.** The default convention is:
- Personal / local dev → laptop
- Server-deployed / long-running → server

**Always ask which machine before any path op outside `/root/` or `~/`.**
