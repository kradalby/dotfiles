{ pkgs, self }:
let
  inherit (pkgs) lib;
  hosts = lib.filterAttrs (name: _: !(lib.hasInfix "." name)) self.nixosConfigurations;
  valid =
    name: host:
    let
      cfg = host.config.services.rex;
      login = cfg.loginServer;
    in
    if login.enable then
      !cfg.enable
      && !login.allowAnonymous
      && login.pam
      && login.extraListen == [ ]
      &&
        login.accounts == {
          kradalby.principals = [
            (if name == "ts1p-ldn" then "peer:21000" else "tailscale:kradalby@kradalby.no")
          ];
        }
      && login.tailscaleServe.enable == (name != "ts1p-ldn")
    else
      host.config.home-manager.users.kradalby.services.rex.enable
      && host.config.users.users.kradalby.linger;
  personal = self.nixosConfigurations.proton-ldn.extendModules {
    modules = [ ../profiles/rex-personal.nix ];
  };
  failed = lib.attrNames (lib.filterAttrs (name: host: !(valid name host)) hosts);
in
assert !personal.config.services.rex.loginServer.enable;
assert valid "personal" personal;
assert !personal.config.home-manager.users.kradalby.services.rex.tailscale.enable;
assert lib.assertMsg (
  failed == [ ]
) "Unexpected Rex access on: ${lib.concatStringsSep ", " failed}";
pkgs.runCommand "rex-access" { } "touch $out"
