{
  lib,
  pkgs,
  ...
}: {
  options = {
    my.wan = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    my.lan = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    my.extraLan = lib.mkOption {
      type = lib.types.list lib.types.str;
      default = [];
    };

    my.machines = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [];
    };
  };

  config = lib.mkIf pkgs.stdenv.isLinux {
    networking.useDHCP = false;
    networking.useNetworkd = lib.mkDefault true;
    networking.dhcpcd.enable = lib.mkDefault false;
    systemd.network.enable = lib.mkDefault true;
    systemd.network.wait-online.ignoredInterfaces = lib.mkDefault ["tailscale0" "wg0"];
  };
}
