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
  option/       option.lua (editor settings), cmd.lua, colorscheme.lua, cd.lua, tabstop.lua
  keymap/       keymap.lua (leader mappings), yankround.lua
  plugins/      lspconfig.lua, formatter.lua, nvim-tree.lua, autocmd.lua, image_preview.lua
```

`init.lua` requires only `option/option`, `darkpowerd/dpp`, `keymap/keymap`, `plugins/lspconfig`, `plugins/formatter` and `plugins/nvim-tree`. The rest — `option/cd`, `darkpowerd/ddu`, `keymap/yankround`, `plugins/autocmd` — are present but commented out; enable them by uncommenting the relevant `require()` lines. Note `init.lua` wraps everything in `if not vim.g.vscode`, so nothing loads under vscode-neovim.

Because `plugins/autocmd` is disabled, **format-on-save is not active** — formatter.nvim is configured, but `:Format` / `:FormatWrite` must be run manually.

### Filer (nvim-tree)

nvim-tree is the only file explorer. `lua/plugins/nvim-tree.lua` disables netrw, shows dotfiles, and uses a 30-column drawer; icons come from `nvim-web-devicons`. `,uj` toggles it, revealing the current file when the buffer holds a real file.

fern.vim (plus nerdfont.vim, fern-renderer-nerdfont.vim and glyph-palette.vim) was removed in favour of nvim-tree, because `claudecode.nvim` dispatches on filetype and only supports `NvimTree`, `neo-tree`, `oil`, `minifiles`, `netrw` and `snacks_picker_list` — `,at` (`ClaudeCodeTreeAdd`) could never work from a fern buffer.

### Fuzzy finder (ddu.vim)

`lua/darkpowerd/ddu.lua` configures the ddu fuzzy finder using `,u` as a prefix: `,uc` for file\_rec, `,ub` for buffers, `,um` for MRU, etc. It is commented out in `init.lua`, so **those `,u*` mappings are currently inactive** even though the ddu plugins are installed. `keymap.lua` maps `,u` itself to `<Nop>`, so only the `,u` mappings defined there (`,uj`, `,ug`) respond.

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

### LSP

`lua/plugins/lspconfig.lua` sets up mason.nvim + mason-lspconfig for automatic LSP server installation, enabling `lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls` and `pyright` through `automatic_enable`.

The `on_attach` function at the top of that file (defining `gd`, `K`, `gy`, `rn`, `ma`, `gr`, `[d`, `]d`, …) is **never passed to anything** — with `automatic_enable` those keymaps are not applied, and Neovim's built-in LSP defaults (`grn`, `gra`, `grr`, `K`) are what actually take effect. Wire it up via `vim.lsp.config('*', { on_attach = on_attach })` if those bindings are wanted.

`nvim/.luarc.json` configures lua_ls (LuaJIT runtime, `vim` global, `$VIMRUNTIME/lua` library). It only applies when `~/.config/nvim` is the workspace root — editing these files from the dotfiles repo root produces spurious `Undefined global vim` warnings.

## Shell / bin scripts

Scripts in `bin/` are standalone shell utilities (QEMU/TPM setup, buildroot helpers, SSH shortcuts, etc.). No build step required.
