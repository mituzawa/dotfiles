# dotfiles

Personal dotfiles for a Linux/WSL2 environment: bash, Neovim, a handful of shell utilities under `bin/`, and the Windows-side settings under `windows/`.

`CLAUDE.md` is the reference for *why* things are the way they are — the `PATH` ordering, the fzf and ssh-agent blocks, the Neovim plugin stack, the format-on-save traps. This file only covers getting a new machine back to a working state.

| | |
|---|---|
| `.bashrc`, `.profile`, `.gitconfig`, `.clang-format`, `.vimrc`, `.vim` | linked into `$HOME` by `setup.sh` |
| `bin/` | linked as `~/bin`, first on `PATH` |
| `nvim/` | linked as `~/.config/nvim` |
| `windows/` | copied to the Windows side by `bin/win-sync.sh` |
| `etc/` | reference copies, deployed by hand |

## Restoring on a new machine

### 1. Windows side

WSL2 with Ubuntu 24.04. Install **JetBrainsMono Nerd Font** on Windows before anything else: both the Windows Terminal Ubuntu profile and wezterm name that face, and without it they fall back silently and nvim-web-devicons render as boxes. wezterm is optional — nothing depends on it — but its config is in `windows/` and will be restored in step 8.

### 2. apt packages

```sh
sudo apt update
sudo apt install -y git curl build-essential bash-completion fzf fd-find jq wslu
```

- `fd-find` installs the binary as **`fdfind`**, which is the name `.bashrc`'s fzf block keys on. Do not rename it.
- `wslu` provides `wslvar` and `wslview`. `bin/win-sync.sh` needs the former and `.bashrc` sets `BROWSER=wslview`.
- `fzf` from apt is 0.44, which predates `fzf --bash`; `.bashrc` sources the two integration files by path and accounts for Debian putting the completion outside `examples/`.

### 3. Clone and link

```sh
git clone https://github.com/mituzawa/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
exec bash -l
```

HTTPS on purpose — the SSH remote needs a key that is deliberately not in this repository. Step 7 switches the remote over.

`setup.sh` symlinks each entry of its `TARGETS` list into `$HOME`, backing up any pre-existing **real** file as `<name>_ORG` (the distro skeletons land there on a fresh install; delete them once the shell looks right). `exec bash -l` is what makes `.profile` rebuild `PATH`, which is how `~/bin` gets ahead of everything else.

### 4. Neovim

```sh
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
```

`/opt/nvim-linux-x86_64/bin` is the one path `.profile` adds for Neovim, so install it there rather than elsewhere. The `view='nvim -R'` alias appears once that entry exists.

### 5. Deno

```sh
curl -fsSL https://deno.land/install.sh | sh
```

Not optional. The plugin manager (dpp.vim) runs `nvim/config.ts` through denops.vim, which is a Deno process — without `deno` on `PATH` the plugin state is never built and nothing loads. The installer writes `~/.deno/env`, which `.bashrc` sources.

### 6. First Neovim start

`lua/darkpowerd/dpp.lua` clones dpp.vim, denops.vim and the five dpp extensions into `~/.cache/nvim/dpp/repos/github.com/` by itself, so the first `nvim` is slow and may report errors before the state cache exists. Then, inside Neovim:

```vim
:DppMakeState
:DppInstall
```

Restart, and install the formatter binaries mason does not pull in as an LSP dependency:

```vim
:MasonInstall prettierd biome djlint mdformat yamlfix shfmt
```

The LSP servers (`lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls`, `pyright`) install themselves through mason-lspconfig's `automatic_enable`, and `clang-format` and `stylua` arrive with them. `jq` comes from apt in step 2.

State can also be rebuilt without an interactive session, which is what to use after editing the TOML files from a shell:

```sh
nvim --headless -c 'autocmd User Dpp:makeStatePost qall!' \
  -c 'call dpp#make_state(stdpath("cache").."/dpp", stdpath("config").."/config.ts")'
```

`bin/init-dpp.sh` predates all of this and clones into `~/.cache/dpp/`, a path nothing reads (`stdpath("cache")` is `~/.cache/nvim`). Do not run it.

### 7. SSH key and the git remote

```sh
ssh-keygen -t ed25519 -C mituzawa@gmail.com
```

`~/.ssh/config` is **not** in this repository. Write the github.com stanza by hand:

```
Host github.com
	HostName github.com
	User git
	IdentityFile "~/.ssh/id_ed25519"
```

Add the public key to GitHub, then switch the remote and check it:

```sh
git -C ~/dotfiles remote set-url origin git@github.com:mituzawa/dotfiles.git
ssh -T git@github.com    # Hi mituzawa! You've successfully authenticated, ...
```

The key has a passphrase. `.bashrc` pins the agent socket to `~/.ssh/agent.sock` so one agent serves every shell; type the passphrase once per WSL boot:

```sh
ssh-add ~/.ssh/id_ed25519
```

### 8. Windows-side settings

```sh
win-sync.sh diff    # read-only: what the new machine has vs. this repository
win-sync.sh push    # repository -> Windows
```

This restores `.wslconfig`, the Windows Terminal settings, the wezterm config and the VS Code settings. `push` backs each destination up as `<name>_ORG`; on a machine that was never pulled from, keep those until the result looks right, then delete them.

`.wslconfig` only takes effect after `wsl --shutdown` from PowerShell. Note that its values are this machine's — 8GB / 4 processors / 2GB swap — so check them against the new host before shutting down.

### 9. Optional extras

None of these are needed for the shell or Neovim to work; they exist because `.profile` and the keymaps reference them.

| | |
|---|---|
| lazygit (`,ug`) | `go install github.com/jesseduffield/lazygit@latest` → `~/go/bin` |
| Node.js | mason's `prettierd` and `biome` are npm packages |
| Rust | `rustup`; writes `~/.cargo/env`, which `.bashrc` sources, and backs `rust_analyzer` |
| WASI SDK | unpack to `~/images/wasi-sdk-33.0-x86_64-linux`; `.profile` exports `WASI_SDK_PATH` and keeps its `bin/` **off** `PATH` on purpose |
| wasmtime | installs to `~/.wasmtime`; `.profile` adds its `bin/` only when the directory exists |
| VS Code | `bin/code` shims the Windows launcher, because the `PATH` space filter removes it |

## Verifying

```sh
exec bash -l
echo "$PATH" | tr : '\n' | head -6   # ~/bin, ~/.local/bin, ~/go/bin, ... , /opt/nvim-linux-x86_64/bin
command -v nvim deno fzf fdfind jq wslvar
ssh -T git@github.com
win-sync.sh diff                     # every target SAME
```

In Neovim: `,uc` opens the ddu file finder, `,uj` toggles nvim-tree with icons, `:checkhealth` reports denops as running, and saving a file in this repository produces no diff (the tree is already formatted with the configured formatters).
