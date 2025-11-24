{
  pkgs,
  lib,
  config,
  ...
}: let
  location = lib.elemAt (lib.splitString "." config.networking.domain) 0;
  serviceName = "svc:minio-${location}";
  consoleAddress = "127.0.0.1:49005";
in {
  age.secrets.minio-oracldn = {
    file = ../secrets/minio-oracldn.age;
  };

  services.minio = {
    enable = true;
    inherit consoleAddress;
    rootCredentialsFile = config.age.secrets.minio-oracldn.path;
  };

  services.tailscale.services.${serviceName} = {
    endpoints = {
      "tcp:80" = "http://${consoleAddress}";
      "tcp:443" = "http://${consoleAddress}";
    };
  };
}
