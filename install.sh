#!/usr/bin/env bash
# nexo-persona-cody — install script (v0.1.0)
#
# Idempotent installer for the Cody persona pack. Copies the
# bundled artifacts (agents.d/cody.yaml, plugins/telegram.partial.yaml,
# secrets templates, workspace seed) into the operator's nexo-rs
# config directory.
#
# Usage:
#   ./install.sh                    # standard install (refuses on conflict)
#   ./install.sh --reinstall        # overwrite existing files
#   ./install.sh --dry-run          # print planned actions, change nothing
#   ./install.sh --config-dir DIR   # override default config dir (~/.nexo)
#   ./install.sh --help             # print usage
#
# Exit codes (per spec):
#   0  install successful (or dry-run completed)
#   1  pre-checks failed
#   2  file conflict without --reinstall
#   3  telegram.yaml merge failed
#   4  secrets template write failed (permissions)
#   5  workspace seed write failed (permissions)

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_CONFIG_DIR="$HOME/.nexo"
MIN_NEXO_VERSION="0.1.6"

# ── Color helpers (only when stdout is a tty) ──────────────────────────

if [[ -t 1 ]]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_DIM=""; C_RESET=""
fi

ok()   { printf '%s[OK]%s %s\n'      "$C_GREEN"  "$C_RESET" "$*"; }
info() { printf '%s[INFO]%s %s\n'    "$C_CYAN"   "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n'    "$C_YELLOW" "$C_RESET" "$*" >&2; }
fail() { printf '%s[FAIL]%s %s\n'    "$C_RED"    "$C_RESET" "$*" >&2; }
dry()  { printf '%s[DRY]%s %s\n'     "$C_DIM"    "$C_RESET" "$*"; }
keep() { printf '%s[KEEP]%s %s\n'    "$C_DIM"    "$C_RESET" "$*"; }
inst() { printf '%s[INSTALL]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }

# ── Args ───────────────────────────────────────────────────────────────

CONFIG_DIR="$DEFAULT_CONFIG_DIR"
DRY_RUN=0
REINSTALL=0

usage() {
    cat <<EOF
nexo-persona-cody installer (v0.1.0)

Usage: $0 [options]

Options:
  --config-dir DIR   Install into DIR instead of ~/.nexo
  --dry-run          Print planned actions without touching disk
  --reinstall        Overwrite existing files (operator-confirmed upgrade)
  --help             Show this message

Exit codes: 0 ok | 1 pre-check fail | 2 conflict | 3 telegram merge fail | 4 secrets write fail | 5 workspace write fail

Repo:    https://github.com/lordmacu/persona-cody
nexo-rs: https://github.com/lordmacu/nexo-rs
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir)
            [[ $# -ge 2 ]] || { fail "--config-dir needs an argument"; exit 1; }
            CONFIG_DIR="$2"
            shift 2
            ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --reinstall) REINSTALL=1; shift ;;
        --help|-h)   usage; exit 0 ;;
        *)           fail "unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── Pre-checks ─────────────────────────────────────────────────────────

# bash 4+
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    fail "bash 4+ required (yours: ${BASH_VERSION})."
    fail "On macOS the default /bin/bash is 3.2. Install bash 5: brew install bash, then re-run."
    exit 1
fi

# git on PATH
if ! command -v git >/dev/null 2>&1; then
    fail "git not on PATH. Install git first."
    exit 1
fi

# nexo on PATH
if ! command -v nexo >/dev/null 2>&1; then
    fail "nexo not on PATH. Install nexo-rs ≥ ${MIN_NEXO_VERSION} first:"
    fail "  cargo install nexo-rs"
    fail "  OR follow https://github.com/lordmacu/nexo-rs#install"
    exit 1
fi

# nexo version >= MIN_NEXO_VERSION (semver-ish compare via shell)
NEXO_VERSION_RAW="$(nexo --version 2>/dev/null || echo '')"
NEXO_VERSION="$(printf '%s\n' "$NEXO_VERSION_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [[ -z "$NEXO_VERSION" ]]; then
    warn "could not detect nexo version from '$NEXO_VERSION_RAW' — assuming compatible."
else
    # Lexicographic semver compare via sort -V (covers e.g. 0.1.6 < 0.1.10).
    LOWER="$(printf '%s\n%s\n' "$NEXO_VERSION" "$MIN_NEXO_VERSION" | sort -V | head -1)"
    if [[ "$LOWER" != "$MIN_NEXO_VERSION" ]] && [[ "$NEXO_VERSION" != "$MIN_NEXO_VERSION" ]]; then
        fail "nexo daemon version ${NEXO_VERSION} detected; persona requires ≥${MIN_NEXO_VERSION}."
        fail "Upgrade with: cargo install nexo-rs --force"
        exit 1
    fi
    ok "nexo daemon detected: ${NEXO_VERSION} (≥${MIN_NEXO_VERSION})"
fi

# Required plugins note (informational — install.sh doesn't auto-install plugins)
info "Required plugins (operator must enable separately): telegram, whatsapp"

# ── Helpers ────────────────────────────────────────────────────────────

# write_or_skip <src> <dst> [conflict_exit_code]
# Copies src to dst respecting dry-run / reinstall / conflict-exit semantics.
# Returns 0 on success / skip-because-already-installed,
# Returns the conflict_exit_code (default 2) if file exists and --reinstall not set.
write_or_skip() {
    local src="$1" dst="$2" exit_on_conflict="${3:-2}"
    if [[ ! -f "$src" ]]; then
        fail "source file missing: $src"
        return 1
    fi
    if [[ -e "$dst" && $REINSTALL -eq 0 ]]; then
        fail "$dst already exists. Use --reinstall to overwrite, or --dry-run to preview."
        return "$exit_on_conflict"
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        dry "Would copy: $src → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    inst "$src → $dst"
    return 0
}

# write_template_if_absent <src> <dst>
# Writes template only if the dst .txt is missing or empty (operator-populated
# templates are NEVER overwritten — protects the bot token).
write_template_if_absent() {
    local src="$1" dst="$2"
    if [[ -f "$dst" && -s "$dst" ]]; then
        keep "$dst already populated (your real token), not overwriting"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        dry "Would write template: $src → $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst" || { fail "secrets template write failed (permissions?): $dst"; return 4; }
    chmod 600 "$dst" || true
    inst "secrets template: $src → $dst (chmod 600)"
    return 0
}

# merge_telegram_partial <partial-yaml-path> <dst-yaml-path>
# Appends the partial block to the destination if the cody_nexo_bot
# instance isn't already present. Backs up the original first.
merge_telegram_partial() {
    local partial="$1" dst="$2"
    if [[ ! -f "$dst" ]]; then
        # Brand new telegram.yaml — write a `telegram:` header + the
        # partial as the first instance.
        if [[ $DRY_RUN -eq 1 ]]; then
            dry "Would create $dst with cody_nexo_bot as first instance"
            return 0
        fi
        mkdir -p "$(dirname "$dst")"
        {
            echo "telegram:"
            cat "$partial"
        } > "$dst"
        inst "created $dst with cody_nexo_bot block"
        return 0
    fi
    # File exists — check for duplicate.
    if grep -q '^- instance: cody_nexo_bot' "$dst" 2>/dev/null \
       || grep -q '^  - instance: cody_nexo_bot' "$dst" 2>/dev/null; then
        keep "cody_nexo_bot block already present in $dst, skipping merge"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        dry "Would append cody_nexo_bot block to $dst (after backup)"
        return 0
    fi
    cp "$dst" "$dst.bak" || { fail "could not back up $dst"; return 3; }
    cat "$partial" >> "$dst" || { fail "append to $dst failed"; cp "$dst.bak" "$dst"; return 3; }
    inst "appended cody_nexo_bot block to $dst (backup: $dst.bak)"
    return 0
}

# copy_workspace_seed <src-dir> <dst-dir>
copy_workspace_seed() {
    local src="$1" dst="$2"
    if [[ -d "$dst" && $REINSTALL -eq 0 ]]; then
        # Honour conflict semantics — but workspace seed is unusual:
        # operators may have populated it post-install. Refuse without
        # --reinstall, but message gently.
        fail "$dst already exists. Use --reinstall to overwrite the workspace seed, or --dry-run to preview."
        fail "(if you've populated PHASES.md / FOLLOWUPS.md with real content, --reinstall WILL clobber them; back up first.)"
        return 5
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        dry "Would create workspace: $dst (PHASES.md, FOLLOWUPS.md, DREAMS.md, README.md)"
        return 0
    fi
    mkdir -p "$dst" || { fail "workspace mkdir failed (permissions?): $dst"; return 5; }
    cp -r "$src"/. "$dst"/ || { fail "workspace seed copy failed: $src → $dst"; return 5; }
    inst "workspace seed: $src → $dst"
    return 0
}

# ── Install ────────────────────────────────────────────────────────────

info "Using config dir: $CONFIG_DIR"
[[ $DRY_RUN -eq 1 ]] && info "DRY-RUN — no changes will be made."

# 1. agent config
write_or_skip \
    "$REPO_ROOT/agents.d/cody.yaml" \
    "$CONFIG_DIR/agents.d/cody.yaml" \
    || exit $?

# 2. telegram instance block (special merge logic)
merge_telegram_partial \
    "$REPO_ROOT/plugins/telegram.partial.yaml" \
    "$CONFIG_DIR/plugins/telegram.yaml" \
    || exit $?

# 3. secrets template (NEVER overwrites populated tokens)
# Strip the .template suffix when copying so the daemon picks up the
# real filename. Operator must edit the destination to insert their
# real token.
write_template_if_absent \
    "$REPO_ROOT/secrets/cody_nexo_bot_telegram_token.txt.template" \
    "$CONFIG_DIR/secrets/cody_nexo_bot_telegram_token.txt" \
    || exit $?

# 4. workspace seed
copy_workspace_seed \
    "$REPO_ROOT/data/workspace/cody" \
    "$CONFIG_DIR/data/workspace/cody" \
    || exit $?

# ── Next steps ─────────────────────────────────────────────────────────

echo ""
ok "Cody persona installed."
echo ""
cat <<EOF
NEXT STEPS:

  1. Edit your bot token:
     ${C_CYAN}\$ \$EDITOR $CONFIG_DIR/secrets/cody_nexo_bot_telegram_token.txt${C_RESET}
     (replace the placeholder with the token from @BotFather)

  2. Export Anthropic credentials:
     ${C_CYAN}\$ export ANTHROPIC_API_KEY=sk-ant-...${C_RESET}
     (or use the OAuth subscription wizard via 'agent llm-keys')

  3. Start the daemon:
     ${C_CYAN}\$ nexo daemon${C_RESET}

  4. Pair Cody on Telegram (DM your bot, follow the QR pair flow),
     then chat:
     ${C_CYAN}cody> what phases are pending?${C_RESET}

  5. To switch Cody to your own project:
     ${C_CYAN}cody> work in /path/to/your-project${C_RESET}

Troubleshooting:
  - "AgentContext.dispatch is not set"  →  ensure cody.yaml has
    \`dispatch_policy.mode: full\` (it does by default in this
    persona pack); the driver auto-boots when any agent does.
  - Bot doesn't respond  →  check NEXO_DAEMON_LOG=info nexo daemon
    output for telegram polling errors.
  - Self-modify refused  →  unset NEXO_DISALLOW_SELF_MODIFY (default
    is allow; production sets =1 to refuse).

Repo issues: https://github.com/lordmacu/persona-cody/issues
EOF

exit 0
