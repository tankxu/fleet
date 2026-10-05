#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLCHAIN_FILE="$ROOT/Native/DiffSidecar/rust-toolchain.toml"
TOOLCHAIN="$(awk -F '"' '/^[[:space:]]*channel[[:space:]]*=/{print $2; exit}' "$TOOLCHAIN_FILE")"

if [[ -z "$TOOLCHAIN" ]]; then
  echo "error: missing Rust channel in $TOOLCHAIN_FILE" >&2
  exit 1
fi
if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required for the pinned Rust $TOOLCHAIN toolchain" >&2
  exit 1
fi

# Xcode script phases export SDKROOT / MACOSX_DEPLOYMENT_TARGET / CFLAGS.
# rustc 1.88 on macOS 27 then compiles proc-macros but cannot load them (E0463).
# Run cargo in a scrubbed environment so only the vars it actually needs survive.
clean_env=(
  HOME="$HOME"
  USER="$USER"
  LOGNAME="${LOGNAME:-$USER}"
  PATH="$PATH"
  SHELL="${SHELL:-/bin/bash}"
  TMPDIR="${TMPDIR:-/tmp}"
  TERM="${TERM:-dumb}"
  LANG="${LANG:-en_US.UTF-8}"
  CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
)
[[ -n "${CARGO_TARGET_DIR:-}" ]] && clean_env+=("CARGO_TARGET_DIR=$CARGO_TARGET_DIR")
[[ -n "${GIT_CONFIG_GLOBAL:-}" ]] && clean_env+=("GIT_CONFIG_GLOBAL=$GIT_CONFIG_GLOBAL")
[[ -n "${GIT_CONFIG_NOSYSTEM:-}" ]] && clean_env+=("GIT_CONFIG_NOSYSTEM=$GIT_CONFIG_NOSYSTEM")
[[ -n "${SSH_AUTH_SOCK:-}" ]] && clean_env+=("SSH_AUTH_SOCK=$SSH_AUTH_SOCK")
# Per-target flags (e.g. a cross link's sysroot) apply only to that target's
# artifacts, never to host proc-macros, so they are safe to forward.
while IFS='=' read -r name value; do
  [[ "$name" == CARGO_TARGET_*_RUSTFLAGS ]] && clean_env+=("$name=$value")
done < <(env)

exec env -i "${clean_env[@]}" rustup run "$TOOLCHAIN" cargo "$@"
