{lib, ...}: {
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
  };

  config = {
    networking.useDHCP = false;

    # TODO: Re-evaluate if it turns less buggy later
    networking.useNetworkd = lib.mkDefault false;
  };
}
