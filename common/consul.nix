{ pkgs, config, lib, ... }: {
  options = {
    my.consulServices = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };

  config.services.consul = {
    enable = lib.mkDefault true;
    webUi = lib.mkDefault false;
    # interface = {
    #   bind = "br0";
    #   advertise = "br0";
    # };

    extraConfig = {
      node_name = builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.fqdn;
      server = lib.mkDefault false;
      log_level = "INFO";

      connect = {
        enabled = true;
      };

      services = builtins.attrValues config.my.consulServices;
    };
  };

}
