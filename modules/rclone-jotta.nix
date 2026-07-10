# Declarative Jottacloud rclone remote.
#
# Jottacloud auth is OAuth, not a static key: a single-use *personal login token*
# (generated at https://www.jottacloud.com/web/secure) is exchanged once for an
# access+refresh token that rclone stores and thereafter keeps refreshing in a
# writable config. Jottacloud rotates the refresh token on every refresh, so that
# config MUST be persistent and writable and MUST NOT be copied between machines
# (both invalidate the "token family"). Hence: put the login token in a per-host
# .age file, and let a boot-time oneshot mint the config from it — but only when
# we're actually logged out, so a live rotated token is never clobbered.
#
# BRING UP ONE HOST AT A TIME. The personal login token is short-lived (minutes)
# and the account holds a single active one — generating a new token invalidates
# the previous, and a stashed token expires long before any later use. So the
# .age secret is a just-in-time credential, not an armed recovery secret. Per
# host: generate a fresh token, `EDITOR='cp tok' ragenix -e` it into that host's
# secret, deploy that host immediately (bootstrap mints while the token is live),
# then move to the next host. Same drill to recover a logged-out host.
# Verified end-to-end: mint -> `rclone lsd Jotta:` -> restic reads the repo.
{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.rclone-jotta;
  bootstrap = pkgs.writeShellScript "rclone-jotta-bootstrap" ''
    set -eu
    conf=${escapeShellArg cfg.configFile}
    rclone=${pkgs.rclone}/bin/rclone

    # Are we already logged in? A real API call proves the token is alive. Retry
    # a few times: if we ARE logged in, a still-settling network (or a token
    # mid-rotation) must not read as "logged out" and trigger a needless
    # re-login that clobbers the live token family.
    for _ in 1 2 3 4 5; do
      if "$rclone" --config "$conf" lsd Jotta: >/dev/null 2>&1; then
        echo "Jotta logged in; skipping bootstrap"
        exit 0
      fi
      sleep 5
    done

    # Genuinely logged out (fresh host, or a dead/revoked token needing a new
    # login token). Mint in place, then verify. A spent/expired token makes
    # `config create` write a tokenless [Jotta] that would corrupt the config
    # and make every later run re-mint and fail — so on any failure delete the
    # partial remote, leaving the rest of the config untouched. (This also
    # self-heals a host already corrupted by the old behaviour.)
    echo "Jotta not logged in; minting from login token"
    mkdir -p "$(dirname "$conf")"
    if "$rclone" --config "$conf" config create Jotta jottacloud \
         config_type=standard \
         config_login_token="$(cat "$CREDENTIALS_DIRECTORY/login-token")" \
       && "$rclone" --config "$conf" lsd Jotta: >/dev/null 2>&1; then
      echo "Jotta minted and verified"
    else
      "$rclone" --config "$conf" config delete Jotta 2>/dev/null || true
      echo "mint failed (spent/expired login token?); removed partial Jotta" >&2
      exit 1
    fi
  '';
in {
  options.services.rclone-jotta = {
    enable = mkEnableOption "declarative Jottacloud rclone remote";

    secret = mkOption {
      type = types.str;
      description = ''
        Name of the age secret (in secrets/) holding a Jottacloud personal login
        token. Per-host, and just-in-time: the token is short-lived and the
        account has a single active one, so re-encrypt a fresh token and deploy
        this host immediately (do it one host at a time). On logout, same drill —
        fresh token in this file, then deploy/restart rclone-jotta-bootstrap.
      '';
    };

    configFile = mkOption {
      type = types.str;
      default = "/root/.config/rclone/rclone.conf";
      description = ''
        Writable path rclone mints the remote into and keeps refreshing. Default
        is rclone's default location so restic (rclone:Jotta:...) and manual
        `rclone` CLI both use it without extra flags.
      '';
    };

    owner = mkOption {
      type = types.str;
      default = "root";
      description = "User that owns the login-token secret and runs the bootstrap.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.${cfg.secret} = {
      file = ../secrets + "/${cfg.secret}.age";
      owner = cfg.owner;
    };

    systemd.services.rclone-jotta-bootstrap = {
      description = "Mint Jottacloud rclone remote from login token (once)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.owner;
        LoadCredential = "login-token:${config.age.secrets.${cfg.secret}.path}";
        ExecStart = bootstrap;
      };
    };
  };
}
