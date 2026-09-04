# dotfiles

Linux/WSL2 環境の個人用 dotfiles。bash、Neovim、`bin/` 以下のシェルユーティリティ、そして `windows/` 以下の Windows 側設定。

*なぜ* そうなっているのかは `CLAUDE.md` を参照 — `PATH` の順序、fzf と ssh-agent のブロック、Neovim のプラグイン構成、保存時フォーマットの落とし穴。このファイルが扱うのは、新しいマシンを動く状態に戻す手順だけ。

| | |
|---|---|
| `.bashrc`, `.profile`, `.gitconfig`, `.clang-format`, `.vimrc`, `.vim` | `setup.sh` が `$HOME` へリンクする |
| `bin/` | `~/bin` としてリンクされ、`PATH` の先頭に来る |
| `nvim/` | `~/.config/nvim` としてリンクされる |
| `windows/` | `bin/win-sync.sh` が Windows 側へコピーする |
| `etc/` | 参照用のコピー。配置は手作業 |

## 新しいマシンでの復元

### 1. Windows 側

WSL2 + Ubuntu 24.04。何よりも先に **JetBrainsMono Nerd Font** を Windows にインストールすること。Windows Terminal の Ubuntu プロファイルがこの face を名指ししており、無いと Windows Terminal は黙ってフォールバックし、nvim-web-devicons も ddu の `converter_devicon` も lightline の powerline セパレータも軒並み豆腐になる。wezterm は任意 — 何もこれに依存していない — だが設定は `windows/` にあり、手順 8 で復元される。

wezterm は face を名指し **していない**。`windows/wezterm/wezterm.lua` が設定しているのは `font_size` だけで、同梱の JetBrains Mono（Nerd Font ビルドではない方）を使う。それでも字形が欠けないのは、wezterm が *Symbols Nerd Font Mono* を実行ファイルに内蔵していて私用領域をそこへフォールバックさせ、powerline セパレータは `custom_block_glyphs` で自前描画するため。実際にどのフォントで解決されたかは次で確認できる。

```sh
'/mnt/c/Program Files/WezTerm/wezterm.exe' ls-fonts --text $'\ue0b0\uf07b'
```

つまりフォントのインストールは Windows Terminal の要件であって、wezterm の要件ではない。Linux 側には何も入れる必要がない。nvim は TUI なので `guifont` を持たず、このリポジトリのどの設定もそれを設定していない。

### 2. apt パッケージ

```sh
sudo apt update
sudo apt install -y git curl build-essential bash-completion fzf fd-find jq wslu
```

- `fd-find` はバイナリを **`fdfind`** という名前で入れる。`.bashrc` の fzf ブロックはその名前を前提にしているので、リネームしないこと。
- `wslu` が `wslvar` と `wslview` を提供する。前者は `bin/win-sync.sh` が必要とし、後者は `.bashrc` が `BROWSER=wslview` に使う。
- apt の `fzf` は 0.44 で、`fzf --bash` より前のバージョン。`.bashrc` は 2 つの統合スクリプトをパス指定で source し、Debian が補完を `examples/` の外に置いていることも織り込んである。

### 3. clone とリンク

```sh
git clone https://github.com/mituzawa/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
exec bash -l
```

HTTPS なのは意図的。SSH の remote には、このリポジトリに意図的に含めていない鍵が要る。remote の切り替えは手順 7 で行う。

`setup.sh` は `TARGETS` リストの各項目を `$HOME` へシンボリックリンクし、既存の **実体** ファイルは `<name>_ORG` として退避する（新規インストールではディストリのスケルトンがそこに落ちる。シェルが期待どおりになったら削除してよい）。`exec bash -l` が `.profile` に `PATH` を組み直させ、それによって `~/bin` が他のすべてより前に来る。

### 4. Neovim

```sh
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
```

`.profile` が Neovim 用に足すパスは `/opt/nvim-linux-x86_64/bin` ひとつだけなので、別の場所ではなくそこへ入れること。`view='nvim -R'` のエイリアスは、そのエントリが存在して初めて有効になる。

### 5. Deno

```sh
curl -fsSL https://deno.land/install.sh | sh
```

任意ではない。プラグインマネージャ (dpp.vim) は `nvim/config.ts` を denops.vim 経由で走らせ、その実体は Deno プロセスである。`deno` が `PATH` に無ければプラグインの状態は生成されず、何もロードされない。インストーラは `~/.deno/env` を書き、それを `.bashrc` が source する。

