{
  config,
  lib,
  pkgs,
  ...
}:
{
  age.secrets.cloudflare-token.file = ../secrets/cloudflare-token.age;

  security.acme = {
    acceptTerms = true;

    defaults = {
      email = "kristoffer@dalby.cc";
      dnsProvider = "cloudflare";
      environmentFile = "${config.age.secrets.cloudflare-token.path}";
      group = "nginx";
    };
  };
}
