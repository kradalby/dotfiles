# Personal base configuration for Kristoffer's Darwin (macOS) machines
# This contains shared settings across all personal Mac machines
{
  pkgs,
  config,
  machine,
  lib,
  stdenv,
  inputs,
  ...
}:
let
  # Linux builder configuration for cross-compiling to aarch64-linux
  #
  # Bootstrap process for new machines:
  # 1. First run with useRosettaBuilder = false (uses nix.linux-builder)
  #    This bootstraps the basic linux builder using Apple Virtualization.framework
  # 2. Once the linux-builder is working, set useRosettaBuilder = true
  #    This builds and enables the rosetta-based builder which is faster
  #
  # To bootstrap: temporarily set to false, rebuild, then set back to true
  useRosettaBuilder = true;

  # skhd runs commands via /bin/sh with a bare launchd PATH, so reference the
  # script derivations by store path rather than relying on PATH lookup.
  ghostty-new-mosh-tab = import ../../pkgs/scripts/ghostty-new-mosh-tab.nix { inherit pkgs; };
  tailscale-switch-toggle = import ../../pkgs/scripts/tailscale-switch-toggle.nix { inherit pkgs; };
in
{
  imports = [
    ../darwin.nix
    # Base system toolset; the fuller interactive userland comes via
    # home-manager (pkgs/home-packages.nix).
    ../../pkgs/base.nix
    ../../common/tmux.nix
    ../../pkgs/homebrew.nix
    ./syncthing.nix
    ./tailscale-notify.nix
    ../../modules/macos.nix
  ];

  # Put fish in the system profile so the login shell
  # (/run/current-system/sw/bin/fish) resolves; user-level fish config
  # still comes from home-manager (home/fish.nix).
  programs.fish.enable = true;

  # TODO(ghostty): Workaround for Ghostty lacking an exec/command keybind
  # action. skhd provides a global hotkey that runs an external command,
  # scoped to Ghostty via proc_map. The script uses ghostty-tab to open a
  # new Ghostty tab with mosh completely out-of-band via AppleScript.
  # Ref: https://github.com/ghostty-org/ghostty/issues/9961
  # Remove when Ghostty supports an exec keybind action.
  # NOTE: skhd requires Accessibility permissions in
  # System Settings > Privacy & Security > Accessibility.
  services.skhd = {
    enable = true;
    skhdConfig = ''
      cmd + shift - t [
          "Ghostty" : ${ghostty-new-mosh-tab}/bin/ghostty-new-mosh-tab
          *         ~
      ]
      cmd + shift - b : ${tailscale-switch-toggle}/bin/tailscale-switch-toggle
    '';
  };

  nix-rosetta-builder = {
    enable = useRosettaBuilder;
    speedFactor = 10; # Highest priority - local builder
  };
  nix.linux-builder.enable = !useRosettaBuilder;

  nix = {
    settings = {
      trusted-users = [ machine.username ];
      # builders = "@/etc/nix/machines";
    };

    # distributedBuilds = true;
    # buildMachines = import ../buildmachines.nix;
  };

  users.users.kradalby = {
    name = machine.username;
    home = machine.homeDir;
  };

  home-manager = {
    verbose = true;
    # Force-overwrite backups instead of backupFileExtension, which aborts
    # activation when a stale *.hm_bak~ already exists (apps like go/claude
    # rewrite HM-managed config, so the collision recurs every switch). A
    # failed activation freezes user services on the old generation, so new
    # package versions are never adopted.
    backupCommand = "${pkgs.writeShellScript "hm-backup" ''
      exec ${pkgs.coreutils}/bin/mv -f "$1" "$1.hm_bak~"
    ''}";
    useUserPackages = true;
    useGlobalPkgs = true;
    sharedModules = [ inputs.nix-index-database.homeModules.nix-index ];
    users."${machine.username}" = {
      imports = [
        ../../home
      ];

      # macOS Safari settings - disable autofill and password manager
      targets.darwin.defaults = {
        "com.apple.Safari" = {
          AutoFillPasswords = false;
          AutoFillCreditCardData = false;
          AutoFillMiscellaneousForms = false;
          AutoFillFromAddressBook = false;
          AutoOpenSafeDownloads = false;
          ShowOverlayStatusBar = true;
          ShowFullURLInSmartSearchField = true;
          IncludeDevelopMenu = true;
          WebKitDeveloperExtrasEnabledPreferenceKey = true;
        };
      };
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  networking = {
    hostName = machine.hostname;
    computerName = machine.hostname;
    localHostName = machine.hostname;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
