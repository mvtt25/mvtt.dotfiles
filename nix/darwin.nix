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
      # Fast key repeat, for hjkl and Backspace; takes effect after logging out.
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      # 24-hour time everywhere, the menu bar's clock too.
      AppleICUForce24HourTime = true;
    };
    dock = {
      tilesize = 50;
      show-recents = false;
    };
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
      "com.apple.controlcenter" = {
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
    # Not Obsidian: it is downloaded by hand. An app already installed
    # by hand can't be adopted by Homebrew (macOS App Management) and fails the whole switch.
    casks = [
      "latest" # tells which installed apps have updates
      "orbstack"
    ];
  };
}
