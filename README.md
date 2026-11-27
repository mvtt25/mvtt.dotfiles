# mvtt.dotfiles

Reproducible macOS (Apple Silicon) workstation. One rule: **Nix decides what is installed, chezmoi decides how it is configured.**

| Layer | Owns | Lives in |
|---|---|---|
| nix-darwin | CLI tools, macOS defaults, Touch ID sudo, the Homebrew cask list | `flake.nix`, `nix/` |
| Homebrew | GUI apps only, declared by nix-darwin | `nix/darwin.nix` |
| chezmoi | `~/Developer` (`personal`, `work`, `oss`: the git identity follows the folder) and the dotfiles in `$HOME`: zsh, Starship, mise, Ghostty, OmniWM, TUIOS, git, atuin, btop, lazygit, Claude Code; the wallpaper (downloaded, not committed) | `home/` |
| NvChad | Neovim config, linked as `~/.config/nvim`; plugin versions pinned in `nvim/lazy-lock.json` | `nvim/` |
| mise / uv / rustup | runtimes: node, pnpm and friends / Python / Rust | each project |
| Secrets | never in this repo: `~/.config/zsh/local.zsh` (mode 600) | the machine |

## Using it yourself

This is one person's workstation, published to read and to copy from. To run it on your own Mac, fork it first:

- **Point it at your fork**: `repo=` in [`install.sh`](install.sh) and the URL in the bootstrap command below. `chezmoi update` runs `sudo darwin-rebuild` on whatever the repo's owner pushes: follow only a repo you own.
- **Read `nix/darwin.nix` before the first switch**: `homebrew.onActivation.cleanup = "zap"` uninstalls every Homebrew formula and cask the file does not list, the apps' data too. List yours there, or set it to `"none"`. The same file changes macOS defaults and turns on the firewall and Touch ID for sudo.
- **`home/dot_claude` is a personal Claude Code setup**: `settings.json` enables third-party plugin marketplaces, and `rules/` has Claude run a Telegram notifier after each task. Drop what you do not want.
- **OmniWM's seed** (`create_settings.toml`) approves the `spaces` and `crew` widgets' programs under `/Users/matt`: under another username the approval does not match, so expect OmniWM's trust prompt.

## Bootstrap (fresh Mac)

```sh
curl -fsSL https://raw.githubusercontent.com/mvtt25/mvtt.dotfiles/master/install.sh | sh
```

[`install.sh`](install.sh) installs Determinate Nix and Homebrew, clones this repo to
`~/Developer/personal/mvtt.dotfiles`, applies it with chezmoi (which switches nix-darwin: it asks for sudo),
then installs mise's runtimes (node, pnpm, ruby, go, OpenTofu), rustup with
rust-analyzer, and Claude Code. Run it again after a failure: it skips what is done. No username lives in
this repo: nix-darwin takes it from `$SUDO_USER`, hence `--impure` on every switch.

Then, by hand:
1. Secrets and machine-local settings in `~/.config/zsh/local.zsh` (mode 600).
2. `gh auth login`, your SSH keys, and your git identity: `user.name` and `user.email`
   in `~/.gitconfig-personal` and `~/.gitconfig-work` (`~/.gitconfig` picks one by folder).
3. Obsidian, from obsidian.md.
4. Firefox: sign in to Firefox Sync, which brings back extensions, settings and bookmarks.
5. OmniWM: grant Accessibility and Input Monitoring in System Settings >
   Privacy & Security, then OmniWM's Settings > General > Start at Login.
6. Neovim: the first `nvim` installs the plugins and Treesitter parsers; then **open any
   file** and run `:MasonInstallAll`: opening a file loads the LSP config, so it sees
   every language server, plus the formatters and debug adapters. An existing
   `~/.config/nvim` directory is left untouched.

## Day to day

```sh
chezmoi update                                    # pull, apply dotfiles, rebuild Nix if nix/ changed
sudo darwin-rebuild switch --flake .#mac --impure # rebuild Nix only
nix flake update                                  # bump pinned inputs, then switch
nix run nixpkgs#<tool> -- <args>                  # occasional tools, without installing them
```

Nix flakes only see files tracked by git: `git add` new files before rebuilding.

Claude Code: only `settings.json` (with TUIOS's hooks), the global rules, the statusline,
the Telegram notifier and the TUIOS skill (as `tuios integration install claude-code`
writes them) live here; agents, commands and other skills come from the plugins
`settings.json` enables. Claude Code rewrites `settings.json` itself (`/model`, `/config`, `/plugin`):
`chezmoi diff` shows the drift, `chezmoi re-add ~/.claude/settings.json` keeps it.
This repo is public: read the diff before `re-add`, since tools add hooks with absolute paths.

OmniWM does the same with `shell/shell.toml` from Styles & Widgets: `chezmoi re-add` keeps the
change. `~/.config/omniwm/settings.toml` is different: the repo holds a seed
(`create_settings.toml`) that chezmoi writes only on a Mac without one, and from then on the
file is OmniWM's. Its Settings window saves the machine's monitors and app rules there, which
stay out of this repo: copy a change worth keeping (a hotkey, a gap) into the seed by hand.
The file is strict (a missing required key rejects all of it): edit values in place.
The bar's style is `mvtt` (`shell/mvtt`), a copy of OmniWM's Default to customize. For any
style, Styles & Widgets offers the TUIOS agents widget (`shell/widgets/agents`, fed by TUIOS's
hooks over OmniWM's IPC) and the Modest Dark palette (`shell/themes`). `shell/default` and the
styles from the gallery are OmniWM's, not this repo's.

`chezmoi update` runs `sudo darwin-rebuild` on whatever it pulls, so push access to this repo means root on the machine: keep 2FA on the GitHub account.

## License

[MIT](LICENSE), except `home/dot_config/omniwm/shell`, which is
[GPL-2.0-only](LICENSES/GPL-2.0-only.txt): `shell/mvtt` is a copy of
[OmniWM](https://github.com/OmniNull/OmniWM)'s Default style (© OmniNull), and the widgets and
theme beside it load into it. A file changed in `shell/mvtt` must say so, as the GPL asks.
