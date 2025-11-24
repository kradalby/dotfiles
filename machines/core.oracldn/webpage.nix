{
  pkgs,
  config,
  ...
}: let
  domain = "kradalby.no";
in {
  age.secrets.krapage-env = {
    file = ../../secrets/krapage-env.age;
    owner = config.services.krapage.user;
  };

  users.users.krapage = {
    home = config.services.krapage.dataDir;
    createHome = true;
    inherit (config.services.krapage) group;
    isSystemUser = true;
    isNormalUser = false;
    description = "krapage";
  };

  users.groups.krapage = {};

  services.krapage = {
    enable = true;
    verbose = false;
    tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;
    environmentFile = config.age.secrets.krapage-env.path;
  };

  services.vhost."${domain}" = {
    proxyPass = "http://127.0.0.1:${toString config.services.krapage.localhostPort}";
  };
}
