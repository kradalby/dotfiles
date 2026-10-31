{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rex;
  # shortcut: checks the Serve mapping, not its data path. A probe from this host
  # would likely skip Serve, and an off-host one needs its own ACL grant. Upgrade
  # if the mapping is ever up while clients fail.
  probe = pkgs.writeShellApplication {
    name = "rex-login-server-probe";
    runtimeInputs = [
      config.services.tailscale.package
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      # Any HTTP answer proves it is serving. Root has no account here, so it is
      # refused before an account server starts, which would log in every run.
      curl -sS -o /dev/null --max-time 10 --unix-socket /run/rex/login-server.sock http://localhost/
      tailscale serve status --json \
        | jq -e '.TCP["${toString cfg.loginServer.tailscaleServe.httpsPort}"]' >/dev/null
    '';
  };
in
{
  # The login server, not the shared server: sessions run as kradalby instead of
  # a `rex` system user. This node is tagged and so has no owner, which makes the
  # accounts file what names the allowed caller. Serve reuses the host's
  # tailscaled, so no extra node, auth key, or firewall rule.
  services.rex.loginServer = {
    enable = true;
    accounts.kradalby.principals = [ "tailscale:kradalby@kradalby.no" ];
    tailscaleServe.enable = true;
  };

  # The Rex module calls getExe on this package expecting the CLI, as in nixpkgs,
  # but Tailscale's flake sets mainProgram to tailscaled. Merged rather than
  # overrideAttrs, which changes the store path and so restarts tailscaled.
  services.tailscale.package = pkgs.tailscale // {
    meta = pkgs.tailscale.meta // {
      mainProgram = "tailscale";
    };
  };

  # Both read-modify-write tailscaled's serve config, so a tailscaled restart
  # could otherwise lose whichever write lands first.
  systemd.services.rex-tailscale-serve.after = [ "tailscaled-serve-config.service" ];

  systemd.services.rex-login-server-health = {
    description = "Probe the Rex login server for node_exporter";
    after = [
      "rex-login-server.service"
      "rex-tailscale-serve.service"
    ];
    path = [ pkgs.coreutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      success=0
      if ${lib.getExe probe}; then
        success=1
      fi
      dir=/var/lib/prometheus-node-exporter-textfile
      tmp=$(mktemp "$dir/.rex-login-server.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      printf 'rex_login_server_probe_success %s\nrex_login_server_probe_timestamp_seconds %s\n' \
        "$success" "$(date +%s)" >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" "$dir/rex-login-server.prom"
    '';
  };
  systemd.timers.rex-login-server-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };
}
