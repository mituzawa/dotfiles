# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Personal dotfiles for a Linux/WSL2 environment. The Neovim config is the most structured part; shell configs and scripts live at the repo root and in `bin/`.

The dotfiles are deployed by symlinking into the home directory via `setup.sh`, which reads the `TARGETS` list (`.bashrc`, `.profile`, `.gitconfig`, `.clang-format`, `.vimrc`, `.vim`, `bin`, `nvim:.config/nvim`) and backs up any pre-existing real file as `<name>_ORG`. `~/.config/nvim/` corresponds to `nvim/` in this repo (e.g. `~/.config/nvim/toml/` → `dotfiles/nvim/toml/`).

`windows/` is outside all of that: those files belong on the Windows side of WSL, cannot be symlinked there, and are copied by `bin/win-sync.sh` instead. See [Windows-side configuration](#windows-side-configuration-windows-binwin-syncsh).

## Neovim configuration architecture

The plugin stack is built on two layers:

- **denops.vim** — Deno runtime bridge that allows TypeScript/JavaScript plugin code to run inside Neovim.
- **dpp.vim** — "dark powered" plugin manager that uses denops to run `config.ts` at startup.

### Bootstrap flow

1. `nvim/init.lua` requires `option/option` (editor options) then `darkpowerd/dpp`.
1. `lua/darkpowerd/dpp.lua` bootstraps: auto-clones `dpp.vim` and `denops.vim` into `~/.cache/nvim/dpp/` if absent, adds them to runtimepath, then loads the cached plugin state from `~/.cache/nvim/dpp/`.
1. On first run (or after `:DppMakeState`), `config.ts` is invoked via denops. It reads `toml/dein.toml` (eager plugins) and `toml/dein_lazy.toml` (lazy-loaded by filetype), plus any plugins found under `~/work/` (local development).
1. The generated state is persisted to disk; subsequent startups load it directly without re-running TypeScript.

### Key plugin management commands

| Command | Purpose |
|---|---|
| `:DppInstall` | Install all plugins listed in the TOML files |
| `:DppUpdate [name ...]` | Update all plugins (or named ones) |
| `:DppMakeState` | Regenerate the plugin state cache after changing TOML files |

### Adding or removing plugins

Edit `nvim/toml/dein.toml` (load on startup) or `nvim/toml/dein_lazy.toml` (load on filetype). After saving, run `:DppMakeState` inside Neovim, then `:DppInstall` if adding new repos.

Removing a plugin from the TOML and regenerating the state drops it from the runtimepath, but its clone stays under `~/.cache/nvim/dpp/repos/github.com/`; delete that directory by hand to reclaim the space.

State can also be regenerated without an interactive session, which is useful after editing the TOML files from a shell:

```sh
nvim --headless -c 'autocmd User Dpp:makeStatePost qall!' \
  -c 'call dpp#make_state(stdpath("cache").."/dpp", stdpath("config").."/config.ts")'
```

### Lua module layout

```
nvim/lua/
  darkpowerd/   dpp.lua (bootstrap), ddu.lua (fuzzy finder config)
  option/       option.lua (editor settings), cmd.lua, colorscheme.lua, cd.lua
  keymap/       keymap.lua (leader mappings), yankround.lua
  plugins/      lspconfig.lua, formatter.lua, nvim-tree.lua, autocmd.lua, claude_transcript.lua
```

`init.lua` requires every module under `lua/`: `option/option`, `option/cd`, `darkpowerd/dpp`, `darkpowerd/ddu`, `keymap/keymap`, `keymap/yankround`, `plugins/lspconfig`, `plugins/formatter`, `plugins/nvim-tree`, `plugins/autocmd` and `plugins/claude_transcript`. Nothing is commented out any more. Note `init.lua` wraps everything in `if not vim.g.vscode`, so nothing loads under vscode-neovim.

### Format-on-save

`lua/plugins/autocmd.lua` registers a single `BufWritePost` → `:FormatWrite` autocmd inside the `format_on_save` augroup (`clear = true`, so `,r` re-sourcing `init.lua` cannot register duplicates). Its `pattern` is `"*"` on purpose: `lua/plugins/formatter.lua` is the single source of truth for which filetypes get formatted, and formatter.nvim returns early with "No formatter defined" for anything else.

To suppress formatting for one buffer — useful in other people's repos, where these formatters will happily rewrite a whole file with their own defaults:

```vim
:let b:formatter_skip_buf = v:true
```

The external binaries come from mason. Re-create them on a fresh machine with:

```
:MasonInstall prettierd biome djlint mdformat yamlfix shfmt
```

`clang-format` and `stylua` are pulled in as LSP/tooling dependencies already; `jq` comes from the system. mason prepends `~/.local/share/nvim/mason/bin` to `PATH`, so `vim.fn.jobstart` resolves all of them without extra configuration.

Shell scripts (`setup.sh`, `.bashrc`, `.profile`, everything under `bin/`) all resolve to `filetype=sh`, so the single `sh` entry covers them; there is no `bash` filetype in play and `formatter.filetypes.bash` does not exist. shfmt runs with `-ci` because these scripts indent their `case` patterns (the Debian skeleton style) and shfmt flattens them to the `case` column without it. The tree was formatted once with `shfmt -w -ci -i 4`, so saving any of them should now produce no diff.

Three traps worth remembering when editing `formatter.lua`:

- `require("formatter.filetypes.<ft>").<tool>` returns `nil` when that module does not export the tool, and a table holding only `nil` counts as empty — the result is a silent "No formatter defined". `formatter.filetypes.html` has no `djlint` (only prettier variants and `tidy`), so html pulls it from `formatter.defaults` instead.
- A formatter invoked with `stdin = true` must actually be told to read stdin. `mdformat` without a trailing `-` prints a warning to stderr and exits 0, which formatter.nvim reads as success and quietly does nothing.
- `formatter.filetypes.sh.shfmt` passes `vim.opt.shiftwidth:get()` straight to `shfmt -i`. `option.lua` sets `shiftwidth = 0` (follow `tabstop`), so the builtin would emit `-i 0`, meaning tab indentation, in a config where `expandtab` is on. The `sh` entry therefore calls `vim.fn.shiftwidth()`, which resolves 0 to the effective width (4).

`logging = true` with `log_level = vim.log.levels.ERROR` keeps normal saves silent while still surfacing formatter failures; setting `logging = false` suppresses errors too (`log.lua:57-66`).

`nvim/.stylua.toml` pins `column_width = 160` so the long single-line `vim.keymap.set(...)` calls in `keymap.lua` survive stylua's default 120-column wrapping.

### Filer (nvim-tree)

nvim-tree is the only file explorer. `lua/plugins/nvim-tree.lua` disables netrw, shows dotfiles, and uses a 30-column drawer; icons come from `nvim-web-devicons`. `,uj` toggles it, revealing the current file when the buffer holds a real file.

fern.vim (plus nerdfont.vim, fern-renderer-nerdfont.vim and glyph-palette.vim) was removed in favour of nvim-tree, because `claudecode.nvim` dispatches on filetype and only supports `NvimTree`, `neo-tree`, `oil`, `minifiles`, `netrw` and `snacks_picker_list` — `,at` (`ClaudeCodeTreeAdd`) could never work from a fern buffer.

### Fuzzy finder (ddu.vim)

`lua/darkpowerd/ddu.lua` configures the ddu fuzzy finder using `,u` as a prefix: `,uc` file_rec, `,uf` file, `,ub` buffers, `,um` MRU, `,ur` registers, `,up` file_point, `,un` new file, `,ul` colorscheme. It sets a floating ff UI with automatic preview and devicon converters, and binds `<CR>` / `q` / `<Space>` / `i` / `P` inside `ddu-ff` buffers.

`keymap.lua` also maps `,u` itself to `<Nop>`, which coexists with the longer mappings — pressing `,u` alone just waits out `timeoutlen` and does nothing. Note `init.lua` loads `darkpowerd/ddu` before `keymap/keymap`, so `,uj` and `,ug` from the latter sit alongside ddu's mappings rather than replacing them.

ddu accounts for 16 of the 35 plugin entries in `dein.toml` — each source, filter and kind is its own repository. `fall.vim` is also installed but has no config; it and `snacks.nvim`'s picker (already present as a claudecode.nvim dependency) are the alternatives if that count ever becomes a problem.

### Keymaps (`lua/keymap/keymap.lua`)

| Mapping | Action |
|---|---|
| `,r` | Re-source `init.lua` |
| `,uj` | Toggle nvim-tree (reveals current file) |
| `,ug` | `:LazyGit` |
| `,ac` / `,af` | Claude Code toggle / focus |
| `,ar` / `,ak` | Resume Claude session (`--resume`, picker) / continue the latest one (`--continue`) |
| `,ab` / `,at` | Add current buffer / file under tree cursor to Claude |
| `,al` | `:ClaudeLog` — read back the Claude pane's scrollback (`lua/plugins/claude_transcript.lua`) |
| `,as` (visual) | Send selection to Claude |
| `<Space>cd` | `:CD` — `lcd` to the current file's directory (`lua/option/cd.lua`) |
| `p` / `P` | Paste through yankround |
| `<C-p>` / `<C-n>` | Cycle backwards / forwards through the yank history (`lua/keymap/yankround.lua`) |

`<C-p>` and `<C-n>` have no default *mapping*, but they are default *motions* (up/down a line, like `k`/`j`); yankround takes them over in normal mode. Insert-mode completion is untouched, since `yankround.lua` only maps normal mode. Note that `plugin/yankround.vim` records the yank history whether or not these mappings exist, so the history already had entries before they were enabled.

`:ClaudeCode` takes `nargs = "*"` and appends whatever it is given to the `claude` binary (`terminal.lua:356`), so any CLI flag can be bound this way. Sessions are stored per working directory under `~/.claude/projects/<slugified-cwd>/`; `git_repo_cwd = true` in the `dein.toml` hook makes the terminal spawn at the git root (`terminal.lua:263-266`), so history is shared no matter which subdirectory Neovim was started from. All three of `,ac` / `,af` / `,ar` are toggles — arguments only take effect when the terminal is actually being spawned, so pressing them while it is open just hides the window.

**`claudecode.setup()` silently discards misplaced keys.** `split_side`, `split_width_percentage`, `git_repo_cwd`, `auto_close`, `auto_insert` and `snacks_win_opts` all belong inside `terminal = { ... }`; `track_selection`, `diff_opts`, `terminal_cmd`, `env` and `models` are top-level. `config.lua` validates only the keys it knows about, and `init.lua` forwards nothing but `opts.terminal` to the terminal module, so a key at the wrong depth produces no warning — the default just quietly applies. All three of the split options had been sitting at the top level, which is why the pane used the 0.30 default instead of the 0.35 written in the hook. To check what actually took effect:

```vim
:lua print(vim.inspect(require("claudecode").state.config.terminal))
```

### Reading back the Claude pane (`:ClaudeLog`, `,al`)

**The Claude Code pane has no scrollback in nvim's sense.** It emits `ESC[?1049h` at startup, so it runs on the alternate screen: the terminal buffer only ever holds the frame currently on display. `<C-\><C-n>` followed by `k` therefore has nothing above it to reach, and this is structural, not a misconfiguration — `,ug` (LazyGit) behaves the same way.

Claude Code also enables mouse reporting (`ESC[?1000h`, `?1002h`, `?1003h`, `?1006h`), so nvim forwards wheel events to it rather than scrolling the buffer. That happens regardless of `'mouse'`, but with `mouse = ""` (which `option.lua` sets) nvim never asks the outer terminal to report the wheel in the first place, so nothing arrives to forward.

`lua/plugins/claude_transcript.lua` reads the conversation off disk instead. Sessions live at `~/.claude/projects/<slugified-cwd>/<session-uuid>.jsonl`, one JSON object per line:

- The slug is the directory Claude started in with every non-alphanumeric character replaced by `-`, so `/home/mituzawa/dotfiles` becomes `-home-mituzawa-dotfiles`. It resolves the **git root**, since `git_repo_cwd = true` is what the terminal spawns at.
- The current session is just the most recently modified `.jsonl` in that directory; `--resume` and `--continue` keep appending to the file they reopened.
- `:ClaudeLog` renders `user` and `assistant` records into a markdown scratch buffer in a new tab and lands on the last line. `:ClaudeLog!` opens the raw `.jsonl` instead. Both are opened `modifiable = false` + `readonly = true` — the raw one especially, since it is a real file that the running session is still appending to.

Two things the format forces:

- `thinking` blocks are stored with the text stripped — only `signature` survives — so they are skipped rather than rendered as empty markers.
- Truncation of tool arguments and results counts characters via `strcharpart`, not bytes. `string.sub` cuts multibyte characters in half, and the resulting invalid UTF-8 is enough to make GNU grep stop matching the buffer's text.

### LSP

`lua/plugins/lspconfig.lua` sets up mason.nvim + mason-lspconfig for automatic LSP server installation, enabling `lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls` and `pyright` through `automatic_enable`.

**No LSP keymaps are defined here.** Neovim 0.11+ ships its own and they are what actually take effect: `grn` rename, `gra` code action, `grr` references, `gri` implementation, `grt` type definition, `grx` codelens, `gO` document symbol, `[d` / `]d` diagnostic jumps, `K` hover (buffer-local on attach), and goto-definition through `tagfunc` on `<C-]>`.

An `on_attach` function defining `gd` / `K` / `<C-m>` / `gy` / `rn` / `ma` / `gr` / `<space>e` / `[d` / `]d` used to sit at the top of the file, but nothing ever passed it anywhere — `automatic_enable` has no hook for it — so it was dead code. It was removed rather than wired up because wiring it would have meant rewriting it: three of its ten mappings called `vim.lsp.diagnostic.show_line_diagnostics` / `goto_prev` / `goto_next`, which no longer exist (that functionality moved to `vim.diagnostic.jump`); `[d` and `]d` would have replaced working built-ins with errors; and none of the `vim.keymap.set` calls passed `{ buffer = bufnr }`, so they would have leaked into every buffer including ones with no LSP attached.

If per-server behaviour is ever needed, `vim.lsp.config('*', { on_attach = ... })` is the hook to use.

`nvim/.luarc.json` configures lua_ls (LuaJIT runtime, `vim` global, `$VIMRUNTIME/lua` library). It only applies when `~/.config/nvim` is the workspace root — editing these files from the dotfiles repo root produces spurious `Undefined global vim` warnings.

## Shell / bin scripts

Scripts in `bin/` are standalone shell utilities (QEMU/TPM setup, buildroot helpers, SSH shortcuts, etc.). No build step required.

### Login shell (`.profile`)

`.profile` sources `.bashrc` first, then does nothing but build `PATH`. Entries go through `_path_add`, which appends each existing directory to `_path_head`; that whole string is prepended to the inherited `PATH` in one step at the end. **The list therefore reads in the same order as the resulting `PATH`** — highest priority first:

| Priority | Path | Holds |
|---|---|---|
| 1 | `~/bin` | this repo's `bin/`, symlinked by `setup.sh` |
| 2 | `~/.local/bin` | pip / user-local installs |
| 3 | `~/go/bin` | `go install` output |
| 4 | `~/github/wasm-micro-runtime/product-mini/platforms/linux/build` | `iwasm` |
| 5 | `$WASMTIME_HOME/bin` | wasmtime |
| 6 | `/opt/nvim-linux-x86_64/bin` | Neovim |

A new entry goes at the position it should occupy — no mental inversion. This replaced seven `if [ -d X ]; then PATH="Y:$PATH"; fi` blocks, where the last block written won and adding one at the bottom silently gave it the *highest* precedence.

`_path_add` also tests the directory it is about to add, so the two cannot drift apart. `unset -f _path_add` and `unset _path_head` at the end keep the helper out of the resulting shell.

`~/.cargo/bin` and `~/.deno/bin` are outside this list and stay below everything in it. `~/.cargo/env` and `~/.deno/env` are generated by rustup and deno, they prepend on their own, and `.bashrc` sources them before `.profile` reaches the list — putting them in `_path_add` would only duplicate the entries.

`bin/clean-wsl-path.sh` is sourced last and must stay last. It splits `PATH` on `:` and rebuilds it with empty entries and entries containing spaces dropped, which is what keeps WSL's injected `C:\Program Files\...` paths out. Anything appended after it escapes the filter.

The space filter is not cosmetic: Buildroot's `support/dependencies/dependencies.sh` aborts outright when `PATH` contains a space, so the `~/github/keystone` build (`build-generic64/buildroot.build`) cannot run without it.

The wasmtime entry is the one that cannot be written plainly. `WASMTIME_HOME` is exported by its own `-d "$HOME/.wasmtime"` block above the list, and the list references it as `${WASMTIME_HOME:+$WASMTIME_HOME/bin}` so an unset value expands to the empty string, which `_path_add` skips. A bare `"$WASMTIME_HOME/bin"` would expand to `/bin` instead — a directory that exists, so it would silently join the list.

That is not hypothetical. The export used to live in `.bashrc` while `.profile` tested `-d $HOME/.wasmtime` and expanded `$WASMTIME_HOME`; since `.bashrc` returns early in a non-interactive shell, `bash -lc`, `ssh host cmd` and cron all got the empty expansion and prepended `/bin` (`/usr/bin` under merged-usr) into the list. Nothing was actually shadowed. `WASMTIME_HOME` is unset in a non-login interactive shell, which is correct: that shell does not get the `PATH` entry either.

### The WASI SDK is deliberately not on `PATH`

`.profile` exports `WASI_SDK_PATH=$HOME/images/wasi-sdk-33.0-x86_64-linux` and stops there — the SDK's `bin/` used to sit at priority 5, ahead of `/usr/bin`, and that shadowed the host toolchain:

- `clang` and `clang++` resolved to the SDK's clang-22, whose `bin/clang.cfg` pins the target to `wasm32-unknown-wasip1` and points at the bundled wasi-sysroot. `clang hello.c` produced a WebAssembly module, silently, where `/usr/bin/clang` (Ubuntu 18.1.3, x86_64) would have produced an ELF binary.
- `ar`, `nm`, `objcopy`, `objdump`, `ranlib`, `size`, `strings`, `strip` and `c++filt` are symlinks to the `llvm-*` tools. Those do handle ELF, so nothing broke outright, but their flags and output differ from GNU binutils — which matters for Buildroot, and therefore for the Keystone build.

Build systems read `WASI_SDK_PATH` (the CMake toolchain file included with the SDK does). Anything else should spell out `$WASI_SDK_PATH/bin/clang`. The uniquely named tools — `llvm-*`, `clang-22` — went off `PATH` along with the rest, so they need the same prefix.

`bin/wasm-ld` is the exception, a shim for the one that gets typed by hand. It falls back to the install path when `WASI_SDK_PATH` is unset, which is the case in a non-login shell since `.profile` is what exports it. It execs `$WASI_SDK_PATH/bin/wasm-ld` rather than `lld` on purpose: that file is a symlink to `lld`, and LLD picks its driver from `argv[0]`, so the name is what selects the wasm linker over `ld.lld` or `lld-link`.

Everything still on the list is collision-free against `/usr/bin`: `~/.local/bin` wins `docutils` and the `rst2*` scripts from the apt package, which is the point of a pip user install, and the wamr build directory holds only `iwasm` and `test_wrgsbase`.

Note that mason's `~/.local/share/nvim/mason/bin` is not here — Neovim prepends that itself, which is why the formatter binaries resolve inside nvim but not in a plain shell.

### Launching VS Code (`bin/code`)

The space filter's one casualty is VS Code, whose launcher lives in `/mnt/c/Users/<user>/AppData/Local/Programs/Microsoft VS Code/bin`. `bin/code` exists to get it back without weakening the filter: `~/bin` has no spaces, so it survives, and the shim calls the real launcher by absolute path.

There are two launchers and they are not interchangeable:

- `~/.vscode-server/bin/<commit>/bin/remote-cli/code` hands its arguments to an already attached window over `$VSCODE_IPC_HOOK_CLI`, and errors out when that variable is unset.
- The Windows-side wrapper starts a window (or reuses one) from scratch. It finds its own install with `realpath "$0"` and reaches Windows through `/usr/bin/wslpath`, a Linux binary — so nothing has to be on `PATH` for it to work.

The shim branches on `$VSCODE_IPC_HOOK_CLI` rather than leaving the choice to `PATH` order, because VS Code puts the remote-cli directory on `PATH` for its integrated terminal but `.profile` prepends `~/bin` afterwards, so the shim wins there too. Both the user install (`AppData/Local/Programs`) and the system install (`/mnt/c/Program Files`) are probed, so re-installing VS Code the other way does not break it.

Two alternatives were rejected. Stripping `PATH` only around the Keystone build inverts the safe default and assumes Buildroot is the only thing that minds. `appendWindowsPath=false` in `/etc/wsl.conf` stops the injection at the source, but the VS Code path contains a space either way, so it would still need re-adding by hand — and `explorer.exe`, `clip.exe` and friends would then need it too.

### Interactive shell (`.bashrc`)

Lines 1-91 are the stock Debian skeleton (non-interactive early return, `histappend`, `checkwinsize`, lesspipe, `PS1`, dircolors and the `--color=auto` aliases) with one edit: `HISTSIZE` / `HISTFILESIZE` were raised from 1000 / 2000 to 10000 / 20000, keeping the skeleton's 1:2 ratio, so fzf's `CTRL-R` has something to search. Everything below that is local: `BROWSER=wslview`, the eight `KEYSTONE*` / `BUILDROOT_BUILDDIR` exports, a `uname -m` case that sets `TZ` only on riscv64 hardware, `view='nvim -R'`, conditional sourcing of `~/.bash_aliases`, bash-completion, the fzf block and `~/.cargo/env` / `~/.deno/env`, and the ssh-agent block below.

The early return at the top means none of this reaches a non-interactive shell. Claude Code still sees these variables because its environment is captured from the profile once at session start.

### fzf

fzf is the apt package (`/usr/bin/fzf`, 0.44). Its configuration is in `.bashrc` rather than `.profile`, which does nothing but build `PATH` — `/usr/bin` is already on it, and both integration scripts return early in a non-interactive shell anyway.

| Key | Action |
|---|---|
| `CTRL-T` | Insert a path at the cursor (preview in the right 60%) |
| `CTRL-R` | Search command history (`?` toggles a full-text preview of the selection) |
| `ALT-C` | `cd` into a subdirectory (`ls` preview) |
| `**<TAB>` | Complete anywhere — `vim **<TAB>`, `kill **<TAB>`, `ssh **<TAB>` |
| `cd **<TAB>` | Directories only — same for `pushd` and `rmdir` |

0.44 predates `fzf --bash` (0.48), so the two integration files are sourced by path. They are not in the same place: key bindings ship as `/usr/share/doc/fzf/examples/key-bindings.bash`, but Debian installs the completion as `/usr/share/bash-completion/completions/fzf` — there is no `examples/completion.bash`, only the zsh one. Both are guarded with `-f` so the block survives fzf being uninstalled.

Two ordering traps:

- The completion has to be sourced **after** the bash-completion block above it, because it wraps whatever completions are already installed.
- It has to be sourced **explicitly**, not left to bash-completion's lazy loader. The loader keys on the command name, so it would only fire on `fzf<TAB>` — the `**` trigger for every *other* command would never be installed.

File listing goes through **fdfind** (the Debian/Ubuntu name for `fd`) instead of the bundled `find` walk, which is what skips `.gitignore` matches. `--hidden --follow` put back the dotfiles and symlinks `find` would have listed, and `--exclude .git` stops `--hidden` from dumping the object store.

`FZF_CTRL_T_COMMAND` and `FZF_ALT_C_COMMAND` cover the key bindings, but the `**` trigger reads neither — it calls the `_fzf_compgen_path` / `_fzf_compgen_dir` hooks, which `completion.bash` defines only if they do not already exist, so the block defines them first. Their bodies spell the `fdfind` invocation out instead of interpolating a shared variable: function bodies expand at call time, so such a variable would have to stay set in every interactive shell for the hooks to keep working.

`cd` needs no configuration — `completion.bash` routes `cd`, `pushd` and `rmdir` through `_fzf_dir_completion` by default (`FZF_COMPLETION_DIR_COMMANDS` overrides the list). It does need one fix, though: fd prints a directory with a trailing `/` and `_fzf_dir_completion` appends a `/` of its own, so `_fzf_compgen_dir` pipes through `sed 's|/$||'` to keep `cd **<TAB>` from inserting `./nvim//`. `_fzf_compgen_path` deliberately keeps fd's slash — `_fzf_path_completion` appends nothing, and its `-o nospace` then lets a second `**` keep descending from the directory just accepted.

Everything is gated on `command -v fzf`, and the fdfind-specific half on `command -v fdfind`, so the block degrades to fzf's built-in `find` behaviour rather than breaking on a machine with only one of them.

### ssh-agent and the git remote

`origin` is `git@github.com:mituzawa/dotfiles.git`, and `~/.ssh/config` points github.com at `~/.ssh/id_ed25519`, **which has a passphrase** (`id_ed25519_nopass` exists but is scoped to two LAN hosts). Claude Code's shell has no TTY, so it cannot answer `Enter passphrase for key ...:` — a push would hang or fail rather than prompt.

`.bashrc` works around this by pinning the agent socket to a fixed path so one agent serves every shell:

```sh
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
ssh-add -l >/dev/null 2>&1
if [ $? -eq 2 ]; then
    rm -f "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1
fi
```

The passphrase is then typed once per WSL boot, in an interactive terminal:

```sh
ssh-add ~/.ssh/id_ed25519
```

Two things about that snippet are load-bearing:

- The spawn is gated on `ssh-add -l` exiting **2**, not on it merely being non-zero. Exit 2 means no agent answered; exit **1** means an agent is running but holds no keys yet. Writing `if ! ssh-add -l` would therefore discard a live agent every time a new shell opened before the first `ssh-add`.
- The default socket path (`/tmp/ssh-XXXXXX/agent.<pid>`) changes on every agent restart, which is why it is pinned. Without that, the socket has to be hunted down with `ls /tmp/ssh-*/agent.*` before every push.

Claude Code takes its environment from the profile once, at session start, so a session older than the `.bashrc` change will not have `SSH_AUTH_SOCK` set. Prefixing the command works without restarting:

```sh
SSH_AUTH_SOCK=~/.ssh/agent.sock git push
```

Verify auth without pushing anything with `ssh -T git@github.com`, which answers `Hi mituzawa! You've successfully authenticated, but GitHub does not provide shell access.`

## Windows-side configuration (`windows/`, `bin/win-sync.sh`)

`setup.sh` only ever links into `$HOME`, so the files under `windows/` are handled separately, by `bin/win-sync.sh`. `bin` is already one of `setup.sh`'s `TARGETS`, so the script arrives on `PATH` as `~/bin/win-sync.sh` with no change to the target list.

| `windows/` | Destination |
|---|---|
| `.wslconfig` | `%USERPROFILE%\.wslconfig` |
| `wezterm/wezterm.lua`, `wezterm/keybinds.lua` | `%USERPROFILE%\.config\wezterm\` |
| `vscode/settings.json` | `%APPDATA%\Code\User\settings.json` |
| `windows-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json` |

```sh
win-sync.sh diff [name ...]   # what differs (default, read-only)
win-sync.sh pull [name ...]   # Windows -> repository
win-sync.sh push [name ...]   # repository -> Windows
```

`<name>` is a path under `windows/`; an unknown one is rejected with the list of known targets rather than silently doing nothing.

### These targets are copied, not symlinked

Symlinking is what `setup.sh` does on the Linux side, and it is the wrong tool here for two independent reasons:

- **`.wslconfig` is read before the distribution starts.** It configures the VM that `\\wsl.localhost\<distro>\...` lives inside, so a link pointing there could never be followed — a chicken-and-egg problem, not a permissions one. (Developer Mode is on, `AllowDevelopmentWithoutDevLicense = 1`, so creating links without elevation does work.)
- **Windows Terminal and VS Code rewrite their own settings** whenever the GUI is used, and Windows applications generally write a temp file and rename it over the destination. That replaces a symlink with a real file, so the link breaks silently the first time a checkbox is ticked.

Copying makes "the application changed its settings" a case the tool handles — `pull` — instead of a failure mode. `push` backs the destination up as `<name>_ORG` first, the same convention `setup.sh` uses, and keeps the first backup if one already exists.

### Line endings

The three applications do not agree: Windows Terminal writes LF, VS Code and wezterm write CRLF, and `.wslconfig` was CRLF on the Windows side while the repository copy was LF. **The repository keeps LF throughout** — `pull` runs the Windows file through `sed 's/\r$//'`, and `diff` normalises both sides before comparing, so a save on the Windows side shows up as the lines that actually changed rather than as a whole-file diff. `push` writes LF, which all four readers accept.

`.gitattributes` (`* text=auto eol=lf`) keeps a future clone on the Windows side from checking these out as CRLF. Nothing already committed is renormalised by it: the only tracked file that is not LF in the worktree is `.luarc.json`, and that is a symlink.

### Two details in the script

- `~/bin` is a symlink to this repository's `bin/`, so `$0` has to be resolved with `readlink -f`. `setup.sh`'s `cd "$(dirname "$0")" && pwd` would land in `$HOME`, because bash's `cd` keeps the logical path.
- The Windows Terminal package directory is named after the build (Store, Preview, unpackaged), so it is resolved with a `Microsoft.WindowsTerminal*` glob. When nothing matches, that one target is dropped with a `SKIP` line and the rest still run.

### Deliberately not synced

`~/.ssh` and the Windows-side `.claude/` (which holds `.credentials.json`) are secrets. `/etc/wsl.conf` is a Linux-side file inside the distribution, not a Windows one. The PowerShell profile, VS Code's `keybindings.json` and VS Code's `snippets/` do not exist yet, and there is no winget package export.

### The drift this was built for

`windows/.wslconfig` was committed in `57f7453` and then reached nothing — it was never in `TARGETS`, and there was no other mechanism. By the time `win-sync.sh` was written the repository asked for 16GB / 8 processors / 32GB swap while `C:\Users\mituz\.wslconfig` said 8GB / 4 / 2GB, and the running WSL had 4 CPUs and 7.8GB: the committed values had never once been applied. The initial `pull` took the live values as the truth.
