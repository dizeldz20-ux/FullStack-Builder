# Cron Toolset Failure — Diagnosis & Repair

When a Hermes scheduled cron job that worked yesterday
silently fails today with "I do not have access to a web
search tool" or `[SILENT]`, the first place to look is the
`enabled_toolsets` field on the job. This is a
**recurring class of failure** that surfaces as
"my AI-news cron / my daily-research cron / my weekly-summary
cron stopped working without any error in the log." Captured
June 2026 on the `daily-ai-news-telegram-hebrew` cron
(had been working 2026-06-10 and 2026-06-11, failed
2026-06-12 08:10).

## Why it fails silently

The cron delivery status reads `ok` even when the
agent's actual answer is "I have no tools." This is by
design — the cron runner checks whether the *runner*
delivered the response, not whether the response was
substantive. So:

- `last_status: ok` ≠ the agent did the work
- `last_delivery_error: null` ≠ the agent had the right tools
- A `[SILENT]` response is delivered as `ok` (no message sent)

You only find out something's wrong from the **delivered
message itself** ("no web access") or from the
**per-run output file** in
`~/.hermes/cron/output/<job_id>/<timestamp>.md`.

## The 4-question diagnostic

Run these in order, in a single shell session:

### 1. What's the current `enabled_toolsets`?

```bash
python3 -c "
import json
with open('/root/.hermes/cron/jobs.json') as f: d = json.load(f)
for j in d.get('jobs', []):
    if j.get('name') == '<your-job-name>':
        print('enabled_toolsets:', j.get('enabled_toolsets'))
        print('last_run_at:', j.get('last_run_at'))
        print('last_status:', j.get('last_status'))
        print('last_error:', j.get('last_error'))
        print('next_run_at:', j.get('next_run_at'))
"
```

The minimal set for any "search the web and report" cron:

```json
"enabled_toolsets": ["web", "terminal", "file"]
```

(`session_search` is optional — only needed if the cron
references past sessions.)

**Why `terminal` is mandatory alongside `web`:** the
`web-search` skill at
`~/.hermes/skills/web-search/scripts/search.py` is a
Python script. The agent invokes it via the `terminal`
tool, not via a direct function call. Without
`terminal` in the toolset, the skill is registered but
unreachable. The `web` toolset alone is not enough.

### 2. What tools did the agent actually have?

The per-run output file
(`~/.hermes/cron/output/<job_id>/<timestamp>.md`) may
contain a `## Diagnostic note` section if the agent was
self-aware enough to write one. Look for a line like
"the agent function definitions exposed in the cron
runtime are only: `read_file`, `search_files`,
`write_file`, `patch`". That list is the actual
toolset — if `web_search` / `terminal` / `execute_code`
isn't there, the wiring is broken even if the config
declares them.

### 3. Did a previous successful run have more tools?

Compare today's `*.md` output to the previous successful
day. If yesterday's transcript shows
`web_search('AI news today')` calls and today's doesn't,
the toolset is the diff.

### 4. Is the API key in the env the service sees?

The same `EnvironmentFile=/root/.hermes/.env` trap
documented in the `plan` skill's
`cross-platform-voice-install-on-linux-vps.md` reference
applies here: the key has to be in the env the
**hermes gateway** sees (which runs the cron), not just
in the shell that started the gateway.

```bash
# Verify the env the running gateway sees has the key
sudo cat /proc/$(pgrep -f "hermes.*gateway")/environ | tr '\0' '\n' | grep -E "^(GROQ|ELEVEN|API|TELEGRAM)_"
# (or whatever key the cron needs)
```

## The fix

Update the job's toolsets via the `cronjob` action:

```bash
# 1. Update with the minimum needed set
hermes cron update <job_id> --toolsets web,terminal,file

# 2. Or via the skill action
# (skill equivalent: cronjob(action='update', job_id='...',
#   enabled_toolsets=['web', 'terminal', 'file']))

# 3. Force a re-run
hermes cron run <job_id>
```

If `hermes cron run` doesn't actually trigger (the
`action=run` endpoint sets `next_run_at` to "+1 minute"
but may not force execution immediately), use the
**back-dating trick**: open `~/.hermes/cron/jobs.json`,
find the job, and set `next_run_at` to ~1 hour in the
past. The scheduler's next tick will treat the job as
overdue and run it.

```python
import json
from datetime import datetime, timezone, timedelta

tz = timezone(timedelta(hours=2))   # match the cron user's TZ
back = (datetime.now(tz) - timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S+02:00')

with open('/root/.hermes/cron/jobs.json') as f: d = json.load(f)
for j in d['jobs']:
    if j.get('name') == '<your-job-name>':
        j['next_run_at'] = back
        j['repeat']['completed'] = 0   # reset counter
        with open('/root/.hermes/cron/jobs.json', 'w') as f: json.dump(d, f, indent=2)
        print(f'forced next_run_at to {back}')
```

Within 30-60 seconds the scheduler ticks, picks up the
overdue job, and runs it. Watch
`~/.hermes/cron/output/<job_id>/` for the new file.

## The self-diagnostic NOTE pattern

Worth praising: the agent that failed the Jarvis
news-cron on 2026-06-12 left a **diagnostic note** to
disk (separate from the user-facing response) explaining
what tools it had, what it had on previous successful
runs, and 3 candidate fixes. The user-facing response
was `[SILENT]` (per spec — "don't spam the user") and
the actual diagnosis was in
`~/.hermes/cron/output/<job_id>/<timestamp>-NOTE.md`.

To make this pattern the default for cron prompts,
add this clause to the job's prompt:

```text
Diagnostic policy: if a run fails because the tools
available to you are insufficient for the task (e.g.
"no web_search", "no terminal"), write a `## Diagnostic
note` section in your response documenting (a) what
tools you had, (b) what tools you needed, (c) 2-3
candidate fixes. Then either deliver the fallback
content (per spec) or `[SILENT]`. This note is for the
operator's next maintenance session, not for the
delivery channel.
```

The next time a cron silently degrades, the operator
opens the per-run file and gets the diagnosis without
having to guess.

## The minimum-viable toolsets cheat-sheet

| Cron job kind | Minimum toolsets |
|---|---|
| Web search + report (AI news, daily briefings) | `web`, `terminal`, `file` |
| Session summary (recall past agent sessions) | `session_search`, `file` |
| File maintenance / cleanup | `file`, `terminal` |
| Memory distillation (read sessions → write notes) | `file`, `session_search`, `skills`, `memory` |
| Plugin-driven (e.g. HUD display) | `web` (or whatever the plugin needs), `file` |

When in doubt, start with `["web", "terminal", "file",
"session_search"]` — covers 90% of cron use-cases and
the redundancy is cheap (each toolset is a few hundred
tokens of schema).

## What this does NOT cover

- The agent's **model** choice — some models decline
  tool calls more than others. If the tools are present
  and the agent still says "I can't," the issue is
  the model, not the toolset. Check the job's `model:`
  field.
- The **delivery channel** failure (Telegram bot
  down, etc.) — separate skill,
  `gmail` / `telegram` / etc.
- The **schedule** itself — if the cron isn't firing
  at the expected time, check `next_run_at` and
  `state` fields. `state: paused` is the most common
  silent cause.
