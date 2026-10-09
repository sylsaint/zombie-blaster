#!/usr/bin/env bash
# Export arm64-v8a release and debug APKs.
# Release uses the release export template. Without the three release
# keystore secrets, that APK is signed with a generated debug keystore
# so it can be installed. When all three secrets are set, the release
# APK uses them instead. The debug APK always uses the debug keystore.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/tools/release/common.sh"

if [[ -z "${JAVA_HOME:-}" ]]; then
  echo "JAVA_HOME is required (JDK 17). The Android exporter looks up bin/java and bin/keytool there." >&2
  exit 1
fi
if [[ -z "${ANDROID_HOME:-}" ]]; then
  echo "ANDROID_HOME is required. It must contain platform-tools/ and build-tools/." >&2
  exit 1
fi
if [[ ! -x "$JAVA_HOME/bin/keytool" ]]; then
  echo "keytool not found at $JAVA_HOME/bin/keytool" >&2
  exit 1
fi
if [[ ! -d "$ANDROID_HOME/platform-tools" || ! -d "$ANDROID_HOME/build-tools" ]]; then
  echo "ANDROID_HOME ($ANDROID_HOME) is missing platform-tools or build-tools." >&2
  exit 1
fi

tag="$(resolve_artifact_tag)"
out_dir="$ROOT/build/release"
sign_dir="$ROOT/build/signing"
mkdir -p "$out_dir" "$sign_dir"

release_apk="$out_dir/zombie-blaster-${tag}-android-release.apk"
debug_apk="$out_dir/zombie-blaster-${tag}-android-debug.apk"

debug_ks="$sign_dir/debug.keystore"
debug_alias="androiddebugkey"
debug_pass="android"
if [[ ! -f "$debug_ks" ]]; then
  note "Generating a debug keystore"
  keytool -genkeypair -keystore "$debug_ks" \
    -storepass "$debug_pass" -keypass "$debug_pass" \
    -alias "$debug_alias" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug, OU=Zombie Blaster CI, O=Zombie Blaster, C=US" >/dev/null
fi

has_ks="${ANDROID_KEYSTORE_BASE64:-}"
has_pass="${ANDROID_KEYSTORE_PASSWORD:-}"
has_alias="${ANDROID_KEY_ALIAS:-}"
if [[ -n "$has_ks" || -n "$has_pass" || -n "$has_alias" ]]; then
  if [[ -z "$has_ks" || -z "$has_pass" || -z "$has_alias" ]]; then
    echo "Android release signing is partial. Set all of ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, and ANDROID_KEY_ALIAS, or none of them." >&2
    exit 1
  fi
  release_ks="$sign_dir/release.keystore"
  printf '%s' "$ANDROID_KEYSTORE_BASE64" | decode_base64_to "$release_ks"
  release_alias="$ANDROID_KEY_ALIAS"
  release_pass="$ANDROID_KEYSTORE_PASSWORD"
  if ! keytool -list -keystore "$release_ks" -storepass "$release_pass" -alias "$release_alias" >/dev/null; then
    echo "Release keystore could not be read with ANDROID_KEY_ALIAS. Godot also requires the key password to match ANDROID_KEYSTORE_PASSWORD." >&2
    exit 1
  fi
  note "Release APK will be signed with the keystore from ANDROID_KEYSTORE_BASE64."
else
  release_ks="$debug_ks"
  release_alias="$debug_alias"
  release_pass="$debug_pass"
  note "ANDROID_KEYSTORE_BASE64 / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS are unset. Signing the release APK with the generated debug keystore."
fi

# Absolute paths. Godot does not resolve a relative keystore from the project.
release_ks="$(cd "$(dirname "$release_ks")" && pwd)/$(basename "$release_ks")"
debug_ks="$(cd "$(dirname "$debug_ks")" && pwd)/$(basename "$debug_ks")"

ensure_godot

note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

export_one() {
  local mode="$1" apk="$2" ks="$3" alias="$4" pass="$5"
  local path_var user_var pass_var
  if [[ "$mode" == "release" ]]; then
    path_var="GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    user_var="GODOT_ANDROID_KEYSTORE_RELEASE_USER"
    pass_var="GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"
    unset GODOT_ANDROID_KEYSTORE_DEBUG_PATH GODOT_ANDROID_KEYSTORE_DEBUG_USER GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD || true
  else
    path_var="GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
    user_var="GODOT_ANDROID_KEYSTORE_DEBUG_USER"
    pass_var="GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"
    unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD || true
  fi
  export "$path_var=$ks" "$user_var=$alias" "$pass_var=$pass"
  note "Exporting $mode APK -> $(basename "$apk")"
  if [[ "$mode" == "release" ]]; then
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-release "Android" "$apk"
  else
    "$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
      --export-debug "Android" "$apk"
  fi
  unset "$path_var" "$user_var" "$pass_var"
  if [[ ! -s "$apk" ]]; then
    echo "Export did not produce $apk" >&2
    exit 1
  fi
}

export_one release "$release_apk" "$release_ks" "$release_alias" "$release_pass"
export_one debug "$debug_apk" "$debug_ks" "$debug_alias" "$debug_pass"

aapt="$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort | tail -n 1)"
apksigner="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort | tail -n 1)"
if [[ -z "$aapt" || -z "$apksigner" ]]; then
  echo "aapt or apksigner is missing under $ANDROID_HOME/build-tools" >&2
  exit 1
fi

verify_apk() {
  local apk="$1"
  local badging
  badging="$("$aapt" dump badging "$apk")"
  printf '%s\n' "$badging" | awk 'NR<=20 { print }'
  case "$badging" in
    *"package: name='com.zombieblaster.game'"*) ;;
    *) echo "$apk package name is not com.zombieblaster.game" >&2; exit 1 ;;
  esac
  case "$badging" in
    *"native-code: 'arm64-v8a'"*) ;;
    *) echo "$apk is not arm64-v8a" >&2; exit 1 ;;
  esac
  case "$badging" in
    *armeabi-v7a*)
      echo "$apk contains armeabi-v7a; the preset is arm64-v8a only." >&2
      exit 1
      ;;
  esac
  "$apksigner" verify --print-certs "$apk"
  note "$(basename "$apk"): $(wc -c < "$apk" | tr -d ' ') bytes"
}

verify_apk "$release_apk"
verify_apk "$debug_apk"
note "Android export finished: $release_apk"
note "Android export finished: $debug_apk"
