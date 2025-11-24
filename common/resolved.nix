{
  lib,
  config,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;

  nextdnsServers = [
    "45.90.28.0#842cee.dns.nextdns.io"
    "45.90.30.0#842cee.dns.nextdns.io"
    "2a07:a8c0::#842cee.dns.nextdns.io"
    "2a07:a8c1::#842cee.dns.nextdns.io"
  ];

  cloudflareFallback = [
    "1.1.1.1#one.one.one.one"
    "1.0.0.1#one.one.one.one"
    "2606:4700:4700::1111#one.one.one.one"
    "2606:4700:4700::1001#one.one.one.one"
  ];

in
lib.mkIf isLinux {
  networking.resolvconf.enable = lib.mkForce false;
  networking.nameservers = lib.mkDefault nextdnsServers;

  services.resolved = {
    enable = true;
    dnssec = "true";
    dnsovertls = "true";
    domains = ["~."];
    fallbackDns = cloudflareFallback;
  };
}
