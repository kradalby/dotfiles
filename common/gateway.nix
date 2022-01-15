{ lib, ... }: {
  options = {
    my.wan = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    my.lan = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };
}
