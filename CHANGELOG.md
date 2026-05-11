# Changelog

All notable changes to this persona pack are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-11

Initial extraction from `nexo-rs` (`lordmacu/nexo-rs`) per the
2026-05-11 Cody mapping deep-dive audit. The persona shipped
in-tree under `nexo-rs/proyecto/config/agents.d/cody.yaml` from
2026-04 onward; this 0.1.0 cuts it to a sibling repo so other
operators can install Cody without forking the framework.

### Added

- `persona.toml` v1 manifest (id, version, min_nexo_version,
  requires.plugins, requires.features, requires.env_vars,
  contributes.{agent_configs, plugin_configs_partial,
  secrets_templates, workspace_seed}).
- `install.sh` idempotent bash installer with flags
  `--dry-run` / `--reinstall` / `--config-dir DIR` / `--help`.
  Pre-checks `nexo` ≥ 0.1.6, `git`, bash 4+. Exit codes per
  spec: 0 ok / 1 pre-check / 2 conflict / 3 telegram merge /
  4 secrets write / 5 workspace write.
- `agents.d/cody.yaml` (391 LOC) — the Cody agent config + 332
  LOC system prompt with HARD RULES for tool routing, dispatch
  surface use, AUTO-BEHAVIOR after `set_active_workspace`, etc.
- `plugins/telegram.partial.yaml` — `cody_nexo_bot` instance
  block restricted to `allow_agents: [cody]`.
- `secrets/cody_nexo_bot_telegram_token.txt.template` —
  placeholder with inline operator instructions.
- `data/workspace/cody/` starter — Phase 1 skeleton in `PHASES.md`,
  empty headers in `FOLLOWUPS.md` + `DREAMS.md`, README explaining
  the workspace concept.
- `README.md` setup guide + troubleshooting + uninstall +
  upgrade flow.
- `LICENSE` (MIT).

### Compatibility

- Requires nexo-rs **≥ 0.1.6** (Phase 90 audit fixes — Cody
  references `add_hook` / `remove_hook` / `program_phase_chain`
  / `program_phase_parallel` handlers shipped in 0.1.6).
- Requires `telegram` and `whatsapp` plugins (operator installs
  separately; the pack does NOT auto-install plugins).
- Requires `bash` ≥ 4 (macOS default 3.2 unsupported; install
  via `brew install bash`).

### Notes

- The 5 framework deudas surfaced by the same audit shipped
  in nexo-rs commit `aacc337` (cody-deudas-2026-05-11 branch)
  before this extraction. This persona pack assumes those fixes
  are present in the daemon.
- Per-goal worktree isolation (nexo-rs Phase 67.6) keeps the
  daemon's source safe even when Cody dispatches against
  itself in dev mode (`NEXO_DISALLOW_SELF_MODIFY` unset).
