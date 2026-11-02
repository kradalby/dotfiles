{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    accounts.kradalby.principals = [ "tailscale:kradalby@kradalby.no" ];
    tailscaleServe.enable = true;
  };

  # Rex expects the Tailscale CLI; the flake package defaults to tailscaled.
  services.tailscale.package = pkgs.tailscale // {
    meta = pkgs.tailscale.meta // {
      mainProgram = "tailscale";
    };
  };

  # Both configure Serve; serialize their writes, as on dev.ldn.
  systemd.services.rex-tailscale-serve.after = [ "tailscaled-serve-config.service" ];
}
