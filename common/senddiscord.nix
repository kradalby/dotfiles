{ config, lib, pkgs, ... }:
let
  discordScript = builtins.fetchGit {
    url = "https://github.com/ChaoticWeg/discord.sh.git";
    ref = "master";
    rev = "6d50287671e57f8d6c4e85a37ce23d83bfc3db14";
  };
in
{
  sops.secrets.discord-systemd-webhook = { };

  systemd.services."notify-discord@" = {
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ systemd system-sendmail ];
    scriptArgs = "%I";
    script = ''
      export PATH=$PATH:${pkgs.jq}/bin:${pkgs.curl}/bin
      UNIT=$(systemd-escape $1)
      BODY=$(systemctl status --no-pager $UNIT || true)
      HOSTNAME=$(${pkgs.hostname}/bin/hostname -f)
      WEBHOOK_URL="$(cat '${config.sops.secrets.discord-systemd-webhook.path}')"

      ${pkgs.bash}/bin/bash ${discordScript}/discord.sh \
              --webhook-url="$WEBHOOK_URL" \
              --username="nixy" \
              --title="$HOSTNAME: unit $UNIT failed" \
              --field="Hostname;$HOSTNAME" \
              --field="Unit;$UNIT"
    '';
  };
}
