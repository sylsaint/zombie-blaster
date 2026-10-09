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
