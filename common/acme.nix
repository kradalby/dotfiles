{ config, lib, pkgs, ... }:
{

  sops.secrets.cloudflare_token = { };

  security.acme = {
    acceptTerms = true;

    defaults = {
      email = "kristoffer@dalby.cc";
      dnsProvider = "cloudflare";
      credentialsFile = "${config.sops.secrets.cloudflare_token.path}";
      group = "nginx";
    };
  };
}
