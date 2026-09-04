#!/bin/bash
# win-sync.sh
# Copy the Windows-side dotfiles in this repository to and from their real
# locations on C:.
#
# These targets cannot be symlinked the way setup.sh links the Linux ones:
#   - .wslconfig is read by the WSL service *before* the distribution starts,
#     so a link pointing into \\wsl.localhost\<distro>\... is a chicken-and-egg
#     problem.
#   - Windows Terminal and VS Code rewrite their own settings when the GUI is
#     used, and Windows applications typically write a temp file and rename it
#     over the destination -- which replaces a symlink with a real file and
#     silently breaks the link.
# Copying in both directions avoids both, and makes "the application changed
# its settings" a case the tool handles (pull) rather than a failure mode.
#
#   win-sync.sh diff [name ...]   show what differs (default, read-only)
#   win-sync.sh pull [name ...]   Windows -> repository
#   win-sync.sh push [name ...]   repository -> Windows

set -e

usage() {
    cat <<'EOF'
Usage: win-sync.sh [diff|pull|push] [name ...]

  diff   Show what differs between the repository and Windows (default)
  pull   Copy from Windows into the repository
  push   Copy from the repository out to Windows

<name> is a path under windows/, e.g. wezterm/wezterm.lua. Every target is
processed when no name is given.
EOF
}

if [ $# -gt 0 ]; then
    mode="$1"
    shift
else
    mode="diff"
fi

case "$mode" in
    diff | pull | push) ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

if [ -z "$WSL_DISTRO_NAME" ]; then
    echo "win-sync.sh: this only runs inside WSL" >&2
    exit 1
fi

if ! command -v wslvar >/dev/null 2>&1; then
    echo "win-sync.sh: wslvar not found; install the wslu package" >&2
    exit 1
fi

# ~/bin is a symlink to this repository's bin/, so $0 has to be resolved
# physically -- "cd $(dirname $0)/.." would land in $HOME instead.
SCRIPT_PATH="$(readlink -f "$0")"
WINDOWS_DIR="$(dirname "$(dirname "$SCRIPT_PATH")")/windows"

# wslvar reaches the Windows environment through a Windows process, so its
# output carries a trailing CR.
win_dir() {
    local value
    value="$(wslvar "$1" 2>/dev/null | tr -d '\r')"
    if [ -z "$value" ]; then
        echo "win-sync.sh: cannot read %$1% from Windows" >&2
        return 1
    fi
    wslpath -u "$value"
}

USERPROFILE_DIR="$(win_dir USERPROFILE)"
APPDATA_DIR="$(win_dir APPDATA)"
LOCALAPPDATA_DIR="$(win_dir LOCALAPPDATA)"

# "<path under windows/>|<absolute destination>"
TARGETS=(
    ".wslconfig|$USERPROFILE_DIR/.wslconfig"
    "wezterm/wezterm.lua|$USERPROFILE_DIR/.config/wezterm/wezterm.lua"
    "wezterm/keybinds.lua|$USERPROFILE_DIR/.config/wezterm/keybinds.lua"
    "vscode/settings.json|$APPDATA_DIR/Code/User/settings.json"
)

# The Windows Terminal package directory is named after the build (Store,
# Preview, ...), so resolve it instead of hard-coding one.
wt_state=""
for _dir in "$LOCALAPPDATA_DIR"/Packages/Microsoft.WindowsTerminal*/LocalState; do
    if [ -d "$_dir" ]; then
        wt_state="$_dir"
        break
    fi
done
if [ -n "$wt_state" ]; then
    TARGETS+=("windows-terminal/settings.json|$wt_state/settings.json")
else
    echo "SKIP (Windows Terminal not installed): windows-terminal/settings.json"
fi

selected=("$@")

for want in "${selected[@]}"; do
    found=""
    for target in "${TARGETS[@]}"; do
        if [ "${target%%|*}" = "$want" ]; then
            found="yes"
            break
        fi
    done
    if [ -z "$found" ]; then
        echo "win-sync.sh: unknown target: $want" >&2
        echo "Known targets:" >&2
        printf '  %s\n' "${TARGETS[@]%%|*}" >&2
        exit 1
    fi
done

wanted() {
    local name="$1"
    local want
    if [ ${#selected[@]} -eq 0 ]; then
        return 0
    fi
    for want in "${selected[@]}"; do
        if [ "$want" = "$name" ]; then
            return 0
        fi
    done
    return 1
}

# VS Code and wezterm keep their files in CRLF, Windows Terminal in LF. The
# repository keeps LF throughout, so the Windows side goes through this before
# it is compared or stored -- otherwise every save on the Windows side would
# show up as a whole-file diff.
strip_cr() {
    sed 's/\r$//' "$1"
}

do_diff() {
    local src="$1" dst="$2" name="$3"

    if [ ! -e "$dst" ]; then
        echo "ABSENT ON WINDOWS: $name ($dst)"
        return
    fi
    if [ ! -e "$src" ]; then
        echo "ABSENT IN REPO:    $name"
        return
    fi
    if cmp -s <(strip_cr "$src") <(strip_cr "$dst"); then
        echo "SAME:    $name"
    else
        echo "DIFF:    $name"
        diff -u --label "windows/$name" --label "$dst" \
            <(strip_cr "$src") <(strip_cr "$dst") || true
    fi
}

do_pull() {
    local src="$1" dst="$2" name="$3"

    if [ ! -e "$dst" ]; then
        echo "SKIP (not found on Windows): $name"
        return
    fi
    if [ -e "$src" ] && cmp -s "$src" <(strip_cr "$dst"); then
        echo "SAME:    $name"
        return
    fi
    mkdir -p "$(dirname "$src")"
    strip_cr "$dst" >"$src"
    echo "PULL:    $dst -> windows/$name"
}

do_push() {
    local src="$1" dst="$2" name="$3"
    local org="${dst}_ORG"

    if [ ! -e "$src" ]; then
        echo "SKIP (not found in repo): $name"
        return
    fi
    if [ -e "$dst" ] && cmp -s "$src" <(strip_cr "$dst"); then
        echo "SAME:    $name"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ]; then
        if [ -e "$org" ]; then
            # _ORG already exists; keep the first backup and overwrite
            echo "SKIP BACKUP (_ORG already exists): $name"
        else
            echo "BACKUP:  $dst -> $org"
            # No -p: DrvFs cannot take the ownership cp would try to preserve.
            cp "$dst" "$org"
        fi
    fi
    cp "$src" "$dst"
    echo "PUSH:    windows/$name -> $dst"
}

for target in "${TARGETS[@]}"; do
    name="${target%%|*}"
    dst="${target#*|}"
    if wanted "$name"; then
        "do_$mode" "$WINDOWS_DIR/$name" "$dst" "$name"
    fi
done
