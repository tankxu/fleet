#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="${ROOT}/Native/DiffSidecar"
BINARY_NAME="cmux-diff-sidecar"
BUILD_OUTPUT_DIR="${TARGET_BUILD_DIR:-${CRATE_DIR}/target/cmux-diff-sidecar}"
# Do not use TARGET_TEMP_DIR: Xcode's temp mixes host/target cargo layouts and
# leftover failed builds make proc-macros unresolvable (E0463).
BUILD_WORK_DIR="${CRATE_DIR}/target/cmux-diff-sidecar-build"
CARGO_RUNNER="${ROOT}/scripts/run-diff-sidecar-cargo.sh"
TOOLCHAIN="$(awk -F '"' '/^[[:space:]]*channel[[:space:]]*=/{print $2; exit}' "${CRATE_DIR}/rust-toolchain.toml")"

# Xcode build phases do not inherit a login-shell PATH. Prefer rustup's
# conventional bin directory, then the standard Homebrew prefixes.
export PATH="${CARGO_HOME:-${HOME}/.cargo}/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

if ! command -v rustup >/dev/null 2>&1; then
  echo "error: rustup is required to build ${BINARY_NAME}; run ./scripts/setup.sh after installing Rust from https://rustup.rs" >&2
  exit 1
fi

rust_target_for_arch() {
  case "$1" in
    arm64|arm64e) echo "aarch64-apple-darwin" ;;
    x86_64) echo "x86_64-apple-darwin" ;;
    *)
      echo "error: unsupported Rust macOS arch $1" >&2
      return 1
      ;;
  esac
}

ensure_rust_target() {
  local target="$1"
  if ! rustup target list --toolchain "$TOOLCHAIN" --installed | grep -qx "$target"; then
    rustup target add --toolchain "$TOOLCHAIN" "$target"
  fi
}

requested_archs="${CMUX_DIFF_SIDECAR_ARCHS:-${ARCHS:-}}"
if [[ -z "$requested_archs" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) requested_archs="arm64" ;;
    x86_64) requested_archs="x86_64" ;;
    *)
      echo "error: cannot infer Rust macOS target for host arch $(uname -m)" >&2
      exit 1
      ;;
  esac
fi
if [[ "${ONLY_ACTIVE_ARCH:-NO}" == YES ]]; then
  case "$(uname -m)" in
    arm64|aarch64) requested_archs="arm64" ;;
    x86_64) requested_archs="x86_64" ;;
  esac
fi

mkdir -p "$BUILD_OUTPUT_DIR"
mkdir -p "$BUILD_WORK_DIR"
binaries=()
prebuilt="${CRATE_DIR}/target/cmux-diff-sidecar/${BINARY_NAME}"
# Xcode's script-phase sandbox blocks rustc from loading proc-macro dylibs
# (E0463). Copy a sidecar built outside that sandbox when it matches this arch.
if [[ -n "${TARGET_BUILD_DIR:-}" && -x "$prebuilt" ]]; then
  host_arch="$(uname -m)"
  [[ "$host_arch" == aarch64 ]] && host_arch=arm64
  prebuilt_ok=1
  for arch in $requested_archs; do
    if [[ "$arch" != "$host_arch" ]]; then
      prebuilt_ok=0
      break
    fi
  done
  if [[ "$prebuilt_ok" == 1 ]]; then
    echo "Using prebuilt ${prebuilt} (skipping cargo inside Xcode sandbox)"
    binaries+=("$prebuilt")
  fi
fi
seen_targets=""
if [[ "${#binaries[@]}" -eq 0 ]]; then
for arch in $requested_archs; do
  target="$(rust_target_for_arch "$arch")"
  case " $seen_targets " in
    *" $target "*) continue ;;
  esac
  seen_targets="$seen_targets $target"
  ensure_rust_target "$target"
  target_dir="${BUILD_WORK_DIR}"
  cargo_args=(
    build
    --manifest-path "${CRATE_DIR}/Cargo.toml"
    --bin "$BINARY_NAME"
    --release
    --locked
    --no-default-features
  )
  # --target even for the host triple, together with MACOSX_DEPLOYMENT_TARGET,
  # makes rustc fail to load proc-macros (E0463). Native builds omit --target
  # so minos 14.0 can still be applied.
  host_target="$(rust_target_for_arch "$(uname -m)")"
  if [[ "$target" == "$host_target" ]]; then
    source_binary="${target_dir}/release/${BINARY_NAME}"
    CARGO_TARGET_DIR="$target_dir" \
      "$CARGO_RUNNER" "${cargo_args[@]}"
  else
    source_binary="${target_dir}/${target}/release/${BINARY_NAME}"
    # The scrubbed cargo env has no SDKROOT, and a cross link cannot find the
    # SDK on its own (ld: library 'iconv' not found). Hand the sysroot to the
    # target's link only; host proc-macros stay untouched, so E0463 stays away.
    sdk_path="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
    target_env="$(printf '%s' "$target" | tr '[:lower:]-' '[:upper:]_')"
    env "CARGO_TARGET_${target_env}_RUSTFLAGS=-C link-arg=-isysroot -C link-arg=${sdk_path}" \
      CARGO_TARGET_DIR="$target_dir" \
      "$CARGO_RUNNER" "${cargo_args[@]}" --target "$target"
  fi
  [[ -x "$source_binary" ]] || { echo "error: missing ${source_binary}" >&2; exit 1; }
  # rustc 1.88 + macOS 27 cannot load proc-macros if MACOSX_DEPLOYMENT_TARGET
  # is set, so minos is stamped after the link instead of during it.
  min_macos="${CMUX_DIFF_SIDECAR_MIN_MACOS:-14.0}"
  sdk_version="$(sw_vers -productVersion | awk -F. '{print $1".0"}')"
  xcrun vtool -set-build-version macos "$min_macos" "$sdk_version" -replace \
    -output "$source_binary" "$source_binary"
  chmod +x "$source_binary"
  binaries+=("$source_binary")
done
fi

output_binary="${BUILD_OUTPUT_DIR}/${BINARY_NAME}"
if [[ "${#binaries[@]}" -eq 1 ]]; then
  rsync -a "${binaries[0]}" "$output_binary"
else
  lipo -create -output "$output_binary" "${binaries[@]}"
fi
chmod +x "$output_binary"
"${ROOT}/scripts/verify-diff-sidecar-artifact.sh" "$output_binary" --archs "$requested_archs"

if [[ -z "${TARGET_BUILD_DIR:-}" ]]; then
  echo "built ${output_binary}"
  exit 0
fi

destination_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/bin"
destination="${destination_dir}/${BINARY_NAME}"
mkdir -p "$destination_dir"
rsync -a "$output_binary" "$destination"
chmod +x "$destination"
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$destination" >/dev/null
fi
