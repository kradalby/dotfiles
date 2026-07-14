{
  config,
  lib,
  ...
}:
{
  # Lightest reliable MTA for the fleet: a send-only spool that forwards ALL
  # local mail (root, users, cron, systemd OnFailure) to the personal inbox via
  # gigabuilder's relay. No listener, no full postfix — just a queue + sendmail
  # shim. gigabuilder itself runs the real postfix relay and force-disables this.
  services.nullmailer = {
    enable = true;
    config = {
      # Canonical identity for this host; senders leave as <user>@<host>.fap.no.
      me = "${config.networking.hostName}.${config.networking.domain}";
      defaultdomain = "fap.no";
      # Everything addressed to a local user (root@me, <user>@me, bare "root")
      # is remapped here — all root/user mail lands in the personal inbox.
      adminaddr = "kristoffer@dalby.cc";
      # The one hop out: gigabuilder, reached as smtp.fap.no over the tailnet,
      # which relays on to spamvask. No auth (relay-by-IP at gigabuilder).
      remotes = "smtp.fap.no smtp --port=25";
    };
  };
}
