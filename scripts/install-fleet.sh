#!/usr/bin/env bash
# Build Fleet (Release) and install it to /Applications, plus the `fleet` command.
#
# Fleet has its own bundle id (com.tankxu.fleet), so it installs alongside
# cmux.app instead of replacing it: config, auth tokens, and session snapshots
# live in ~/.config/fleet and Application Support/fleet, and UserDefaults is
# already keyed by bundle id. Nothing here touches the cmux install.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

# The Release configuration builds universal (ONLY_ACTIVE_ARCH=NO) because that is
# what shipping a signed app to other people requires. A local install runs on
# this machine only, so the second architecture is half the build time spent on
# code that will never execute here — hence ONLY_ACTIVE_ARCH=YES below. Keep the
# derived data around between runs; whole-module optimization limits incremental
# reuse, but it still beats starting cold.
DERIVED="${FLEET_DERIVED_DATA:-/tmp/fleet-release}"
APP_DEST="/Applications/Fleet.app"
BIN_DIR="${FLEET_BIN_DIR:-$HOME/bin}"

# Signing. The Release configuration carries a keychain-access-groups entitlement,
# which needs a real certificate AND a provisioning profile for this bundle id —
# and creating that profile registers a new App ID in the developer account.
#
# We don't need it: on macOS the token store is keychain-primary with a
# file-backed fallback (FileStackTokenStore), and that fallback exists precisely
# for builds without this entitlement. So by default Fleet is signed locally,
# exactly like the Debug builds that have been in daily use, and signs in through
# the 0600 file store.
#
# Set FLEET_DEVELOPMENT_TEAM to sign with a real certificate instead. That path
# needs -allowProvisioningUpdates, which will register com.tankxu.fleet as an
# App ID in that team.
SIGN_ARGS=()
if [[ -n "${FLEET_DEVELOPMENT_TEAM:-}" ]]; then
  echo "==> Building Fleet (Release), signing with team $FLEET_DEVELOPMENT_TEAM"
  echo "    (this registers com.tankxu.fleet as an App ID in that team)"
  SIGN_ARGS=(
    DEVELOPMENT_TEAM="$FLEET_DEVELOPMENT_TEAM"
    -allowProvisioningUpdates
  )
else
  echo "==> Building Fleet (Release), signed locally"
  SIGN_ARGS=(
    CODE_SIGN_ENTITLEMENTS=""
    CODE_SIGN_IDENTITY="-"
    CODE_SIGN_STYLE=Manual
    DEVELOPMENT_TEAM=""
  )
fi

xcodebuild \
  -project cmux.xcodeproj \
  -scheme cmux \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ${CMUX_DISABLE_AUTOMATIC_PACKAGE_RESOLUTION:+-disableAutomaticPackageResolution} \
  "${SIGN_ARGS[@]}" \
  ONLY_ACTIVE_ARCH=YES \
  build

APP_SRC="$DERIVED/Build/Products/Release/Fleet.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "error: build did not produce $APP_SRC" >&2
  exit 1
fi

BUILT_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_SRC/Contents/Info.plist")"
if [[ "$BUILT_ID" != com.tankxu.fleet ]]; then
  echo "error: built bundle id is $BUILT_ID, expected com.tankxu.fleet" >&2
  echo "       Installing it would make Fleet fight cmux over the same identity." >&2
  exit 1
fi

echo "==> Installing $APP_DEST"
if pgrep -f "$APP_DEST/Contents/MacOS/Fleet" >/dev/null 2>&1; then
  echo "    quitting the running Fleet first"
  osascript -e 'quit app id "com.tankxu.fleet"' >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    pgrep -f "$APP_DEST/Contents/MacOS/Fleet" >/dev/null 2>&1 || break
    /bin/sleep 0.25
  done
fi
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

echo "==> Installing the fleet command into $BIN_DIR"
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/fleet" <<'SHIM'
#!/usr/bin/env bash
# Fleet CLI entry point (managed by scripts/install-fleet.sh).
#
# Inside a cmux/Fleet terminal, CMUX_BUNDLED_CLI_PATH names the CLI of the app
# that owns this terminal; honour it so `fleet` always drives the app you are
# actually sitting in. Outside one, drive the installed Fleet.
set -euo pipefail
if [[ -n "${CMUX_BUNDLED_CLI_PATH:-}" && -x "${CMUX_BUNDLED_CLI_PATH:-}" ]]; then
  exec "$CMUX_BUNDLED_CLI_PATH" "$@"
fi
FLEET_CLI=/Applications/Fleet.app/Contents/Resources/bin/fleet
if [[ ! -x "$FLEET_CLI" ]]; then
  echo "error: Fleet is not installed at /Applications/Fleet.app" >&2
  exit 1
fi
exec "$FLEET_CLI" "$@"
SHIM
chmod +x "$BIN_DIR/fleet"

echo
echo "Installed:"
echo "  app : $APP_DEST  ($BUILT_ID)"
echo "  cli : $BIN_DIR/fleet"
echo "  cmux: left untouched — your existing hooks keep working"
echo
echo "State directories for this identity:"
echo "  ~/.config/fleet/fleet.json"
echo "  ~/Library/Application Support/fleet/"
