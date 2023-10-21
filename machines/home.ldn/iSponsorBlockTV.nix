{
  config,
  pkgs,
  lib,
  ...
}: let
  # domain = "pdf.fap.no";
  # port = 63456;
  # nginx = import ../../common/funcs/nginx.nix {inherit config lib;};
  #
  # vhost = nginx.internalVhost {
  #   inherit domain;
  #   proxyPass = "http://127.0.0.1:${toString port}";
  # };
in
  # lib.mkMerge [
  {
    # users.users.stirling = {
    #   home = "/var/lib/stirling";
    #   createHome = true;
    #   group = "stirling";
    #   isSystemUser = true;
    #   isNormalUser = false;
    #   description = "Stirling PDF";
    # };
    #
    # users.groups.stirling = {};

    virtualisation.oci-containers.containers.isponsorblocktv = {
      image = "ghcr.io/dmunozv04/isponsorblocktv:latest";
      # user = config.users.users.stirling.uid;
      autoStart = true;
      # ports = [
      #   "${toString port}:8080/tcp"
      # ];
      environment = {};
      volumes = [
        "/var/lib/isponsorblocktv:/app/data"
      ];
    };
  }
#   vhost
# ]
