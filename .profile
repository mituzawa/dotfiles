# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# added begin
# WASMTIME_HOME is exported here rather than beside its PATH entry, and that
# entry is written as ${WASMTIME_HOME:+...} so an unset value contributes
# nothing: a bare "$WASMTIME_HOME/bin" expands to "/bin", which exists and would
# silently join the list.
if [ -d "$HOME/.wasmtime" ]; then
    export WASMTIME_HOME="$HOME/.wasmtime"
fi

# The WASI SDK deliberately stays off PATH. Its bin/ ships clang, clang++ and
# LLVM binutils under the plain names ar, nm, objcopy, objdump, ranlib, size,
# strings and strip, so putting it ahead of /usr/bin made "clang foo.c" emit a
# WebAssembly module instead of an ELF binary -- bin/clang.cfg pins the target
# to wasm32-unknown-wasip1. Build systems read WASI_SDK_PATH; anything else
# should spell out "$WASI_SDK_PATH/bin/clang".
if [ -d "$HOME/images/wasi-sdk-33.0-x86_64-linux" ]; then
    export WASI_SDK_PATH="$HOME/images/wasi-sdk-33.0-x86_64-linux"
fi

# _path_add tests the directory it is about to add, so the two can never drift
# apart the way a hand-written "if [ -d A ]; then PATH=B:$PATH; fi" pair can.
_path_add() {
    if [ -d "$1" ]; then
        _path_head="${_path_head:+$_path_head:}$1"
    fi
}

# Highest priority first -- this list reads in the same order as the resulting
# PATH, so a new entry goes at the position it should occupy. The whole set is
# prepended to the inherited PATH in one step below.
_path_head=""
_path_add "$HOME/bin"                                                          # dotfiles bin/, symlinked by setup.sh
_path_add "$HOME/.local/bin"                                                   # pip / user-local installs
_path_add "$HOME/go/bin"                                                       # "go install" output
_path_add "$HOME/github/wasm-micro-runtime/product-mini/platforms/linux/build" # iwasm
_path_add "${WASMTIME_HOME:+$WASMTIME_HOME/bin}"                               # wasmtime
_path_add "/opt/nvim-linux-x86_64/bin"                                         # Neovim

PATH="${_path_head:+$_path_head:}$PATH"

unset -f _path_add
unset _path_head

# .bashrc defines "view" only when nvim is on PATH, but it ran before the list
# above -- the Neovim entry is what puts nvim there. Re-run its guard now that
# PATH is final; a non-login shell already inherited PATH and did this itself.
if command -v _view_alias >/dev/null 2>&1; then
    _view_alias
    unset -f _view_alias
fi

if [ -f "$HOME/bin/clean-wsl-path.sh" ]; then
    . "$HOME/bin/clean-wsl-path.sh"
fi
