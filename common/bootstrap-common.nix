{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.bootstrap;
in {
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
      default = ["tag:server"];
      description = "Tailscale tags to advertise on first up.";
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
      firewall.enable = mkForce false;
      useDHCP = mkForce true;

      wireless = {
        enable = true;
        networks."_kad".psk = cfg.kadPsk;
      };
    };

    # networkd default DHCP match only covers eth*/en*.
    systemd.network.networks."40-wlan" = {
      matchConfig.Name = "wl*";
      networkConfig.DHCP = "yes";
      dhcpV4Config.RouteMetric = 2048;
    };

    services.tailscale = {
      authKeyFile = mkForce (pkgs.writeText "authkey" cfg.tsAuthKey);
      inherit (cfg) tags;
    };
  };
}
