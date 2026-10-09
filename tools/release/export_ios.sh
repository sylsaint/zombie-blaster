#!/usr/bin/env bash
# Export an iOS Xcode project with the release template.
# When IOS_P12_BASE64, IOS_P12_PASSWORD, IOS_PROVISION_PROFILE_BASE64, and
# IOS_TEAM_ID are all set, archive it and export an IPA.
# If any of those secrets is missing, skip signing, zip the Xcode project,
# and exit 0.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common.sh
source "$ROOT/tools/release/common.sh"

tag="$(resolve_artifact_tag)"
out_dir="$ROOT/build/release"
ios_dir="$ROOT/build/ios"
scheme="zombie-blaster"
mkdir -p "$out_dir" "$ios_dir"

preset="$ROOT/export_presets.cfg"
backup="$ROOT/build/export_presets.cfg.bak"
cp "$preset" "$backup"
restore_preset() {
  if [[ -f "$backup" ]]; then
    cp "$backup" "$preset"
  fi
}
trap restore_preset EXIT

secret_set() {
  [[ -n "${1:-}" ]]
}

missing=""
secret_set "${IOS_P12_BASE64:-}" || missing="${missing} IOS_P12_BASE64"
secret_set "${IOS_P12_PASSWORD:-}" || missing="${missing} IOS_P12_PASSWORD"
secret_set "${IOS_PROVISION_PROFILE_BASE64:-}" || missing="${missing} IOS_PROVISION_PROFILE_BASE64"
secret_set "${IOS_TEAM_ID:-}" || missing="${missing} IOS_TEAM_ID"

sign=0
team_id="0000000000"
if [[ -z "$missing" ]]; then
  sign=1
  team_id="$IOS_TEAM_ID"
  note "iOS signing secrets are present. The job will archive and export an IPA."
else
  note "iOS signing skipped. Missing:${missing}. Uploading an unsigned Xcode project. The job stays green."
  note "Godot still requires a non-empty App Store Team ID to write the Xcode project. Using placeholder ${team_id} only in this working copy."
fi

python3 - "$preset" "$team_id" "$sign" << 'PY'
import pathlib, sys
path, team_id, sign = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
text = pathlib.Path(path).read_text()

def set_line(text, key, value):
    lines = text.splitlines()
    found = False
    out = []
    prefix = key + "="
    for line in lines:
        if line.startswith(prefix):
            out.append(f"{key}={value}")
            found = True
        else:
            out.append(line)
    if not found:
        raise SystemExit(f"export_presets.cfg is missing {key}")
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")

text = set_line(text, "application/app_store_team_id", f'"{team_id}"')
if sign:
    # Filled later if we already know the profile UUID. The shell calls this
    # again after the profile is decoded when sign=1 and extra env is set.
    pass
pathlib.Path(path).write_text(text)
PY

