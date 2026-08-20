{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.my.bootstrap;
in
{
  options.my.bootstrap = {
    enable = mkEnableOption "Raspberry Pi bootstrap image configuration";

    name = mkOption {
      type = types.str;
      default = "bootstrap";
      description = "Hostname for the bootstrap image.";
    };

    kadPsk = mkOption {
      type = types.str;
      default = "";
      description = "WPA passphrase for the _kad wifi network.";
    };

    tsAuthKey = mkOption {
      type = types.str;
      default = "";
      description = "Tailscale preauth key baked into the image.";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:server" ];
      description = "Tailscale tags to advertise on first up.";
    };

    wifi = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the _kad wifi networks. Off for wired installers.";
    };

    firewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Let the host config own the firewall. Default false force-disables it
        (safe on a LAN/wifi rpi). Set true for public-IP installers that must
        lock SSH to an allowlist.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Bootstrap images are headless — avoid pulling every terminal
    # emulator's terminfo (ghostty/kitty/wezterm/...) and their gtk/x11
    # build chain.
    environment.enableAllTerminfo = mkForce false;

    networking = {
      hostName = cfg.name;
      domain = "bootstrap.fap.no";
      firewall.enable = mkIf (!cfg.firewall) (mkForce false);
      useDHCP = mkForce true;

      wireless = mkIf cfg.wifi {
        enable = true;
        # Only defined when the PSK was actually provided: an empty psk fails
        # the wpa option's pattern type at eval, which would break pure-eval
        # flake checks that never pass the env vars.
        networks = mkIf (cfg.kadPsk != "") {
          "_kad".psk = cfg.kadPsk;
          "_kad24".psk = cfg.kadPsk;
        };
      };
    };

    # networkd default DHCP match only covers eth*/en*.
    systemd.network.networks."40-wlan" = mkIf cfg.wifi {
      matchConfig.Name = "wl*";
      networkConfig.DHCP = "yes";
      dhcpV4Config.RouteMetric = 2048;
    };

    # Warn (not assert — pure-eval flake checks legitimately eval these images
    # with no env) when a bootstrap secret wasn't provided; the built image
    # would boot but join neither wifi nor the tailnet.
    warnings =
      optional (cfg.tsAuthKey == "")
        "bootstrap: BOOTSTRAP_TS_AUTHKEY is unset — build with --impure and the env vars documented in flake.nix"
      ++ optional (
        cfg.wifi && cfg.kadPsk == ""
      ) "bootstrap: BOOTSTRAP_WIFI_PSK is unset — the image will have no wifi credentials";

    services.tailscale = {
      authKeyFile = mkForce (pkgs.writeText "authkey" cfg.tsAuthKey);
      inherit (cfg) tags;
    };

    # Dummy console passwords so you aren't locked out if wifi/ssh
    # fails on first boot. Change after login.
    users.users.kradalby.initialPassword = "kradalby";
    users.users.root.initialPassword = "root";
  };
}
