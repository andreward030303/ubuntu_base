#!/usr/bin/env bash
set -euo pipefail

# ---- OS detection ----
. /etc/os-release || true
is_ubuntu_like() {
  [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${ID_LIKE:-}" == *"ubuntu"* ]]
}
is_amzn2023() {
  [[ "${ID:-}" == "amzn" ]] && [[ "${VERSION_ID:-}" == "2023" ]]
}

# ---- default ROOT depends on OS, but allow override by 1st arg ----
DEFAULT_ROOT="/code"
if is_amzn2023; then
  DEFAULT_ROOT="$HOME/project"
elif is_ubuntu_like; then
  DEFAULT_ROOT="/code"
fi

ROOT="${1:-$DEFAULT_ROOT}"

# ---- pretty output helpers ----
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_RED=$'\033[31m'
else
  C_RESET=""; C_DIM=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_RED=""
fi

ok()    { echo "${C_GREEN}✔${C_RESET} $*"; }
warn()  { echo "${C_YELLOW}⚠${C_RESET} $*"; }
info()  { echo "${C_BLUE}➜${C_RESET} $*"; }
fail()  { echo "${C_RED}✖${C_RESET} $*" >&2; }

# ---- checks ----
command -v tmux >/dev/null 2>&1 || { fail "tmux not found"; exit 1; }
[[ -d "$ROOT" ]] || { fail "ROOT not found: $ROOT"; exit 1; }

# ---- sanitize directory name -> tmux session name ----
sanitize() {
  local s="$1"
  # trim whitespace
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  # keep only [A-Za-z0-9_-], replace others with "_"
  s="$(printf '%s' "$s" | tr -c '[:alnum:]_-' '_' )"
  # collapse multiple underscores
  s="$(printf '%s' "$s" | sed -E 's/_+/_/g')"
  # trim leading/trailing underscores
  s="$(printf '%s' "$s" | sed -E 's/^_+//; s/_+$//')"
  # fallback
  [[ -z "$s" ]] && s="proj"
  printf '%s' "$s"
}

created=0
skipped=0
missing=0

# ---- OS-specific info message (optional) ----
if is_amzn2023; then
  info "Detected Amazon Linux 2023 → default ROOT: ${C_DIM}${DEFAULT_ROOT}${C_RESET}"
elif is_ubuntu_like; then
  info "Detected Ubuntu/Debian → default ROOT: ${C_DIM}${DEFAULT_ROOT}${C_RESET}"
else
  warn "Unknown OS (ID=${ID:-}) → default ROOT: ${C_DIM}${DEFAULT_ROOT}${C_RESET}"
fi

info "Scanning ${C_DIM}${ROOT}${C_RESET} (direct children only)"
info "Format: <dir>  →  <session>"

# /ROOT直下のディレクトリを列挙（名前順）
while IFS= read -r -d '' dir; do
  base="$(basename "$dir")"
  session="$(sanitize "$base")"

  if [[ ! -d "$dir" ]]; then
    warn "skip ${C_DIM}${dir}${C_RESET}  →  ${session} (missing)"
    missing=$((missing+1))
    continue
  fi

  if tmux has-session -t "$session" 2>/dev/null; then
    ok "exists  ${C_DIM}${dir}${C_RESET}  →  ${session}"
    skipped=$((skipped+1))
    continue
  fi

  tmux -2 new-session -d -s "$session" -c "$dir"
  ok "created ${C_DIM}${dir}${C_RESET}  →  ${session}"
  created=$((created+1))
done < <(find "$ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

echo
info "Summary: created=${created}, skipped=${skipped}, missing=${missing}"
info "Tip: tmux ls   /   tmux a -t <session>"

