# CLI tools used daily, shared by every machine.
# Anything occasional runs on demand without installing it: `nix run nixpkgs#k6 -- run test.js`.
# Runtimes live outside Nix: node, pnpm, go, terraform/tofu in mise, Python in uv, Rust in rustup.
pkgs: with pkgs; [
  # shell
  atuin bat eza fd fzf ripgrep zoxide starship tmux tuios httpie
  zsh-autosuggestions zsh-syntax-highlighting zsh-completions
  zsh-history-substring-search zsh-fzf-tab

  # TUIOS popups
  yazi btop lazygit lazydocker

  # dotfiles, toolchains, secrets
  chezmoi mise uv sops age

  # git and editor (git and jq ship with macOS). Neovim's language servers come
  # from Mason, except Nix's own tooling; tree-sitter compiles the parsers.
  gh neovim tree-sitter nixd nixfmt

  # kubernetes and cloud (docker, compose and kubectl ship with OrbStack)
  kubernetes-helm k9s kubectx k3d awscli2 ssm-session-manager-plugin

  # security
  # semgrep 1.180 is broken in nixpkgs (needs mcp 1.x, nixpkgs ships 2.x): use `uvx semgrep`, re-add once fixed.
  nmap gobuster trivy cosign gitleaks sonar-scanner-cli
]
