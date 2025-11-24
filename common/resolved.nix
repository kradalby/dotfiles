{
  lib,
  config,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;

  cloudflareServers = [
    "1.1.1.1#one.one.one.one"
    "1.0.0.1#one.one.one.one"
    "2606:4700:4700::1111#one.one.one.one"
    "2606:4700:4700::1001#one.one.one.one"
  ];

in
lib.mkIf isLinux {
  networking.resolvconf.enable = lib.mkForce false;
  networking.nameservers = lib.mkDefault cloudflareServers;

  services.resolved = {
    enable = true;
    dnssec = "true";
    dnsovertls = "true";
    domains = ["~."];
    fallbackDns = cloudflareServers;
  };
}
