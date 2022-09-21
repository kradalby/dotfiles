{config, ...}: {
  # sops.secrets.cloudflare_ddns_token = {
  #   mode = "0400";
  #   owner = config.users.users.cfdyndns.name;
  #   group = config.users.users.cfdyndns.group;
  # };

  # services.cfdyndns = {
  #   enable = true;
  #   email = "kradalby@kradalby.no";
  #   apikeyFile = config.sops.secrets.cloudflare_token.path;
  #
  #   records = [
  #     config.networking.domain
  #   ];
  # };

  age.secrets.cloudflare-ddns-token = {
    mode = "0400";
    file = ../secrets/cloudflare-token.age;
  };

  services.ddclient = {
    enable = true;
    domains = [config.networking.domain];
    zone = "fap.no";
    ipv6 = true;
    server = "www.cloudflare.com";
    username = "kradalby@kradalby.no";
    passwordFile = config.age.secrets.cloudflare-ddns-token.path;
    protocol = "cloudflare";
  };

  systemd.services.ddclient.onFailure = ["notify-discord@%n.service"];
}
