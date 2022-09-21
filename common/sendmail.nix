{
  config,
  lib,
  pkgs,
  ...
}: {
  # TODO:
  services.ssmtp = {
    enable = true;
    root = "kradalby@kradalby.no";
    # TODO: Does this need to be overriden?
    domain = "";
    hostName = "smtp.fap.no:25";
    useTLS = false;

    settings = {
      Debug = true;
    };
  };

  systemd.services."notify-email@" = {
    serviceConfig.Type = "oneshot";
    path = with pkgs; [systemd system-sendmail];
    scriptArgs = "%I";
    script = ''
      UNIT=$(systemd-escape $1)
      TO="kradalby@kradalby.no"
      FROM="root@home.ldn.fap.no"
      SUBJECT="$UNIT Failed"
      HEADERS="To:$TO\nFrom:$FROM\nSubject: $SUBJECT\n"
      BODY=$(systemctl status --no-pager $UNIT || true)
      echo -e "$HEADERS\n$BODY" | sendmail -t
    '';
  };
}
