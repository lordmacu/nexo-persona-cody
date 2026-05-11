# Cody workspace

This directory is the **active workspace** Cody operates against
when you ask it about phases, follow-ups, or dispatch a goal.

## What lives here

- `PHASES.md` — your project's roadmap. Cody reads it via the
  `project_phases_list` and `project_status` tools. Sub-phase
  syntax: `#### <id> — <title>   <status-marker>` where the
  marker is `⬜` (pending), `🔄` (in progress), or `✅` (done).
- `FOLLOWUPS.md` — your active technical backlog. Cody reads
  individual entries via `followup_detail code=<X>`.
- `DREAMS.md` — auto-generated dream consolidations land here
  (24 h interval per `cody.yaml::dreaming.interval_secs`).
- `.git/` (created by `init_project`) — Cody's per-goal worktrees
  branch off this repo so each Claude Code dispatch runs in
  isolation. The daemon's `nexo-driver` subsystem manages the
  branches.

## How to point Cody at a different workspace

The daemon picks **one** active workspace at a time. To switch:

```
cody> work in /path/to/another-project
```

Cody calls `set_active_workspace path=/path/to/another-project`
under the hood. The path must contain a `PHASES.md` (and ideally
`FOLLOWUPS.md`) at its root.

To create a fresh project from scratch from chat:

```
cody> create folder /tmp/new-project and help me build a web scraper
```

Cody calls `init_project name=new-project description="..." phases=[...]`
which scaffolds `PHASES.md` + `FOLLOWUPS.md` + `git init` and
switches the tracker to it.

## What this starter ships

The included `PHASES.md` is a minimal Phase 1 placeholder. Replace
it with your project's actual phases before asking Cody about
"what's pending?" — otherwise it'll just see the placeholder.

`FOLLOWUPS.md` and `DREAMS.md` ship with headers only.

## Out-of-tree use

Most operators don't run Cody against this in-tree starter forever
— it's a sane default for the first `nexo daemon` boot. You'll
typically `set_active_workspace` to your real project the first
time you chat with Cody.
