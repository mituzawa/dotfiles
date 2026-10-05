#!/bin/bash
# pkg-sync.sh
# Record the packages installed by hand through apt, snap, pipx and npm into
# packages/*.txt, and install them again on a new machine.
#
# Only names are recorded, never versions: the point is to get a new machine
# to the same set of tools, at their current versions. Applying only ever
# adds -- a package missing from a list is reported by diff, not removed.
#
#   pkg-sync.sh diff  [name ...]   show what differs (default, read-only)
#   pkg-sync.sh dump  [name ...]   this machine -> packages/*.txt
#   pkg-sync.sh apply [name ...]   packages/*.txt -> this machine

set -e

usage() {
    cat <<'EOF'
Usage: pkg-sync.sh [diff|dump|apply] [name ...]

  diff   Show what differs between packages/*.txt and this machine (default)
  dump   Write the packages installed on this machine into packages/*.txt
  apply  Install every listed package that is not installed yet

<name> is one of apt, snap, pip, npm. Every target is processed, in that
order, when no name is given.
EOF
}

if [ $# -gt 0 ]; then
    mode="$1"
    shift
else
    mode="diff"
fi

case "$mode" in
    diff | dump | apply) ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

# ~/bin is a symlink to this repository's bin/, so $0 has to be resolved
# physically -- "cd $(dirname $0)/.." would land in $HOME instead.
SCRIPT_PATH="$(readlink -f "$0")"
PACKAGES_DIR="$(dirname "$(dirname "$SCRIPT_PATH")")/packages"

# "<name>|<file under packages/>|<command that must exist>"
# apt comes first: it is what provides snapd, pipx and npm.
TARGETS=(
    "apt|packages.txt|apt-mark"
    "snap|snap-packages.txt|snap"
    "pip|pip-packages.txt|pipx"
    "npm|npm-global.txt|npm"
)

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
        echo "pkg-sync.sh: unknown target: $want" >&2
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

# Runs a command as root, without sudo when already root.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# --- current state, one entry per line, in the same format as the list ---

current_apt() {
    apt-mark showmanual | sort
}

# Snaps installed only because another snap needs them are left out: bases
# (core22, ...), snapd itself, content snaps without commands
# (gtk-common-themes, gnome-*), and anything another installed snap names as
# its default-provider (mesa-2404, cups for chromium). snapd brings those back
# on its own when the snap that wants them is installed.
current_snap() {
    local providers name notes yaml tracking
    providers="$(grep -h 'default-provider:' /snap/*/current/meta/snap.yaml 2>/dev/null |
        sed 's/.*default-provider: *//; s/:.*//' | sort -u)"
    snap list | awk 'NR > 1 { print $1, $6 }' |
        while read -r name notes; do
            case ",$notes," in
                *,base,* | *,snapd,*) continue ;;
            esac
            yaml="/snap/$name/current/meta/snap.yaml"
            if ! grep -q '^apps:' "$yaml" 2>/dev/null; then
                continue
            fi
            if grep -qx "$name" <<<"$providers"; then
                continue
            fi
            # "snap list" truncates long channels ("latest/stable/…").
            tracking="$(snap info "$name" | awk '$1 == "tracking:" { print $2 }')"
            case ",$notes," in
                *,classic,*) echo "$name $tracking classic" ;;
                *) echo "$name $tracking" ;;
            esac
        done | sort
}

current_pip() {
    pipx list --short 2>/dev/null | cut -d' ' -f1 | sort
}

current_npm() {
    local root
    root="$(npm root -g)"
    npm ls -g --depth=0 --parseable 2>/dev/null |
        sed -n "s|^$root/||p" | grep -vxE 'npm|corepack' | sort || true
}

# --- the list, with comments and blank lines dropped ---

listed() {
    sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$1" | sort
}

# --- installers: given the missing entries on stdin ---

install_apt() {
    local pkg installable=()
    while read -r pkg; do
        if apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
            installable+=("$pkg")
        else
            echo "SKIP (no candidate; add its apt source first): $pkg"
        fi
    done
    if [ ${#installable[@]} -gt 0 ]; then
        as_root apt-get install -y "${installable[@]}"
    fi
}

install_snap() {
    local name channel classic
    while read -r name channel classic; do
        as_root snap install "$name" ${channel:+--channel="$channel"} \
            ${classic:+--classic} </dev/null
    done
}

install_pip() {
    local name
    while read -r name; do
        pipx install "$name" </dev/null
    done
}

install_npm() {
    local names=()
    mapfile -t names
    if [ -w "$(npm config get prefix)/lib" ]; then
        npm install -g "${names[@]}"
    else
        as_root npm install -g "${names[@]}"
    fi
}

# --- modes ---

# The lines of $2 that are not in $1, both sorted.
only_in() {
    comm -13 <(printf '%s\n' "$1" | sed '/^$/d') <(printf '%s\n' "$2" | sed '/^$/d')
}

do_diff() {
    local name="$1" file="$2"
    local want have
    if [ ! -e "$file" ]; then
        echo "ABSENT IN REPO:    $name"
        return
    fi
    want="$(listed "$file")"
    have="$("current_$name")"
    if [ "$want" = "$have" ]; then
        echo "SAME:    $name"
        return
    fi
    echo "DIFF:    $name"
    only_in "$have" "$want" | sed 's/^/  - not installed: /'
    only_in "$want" "$have" | sed 's/^/  + not listed:    /'
}

do_dump() {
    local name="$1" file="$2"
    local have
    have="$("current_$name")"
    if [ -e "$file" ] && [ "$(cat "$file")" = "$have" ]; then
        echo "SAME:    $name"
        return
    fi
    mkdir -p "$(dirname "$file")"
    printf '%s\n' "$have" >"$file"
    echo "DUMP:    $name -> packages/$(basename "$file")"
}

do_apply() {
    local name="$1" file="$2"
    local missing
    if [ ! -e "$file" ]; then
        echo "SKIP (not found in repo): $name"
        return
    fi
    missing="$(only_in "$("current_$name")" "$(listed "$file")")"
    # snap lines carry a channel, so compare on the name alone: a snap that
    # tracks another channel than the list is installed, not missing.
    if [ "$name" = snap ] && [ -n "$missing" ]; then
        missing="$(awk 'NR == FNR { have[$1]; next } !($1 in have)' \
            <(current_snap) - <<<"$missing")"
    fi
    if [ -z "$missing" ]; then
        echo "SAME:    $name"
        return
    fi
    echo "APPLY:   $name: $(echo "$missing" | awk '{ print $1 }' | tr '\n' ' ')"
    "install_$name" <<<"$missing"
}

for target in "${TARGETS[@]}"; do
    name="${target%%|*}"
    rest="${target#*|}"
    file="$PACKAGES_DIR/${rest%%|*}"
    cmd="${rest#*|}"
    if ! wanted "$name"; then
        continue
    fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "SKIP ($cmd not found): $name"
        continue
    fi
    "do_$mode" "$name" "$file"
done
