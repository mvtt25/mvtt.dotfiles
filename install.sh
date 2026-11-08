#!/bin/sh
# Bootstraps a fresh Mac; safe to run again, every step skips what is already there:
#   curl -fsSL https://raw.githubusercontent.com/mvtt25/mvtt.dotfiles/master/install.sh | sh
set -eu

repo=https://github.com/mvtt25/mvtt.dotfiles
dir="$HOME/Developer/personal/mvtt.dotfiles"
nix=/nix/var/nix/profiles/default/bin/nix

main() {
  [ "$(uname -s)" = Darwin ] || { echo "macOS only" >&2; exit 1; }

  step "Determinate Nix"
  [ -x "$nix" ] || curl -fsSL https://install.determinate.systems/nix | sh -s -- install

  step "Homebrew, with the Xcode Command Line Tools (and so git)"
  [ -x /opt/homebrew/bin/brew ] ||
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  step "dotfiles and nix-darwin (asks for sudo)"
  [ -d "$dir/.git" ] || git clone "$repo" "$dir"
  "$nix" run nixpkgs#chezmoi -- init --source "$dir" --apply

  step "runtimes from mise"
  /run/current-system/sw/bin/mise install

  step "Rust"
  [ -x "$HOME/.cargo/bin/rustup" ] ||
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  "$HOME/.cargo/bin/rustup" component add rust-analyzer

  step "Claude Code"
  # ~/.zshrc already puts ~/.local/bin on PATH: the installer sees the same, so its
  # shell setup has nothing to add to the chezmoi-managed files.
  [ -x "$HOME/.local/bin/claude" ] ||
    curl -fsSL https://claude.ai/install.sh | PATH="$HOME/.local/bin:$PATH" bash

  cat <<'EOF'

Done. Left to you:
  - secrets and machine-local settings in ~/.config/zsh/local.zsh (chmod 600)
  - gh auth login, your SSH keys, and user.name/user.email in
    ~/.gitconfig-personal and ~/.gitconfig-work
  - Obsidian, from obsidian.md
  - Firefox: sign in to Firefox Sync (extensions, settings, bookmarks)
  - Accessibility and Input Monitoring for OmniWM, then
    OmniWM's Settings > General > Start at Login
  - in a new terminal: nvim, open any file, then :MasonInstallAll
EOF
}

step() { printf '\n==> %s\n' "$1"; }

# Piped from curl, stdin is this script: Homebrew's prompt, git and chezmoi must read the
# terminal instead (the nested curl | sh installers read it on their own).
main </dev/tty
