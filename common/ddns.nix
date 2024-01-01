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
    enable = false;
    verbose = false;
    domains = [config.networking.domain];
    zone = "fap.no";
    server = "www.cloudflare.com";
    username = "kradalby@kradalby.no";
    passwordFile = config.age.secrets.cloudflare-ddns-token.path;
    protocol = "cloudflare";
    use = "web, web=api.ipify.org";
  };
}
