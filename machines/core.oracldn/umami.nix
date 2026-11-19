{
  pkgs,
  config,
  ...
}:
let
  domain = "umami.kradalby.no";
  port = 63458;
in
{
  users.users.umami = {
    home = "/var/lib/umami";
    createHome = true;
    group = "umami";
    isSystemUser = true;
    isNormalUser = false;
    description = "umami analytics";
  };

  users.groups.umami = { };

  age.secrets.umami-env.file = ../../secrets/umami-env.age;

  virtualisation.oci-containers.containers.umami = {
    image = (import ../../metadata/versions.nix).umami;
    user = config.users.users.umami.uid;
    # workdir = "/home/podmanager";
    autoStart = true;
    # Bind loopback only: reached via the nginx vhost on localhost. A bare
    # <port>:3000 binds 0.0.0.0 and docker's DNAT rule bypasses the host
    # firewall, exposing it on this public Oracle VM's WAN leg.
    ports = [
      "127.0.0.1:${toString port}:3000/tcp"
    ];
    environment = {
      DATABASE_URL = "postgresql://umami@172.17.0.1/umami";
      DISABLE_TELEMETRY = "1";
      DISABLE_UPDATES = "1";
    };
    # APP_SECRET: umami >= 3.5 refuses to start on the default placeholder.
    environmentFiles = [ config.age.secrets.umami-env.path ];
    volumes = [ ];
  };

  services.vhost."${domain}" = {
    proxyPass = "http://localhost:${toString port}";
    allowCors = false;
  };
}
