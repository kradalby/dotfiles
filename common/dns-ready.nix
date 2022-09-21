{
  pkgs,
  lib,
  config,
  ...
}: {
  systemd.services.dns-ready = {
    unitConfig = {
      description = "Wait for DNS to be ready";
    };

    after = ["nss-lookup.target" "network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
    };

    script = ''
      ${pkgs.bash}/bin/bash -c 'until ${pkgs.host}/bin/host vg.no; do sleep 1; done'
    '';
  };
}
