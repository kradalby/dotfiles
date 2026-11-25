{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.setec-secrets;
  dir = "/var/lib/setec-secrets";
  secret = import ../pkgs/scripts/secret.nix { inherit pkgs; };
in
{
  options.services.setec-secrets = lib.mkOption {
    default = { };
    description = ''
      Secrets fetched from setec to files under ${dir}. Access is the host's
      tailnet identity, so the host's tag needs a grant for each secret.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            secret = lib.mkOption {
              type = lib.types.str;
              description = "setec secret name.";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
            };
            restartUnits = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Units to restart when the value changes.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "${dir}/${name}";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg != { }) {
    systemd.services.setec-secrets = {
      description = "Fetch setec secrets to disk";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      path = [
        secret
        pkgs.diffutils
      ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "setec-secrets";
        StateDirectoryMode = "0755";
      };
      # Never fails: a setec outage must not break a boot or a deploy. The
      # last good copy stays in place and the stale timestamp alerts instead.
      script = ''
        ok=1
        fetch() {
          name=$1 secret=$2 owner=$3 mode=$4
          shift 4
          tmp=$(mktemp "${dir}/.$name.XXXXXX")
          if secret "$secret" >"$tmp" && [ -s "$tmp" ]; then
            # `secret` strips the trailing newline; OpenSSH keys need it.
            echo >>"$tmp"
            chown "$owner" "$tmp"
            chmod "$mode" "$tmp"
            changed=1
            cmp -s "$tmp" "${dir}/$name" && changed=0
            mv "$tmp" "${dir}/$name"
            [ "$changed" = 0 ] || [ $# -eq 0 ] || systemctl try-restart "$@"
          else
            rm -f "$tmp"
            ok=0
            echo "$secret: fetch failed, keeping last copy" >&2
          fi
        }
        ${lib.concatStrings (
          lib.mapAttrsToList (name: s: ''
            fetch ${
              lib.escapeShellArgs (
                [
                  name
                  s.secret
                  s.owner
                  s.mode
                ]
                ++ s.restartUnits
              )
            }
          '') cfg
        )}
        prom=/var/lib/prometheus-node-exporter-textfile/setec-secrets.prom
        if [ "$ok" = 1 ] || [ ! -e "$prom" ]; then
          ts=0
          if [ "$ok" = 1 ]; then ts=$(date +%s); fi
          tmp=$(mktemp "$(dirname "$prom")/.setec-secrets.XXXXXX")
          printf 'setec_secrets_last_success_timestamp_seconds %s\n' "$ts" >"$tmp"
          chmod 0644 "$tmp"
          mv "$tmp" "$prom"
        fi
      '';
    };

    # setec has no push; its own Go client polls hourly too. The extra boot
    # triggers cover a tailnet that comes up late on first boot.
    systemd.timers.setec-secrets = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = [
          "1min"
          "5min"
          "15min"
        ];
        OnUnitActiveSec = "1h";
      };
    };
  };
}
