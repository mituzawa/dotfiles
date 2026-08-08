# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
# Raised from the Debian skeleton's 1000/2000 to give fzf's CTRL-R something to
# search: the 1:2 ratio is kept, so the file holds roughly two sessions' worth
# more than one shell keeps in memory.
HISTSIZE=10000
HISTFILESIZE=20000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
    xterm* | rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *)
        ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

export BROWSER=wslview

# Keystone
export KEYSTONE=$HOME/github/keystone
export KEYSTONE_BOOTROM=$HOME/github/keystone/bootrom
export KEYSTONE_SM=$HOME/github/keystone/sm
export KEYSTONE_SDK=$HOME/github/keystone/sdk
export KEYSTONE_RUNTIME=$HOME/github/keystone/runtime
export KEYSTONE_DRIVER=$HOME/github/keystone/linux-keystone-driver
export KEYSTONE_EXAMPLES=$HOME/github/keystone/examples
export BUILDROOT_BUILDDIR=$HOME/github/keystone/build-generic64/buildroot.build

case "$(uname -m)" in
    riscv64)
        # risc-v machine
        export TZ='Asia/Tokyo'
        ;;
esac

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# my aliases
alias view='nvim -R'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# fzf. The apt package is 0.44, which predates "fzf --bash", so the two
# integration files are sourced by path instead. They belong here rather than
# in .profile: both are interactive-only (they return early otherwise), and
# completion.bash wraps the completions already installed, so it has to run
# after the bash-completion block above.
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline --cycle"

    # fd is packaged as fdfind on Debian/Ubuntu. Using it over the bundled find
    # walk is what skips .gitignore matches; --hidden and --follow put back the
    # dotfiles and symlinks find would have listed, and --exclude .git keeps
    # --hidden from dumping the object store.
    if command -v fdfind >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fdfind --type f --type l --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND='fdfind --hidden --follow --exclude .git'
        export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'

        # The ** trigger does not read the variables above; it calls these two
        # hooks, which completion.bash only defines if they do not exist yet.
        # Spelled out rather than built from a shared variable, because the
        # bodies are expanded at call time -- a variable would have to outlive
        # this block.
        _fzf_compgen_path() { fdfind --hidden --follow --exclude .git . "$1"; }
        # The trailing slash fd puts on a directory is right for _fzf_compgen_path
        # -- that completion appends nothing, and "-o nospace" then lets the next
        # ** keep descending. _fzf_dir_completion appends a "/" of its own, though,
        # so cd/pushd/rmdir would be handed "./nvim//" without stripping it here.
        _fzf_compgen_dir() { fdfind --type d --hidden --follow --exclude .git . "$1" | command sed 's|/$||'; }
    fi

    # {} arrives shell-quoted, so the directory test and head both stay safe on
    # paths with spaces.
    export FZF_CTRL_T_OPTS="--preview 'if [ -d {} ]; then ls -A --color=always {}; else head -200 {} 2>/dev/null; fi' --preview-window=right:60%:wrap"
    export FZF_ALT_C_OPTS="--preview 'ls -A --color=always {}' --preview-window=right:50%"
    # History lines are often longer than the window; ? unfolds the selection.
    export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:hidden:wrap --bind '?:toggle-preview'"

    # CTRL-T paste path, CTRL-R search history, ALT-C cd into subdirectory.
    if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
        . /usr/share/doc/fzf/examples/key-bindings.bash
    fi
    # Debian ships fzf's completion.bash here, not under examples/. Sourcing it
    # by hand rather than leaving it to bash-completion's lazy loader, which
    # would only fire on "fzf<TAB>" and never install the ** trigger for other
    # commands.
    if [ -f /usr/share/bash-completion/completions/fzf ]; then
        . /usr/share/bash-completion/completions/fzf
    fi
fi

if [ -f $HOME/.cargo/env ]; then
    . $HOME/.cargo/env
fi

if [ -f $HOME/.deno/env ]; then
    . $HOME/.deno/env
fi

if [ -f $HOME/.local/share/bash-completion/completions/deno.bash ]; then
    source $HOME/.local/share/bash-completion/completions/deno.bash
fi

# Reuse one ssh-agent across shells via a fixed socket path, so the github.com
# key's passphrase only has to be typed once per WSL boot:
#   ssh-add ~/.ssh/id_ed25519
# ssh-add -l exits 2 when no agent answers, and 1 when one is running but holds
# no keys -- only the former should spawn a replacement.
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
ssh-add -l >/dev/null 2>&1
if [ $? -eq 2 ]; then
    rm -f "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1
fi