if [[ "$sign" == "1" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "iOS signing secrets are set, but xcodebuild is only available on macOS." >&2
    exit 1
  fi
  sign_dir="$ROOT/build/signing"
  mkdir -p "$sign_dir"
  p12="$sign_dir/ios.p12"
  profile="$sign_dir/ios.mobileprovision"
  plist="$sign_dir/profile.plist"
  printf '%s' "$IOS_P12_BASE64" | decode_base64_to "$p12"
  printf '%s' "$IOS_PROVISION_PROFILE_BASE64" | decode_base64_to "$profile"
  security cms -D -i "$profile" -o "$plist"
  uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist")"
  profile_name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist")"
  method=0
  identity="Apple Distribution"
  if /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$plist" >/dev/null 2>&1; then
    method=3
  elif /usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$plist" >/dev/null 2>&1; then
    task_allow="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$plist" 2>/dev/null || echo false)"
    if [[ "$task_allow" == "true" ]]; then
      method=1
      identity="Apple Development"
    else
      method=2
    fi
  fi
  python3 - "$preset" "$team_id" "$uuid" "$profile_name" "$method" "$identity" << 'PY'
import pathlib, sys
path, team_id, uuid, name, method, identity = sys.argv[1:]
text = pathlib.Path(path).read_text()

def set_line(text, key, value):
    lines = text.splitlines()
    found = False
    out = []
    prefix = key + "="
    for line in lines:
        if line.startswith(prefix):
            out.append(f"{key}={value}")
            found = True
        else:
            out.append(line)
    if not found:
        raise SystemExit(f"export_presets.cfg is missing {key}")
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")

text = set_line(text, "application/app_store_team_id", f'"{team_id}"')
text = set_line(text, "application/provisioning_profile_uuid_debug", f'"{uuid}"')
text = set_line(text, "application/provisioning_profile_uuid_release", f'"{uuid}"')
text = set_line(text, "application/provisioning_profile_specifier_debug", f'"{name}"')
text = set_line(text, "application/provisioning_profile_specifier_release", f'"{name}"')
text = set_line(text, "application/export_method_release", method)
text = set_line(text, "application/code_sign_identity_release", f'"{identity}"')
text = set_line(text, "application/code_sign_identity_debug", f'"{identity}"')
pathlib.Path(path).write_text(text)
PY
  profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$profiles_dir"
  cp "$profile" "$profiles_dir/$uuid.mobileprovision"
  keychain="$sign_dir/ios-signing.keychain-db"
  keychain_pass="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  security create-keychain -p "$keychain_pass" "$keychain"
  security set-keychain-settings -lut 21600 "$keychain"
  security unlock-keychain -p "$keychain_pass" "$keychain"
  security import "$p12" -k "$keychain" -P "$IOS_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_pass" "$keychain" >/dev/null
  security list-keychains -d user -s "$keychain" $(security list-keychains -d user | sed 's/"//g')
  cleanup_keychain() {
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
    restore_preset
  }
  trap cleanup_keychain EXIT
fi

ensure_godot
note "Importing project"
"$GODOT_BIN" --headless --path "$ROOT" --import

export_path="$ios_dir/${scheme}.ipa"
note "Exporting the iOS Xcode project (release template, export project only)"
"$GODOT_BIN" --headless --audio-driver Dummy --path "$ROOT" \
  --export-release "iOS" "$export_path"

proj="$ios_dir/${scheme}.xcodeproj"
app_dir="$ios_dir/${scheme}"
if [[ ! -d "$proj" || ! -d "$app_dir" ]]; then
  echo "Godot did not write $proj" >&2
  exit 1
fi

if [[ "$sign" == "1" ]]; then
  archive="$ios_dir/${scheme}.xcarchive"
  ipa_dir="$ios_dir/ipa"
  mkdir -p "$ipa_dir"
  note "Archiving with xcodebuild"
  xcodebuild \
    -project "$proj" \
    -scheme "$scheme" \
    -configuration Release \
    -sdk iphoneos \
    -destination "generic/platform=iOS" \
    -archivePath "$archive" \
    archive
  note "Exporting the IPA"
  xcodebuild \
    -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$app_dir/export_options.plist" \
    -exportPath "$ipa_dir"
  ipa=""
  while IFS= read -r candidate; do
    ipa="$candidate"
    break
  done < <(find "$ipa_dir" -maxdepth 1 -name '*.ipa' -print)
  if [[ -z "$ipa" ]]; then
    echo "xcodebuild did not write an IPA in $ipa_dir" >&2
    exit 1
  fi
  dest="$out_dir/zombie-blaster-${tag}-ios.ipa"
  mv "$ipa" "$dest"
  note "iOS IPA: $dest ($(wc -c < "$dest" | tr -d ' ') bytes)"
else
  dest="$out_dir/zombie-blaster-${tag}-ios-xcode-unsigned.zip"
  python3 - "$ios_dir" "$scheme" "$dest" << 'PY'
import pathlib, sys, zipfile
ios_dir, scheme, dest = sys.argv[1:]
root = pathlib.Path(ios_dir)
include = [root / f"{scheme}.xcodeproj", root / scheme]
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for base in include:
        for path in base.rglob("*"):
            if path.is_file():
                zf.write(path, path.relative_to(root).as_posix())
PY
  note "Unsigned Xcode project: $dest ($(wc -c < "$dest" | tr -d ' ') bytes)"
fi
