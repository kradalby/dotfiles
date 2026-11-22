{ inputs, ... }:
{
  services.rex.loginServer.enable = false;
  users.users.kradalby.linger = true;
  home-manager.users.kradalby.imports = [ (import ../home/rex-personal.nix { inherit inputs; }) ];
}
