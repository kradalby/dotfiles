{
  pkgs,
  libs,
  ...
}: let
in {
  age.secrets.ts-authkey = {
    file = ../secrets/ts-authkey.age;
    mode = "444";
  };
}
