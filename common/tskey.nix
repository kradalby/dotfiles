{
  pkgs,
  libs,
  ...
}: let
in {
  age.secrets.tailscale-preauthkey = {
    file = ../secrets/tailscale-preauthkey.age;
    mode = "444";
  };
}
