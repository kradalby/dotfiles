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

    systemd.services.tailscaled.onFailure = [ "notify-discord@%n.service" ];

    # create a oneshot job to authenticate to Tailscale
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];
      onFailure = [ "notify-discord@%n.service" ];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script =
        let
          upCommand = [
            "${pkgs.tailscale}/bin/tailscale up"
            "-login-server ${loginServer}"
            "--authkey ${preAuthKey}"
            "--accept-dns=false"
            ''--hostname ${builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.fqdn}''
          ]
          ++ lib.optional exitNode ''--advertise-exit-node \''
          ++ lib.optional ((builtins.length advertiseRoutes) > 0) ''--advertise-routes=${builtins.concatStringsSep "," advertiseRoutes}'';

        in
        ''
          # wait for tailscaled to settle
          sleep 2

          # check if we are already authenticated to tailscale
          status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
          if [ $status = "Running" ]; then # if so, then do nothing
            exit 0
          fi

          # otherwise authenticate with tailscale
          ${builtins.concatStringsSep " " upCommand}
        '';
    };
  };
in
{
  inherit tailscale;
}

