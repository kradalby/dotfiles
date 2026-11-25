{
  config,
  pkgs,
  lib,
  ...
}:
let
  codex = lib.getExe pkgs.master.codex;
  home = config.users.users.kradalby.home;
  socket = "${home}/.codex/app-server-control/app-server-control.sock";
  probe = pkgs.writeShellApplication {
    name = "codex-remote-control-probe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.websocat
    ];
    text = ''
      # The protocol probe checks the upstream connection, not just a live PID.
      socket="''${1:-${socket}}"
      coproc CODEX_PROBE { timeout 15s websocat --text --exit-on-eof --ws-c-uri ws://localhost/ - "ws-c:unix-connect:$socket"; }
      probe_pid=$CODEX_PROBE_PID
      original_reader=''${CODEX_PROBE[0]}
      original_writer=''${CODEX_PROBE[1]}
      exec {reader}<&"$original_reader" {writer}>&"$original_writer"
      exec {original_reader}<&- {original_writer}>&-
      trap 'exec {writer}>&-; exec {reader}<&-; wait "$probe_pid" || true' EXIT

      printf '%s\n' '{"id":0,"method":"initialize","params":{"clientInfo":{"name":"codex-health","version":"1"},"capabilities":{"experimentalApi":true}}}' >&"$writer"
      initialized=0
      while IFS= read -r -t 15 response <&"$reader"; do
        if jq -e '.id == 0' <<<"$response" >/dev/null; then
          jq -e 'has("result")' <<<"$response" >/dev/null || exit 1
          initialized=1
          break
        fi
      done
      [[ "$initialized" == 1 ]] || exit 1
      printf '%s\n' '{"method":"initialized","params":{}}' \
        '{"id":1,"method":"remoteControl/status/read","params":{}}' >&"$writer"
      while IFS= read -r -t 15 response <&"$reader"; do
        if jq -e '.id == 1' <<<"$response" >/dev/null; then
          jq -e '.result.status == "connected"' <<<"$response" >/dev/null
          exit "$?"
        fi
      done
      exit 1
    '';
  };
in
{
  # Nix owns the process/package lifecycle. `remote-control start` instead
  # installs its own package, which the nixpkgs CLI layout cannot supply.
  # In 0.159.1, foreground `remote-control` uses a private temporary socket;
  # app-server's hidden --remote-control flag enables the standard socket that
  # `pair` and the terminal UI use. No TCP listener or firewall opening.
  systemd.services.codex-remote-control = {
    description = "Codex shared app server with remote control";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      HOME = home;
      CODEX_HOME = "${home}/.codex";
      SHELL = lib.getExe pkgs.fish;
      PATH = lib.mkForce "/run/wrappers/bin:/etc/profiles/per-user/kradalby/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
    };
    serviceConfig = {
      User = "kradalby";
      WorkingDirectory = home;
      ExecStart = "${codex} app-server --listen unix:// --remote-control";
      Restart = "always";
      RestartSec = 15;
      KillSignal = "SIGTERM";
      KillMode = "mixed";
      TimeoutStopSec = 60;
      OOMScoreAdjust = 100;
      UMask = "0077";
    };
  };

  # Credentials and state stay in the user's existing ~/.codex; the whole
  # homedir is already covered by restic.nix. Never seed auth.json from Nix.
  systemd.services.codex-remote-control-health = {
    description = "Probe Codex remote control for node_exporter";
    after = [ "codex-remote-control.service" ];
    path = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      success=0
      if runuser -u kradalby -- ${lib.getExe probe}; then
        success=1
      fi
      dir=/var/lib/prometheus-node-exporter-textfile
      tmp=$(mktemp "$dir/.codex-remote-control.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      printf 'codex_remote_control_probe_success %s\ncodex_remote_control_probe_timestamp_seconds %s\n' \
        "$success" "$(date +%s)" >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" "$dir/codex-remote-control.prom"
    '';
  };
  systemd.timers.codex-remote-control-health = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };
}
