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
if [ -d "/opt/nvim-linux-x86_64/bin" ]; then
    PATH="/opt/nvim-linux-x86_64/bin:$PATH"
fi

if [ -d "$HOME/.wasmtime" ]; then
    export WASMTIME_HOME="$HOME/.wasmtime"
    PATH="$WASMTIME_HOME/bin:$PATH"
fi

if [ -d $HOME/images/wasi-sdk-33.0-x86_64-linux/bin ]; then
    PATH="$HOME/images/wasi-sdk-33.0-x86_64-linux/bin:$PATH"
fi

if [ -d $HOME/github/wasm-micro-runtime/product-mini/platforms/linux/build ]; then
    PATH="$HOME/github/wasm-micro-runtime/product-mini/platforms/linux/build:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ]; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

# set PATH so it includes binaries installed by "go install"
if [ -d "$HOME/go/bin" ]; then
    PATH="$HOME/go/bin:$PATH"
fi

if [ -f "$HOME/bin/clean-wsl-path.sh" ]; then
    . "$HOME/bin/clean-wsl-path.sh"
fi
