# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

Personal dotfiles for a Linux/WSL2 environment. The Neovim config is the most structured part; shell configs and scripts live at the repo root and in `bin/`.

The dotfiles are deployed by symlinking into the home directory via `setup.sh`, which reads the `TARGETS` list (`.bashrc`, `.profile`, `.gitconfig`, `.clang-format`, `.vimrc`, `.vim`, `bin`, `nvim:.config/nvim`) and backs up any pre-existing real file as `<name>_ORG`. `~/.config/nvim/` corresponds to `nvim/` in this repo (e.g. `~/.config/nvim/toml/` → `dotfiles/nvim/toml/`).

## Neovim configuration architecture

The plugin stack is built on two layers:

- **denops.vim** — Deno runtime bridge that allows TypeScript/JavaScript plugin code to run inside Neovim.
- **dpp.vim** — "dark powered" plugin manager that uses denops to run `config.ts` at startup.

### Bootstrap flow

1. `nvim/init.lua` requires `option/option` (editor options) then `darkpowerd/dpp`.
2. `lua/darkpowerd/dpp.lua` bootstraps: auto-clones `dpp.vim` and `denops.vim` into `~/.cache/nvim/dpp/` if absent, adds them to runtimepath, then loads the cached plugin state from `~/.cache/nvim/dpp/`.
3. On first run (or after `:DppMakeState`), `config.ts` is invoked via denops. It reads `toml/dein.toml` (eager plugins) and `toml/dein_lazy.toml` (lazy-loaded by filetype), plus any plugins found under `~/work/` (local development).
4. The generated state is persisted to disk; subsequent startups load it directly without re-running TypeScript.

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
  plugins/      lspconfig.lua, formatter.lua, nvim-tree.lua, autocmd.lua, image_preview.lua
```

`init.lua` requires `option/option`, `darkpowerd/dpp`, `darkpowerd/ddu`, `keymap/keymap`, `plugins/lspconfig`, `plugins/formatter`, `plugins/nvim-tree` and `plugins/autocmd`. Two modules — `option/cd` and `keymap/yankround` — are present but commented out; enable them by uncommenting the relevant `require()` lines. `plugins/image_preview` is not referenced at all, and its plugin is commented out in `dein.toml`. Note `init.lua` wraps everything in `if not vim.g.vscode`, so nothing loads under vscode-neovim.

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
| `,as` (visual) | Send selection to Claude |

`:ClaudeCode` takes `nargs = "*"` and appends whatever it is given to the `claude` binary (`terminal.lua:356`), so any CLI flag can be bound this way. Sessions are stored per working directory under `~/.claude/projects/<slugified-cwd>/`; `git_repo_cwd = true` in the `dein.toml` hook makes the terminal spawn at the git root (`terminal.lua:263-266`), so history is shared no matter which subdirectory Neovim was started from. All three of `,ac` / `,af` / `,ar` are toggles — arguments only take effect when the terminal is actually being spawned, so pressing them while it is open just hides the window.

**`claudecode.setup()` silently discards misplaced keys.** `split_side`, `split_width_percentage`, `git_repo_cwd`, `auto_close`, `auto_insert` and `snacks_win_opts` all belong inside `terminal = { ... }`; `track_selection`, `diff_opts`, `terminal_cmd`, `env` and `models` are top-level. `config.lua` validates only the keys it knows about, and `init.lua` forwards nothing but `opts.terminal` to the terminal module, so a key at the wrong depth produces no warning — the default just quietly applies. All three of the split options had been sitting at the top level, which is why the pane used the 0.30 default instead of the 0.35 written in the hook. To check what actually took effect:

```vim
:lua print(vim.inspect(require("claudecode").state.config.terminal))
```

### LSP

`lua/plugins/lspconfig.lua` sets up mason.nvim + mason-lspconfig for automatic LSP server installation, enabling `lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls` and `pyright` through `automatic_enable`.

**No LSP keymaps are defined here.** Neovim 0.11+ ships its own and they are what actually take effect: `grn` rename, `gra` code action, `grr` references, `gri` implementation, `grt` type definition, `grx` codelens, `gO` document symbol, `[d` / `]d` diagnostic jumps, `K` hover (buffer-local on attach), and goto-definition through `tagfunc` on `<C-]>`.

An `on_attach` function defining `gd` / `K` / `<C-m>` / `gy` / `rn` / `ma` / `gr` / `<space>e` / `[d` / `]d` used to sit at the top of the file, but nothing ever passed it anywhere — `automatic_enable` has no hook for it — so it was dead code. It was removed rather than wired up because wiring it would have meant rewriting it: three of its ten mappings called `vim.lsp.diagnostic.show_line_diagnostics` / `goto_prev` / `goto_next`, which no longer exist (that functionality moved to `vim.diagnostic.jump`); `[d` and `]d` would have replaced working built-ins with errors; and none of the `vim.keymap.set` calls passed `{ buffer = bufnr }`, so they would have leaked into every buffer including ones with no LSP attached.

If per-server behaviour is ever needed, `vim.lsp.config('*', { on_attach = ... })` is the hook to use.

`nvim/.luarc.json` configures lua_ls (LuaJIT runtime, `vim` global, `$VIMRUNTIME/lua` library). It only applies when `~/.config/nvim` is the workspace root — editing these files from the dotfiles repo root produces spurious `Undefined global vim` warnings.

## Shell / bin scripts

Scripts in `bin/` are standalone shell utilities (QEMU/TPM setup, buildroot helpers, SSH shortcuts, etc.). No build step required.
