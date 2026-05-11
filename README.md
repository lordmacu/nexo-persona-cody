# nexo-persona-cody

> **Cody** — programmer pair persona for [nexo-rs](https://github.com/lordmacu/nexo-rs).
> Drives Claude Code goals from chat. Runs on Telegram + WhatsApp.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![nexo-rs](https://img.shields.io/badge/nexo--rs-%E2%89%A50.1.6-orange.svg)](https://github.com/lordmacu/nexo-rs)

A persona pack for the [nexo-rs](https://github.com/lordmacu/nexo-rs)
agent framework. Bundles the agent config + system prompt + Telegram
bot binding + workspace seed for **Cody**, an opinionated programming
pair that:

- Reads your project's `PHASES.md` + `FOLLOWUPS.md` over chat.
- Dispatches Claude Code goals against your repo (one phase at a time
  or as a chain), each in an isolated git worktree.
- Auto-attaches an audit-before-done hook so it scans the diff for
  bugs / incomplete follow-ups / missing tests before declaring a
  phase shipped.
- Speaks plain English. Disagrees when it disagrees. Doesn't pad.

## Install

Two install modes coexist:

### A) `nexo persona install` (canonical, future v0.2.x)

Deferred follow-up — to land in v0.2.x as a mirror of the existing
`nexo plugin install <owner>/<repo>` flow (Phase 31.1.c of nexo-rs).
Will be:

```bash
nexo persona install lordmacu/nexo-persona-cody[@v0.2.0]
```

Same UX as plugins: GitHub Releases tarball download + sha256 +
optional cosign verify + extract to the daemon's persona discovery
path + boot-time auto-discovery.

### B) `./install.sh` (today + airgapped / dev-loop)

```bash
git clone https://github.com/lordmacu/nexo-persona-cody ~/chat/nexo-persona-cody
cd ~/chat/nexo-persona-cody
./install.sh
```

Available NOW (v0.1.x). The script:

1. Pre-checks `nexo` ≥ 0.1.6 + `git` + `bash` 4+.
2. Copies `agents.d/cody.yaml` into your daemon's config dir.
3. Merges the `cody_nexo_bot` block into `plugins/telegram.yaml`
   (creates the file if absent; idempotent if already present).
4. Writes a Telegram bot token template into `secrets/`.
5. Seeds a starter workspace (Phase 1 placeholder) at
   `data/workspace/cody/`.

Default config dir is `~/.nexo`. Override with
`./install.sh --config-dir /your/path`.

The shell script will keep working alongside the CLI flow once
v0.2.x ships — useful for airgapped hosts with no GitHub access,
CI pipelines that don't want to invoke `nexo` to avoid daemon
state, and inner-loop development against an unreleased pack.

## Setup after install

1. **Telegram bot token**

   Get one from [@BotFather](https://t.me/BotFather) on Telegram:
   DM `/newbot`, follow prompts. Then:

   ```bash
   $EDITOR ~/.nexo/secrets/cody_nexo_bot_telegram_token.txt
   ```

   Replace the placeholder line with the token.

2. **Anthropic credentials**

   Either an API key:

   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...
   ```

   Or use the OAuth subscription flow:

   ```bash
   nexo llm-keys oauth anthropic
   ```

3. **Start the daemon**

   ```bash
   nexo daemon
   ```

4. **Pair Cody on Telegram**

   DM your bot any message. The daemon will respond with a pairing
   challenge. Approve it (the protocol details are documented in
   the [nexo-rs pairing docs](https://github.com/lordmacu/nexo-rs/blob/main/docs/src/ops/pairing.md)).

5. **Chat**

   ```
   you> what phases are pending?
   cody> [reads PHASES.md, lists pending sub-phases]

   you> dispatch 1.1
   cody> Dispatched goal abc-123 for phase 1.1. I'll ping when done.

   you> work in /home/me/another-project
   cody> Switched. 3 pending phases there: …
   ```

## Configuration

The persona config (`agents.d/cody.yaml`) ships ready-to-run with
sensible defaults:

| Field | Default | Why |
|---|---|---|
| `model.provider` | `anthropic` | Cody's brain |
| `model.model` | `claude-sonnet-4-6` | Best price/quality for code |
| `dispatch_policy.mode` (per-binding) | `full` | Lets Cody dispatch Claude Code goals |
| `heartbeat.enabled` | `true` | Wakes Cody on a schedule for due reminders |
| `dreaming.enabled` + `interval_secs: 86400` | on | Daily session-wide consolidation |
| `pairing_policy.auto_challenge` | `true` | New chats get a pairing challenge |
| `language` | `en` | English only (system prompt is English) |

Edit `~/.nexo/agents.d/cody.yaml` to tune.

## Workspace concept

Cody operates against ONE active workspace at a time. The starter
that ships at `data/workspace/cody/` is a placeholder — most operators
switch to their real project on first chat:

```
you> work in /home/me/my-real-project
```

The path needs a `PHASES.md` at its root. To create one from chat:

```
you> create folder /tmp/scraper and help me build a web scraper
```

Cody calls `init_project` under the hood (scaffolds `PHASES.md` +
`FOLLOWUPS.md` + `git init`).

## Production safety

By default Cody can dispatch goals against the **same source the
daemon is running from** ("self-modify"). This is the canonical
dev usecase — Cody helping finish nexo-rs's own roadmap. Per-goal
git worktree isolation (Phase 67.6 of nexo-rs) keeps the live
source safe.

For production / frozen-binary deploys, opt out:

```bash
export NEXO_DISALLOW_SELF_MODIFY=1
```

Cody will refuse self-modify dispatches with a clear error.

## Required nexo-rs version

This persona requires nexo-rs **≥ 0.1.6** (the version that
ships the Phase 90 audit fixes — `add_hook` / `remove_hook` /
`program_phase_chain` / `program_phase_parallel` handlers + the
shared `LlmRegistry` that PreflightHandler reads).

`./install.sh` enforces this at install time.

## Troubleshooting

### "AgentContext.dispatch is not set"

The in-process driver subsystem didn't boot. Check:
- Is `dispatch_policy.mode: full` set on at least one agent? (it is
  in the shipped `cody.yaml`, but check you didn't remove it)
- Is `config/driver/claude.yaml` present in your daemon's config?
  (nexo-rs ships a default; the wizard should have created one)
- Is the `claude` CLI on PATH? Run `which claude` to verify.

### Bot doesn't respond

Tail the daemon log:

```bash
NEXO_DAEMON_LOG=info nexo daemon
```

Look for `telegram` lines around the time you sent a message. Common
causes:
- Wrong token (check `secrets/cody_nexo_bot_telegram_token.txt`)
- Bot blocked by you (unblock via Telegram settings)
- Daemon's `polling.enabled: true` not set (check `~/.nexo/plugins/telegram.yaml`
  has the `cody_nexo_bot` block intact)

### "self-modify is disabled by NEXO_DISALLOW_SELF_MODIFY=1"

You're trying to dispatch a goal against the daemon's own source
but `NEXO_DISALLOW_SELF_MODIFY=1` is set. Either:

```bash
unset NEXO_DISALLOW_SELF_MODIFY
nexo daemon  # restart
```

Or switch Cody to a different workspace via chat:

```
you> work in /tmp/sandbox
```

### Telegram block conflict on install

If `install.sh` reports `cody_nexo_bot block already present, skipping
merge` but the existing block is stale (e.g. references an old token
file), edit `~/.nexo/plugins/telegram.yaml` manually and replace the
`- instance: cody_nexo_bot` block with the contents of
`plugins/telegram.partial.yaml`.

## Upgrade

To get a newer version of the persona:

```bash
cd ~/chat/nexo-persona-cody
git pull
./install.sh --reinstall
```

`--reinstall` overwrites the bundled files (cody.yaml, telegram block,
workspace seed README/PHASES skeleton/FOLLOWUPS/DREAMS) but **never**
overwrites your populated `secrets/cody_nexo_bot_telegram_token.txt`.

## Uninstall

The persona pack writes only into your config dir. To remove:

```bash
rm ~/.nexo/agents.d/cody.yaml
# Edit ~/.nexo/plugins/telegram.yaml manually to remove the
# `- instance: cody_nexo_bot` block.
rm ~/.nexo/secrets/cody_nexo_bot_telegram_token.txt
rm -rf ~/.nexo/data/workspace/cody/
```

Restart the daemon afterwards.

## Repo layout

```
nexo-persona-cody/
├── persona.toml             # v1 manifest (id, version, requires, contributes)
├── install.sh               # idempotent installer (--dry-run / --reinstall)
├── agents.d/
│   └── cody.yaml            # the agent config + system prompt
├── plugins/
│   └── telegram.partial.yaml
├── secrets/
│   └── cody_nexo_bot_telegram_token.txt.template
└── data/
    └── workspace/cody/      # starter PHASES/FOLLOWUPS/DREAMS skeleton
```

## License

MIT — see [LICENSE](LICENSE).

## Related

- [lordmacu/nexo-rs](https://github.com/lordmacu/nexo-rs) — the agent framework Cody runs on
- [lordmacu/nexo-rs-plugin-admin](https://github.com/lordmacu/nexo-rs-plugin-admin) — admin UI plugin
- [lordmacu/nexo-rs-plugin-telegram](https://github.com/lordmacu/nexo-rs-plugin-telegram) — Telegram channel plugin
- [lordmacu/nexo-rs-plugin-whatsapp](https://github.com/lordmacu/nexo-rs-plugin-whatsapp) — WhatsApp channel plugin
