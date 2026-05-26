#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="BRDiscSplitter"
APP_NAME="BRDisc Splitter"
BUNDLE_ID="com.janlay.BRDiscSplitter"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT_FILE="$ROOT_DIR/BRDiscSplitter.xcodeproj"
PROJECT_CONFIG="$PROJECT_FILE/project.pbxproj"
SCHEME="BRDiscSplitter"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived"
BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
OLD_APP_BUNDLE="$DIST_DIR/$PRODUCT_NAME.app"
LEGACY_APP_BUNDLE="$DIST_DIR/BRDiscSplitterGUI.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
APP_CLI="$APP_BUNDLE/Contents/Resources/brdisc-splitter"

cd "$ROOT_DIR"

GIT_SHORT_HASH="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

current_build_number() {
  awk -F' = ' '/CURRENT_PROJECT_VERSION = / { gsub(/;|[[:space:]]/, "", $2); print $2; exit }' "$PROJECT_CONFIG"
}

next_build_number() {
  local current
  current="$(current_build_number)"

  if [[ -z "$current" || ! "$current" =~ ^[0-9]+$ ]]; then
    echo "invalid CURRENT_PROJECT_VERSION: ${current:-missing}" >&2
    exit 2
  fi

  printf '%s\n' "$((current + 1))"
}

write_build_number() {
  local build_number="$1"

  perl -0pi -e "s/CURRENT_PROJECT_VERSION = \\d+;/CURRENT_PROJECT_VERSION = $build_number;/g" "$PROJECT_CONFIG"
}

write_git_short_hash() {
  local plist="$1/Contents/Info.plist"

  /usr/libexec/PlistBuddy -c "Set :BRDiscGitShortHash $GIT_SHORT_HASH" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :BRDiscGitShortHash string $GIT_SHORT_HASH" "$plist"
}

pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true
pkill -x "BRDiscSplitterGUI" >/dev/null 2>&1 || true

XCODEBUILD_BUILD_NUMBER_ARGS=()

if [[ "$CONFIGURATION" == "Release" ]]; then
  NEXT_BUILD_NUMBER="$(next_build_number)"
  XCODEBUILD_BUILD_NUMBER_ARGS=(CURRENT_PROJECT_VERSION="$NEXT_BUILD_NUMBER")
fi

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  "${XCODEBUILD_BUILD_NUMBER_ARGS[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ "$CONFIGURATION" == "Release" ]]; then
  write_build_number "$NEXT_BUILD_NUMBER"
fi

write_git_short_hash "$BUILT_APP"

rm -rf "$APP_BUNDLE" "$OLD_APP_BUNDLE" "$LEGACY_APP_BUNDLE"
mkdir -p "$DIST_DIR"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"
chmod +x "$APP_BINARY"
chmod +x "$APP_CLI"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PRODUCT_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
