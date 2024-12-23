{
  config,
  pkgs,
  lib,
}: let
  package = pkgs.tailscale;
  tailscale = {
    hostname ? ''${builtins.replaceStrings [".fap.no"] [""] config.networking.fqdn}'',
    loginServer ? "https://headscale.kradalby.no",
    reset ? true,
    reauth ? false,
    ssh ? true,
    tags ? [],
  }: {
    imports = [
      ../../modules/tailscale2-userpace.nix
    ];

    age.secrets.headscale-client-preauthkey.file = ../../secrets/headscale-client-preauthkey.age;

    # make the tailscale command usable to users
    environment.systemPackages = [package];

    # enable the tailscale service
    services.tailscale2 = {
      enable = true;
      inherit package;

      authKeyFile = config.age.secrets.headscale-client-preauthkey.path;

      extraUpFlags =
        [
          ''--hostname=${hostname}''
        ]
        ++ lib.optional ((builtins.stringLength loginServer) > 0) "--login-server=${loginServer}"
        ++ lib.optional reauth "--force-reauth"
        ++ lib.optional reset "--reset"
        ++ lib.optional ssh "--ssh"
        ++ lib.optional ((builtins.length tags) > 0) ''--advertise-tags=${builtins.concatStringsSep "," tags}'';
    };
  };
in {
  inherit tailscale;
}
