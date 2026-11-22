{ inputs }:
{
  imports = [ inputs.rex.homeManagerModules.default ];
  services.rex.enable = true;
}
