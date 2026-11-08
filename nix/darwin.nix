{ pkgs, ... }:
let
  # The user who ran `sudo darwin-rebuild ... --impure`: no username lives in this repo.
  user = builtins.getEnv "SUDO_USER";
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Determinate Nix owns the daemon and nix.conf.
  nix.enable = false;

  system.primaryUser =
    if user != "" then user else throw "run `sudo darwin-rebuild switch --flake .#mac --impure`: the user comes from $SUDO_USER";
  system.stateVersion = 7;

  environment.systemPackages = import ./packages.nix pkgs;
  # Stable paths for ~/.zshrc: these two plugins install outside share/zsh.
  environment.pathsToLink = [ "/share/fzf-tab" "/share/zsh-syntax-highlighting" ];

  # ~/.zshrc (chezmoi) runs compinit once and Starship draws the prompt.
  programs.zsh = {
    enableGlobalCompInit = false;
    enableBashCompletion = false;
    promptInit = "";
    # Set here, not in ~/.zshrc: any shell reading only /etc/zshrc would otherwise
    # rewrite ~/.zsh_history down to the default 2000 entries.
    histSize = 100000;
  };

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Touch ID for sudo, also inside TUIOS/tmux sessions.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      # The menu bar never hides: OmniWM's bar draws in its middle (see CustomUserPreferences).
      _HIHideMenuBar = false;
      # Fast key repeat, for hjkl and Backspace; takes effect after logging out.
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      # 24-hour time everywhere, the menu bar's clock too.
      AppleICUForce24HourTime = true;
    };
    dock = {
      tilesize = 50;
      show-recents = false;
      # OmniWM tiles the whole screen: the Dock appears only at the bottom edge.
      autohide = true;
    };
    # "Displays have separate Spaces", macOS's default: OmniWM pauses without it.
    spaces.spans-displays = false;
    finder.ShowPathbar = true;
    # chezmoi creates the folder (home/Screenshots/.keep).
    screencapture.location = "~/Screenshots";

    # The menu bar's right side: a digital clock with the weekday and the date, the
    # battery with its percentage, Sound and Focus; no Wi-Fi.
    menuExtraClock = {
      IsAnalog = false;
      ShowDayOfWeek = true;
      ShowDate = 1; # always
    };
    controlcenter.BatteryShowPercentage = true;
    CustomUserPreferences = {
      NSGlobalDomain = {
        # See AutoHideMenuBarOption.
        AppleMenuBarVisibleInFullscreen = true;
        # Icons closer together, macOS's and the apps' (each reads it at launch):
        # more room for OmniWM's bar in the middle.
        NSStatusItemSpacing = 10;
        NSStatusItemSelectionPadding = 8;
      };
      "com.apple.controlcenter" = {
        # Since macOS 26 the menu bar's "hide" setting (Always/On Desktop Only/In Full
        # Screen Only/Never: 0-3) is Control Center's, and at login it rewrites
        # _HIHideMenuBar from it: all three keys say "Never". Takes effect after logging out.
        AutoHideMenuBarOption = 3;
        # Since macOS 26 these keys, not controlcenter.Sound & co. (18/24), decide which
        # of Control Center's icons sit in the menu bar.
        "NSStatusItem VisibleCC Sound" = true;
        "NSStatusItem VisibleCC FocusModes" = true;
        "NSStatusItem VisibleCC Battery" = true;
        "NSStatusItem VisibleCC WiFi" = false;
      };
    };
  };

  # GUI apps, plus CLI tools nixpkgs can't build for macOS; the rest come from
  # packages.nix, fonts from fonts.packages.
  homebrew = {
    enable = true;
    # Only what is declared here stays: a formula or cask installed by hand is removed at
    # the next switch, a cask with its app data. Declare it here to keep it.
    onActivation.cleanup = "zap";
    taps = [
      "LargeModGames/spotatui"
    ];
    # Spotify TUI (Premium only), alt-m in TUIOS. nixpkgs builds it for Linux only;
    # the tap's binary has every source and cover art. Fully-qualified names are
    # trusted by default.
    brews = [ "LargeModGames/spotatui/spotatui" ];
    # Not Obsidian: it is downloaded by hand. An app already installed
    # by hand can't be adopted by Homebrew (macOS App Management) and fails the whole switch.
    casks = [
      # The cask, not nixpkgs: its fixed path keeps the Accessibility permission across updates.
      "omniwm"
      "ghostty" # bundles JetBrains Mono and Nerd Font symbols: no font casks needed
      "latest" # tells which installed apps have updates
      "orbstack"
    ];
  };
}