### 6. Neovim の初回起動

`lua/darkpowerd/dpp.lua` が dpp.vim・denops.vim・5 つの dpp 拡張を `~/.cache/nvim/dpp/repos/github.com/` へ自力で clone するので、初回の `nvim` は遅く、状態キャッシュができるまではエラーを出すこともある。その後、Neovim の中で:

```vim
:DppMakeState
:DppInstall
```

再起動し、mason が LSP の依存として引いてこないフォーマッタのバイナリを入れる:

```vim
:MasonInstall prettierd biome djlint mdformat yamlfix shfmt
```

LSP サーバ (`lua_ls`, `vimls`, `clangd`, `rust_analyzer`, `bashls`, `pyright`) は mason-lspconfig の `automatic_enable` が自分で入れ、`clang-format` と `stylua` もそれに付いてくる。`jq` は手順 2 の apt から。

対話セッション無しで状態を作り直すこともできる。シェルから TOML を編集した後はこちらを使う:

```sh
nvim --headless -c 'autocmd User Dpp:makeStatePost qall!' \
  -c 'call dpp#make_state(stdpath("cache").."/dpp", stdpath("config").."/config.ts")'
```

### 7. SSH 鍵と git remote

```sh
ssh-keygen -t ed25519 -C mituzawa@gmail.com
```

`~/.ssh/config` はこのリポジトリに **含まれていない**。github.com のスタンザは手で書く:

```
Host github.com
	HostName github.com
	User git
	IdentityFile "~/.ssh/id_ed25519"
```

公開鍵を GitHub に登録したら、remote を切り替えて確認する:

```sh
git -C ~/dotfiles remote set-url origin git@github.com:mituzawa/dotfiles.git
ssh -T git@github.com    # Hi mituzawa! You've successfully authenticated, ...
```

鍵にはパスフレーズがある。`.bashrc` はエージェントのソケットを `~/.ssh/agent.sock` に固定して 1 つのエージェントで全シェルを賄うようにしてあるので、パスフレーズの入力は WSL の起動ごとに 1 回で済む:

```sh
ssh-add ~/.ssh/id_ed25519
```

### 8. Windows 側の設定

```sh
win-sync.sh diff    # 読み取り専用: 新マシンの内容とこのリポジトリの差分
win-sync.sh push    # リポジトリ -> Windows
```

これで `.wslconfig`、Windows Terminal の設定、wezterm の設定、VS Code の設定が戻る。`push` は各コピー先を `<name>_ORG` として退避する。一度も pull していないマシンでは、結果が期待どおりになるまで残しておき、その後で削除すること。

`.wslconfig` は PowerShell から `wsl --shutdown` するまで効かない。値はこのマシンのもの — 8GB / 4 プロセッサ / 2GB swap — なので、shutdown する前に新しいホストに見合うか確認すること。

### 9. 任意の追加物

以下はシェルや Neovim が動くために必須ではない。`.profile` とキーマップが参照しているから存在している。

| | |
|---|---|
| lazygit (`,ug`) | `go install github.com/jesseduffield/lazygit@latest` → `~/go/bin` |
| Node.js | mason の `prettierd` と `biome` は npm パッケージ |
| Rust | `rustup`。`~/.cargo/env` を書き（`.bashrc` が source する）、`rust_analyzer` の土台にもなる |
| WASI SDK | `~/images/wasi-sdk-33.0-x86_64-linux` に展開する。`.profile` は `WASI_SDK_PATH` を export しつつ、その `bin/` は意図的に `PATH` へ **入れない** |
| wasmtime | `~/.wasmtime` に入る。`.profile` はディレクトリが存在するときだけその `bin/` を足す |
| VS Code | `PATH` の空白フィルタがランチャを落とすので、`bin/code` が Windows 側ランチャを呼ぶシムになっている |

## 確認

```sh
exec bash -l
echo "$PATH" | tr : '\n' | head -6   # ~/bin, ~/.local/bin, ~/go/bin, ... , /opt/nvim-linux-x86_64/bin
command -v nvim deno fzf fdfind jq wslvar
ssh -T git@github.com
win-sync.sh diff                     # 全ターゲットが SAME
```

Neovim の中では、`,uc` で ddu のファイル検索が開き、`,uj` で nvim-tree がアイコン付きでトグルし、`:checkhealth` が denops を running と報告し、このリポジトリのファイルを保存しても差分が出ない（ツリーは設定済みのフォーマッタで整形済みのため）。
