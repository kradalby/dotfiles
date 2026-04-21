{
  nixos-generators,
  inputs,
  overlays,
}: {
  name ? "bootstrap",
  hardwareModule,
  extraOverlays ? [],
  extraModules ? [],
  kadPsk ? "",
  tsAuthKey ? "",
  tags ? ["tag:server"],
}:
  nixos-generators.nixosGenerate {
    system = "aarch64-linux";
    format = "sd-aarch64";
    specialArgs = {inherit inputs;};
    modules =
      [
        inputs.ragenix.nixosModules.age
        inputs.tailscale.nixosModules.default
        ../common
        ../common/tailscale.nix
        ../common/bootstrap-common.nix
        hardwareModule
        {
          nixpkgs.overlays = overlays ++ extraOverlays;
          my.bootstrap = {
            enable = true;
            inherit name kadPsk tsAuthKey tags;
          };
        }
      ]
      ++ extraModules;
  }
