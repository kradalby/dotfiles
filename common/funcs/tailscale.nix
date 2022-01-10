{ config, pkgs, lib }:
let
  tailscale = hostname: loginServer: preAuthKey: exitNode: advertiseRoutes: {

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    # make the tailscale command usable to users
    environment.systemPackages = [ pkgs.tailscale ];

    # enable the tailscale service
    services.tailscale.enable = true;

    # create a oneshot job to authenticate to Tailscale
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${pkgs.tailscale}/bin/tailscale up \
          -login-server ${loginServer} \
          --authkey ${preAuthKey} \
          --accept-dns=false \
          ${lib.strings.optionalString (exitNode) ''--advertise-exit-node \''}
          ${lib.strings.optionalString ((builtins.length advertiseRoutes) > 0) ''--advertise-routes=${builtins.concatStringsSep "," advertiseRoutes} \''}
          --hostname ${builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.fqdn}
      '';
    };
  };
in
{
  inherit tailscale;
}

