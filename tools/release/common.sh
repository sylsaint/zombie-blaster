# Shared helpers for the release export scripts. Source this file; do not execute it.
# shellcheck shell=bash

if [[ -z "${ROOT:-}" ]]; then
  echo "ROOT is not set. Source common.sh from export_android.sh or export_ios.sh." >&2
  exit 1
fi

godot_version() {
  tr -d '[:space:]' < "$ROOT/tools/godot.version"
}

# Cache holds the editor binary and the unpacked export templates.
# CI points GODOT_CACHE at a directory restored by actions/cache.
godot_cache_dir() {
  printf '%s' "${GODOT_CACHE:-$HOME/.cache/zombie-blaster-godot}"
}

find_godot_macos_bin() {
  local dest="$1" candidate
  candidate=""
  while IFS= read -r candidate; do
    printf '%s' "$candidate"
    return
  done < <(find "$dest" -type f -path '*/MacOS/Godot' -print)
}

decode_base64_to() {
  local dest="$1"
  if printf '' | base64 -d >/dev/null 2>&1; then
    tr -d '[:space:]' | base64 -d > "$dest"
  else
    tr -d '[:space:]' | base64 -D > "$dest"
  fi
}

note() {
  printf '%s\n' "$*"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Fail the export if the package dropped the level data or the assets tree.
# Android stores them as loose files under assets/. iOS stores them in the pck.
assert_project_data_packed() {
  python3 - "$1" "${2:-game}" << 'PY'
import struct, sys, zipfile
from pathlib import Path

target = Path(sys.argv[1])
mode = sys.argv[2]
needles = (
    "data/levels/level_01",
    "data/levels/level_02",
    "data/levels/level_03",
    "assets/vfx/",
    "assets/textures/",
    "assets/models/",
)

def pck_paths(blob: bytes):
    magic = blob.find(b"GDPC")
    if magic < 0:
        raise SystemExit(f"{target} has no Godot PCK header")
    version = struct.unpack_from("<I", blob, magic + 4)[0]
    if version < 2 or version > 4:
        raise SystemExit(f"{target} has unsupported PCK version {version}")
    if version >= 3:
        dir_offset = struct.unpack_from("<Q", blob, magic + 4 + 4 + 12 + 4 + 8)[0]
        pos = magic + dir_offset
    else:
        pos = magic + 4 + 4 + 12 + 4 + 8 + 64
    count = struct.unpack_from("<I", blob, pos)[0]
    pos += 4
    paths = []
    for _ in range(count):
        slen = struct.unpack_from("<I", blob, pos)[0]
        pos += 4
        paths.append(blob[pos:pos + slen].decode("utf-8", "replace").rstrip("\0"))
        pos += slen + 8 + 8 + 16 + 4
    return paths

if target.suffix == ".apk":
    with zipfile.ZipFile(target) as zf:
        names = zf.namelist()
elif target.suffix == ".pck":
    names = pck_paths(target.read_bytes())
else:
    raise SystemExit(f"Don't know how to read resources from {target}")

missing = [needle for needle in needles if not any(needle in name for name in names)]
if missing:
    raise SystemExit(f"{target.name} is missing packed project data: {', '.join(missing)}")

def pack_path(name: str) -> str:
    if name.startswith("res://"):
        name = name[len("res://"):]
    if name.startswith("assets/"):
        name = name[len("assets/"):]
    return name

if mode == "profile":
    blocked = ("tests/", "addons/gut/", "docs/", "tools/")
    if not any("scenes/debug/stress_test" in name for name in names):
        raise SystemExit(f"{target.name} is missing scenes/debug/stress_test")
else:
    blocked = ("tests/", "addons/gut/", "docs/", "tools/", "scenes/debug/")
leaked = sorted({name for name in names if pack_path(name).startswith(blocked)})
if leaked:
    preview = "\n".join(leaked[:20])
    raise SystemExit(f"{target.name} packed files that should stay out of the release:\n{preview}")
kept = "stress scene kept; tests, gut, docs, and tools are absent" if mode == "profile" else "tests, gut, docs, tools, and scenes/debug are absent"
print(f"{target.name} includes data/levels and assets ({len(names)} entries); {kept}")
PY
}

# Tag builds only. The committed preset stays at 0.1.0 / 1 for local exports
# and for workflow_dispatch. versionCode is major*10000+minor*100+patch so a
# higher semver always installs over an older one. minor and patch must be
# 0–99 or two tags could share a code (v0.2.100 and v0.3.0 would both be 300).
apply_tag_version() {
  local preset="$ROOT/export_presets.cfg"
  if [[ "${GITHUB_REF_TYPE:-}" != "tag" ]]; then
    note "Not a tag build. Leaving the export preset at version 0.1.0 / code 1."
    return
  fi
  local tag="${GITHUB_REF_NAME:-}"
  if [[ ! "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Tag '$tag' must be vMAJOR.MINOR.PATCH (for example v0.2.1). Pre-release suffixes are not accepted." >&2
    exit 1
  fi
  local major minor patch name code
  major=$((10#${BASH_REMATCH[1]}))
  minor=$((10#${BASH_REMATCH[2]}))
  patch=$((10#${BASH_REMATCH[3]}))
  if (( minor > 99 || patch > 99 )); then
    echo "Tag '$tag' has minor or patch above 99. versionCode is major*10000+minor*100+patch and would collide with another version." >&2
    exit 1
  fi
  name="${major}.${minor}.${patch}"
  code=$((major * 10000 + minor * 100 + patch))
  if (( code < 1 )); then
    echo "versionCode for $tag is 0. Play and the App Store require a positive integer." >&2
    exit 1
  fi
  note "Tag build: versionName ${name}, versionCode ${code} (major*10000+minor*100+patch). This working copy only."
  python3 - "$preset" "$name" "$code" << 'PY'
import pathlib, sys
path, name, code = sys.argv[1:]
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

text = set_line(text, "version/name", f'"{name}"')
text = set_line(text, "version/code", code)
text = set_line(text, "application/short_version", f'"{name}"')
text = set_line(text, "application/version", f'"{code}"')
pathlib.Path(path).write_text(text)
PY
}

resolve_artifact_tag() {
  if [[ -n "${ARTIFACT_TAG:-}" ]]; then
    printf '%s' "$ARTIFACT_TAG"
    return
  fi
  if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    printf '%s' "${GITHUB_REF_NAME}"
    return
  fi
  local sha="${GITHUB_SHA:-local}"
  printf 'manual-%s' "${sha:0:7}"
}

ensure_godot() {
  local version cache dest url bin template_dir
  version="$(godot_version)"
  cache="$(godot_cache_dir)"
  dest="$cache/editor"
  template_dir="$cache/templates"
  mkdir -p "$dest" "$template_dir"

  case "$(uname -s)" in
    Linux)
      url="https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip"
      bin="$dest/godot"
      ;;
    Darwin)
      url="https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_macos.universal.zip"
      ;;
    *)
      echo "Unsupported OS for Godot export: $(uname -s)" >&2
      exit 1
      ;;
  esac

  if [[ "$(uname -s)" == "Linux" && ! -x "$bin" ]]; then
    note "Downloading Godot ${version} editor"
    curl -fL --retry 3 -o "$cache/godot.zip" "$url"
    unzip -q -o "$cache/godot.zip" -d "$dest"
    mv "$dest/Godot_v${version}-stable_linux.x86_64" "$bin"
    chmod +x "$bin"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    bin="$(find_godot_macos_bin "$dest")"
    if [[ -z "$bin" ]]; then
      note "Downloading Godot ${version} editor"
      curl -fL --retry 3 -o "$cache/godot.zip" "$url"
      unzip -q -o "$cache/godot.zip" -d "$dest"
      if command -v xattr >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "$dest" || true
      fi
      bin="$(find_godot_macos_bin "$dest")"
      chmod +x "$bin"
    fi
  fi

  if [[ ! -f "$template_dir/android_release.apk" || ! -f "$template_dir/ios.zip" ]]; then
    note "Downloading Godot ${version} export templates"
    curl -fL --retry 3 -o "$cache/templates.tpz" \
      "https://github.com/godotengine/godot-builds/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz"
    rm -rf "$cache/tpz"
    mkdir -p "$cache/tpz"
    unzip -q -o "$cache/templates.tpz" -d "$cache/tpz"
    rm -rf "$template_dir"
    mkdir -p "$template_dir"
    if [[ -d "$cache/tpz/templates" ]]; then
      mv "$cache/tpz/templates/"* "$template_dir/"
    else
      mv "$cache/tpz/"* "$template_dir/"
    fi
  fi

  GODOT_BIN="$bin"
  GODOT_TEMPLATE_DIR="$template_dir"
  local ver_line template_version
  ver_line="$("$GODOT_BIN" --version)"
  note "Using $GODOT_BIN ($ver_line)"
  template_version="${ver_line%%.official*}"
  if [[ "$template_version" == "$ver_line" ]]; then
    template_version="${version}.stable"
  fi
  install_export_templates "$template_version"
}

install_export_templates() {
  local template_version="$1"
  local link_parent
  case "$(uname -s)" in
    Linux)
      export XDG_DATA_HOME="${XDG_DATA_HOME:-$ROOT/build/xdg/data}"
      export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$ROOT/build/xdg/config}"
      # Recreate editor settings from JAVA_HOME / ANDROID_HOME on this run.
      rm -rf "$XDG_CONFIG_HOME/godot"
      link_parent="$XDG_DATA_HOME/godot/export_templates"
      ;;
    Darwin)
      link_parent="$HOME/Library/Application Support/Godot/export_templates"
      ;;
    *)
      echo "Unsupported OS" >&2
      exit 1
      ;;
  esac
  mkdir -p "$link_parent"
  ln -sfn "$GODOT_TEMPLATE_DIR" "$link_parent/$template_version"
  note "Export templates -> $link_parent/$template_version"
}
