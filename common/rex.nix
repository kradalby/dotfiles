{
  inputs,
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
      ${lib.optionalString cfg.loginServer.tailscaleServe.enable ''
        tailscale serve status --json \
          | jq -e --arg port "${toString cfg.loginServer.tailscaleServe.httpsPort}" \
              --arg backend "unix:${cfg.loginServer.tailscaleServe.socketPath}" \
              '.TCP[$port].HTTPS and any(.Web | to_entries[]; (.key | endswith(":" + $port)) and .value.Handlers["/"].Proxy == $backend)' >/dev/null
      ''}
    '';
  };
in
{
  imports = [ inputs.rex.nixosModules.default ];

  config = lib.mkMerge [
    { services.rex.loginServer.enable = lib.mkDefault true; }
    (lib.mkIf cfg.loginServer.enable {
      services.rex.loginServer = {
        accounts.kradalby.principals = [ "tailscale:kradalby@kradalby.no" ];
        tailscaleServe.enable = lib.mkDefault true;
      };

      # The Rex module calls getExe on this package expecting the CLI, as in nixpkgs,
      # but Tailscale's flake sets mainProgram to tailscaled. Merged rather than
      # overrideAttrs, which changes the store path and so restarts tailscaled.
      services.tailscale.package = pkgs.tailscale // {
        meta = pkgs.tailscale.meta // {
          mainProgram = "tailscale";
        };
      };

      # The module's Requires= stops Rex on every tailscaled restart, and if
      # tailscaled then fails to start, Rex's start fails with it and nothing ever
      # retries, so Rex stays down after tailscaled recovers. Serve's mapping
      # persists in tailscaled's state, so neither needs restarting with it.
      systemd.services.rex-login-server = {
        requires = lib.mkForce [ ];
        wants = [ "tailscaled.service" ];
      };
      systemd.services.rex-tailscale-serve = lib.mkIf cfg.loginServer.tailscaleServe.enable {
        requires = lib.mkForce [ "rex-login-server.service" ];
        wants = [ "tailscaled.service" ];
        # Both read-modify-write tailscaled's serve config, so a tailscaled restart
        # could otherwise lose whichever write lands first.
        after = [ "tailscaled-serve-config.service" ];
      };

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
    })
  ];
}
