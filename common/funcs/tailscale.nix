{
  config,
  pkgs,
  lib,
}: let
  tailscale = hostname: loginServer: preAuthKey: exitNode: advertiseRoutes: {
    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };

    boot.kernel.sysctl = lib.mkIf exitNode {
      # if you use ipv4, this is all you need
      "net.ipv4.ip_forward" = lib.mkForce true;
      "net.ipv4.conf.all.forwarding" = lib.mkForce true;

      # If you want to use it for ipv6
      "net.ipv6.conf.all.forwarding" = lib.mkForce true;
    };

    # make the tailscale command usable to users
    environment.systemPackages = [pkgs.tailscale];

    # enable the tailscale service
    services.tailscale.enable = true;

    systemd.services.tailscaled.onFailure = ["notify-discord@%n.service"];

    # create a oneshot job to authenticate to Tailscale
    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = ["network-pre.target" "tailscale.service"];
      wants = ["network-pre.target" "tailscale.service"];
      wantedBy = ["multi-user.target"];
      onFailure = ["notify-discord@%n.service"];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = let
        upCommand = "${pkgs.tailscale}/bin/tailscale up";
        args =
          [
            "-login-server ${loginServer}"
            "--authkey ${preAuthKey}"
            "--accept-dns=false"
            ''--hostname ${builtins.replaceStrings [".fap.no"] [""] config.networking.fqdn}''
            "--reset"
          ]
          ++ lib.optional exitNode ''--advertise-exit-node ''
          ++ lib.optional ((builtins.length advertiseRoutes) > 0) ''--advertise-routes=${builtins.concatStringsSep "," advertiseRoutes}'';
      in ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${upCommand} ${builtins.concatStringsSep " " args}
      '';
    };
  };
in {
  inherit tailscale;
}
