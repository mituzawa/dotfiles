# CLAUDE.md

このファイルは、このリポジトリのコードを扱う際の Claude Code (claude.ai/code) 向けの指針である。

## リポジトリ概要

Linux/WSL2 環境の個人用 dotfiles。もっとも構造化されているのは Neovim の設定で、シェルの設定とスクリプトはリポジトリ直下と `bin/` にある。

`README.md` は、これらすべてを新しいマシンで復元する手順を、順序と鶏と卵の関係を明示して並べたもの。このファイルは、各部分がなぜその形なのかの参照先である。ブートストラップを変えたときは両者を同期させること。

dotfiles は `setup.sh` がホームディレクトリへシンボリックリンクを張ることで配置される。`setup.sh` は `TARGETS` リスト (`.bashrc`, `.profile`, `.gitconfig`, `.clang-format`, `.vimrc`, `.vim`, `bin`, `nvim:.config/nvim`) を読み、既存の実体ファイルは `<name>_ORG` として退避する。`~/.config/nvim/` はこのリポジトリの `nvim/` に対応する（例: `~/.config/nvim/toml/` → `dotfiles/nvim/toml/`）。

`windows/` はこの仕組みの外にある。これらのファイルは WSL の Windows 側に属していてシンボリックリンクを張れないので、代わりに `bin/win-sync.sh` がコピーする。[Windows 側の設定](#windows-%E5%81%B4%E3%81%AE%E8%A8%AD%E5%AE%9A-windows-binwin-syncsh)を参照。

## Neovim 設定のアーキテクチャ

プラグイン構成は 2 つの層の上に成り立っている。

- **denops.vim** — TypeScript/JavaScript のプラグインコードを Neovim 内で動かすための Deno ランタイムブリッジ。
- **dpp.vim** — denops を使って起動時に `config.ts` を実行する "dark powered" プラグインマネージャ。

### ブートストラップの流れ

1. `nvim/init.lua` が `option/option`（エディタオプション）を require し、続いて `darkpowerd/dpp` を require する。
1. `lua/darkpowerd/dpp.lua` がブートストラップを行う。`dpp.vim` と `denops.vim` が無ければ `~/.cache/nvim/dpp/` へ自動 clone し、runtimepath に加えたうえで、`~/.cache/nvim/dpp/` からキャッシュ済みのプラグイン状態を読み込む。
1. 初回起動時（あるいは `:DppMakeState` の後）に `config.ts` が denops 経由で呼ばれる。これが `toml/dein.toml`（起動時ロード）と `toml/dein_lazy.toml`（ファイルタイプによる遅延ロード）を読み、加えて `~/work/` 以下に見つかったプラグイン（ローカル開発用）も拾う。
1. 生成された状態はディスクに永続化され、以降の起動は TypeScript を再実行せずそれを直接読み込む。

### プラグイン管理の主なコマンド

| コマンド | 用途 |
|---|---|
| `:DppInstall` | TOML に列挙されたプラグインをすべてインストールする |
| `:DppUpdate [name ...]` | すべて（あるいは名前を指定したもの）を更新する |
| `:DppMakeState` | TOML を変更した後にプラグイン状態のキャッシュを作り直す |

### プラグインの追加・削除

`nvim/toml/dein.toml`（起動時ロード）か `nvim/toml/dein_lazy.toml`（ファイルタイプでロード）を編集する。保存したら Neovim 内で `:DppMakeState` を実行し、リポジトリを追加した場合は続けて `:DppInstall` する。

TOML からプラグインを削除して状態を作り直せば runtimepath からは外れるが、clone 自体は `~/.cache/nvim/dpp/repos/github.com/` に残る。容量を戻すにはそのディレクトリを手で消すこと。

状態は対話セッション無しでも作り直せる。シェルから TOML を編集した後に便利:

```sh
nvim --headless -c 'autocmd User Dpp:makeStatePost qall!' \
  -c 'call dpp#make_state(stdpath("cache").."/dpp", stdpath("config").."/config.ts")'
```

### Lua モジュールの配置

```
nvim/lua/
  darkpowerd/   dpp.lua (ブートストラップ), ddu.lua (ファジーファインダの設定)
  option/       option.lua (エディタ設定), cmd.lua, colorscheme.lua, cd.lua
  keymap/       keymap.lua (leader マッピング), yankround.lua
  plugins/      lspconfig.lua, formatter.lua, nvim-tree.lua, autocmd.lua, claude_transcript.lua
```

`init.lua` は `lua/` 以下のすべてのモジュールを require する: `option/option`, `option/cd`, `darkpowerd/dpp`, `darkpowerd/ddu`, `keymap/keymap`, `keymap/yankround`, `plugins/lspconfig`, `plugins/formatter`, `plugins/nvim-tree`, `plugins/autocmd`, `plugins/claude_transcript`。コメントアウトされたものはもう残っていない。なお `init.lua` は全体を `if not vim.g.vscode` で包んでいるので、vscode-neovim 下では何もロードされない。

### 保存時フォーマット

`lua/plugins/autocmd.lua` は `format_on_save` augroup（`clear = true` なので、`,r` で `init.lua` を読み直しても重複登録されない）の中に `BufWritePost` → `:FormatWrite` の autocmd をひとつだけ登録する。`pattern` が `"*"` なのは意図的で、どのファイルタイプをフォーマットするかの唯一の情報源は `lua/plugins/formatter.lua` である。それ以外については formatter.nvim が "No formatter defined" で早期に戻る。

特定のバッファだけフォーマットを抑止したいとき — 他人のリポジトリで有用。これらのフォーマッタは自分の既定値で平気でファイル全体を書き換えるので:

```vim
:let b:formatter_skip_buf = v:true
```

外部バイナリは mason から来る。新しいマシンでは次で入れ直す:

```
:MasonInstall prettierd biome djlint mdformat yamlfix shfmt
```

`clang-format` と `stylua` は LSP/ツールの依存としてすでに入ってくる。`jq` はシステムのもの。mason が `~/.local/share/nvim/mason/bin` を `PATH` の先頭に足すので、`vim.fn.jobstart` は追加設定なしでこれらすべてを解決できる。

シェルスクリプト（`setup.sh`, `.bashrc`, `.profile`, `bin/` 以下すべて）はいずれも `filetype=sh` に解決されるので、`sh` エントリひとつで足りる。`bash` というファイルタイプは登場せず、`formatter.filetypes.bash` は存在しない。shfmt を `-ci` 付きで走らせているのは、これらのスクリプトが `case` のパターンをインデントする（Debian スケルトンのスタイル）ためで、これが無いと shfmt は `case` の位置まで戻してしまう。ツリーは一度 `shfmt -w -ci -i 4` で整形済みなので、いま保存しても差分は出ないはず。

`formatter.lua` を編集するとき覚えておく価値のある罠が 3 つある。

- `require("formatter.filetypes.<ft>").<tool>` は、そのモジュールがツールを export していないと `nil` を返し、`nil` だけを持つテーブルは空とみなされる — 結果は無言の "No formatter defined"。`formatter.filetypes.html` には `djlint` が無い（prettier 系と `tidy` だけ）ので、html は代わりに `formatter.defaults` から引いている。
- `stdin = true` で呼ぶフォーマッタには、実際に stdin を読ませる指定が要る。末尾の `-` を欠いた `mdformat` は警告を stderr に出して 0 で終了するため、formatter.nvim は成功と解釈し、黙って何もしない。
- `formatter.filetypes.sh.shfmt` は `vim.opt.shiftwidth:get()` をそのまま `shfmt -i` に渡す。`option.lua` は `shiftwidth = 0`（`tabstop` に従う）を設定しているので、組み込みのままだと `-i 0`、つまりタブインデントを指示することになる — `expandtab` が有効な設定なのに。そのため `sh` エントリは `vim.fn.shiftwidth()` を呼び、0 を実効値 (4) に解決している。

`logging = true` と `log_level = vim.log.levels.ERROR` の組み合わせは、通常の保存を静かに保ちつつフォーマッタの失敗だけは表に出す。`logging = false` にするとエラーも抑止されてしまう (`log.lua:57-66`)。

`nvim/.stylua.toml` は `column_width = 160` を固定している。`keymap.lua` の長い 1 行 `vim.keymap.set(...)` を、stylua の既定 120 桁の折り返しから守るため。

### ファイラ (nvim-tree)

ファイルエクスプローラは nvim-tree ひとつだけ。`lua/plugins/nvim-tree.lua` は netrw を無効化し、ドットファイルを表示し、30 桁のドロワーを使う。アイコンは `nvim-web-devicons` から来る。`,uj` でトグルし、バッファが実ファイルなら現在のファイルの位置を開いて見せる。

fern.vim（および nerdfont.vim, fern-renderer-nerdfont.vim, glyph-palette.vim）は nvim-tree に置き換えて削除した。`claudecode.nvim` はファイルタイプで分岐しており、対応しているのは `NvimTree`, `neo-tree`, `oil`, `minifiles`, `netrw`, `snacks_picker_list` だけなので、fern のバッファからは `,at` (`ClaudeCodeTreeAdd`) が原理的に動かなかったため。

### アイコンフォント（Nerd フォント）

**Neovim 側にフォントの設定は存在しない。** TUI の nvim は字形を端末エミュレータから受け取るだけで、`guifont` はこのリポジトリのどこにも無い（GUI クライアントの neovide / nvim-qt も使っていない）。したがって設定する場所は端末側しかない。

Nerd フォントの私用領域 (PUA) を要求しているのは 4 か所:

- `nvim-web-devicons` — nvim-tree のファイルアイコン (`dein.toml`)
- `ddu-filter-converter_devicon` — `ddu.lua` が `sourceOptions._` の `converters` に入れているので、ddu の一覧すべて
- lightline の `separator` / `subseparator`（`\ue0b0`–`\ue0b3`、`dein.toml` の hook）
- snacks.nvim / claudecode.nvim の UI

端末側の状況は 2 つで異なる。

- **Windows Terminal** は Ubuntu プロファイルで `"face": "JetBrainsMono Nerd Font"` を名指ししている (`windows/windows-terminal/settings.json`)。フォント本体が無ければ黙って別のフォントへフォールバックし、上の 4 つがすべて豆腐になる。新しいマシンでこれを入れるのが `README.md` の手順 1。
- **wezterm** は face を名指ししていない。`windows/wezterm/wezterm.lua` にあるのは `font_size` だけで、同梱の JetBrains Mono（Nerd Font ビルドではない方）が使われる。それでも崩れないのは、wezterm が *Symbols Nerd Font Mono* を実行ファイルに内蔵していて PUA をそこへフォールバックさせるため。powerline セパレータに至ってはフォントを引かず、`custom_block_glyphs` で自前描画する。

つまり Nerd フォントのインストールは Windows Terminal の要件であって、wezterm の要件ではない。どちらで解決されたのかは推測せず wezterm に聞けばよい:

```sh
'/mnt/c/Program Files/WezTerm/wezterm.exe' ls-fonts --text $'\ue0b0\uf07b'
```

`<built-in>, BuiltIn` と出れば内蔵フォールバック、ファイルパスが出れば OS にインストールされたフォント。`wezterm.lua` に `config.font` を足せばこの暗黙の依存は消えるが、その代わり wezterm 側にも Nerd フォントのインストールが必須になる。

Linux 側にフォントは要らない。fontconfig すら入っていない (`fc-list` が無い)。

### ファジーファインダ (ddu.vim)

`lua/darkpowerd/ddu.lua` は `,u` をプレフィックスとして ddu ファジーファインダを設定する: `,uc` file_rec, `,uf` file, `,ub` buffers, `,um` MRU, `,ur` registers, `,up` file_point, `,un` 新規ファイル, `,ul` colorscheme。フローティングの ff UI に自動プレビューと devicon コンバータを設定し、`ddu-ff` バッファ内で `<CR>` / `q` / `<Space>` / `i` / `P` を割り当てる。

`keymap.lua` は `,u` 自体も `<Nop>` にマップしているが、これは長い方のマッピングと共存する — `,u` だけを押すと `timeoutlen` を待って何も起きない。なお `init.lua` は `darkpowerd/ddu` を `keymap/keymap` より先にロードするので、後者の `,uj` と `,ug` は ddu のマッピングを置き換えるのではなく並んで存在する。

ddu は `dein.toml` の 35 エントリのうち 16 を占める — source も filter も kind もそれぞれ別リポジトリだから。`fall.vim` もインストールされているが設定は無い。この数がいつか問題になったときの代替は、これと（claudecode.nvim の依存としてすでに入っている）`snacks.nvim` のピッカーである。

### キーマップ (`lua/keymap/keymap.lua`)

| マッピング | 動作 |
|---|---|
| `,r` | `init.lua` を読み直す |
| `,uj` | nvim-tree をトグル（現在のファイルを開いて見せる） |
| `,ug` | `:LazyGit` |
| `,ac` / `,af` | Claude Code のトグル / フォーカス |
| `,ar` / `,ak` | Claude セッションの再開（`--resume`、ピッカー） / 直近のものを継続（`--continue`） |
| `,ab` / `,at` | 現在のバッファ / ツリーのカーソル位置のファイルを Claude に追加 |
| `,al` | `:ClaudeLog` — Claude ペインのスクロールバックを読み返す (`lua/plugins/claude_transcript.lua`) |
| `,as` (ビジュアル) | 選択範囲を Claude へ送る |
| `<Space>cd` | `:CD` — 現在のファイルのディレクトリへ `lcd` (`lua/option/cd.lua`) |
| `p` / `P` | yankround 経由のペースト |
| `<C-p>` / `<C-n>` | yank 履歴を前 / 後ろへ巡回 (`lua/keymap/yankround.lua`) |

`<C-p>` と `<C-n>` に既定の *マッピング* は無いが、既定の *モーション*（`k`/`j` と同じく上下 1 行）ではある。yankround がノーマルモードでこれを乗っ取る。`yankround.lua` はノーマルモードしかマップしないので、挿入モードの補完には手を付けない。なお `plugin/yankround.vim` はこれらのマッピングの有無にかかわらず yank 履歴を記録しているので、有効化する前から履歴にはすでにエントリがあった。

`:ClaudeCode` は `nargs = "*"` を取り、与えられたものを `claude` バイナリにそのまま渡す (`terminal.lua:356`) ので、どの CLI フラグでもこの方式で割り当てられる。セッションは作業ディレクトリごとに `~/.claude/projects/<slugified-cwd>/` へ保存される。`dein.toml` の hook にある `git_repo_cwd = true` がターミナルを git のルートで起動させる (`terminal.lua:263-266`) ので、Neovim をどのサブディレクトリで起動しても履歴は共有される。`,ac` / `,af` / `,ar` の 3 つはいずれもトグルで、引数が効くのはターミナルが実際に起動されるときだけ。開いている状態で押せば単にウィンドウが隠れる。

**`claudecode.setup()` は置き場所を間違えたキーを黙って捨てる。** `split_side`, `split_width_percentage`, `git_repo_cwd`, `auto_close`, `auto_insert`, `snacks_win_opts` はすべて `terminal = { ... }` の中に属し、`track_selection`, `diff_opts`, `terminal_cmd`, `env`, `models` はトップレベルに属する。`config.lua` は自分の知っているキーしか検証せず、`init.lua` はターミナルモジュールへ `opts.terminal` しか渡さないので、階層を間違えたキーは警告も出ずに既定値が静かに適用される。split 系 3 つはいずれもトップレベルに置かれていて、それがペインの幅が hook に書かれた 0.35 ではなく既定の 0.30 になっていた理由だった。実際に何が効いているかの確認:

```vim
:lua print(vim.inspect(require("claudecode").state.config.terminal))
```

### Claude ペインの読み返し (`:ClaudeLog`, `,al`)

**Claude Code のペインには、nvim の意味でのスクロールバックが無い。** 起動時に `ESC[?1049h` を出すので代替スクリーン上で動いており、ターミナルバッファはいま表示されているフレームしか保持しない。したがって `<C-\><C-n>` の後に `k` を押しても遡る先が無い。これは設定ミスではなく構造的なもので、`,ug` (LazyGit) も同じ挙動になる。

Claude Code はマウスレポート (`ESC[?1000h`, `?1002h`, `?1003h`, `?1006h`) も有効にするので、nvim はホイールイベントをバッファのスクロールではなく Claude へ転送する。これは `'mouse'` の値に関係なく起きるが、`option.lua` が設定している `mouse = ""` では、そもそも nvim が外側の端末にホイールの報告を要求しないので、転送すべきものが届かない。

`lua/plugins/claude_transcript.lua` は代わりに会話をディスクから読む。セッションは `~/.claude/projects/<slugified-cwd>/<session-uuid>.jsonl` にあり、1 行 1 JSON オブジェクトである。

- slug は Claude が起動したディレクトリの英数字以外をすべて `-` に置き換えたもので、`/home/mituzawa/dotfiles` は `-home-mituzawa-dotfiles` になる。解決するのは **git のルート**。ターミナルがそこで起動されるのは `git_repo_cwd = true` のため。
- 現在のセッションは、そのディレクトリで最後に更新された `.jsonl` にすぎない。`--resume` と `--continue` は開き直したファイルに追記し続ける。
- `:ClaudeLog` は `user` と `assistant` のレコードを markdown のスクラッチバッファへ新しいタブでレンダリングし、最終行に着地する。`:ClaudeLog!` は生の `.jsonl` を開く。どちらも `modifiable = false` + `readonly = true` で開く — 特に生の方は、実行中のセッションがいまも追記している実ファイルなので。

このフォーマットが強いてくることが 2 つある。

- `thinking` ブロックはテキストが取り除かれた状態で保存され、残るのは `signature` だけなので、空のマーカーとしてレンダリングするのではなくスキップする。
- ツールの引数と結果の切り詰めは、バイトではなく `strcharpart` で文字数を数える。`string.sub` はマルチバイト文字を途中で切ってしまい、その結果できる不正な UTF-8 は GNU grep がバッファのテキストにマッチしなくなるには十分である。

### LSP

`lua/plugins/lspconfig.lua` は mason.nvim + mason-lspconfig をセットアップして LSP サーバの自動インストールを有効にし、`automatic_enable` を通じて `lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls`, `pyright` を有効化する。

**ここで LSP のキーマップは定義していない。** Neovim 0.11+ が自前のものを持っており、実際に効くのはそちら: `grn` rename, `gra` code action, `grr` references, `gri` implementation, `grt` type definition, `grx` codelens, `gO` document symbol, `[d` / `]d` 診断のジャンプ, `K` hover（attach 時にバッファローカル）、そして `tagfunc` 経由の `<C-]>` による定義ジャンプ。

`gd` / `K` / `<C-m>` / `gy` / `rn` / `ma` / `gr` / `<space>e` / `[d` / `]d` を定義する `on_attach` 関数がかつてファイル冒頭にあったが、これをどこにも渡していなかった — `automatic_enable` にそのためのフックは無い — ので、単なるデッドコードだった。配線するのではなく削除したのは、配線するなら書き直しが必要だったから。10 個のマッピングのうち 3 つが `vim.lsp.diagnostic.show_line_diagnostics` / `goto_prev` / `goto_next` を呼んでいたが、これらはもう存在しない（機能は `vim.diagnostic.jump` へ移った）。`[d` と `]d` は動いている組み込みをエラーで置き換えることになる。そして `vim.keymap.set` のどの呼び出しも `{ buffer = bufnr }` を渡していないので、LSP が attach していないものも含め全バッファへ漏れ出す。

サーバごとの挙動がいつか必要になったときは、`vim.lsp.config('*', { on_attach = ... })` が使うべきフックである。

`nvim/.luarc.json` は lua_ls の設定（LuaJIT ランタイム、`vim` グローバル、`$VIMRUNTIME/lua` ライブラリ）。効くのは `~/.config/nvim` がワークスペースのルートのときだけで、dotfiles リポジトリのルートからこれらのファイルを編集すると `Undefined global vim` の偽警告が出る。

## シェル / bin スクリプト

`bin/` のスクリプトは単体で動くシェルユーティリティ（QEMU/TPM のセットアップ、buildroot のヘルパ、SSH のショートカットなど）。ビルド手順は不要。

### ログインシェル (`.profile`)

`.profile` はまず `.bashrc` を source し、あとは `PATH` を組み立てるだけである。各エントリは `_path_add` を通り、存在するディレクトリだけが `_path_head` に追記される。その文字列全体が最後に一度だけ、継承した `PATH` の前に付く。**したがってリストは結果の `PATH` と同じ順序で読める** — 優先度の高いものが先:

| 優先度 | パス | 内容 |
|---|---|---|
| 1 | `~/bin` | このリポジトリの `bin/`。`setup.sh` がリンクする |
| 2 | `~/.local/bin` | pip / ユーザローカルのインストール |
| 3 | `~/go/bin` | `go install` の出力 |
| 4 | `~/github/wasm-micro-runtime/product-mini/platforms/linux/build` | `iwasm` |
| 5 | `$WASMTIME_HOME/bin` | wasmtime |
| 6 | `/opt/nvim-linux-x86_64/bin` | Neovim |

新しいエントリは、占めるべき位置にそのまま書く — 頭の中で反転させる必要はない。これは `if [ -d X ]; then PATH="Y:$PATH"; fi` のブロック 7 つを置き換えたもので、以前は最後に書いたブロックが勝ち、末尾に足すと黙って *最高* の優先度になっていた。

`_path_add` は追加しようとするディレクトリの存在確認も行うので、両者が食い違うことがない。末尾の `unset -f _path_add` と `unset _path_head` が、ヘルパを結果のシェルに残さない。

`~/.cargo/bin` と `~/.deno/bin` はこのリストの外にあり、リスト内のすべてより下に来る。`~/.cargo/env` と `~/.deno/env` は rustup と deno が生成するもので、自前で前に足す。しかも `.bashrc` が `.profile` のリストより前にそれらを source するので、`_path_add` に入れてもエントリが重複するだけである。

`bin/clean-wsl-path.sh` は最後に source され、最後のままでなければならない。これは `PATH` を `:` で分割し、空のエントリと空白を含むエントリを落として組み直す — WSL が注入する `C:\Program Files\...` を締め出しているのはこれである。この後に追記したものはフィルタを逃れる。

空白のフィルタは見た目の問題ではない。Buildroot の `support/dependencies/dependencies.sh` は `PATH` に空白が含まれると即座に中断するので、これが無いと `~/github/keystone` のビルド (`build-generic64/buildroot.build`) が走らない。

wasmtime のエントリだけは素直に書けない。`WASMTIME_HOME` はリストの上にある専用の `-d "$HOME/.wasmtime"` ブロックで export され、リストからは `${WASMTIME_HOME:+$WASMTIME_HOME/bin}` として参照される。未設定なら空文字列に展開され、`_path_add` がそれをスキップするからである。素の `"$WASMTIME_HOME/bin"` だと代わりに `/bin` — 存在するディレクトリ — に展開され、黙ってリストに加わってしまう。

これは仮定の話ではない。export はかつて `.bashrc` にあり、`.profile` は `-d $HOME/.wasmtime` を判定して `$WASMTIME_HOME` を展開していた。`.bashrc` は非対話シェルで早期に return するので、`bash -lc`、`ssh host cmd`、cron はいずれも空の展開を受け取り、`/bin`（merged-usr 下では `/usr/bin`）をリストへ前置していた。実際に何かが隠されたわけではない。`WASMTIME_HOME` は非ログインの対話シェルでは未設定だが、それは正しい — そのシェルは `PATH` エントリの方も受け取らないのだから。

### WASI SDK は意図的に `PATH` へ載せない

`.profile` は `WASI_SDK_PATH=$HOME/images/wasi-sdk-33.0-x86_64-linux` を export するだけで止めている。SDK の `bin/` はかつて優先度 5、つまり `/usr/bin` より前にあり、ホストのツールチェーンを隠していた。

- `clang` と `clang++` が SDK の clang-22 に解決されていた。その `bin/clang.cfg` はターゲットを `wasm32-unknown-wasip1` に固定し、同梱の wasi-sysroot を指す。`clang hello.c` は、`/usr/bin/clang`（Ubuntu 18.1.3, x86_64）なら ELF バイナリを作る場面で、黙って WebAssembly モジュールを吐いていた。
- `ar`, `nm`, `objcopy`, `objdump`, `ranlib`, `size`, `strings`, `strip`, `c++filt` は `llvm-*` ツールへのシンボリックリンクである。これらは ELF も扱えるので露骨には壊れないが、フラグと出力が GNU binutils と異なる — Buildroot にとっては、ひいては Keystone のビルドにとっては問題になる。

ビルドシステムは `WASI_SDK_PATH` を読む（SDK 同梱の CMake ツールチェーンファイルがそうしている）。それ以外は `$WASI_SDK_PATH/bin/clang` と明示的に書くべきである。名前が衝突しないツール — `llvm-*`, `clang-22` — も他と一緒に `PATH` から外れたので、同じ接頭辞が要る。

`bin/wasm-ld` は例外で、手で打たれる唯一のものに対するシムである。`WASI_SDK_PATH` が未設定のときはインストールパスにフォールバックする。非ログインシェルではそれを export する `.profile` が走らないので、この状況は実際に起きる。`lld` ではなく `$WASI_SDK_PATH/bin/wasm-ld` を exec しているのは意図的で、そのファイルは `lld` へのシンボリックリンクであり、LLD は `argv[0]` からドライバを選ぶ — つまり `ld.lld` や `lld-link` ではなく wasm リンカを選ばせているのは名前である。

リストに残っているものはいずれも `/usr/bin` と衝突しない。`~/.local/bin` は apt パッケージに対して `docutils` と `rst2*` スクリプトを勝ち取るが、それこそが pip のユーザインストールの目的である。wamr のビルドディレクトリには `iwasm` と `test_wrgsbase` しか無い。

なお mason の `~/.local/share/nvim/mason/bin` はここに無い。Neovim が自分で前置するからであり、フォーマッタのバイナリが nvim の中では解決できて素のシェルでは解決できないのはそのためである。

### VS Code の起動 (`bin/code`)

空白フィルタの唯一の犠牲者が VS Code で、そのランチャは `/mnt/c/Users/<user>/AppData/Local/Programs/Microsoft VS Code/bin` にある。`bin/code` はフィルタを緩めずにこれを取り戻すために存在する。`~/bin` には空白が無いので生き残り、シムが本物のランチャを絶対パスで呼ぶ。

ランチャは 2 つあり、互換ではない。

- `~/.vscode-server/bin/<commit>/bin/remote-cli/code` は、`$VSCODE_IPC_HOOK_CLI` 越しに、すでに接続済みのウィンドウへ引数を渡す。この変数が未設定だとエラーになる。
- Windows 側のラッパーは、ウィンドウを一から起動する（あるいは既存のものを再利用する）。`realpath "$0"` で自身のインストール先を見つけ、Linux バイナリである `/usr/bin/wslpath` を通じて Windows に到達する — したがって動作のために `PATH` に何かが載っている必要はない。

シムが `PATH` の順序に選択を委ねず `$VSCODE_IPC_HOOK_CLI` で分岐しているのは、VS Code が統合ターミナル用に remote-cli のディレクトリを `PATH` へ入れる一方、`.profile` がその後で `~/bin` を前置するので、そこでもシムが勝ってしまうからである。ユーザインストール (`AppData/Local/Programs`) とシステムインストール (`/mnt/c/Program Files`) の両方を探すので、VS Code をもう一方の方式で入れ直しても壊れない。

代替案は 2 つ検討して却下した。Keystone のビルドの前後だけ `PATH` を削るのは、安全な既定を逆転させたうえで、気にするのは Buildroot だけだと仮定することになる。`/etc/wsl.conf` の `appendWindowsPath=false` は注入そのものを止めるが、VS Code のパスにはどのみち空白が含まれるので手で足し直す必要が残り、さらに `explorer.exe` や `clip.exe` などにも同じ手当てが要る。

### 対話シェル (`.bashrc`)

1-91 行目は Debian スケルトンそのまま（非対話での早期 return、`histappend`、`checkwinsize`、lesspipe、`PS1`、dircolors と `--color=auto` のエイリアス群）で、変更は 1 か所だけ: `HISTSIZE` / `HISTFILESIZE` を 1000 / 2000 から 10000 / 20000 へ引き上げ、スケルトンの 1:2 の比率は保った。fzf の `CTRL-R` に検索対象を与えるため。それより下はすべてローカル: `BROWSER=wslview`、8 つの `KEYSTONE*` / `BUILDROOT_BUILDDIR` の export、riscv64 の実機でのみ `TZ` を設定する `uname -m` の case、`view='nvim -R'`、`~/.bash_aliases`・bash-completion・fzf ブロック・`~/.cargo/env` / `~/.deno/env` の条件付き source、そして下記の ssh-agent ブロック。

冒頭の早期 return により、これらはどれも非対話シェルには届かない。Claude Code にこれらの変数が見えているのは、その環境がセッション開始時にプロファイルから一度取り込まれるからである。

### fzf

fzf は apt パッケージ (`/usr/bin/fzf`, 0.44)。設定は `.profile` ではなく `.bashrc` にある。`.profile` は `PATH` を組み立てるだけであり、`/usr/bin` はすでにそこに載っているし、統合スクリプトはどちらも非対話シェルでは早期に return するからである。

| キー | 動作 |
|---|---|
| `CTRL-T` | カーソル位置にパスを挿入（右 60% にプレビュー） |
| `CTRL-R` | コマンド履歴を検索（`?` で選択項目の全文プレビューをトグル） |
| `ALT-C` | サブディレクトリへ `cd`（`ls` のプレビュー） |
| `**<TAB>` | どこでも補完 — `vim **<TAB>`, `kill **<TAB>`, `ssh **<TAB>` |
| `cd **<TAB>` | ディレクトリのみ — `pushd` と `rmdir` も同様 |

0.44 は `fzf --bash` (0.48) より前なので、2 つの統合ファイルはパス指定で source する。両者は同じ場所には無い。キーバインドは `/usr/share/doc/fzf/examples/key-bindings.bash` として配布されるが、Debian は補完を `/usr/share/bash-completion/completions/fzf` に置く — `examples/completion.bash` は存在せず、あるのは zsh 用だけである。どちらも `-f` でガードしてあるので、fzf をアンインストールしてもブロックは生き残る。

順序に関する罠が 2 つ。

- 補完はその上の bash-completion ブロックの **後** に source しなければならない。すでに入っている補完をラップするため。
- 補完は bash-completion の遅延ローダに任せず **明示的に** source しなければならない。ローダはコマンド名をキーにするので `fzf<TAB>` でしか発火せず、*他の* あらゆるコマンドに対する `**` トリガが決してインストールされないことになる。

ファイル一覧は、同梱の `find` による走査ではなく **fdfind**（`fd` の Debian/Ubuntu での名前）を通す。`.gitignore` にマッチするものを飛ばすのはこれである。`--hidden --follow` は、`find` なら列挙していたドットファイルとシンボリックリンクを戻し、`--exclude .git` は `--hidden` がオブジェクトストアを吐き出すのを止める。

`FZF_CTRL_T_COMMAND` と `FZF_ALT_C_COMMAND` はキーバインドを賄うが、`**` トリガはどちらも読まない。`_fzf_compgen_path` / `_fzf_compgen_dir` フックを呼ぶのであり、`completion.bash` はそれらがまだ存在しない場合にのみ定義するので、ブロックの側で先に定義している。その本体が共有変数を展開せず `fdfind` の呼び出しを直接書き下しているのは、関数本体は呼び出し時に展開されるため、そのような変数がすべての対話シェルで設定されたままでなければフックが動かなくなるからである。

`cd` には設定が要らない — `completion.bash` は既定で `cd`, `pushd`, `rmdir` を `_fzf_dir_completion` に通す（一覧は `FZF_COMPLETION_DIR_COMMANDS` で上書きできる）。ただし修正が 1 つ要る: fd はディレクトリを末尾 `/` 付きで出力し、`_fzf_dir_completion` はさらに `/` を足すので、`cd **<TAB>` が `./nvim//` を挿入しないよう `_fzf_compgen_dir` は `sed 's|/$||'` に通している。`_fzf_compgen_path` の方は fd のスラッシュを意図的に残す — `_fzf_path_completion` は何も足さず、その `-o nospace` によって、受理した直後のディレクトリから 2 度目の `**` で降りていけるからである。

すべてが `command -v fzf` で、fdfind 固有の部分はさらに `command -v fdfind` でガードされているので、どちらか一方しか無いマシンでは壊れるのではなく fzf 組み込みの `find` の挙動に落ちる。

### ssh-agent と git remote

`origin` は `git@github.com:mituzawa/dotfiles.git` で、`~/.ssh/config` は github.com を `~/.ssh/id_ed25519` に向けている。**この鍵にはパスフレーズがある**（`id_ed25519_nopass` も存在するが、LAN 内の 2 ホスト専用）。Claude Code のシェルには TTY が無いので `Enter passphrase for key ...:` に答えられない — push はプロンプトを出す代わりにハングするか失敗する。

`.bashrc` はエージェントのソケットを固定パスに固定し、1 つのエージェントですべてのシェルを賄うことでこれを回避している:

```sh
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
ssh-add -l >/dev/null 2>&1
if [ $? -eq 2 ]; then
    rm -f "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1
fi
```

パスフレーズは WSL の起動ごとに 1 回、対話端末で入力する:

```sh
ssh-add ~/.ssh/id_ed25519
```

このスニペットで効いているものが 2 つある。

- 起動の条件は `ssh-add -l` が単に非ゼロで終わることではなく、終了コード **2** であること。2 は応答したエージェントが無いことを意味し、**1** はエージェントは動いているがまだ鍵を持っていないことを意味する。`if ! ssh-add -l` と書くと、最初の `ssh-add` より前に新しいシェルが開かれるたびに、生きているエージェントを捨ててしまう。
- 既定のソケットパス (`/tmp/ssh-XXXXXX/agent.<pid>`) はエージェントを起動し直すたびに変わる。固定しているのはそのため。固定しないと、push のたびに `ls /tmp/ssh-*/agent.*` でソケットを探し回ることになる。

Claude Code は環境をセッション開始時にプロファイルから一度だけ取り込むので、`.bashrc` の変更より古いセッションには `SSH_AUTH_SOCK` が設定されていない。再起動せずとも、コマンドの前に付ければ動く:

```sh
SSH_AUTH_SOCK=~/.ssh/agent.sock git push
```

何も push せずに認証だけ確認するなら `ssh -T git@github.com`。`Hi mituzawa! You've successfully authenticated, but GitHub does not provide shell access.` と返る。

## Windows 側の設定 (`windows/`, `bin/win-sync.sh`)

`setup.sh` は `$HOME` へリンクを張ることしかしないので、`windows/` 以下のファイルは別扱いで `bin/win-sync.sh` が処理する。`bin` はすでに `setup.sh` の `TARGETS` に入っているので、このスクリプトは `TARGETS` を変えることなく `~/bin/win-sync.sh` として `PATH` に載る。

| `windows/` | コピー先 |
|---|---|
| `.wslconfig` | `%USERPROFILE%\.wslconfig` |
| `wezterm/wezterm.lua`, `wezterm/keybinds.lua` | `%USERPROFILE%\.config\wezterm\` |
| `vscode/settings.json` | `%APPDATA%\Code\User\settings.json` |
| `windows-terminal/settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json` |

```sh
win-sync.sh diff [name ...]   # 差分の表示（既定、読み取り専用）
win-sync.sh pull [name ...]   # Windows -> リポジトリ
win-sync.sh push [name ...]   # リポジトリ -> Windows
```

`<name>` は `windows/` 以下のパス。未知の名前は、黙って何もしないのではなく、既知のターゲット一覧とともに拒否される。

### これらのターゲットはコピーであってシンボリックリンクではない

シンボリックリンクは Linux 側で `setup.sh` がやっていることだが、ここでは道具として間違っている。理由は独立に 2 つある。

- **`.wslconfig` はディストリビューションが起動する前に読まれる。** これは `\\wsl.localhost\<distro>\...` が内側に存在する VM を設定するものなので、そこを指すリンクは原理的に辿れない — 権限の問題ではなく鶏と卵の問題である。（開発者モードは有効で `AllowDevelopmentWithoutDevLicense = 1` なので、昇格なしでリンクを作ること自体はできる。）
- **Windows Terminal と VS Code は GUI が使われるたびに自分の設定を書き換える。** そして Windows のアプリケーションは一般に、一時ファイルを書いてコピー先へリネームする。これはシンボリックリンクを実体ファイルで置き換えるので、チェックボックスを 1 つ触った時点でリンクが黙って壊れる。

コピーにすることで、「アプリケーションが設定を変えた」が障害モードではなくツールが扱うケース — `pull` — になる。`push` はコピー先を先に `<name>_ORG` として退避する。これは `setup.sh` と同じ慣習で、既にバックアップがあれば最初のものを保つ。

このバックアップが役に立つのは、一度も pull していないマシンへ push するときだけである。`pull` の後は同じ内容がすでに git にあるので `_ORG` は冗長であり、削除すべきである — チェックイン済みのディストリのスケルトンについて `723361f` が下したのと同じ判断。3 つのアプリケーションはいずれも設定の隣にある `*_ORG` を読まないので、放置しても危険ではなく、単に散らかるだけではある。

### 改行コード

3 つのアプリケーションで一致していない。Windows Terminal は LF を書き、VS Code と wezterm は CRLF を書き、`.wslconfig` は Windows 側が CRLF でリポジトリのコピーは LF だった。**リポジトリは全体を LF に保つ** — `pull` は Windows のファイルを `sed 's/\r$//'` に通し、`diff` は比較の前に両側を正規化するので、Windows 側での保存はファイル全体の差分ではなく実際に変わった行として現れる。`push` は LF を書き、4 つの読み手はいずれもそれを受け付ける。

`.gitattributes` (`* text=auto eol=lf`) は、将来 Windows 側で clone したときにこれらが CRLF でチェックアウトされるのを防ぐ。これによって既存のコミットが再正規化されることはない。ワークツリーで LF でない唯一の追跡ファイルは `.luarc.json` で、それはシンボリックリンクである。

### スクリプト内の 2 つの細部

- `~/bin` はこのリポジトリの `bin/` へのシンボリックリンクなので、`$0` は `readlink -f` で解決する必要がある。`setup.sh` の `cd "$(dirname "$0")" && pwd` だと `$HOME` に着いてしまう。bash の `cd` が論理パスを保つためである。
- Windows Terminal のパッケージディレクトリはビルド（Store、Preview、非パッケージ）ごとに名前が違うので、`Microsoft.WindowsTerminal*` のグロブで解決する。何にもマッチしなければ、そのターゲットだけ `SKIP` 行を出して落とし、残りは実行される。

### 意図的に同期しないもの

`~/.ssh` と Windows 側の `.claude/`（`.credentials.json` を含む）は秘密情報。`/etc/wsl.conf` はディストリビューション内部の Linux 側ファイルであって Windows のものではない。PowerShell のプロファイル、VS Code の `keybindings.json`、VS Code の `snippets/` はまだ存在せず、winget のパッケージエクスポートも無い。

### これが作られた理由となったドリフト

`windows/.wslconfig` は `57f7453` でコミットされたが、その後どこにも届いていなかった — `TARGETS` に入っておらず、他の仕組みも無かった。`win-sync.sh` を書いた時点で、リポジトリは 16GB / 8 プロセッサ / 32GB swap を要求していたのに `C:\Users\mituz\.wslconfig` は 8GB / 4 / 2GB と書いてあり、動作中の WSL は 4 CPU と 7.8GB だった。コミットされた値は一度も適用されたことがなかったのである。最初の `pull` では、動作中の値の方を正とした。
