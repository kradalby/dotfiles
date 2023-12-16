{
  config,
  pkgs,
  lib,
  flakes,
}: let
  package = pkgs.unstable.tailscale;
  tailscale = {
    hostname ? ''${builtins.replaceStrings [".fap.no"] [""] config.networking.fqdn}'',
    loginServer ? "",
    exitNode ? false,
    advertiseRoutes ? [],
    acceptDns ? false,
    reset ? true,
    reauth ? false,
    ssh ? true,
    tags ? [],
  }: {
    disabledModules = ["services/networking/tailscale.nix"];

    imports = [
      "${flakes.nixpkgs-unstable}/nixos/modules/services/networking/tailscale.nix"
    ];

    age.secrets.tailscale-preauthkey.file = ../../secrets/tailscale-preauthkey.age;

    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };

    # make the tailscale command usable to users
    environment.systemPackages = [package];

    # enable the tailscale service
    services.tailscale = {
      enable = true;
      inherit package;

      authKeyFile = config.age.secrets.tailscale-preauthkey.path;

      useRoutingFeatures =
        if exitNode || (builtins.length advertiseRoutes) > 0
        then "both"
        else "client";

      extraUpFlags =
        [
          ''--hostname ${hostname}''
        ]
        ++ lib.optional ((builtins.stringLength loginServer) > 0) "--login-server ${loginServer}"
        ++ lib.optional reauth "--force-reauth"
        ++ lib.optional reset "--reset"
        ++ lib.optional ssh "--ssh"
        ++ lib.optional acceptDns "--accept-dns=false"
        ++ lib.optional exitNode ''--advertise-exit-node ''
        ++ lib.optional exitNode ''--advertise-connector ''
        ++ lib.optional ((builtins.length advertiseRoutes) > 0) ''--advertise-routes=${builtins.concatStringsSep "," advertiseRoutes}''
        ++ lib.optional ((builtins.length tags) > 0) ''--advertise-tags=${builtins.concatStringsSep "," tags}'';
    };
  };
in {
  inherit tailscale;
}
