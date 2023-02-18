{ config
, lib
, pkgs
, ...
}:
let
  dataDir = "/var/lib/immich";
  uploadDir = "${dataDir}/upload";
  dbuser = "immich";
  dbname = "immich";
  dbPasswordFile = config.age.secrets.immich-db-password.path;
  ociBackend = config.virtualisation.oci-containers.backend;
  containersHost = "localhost";
  domain = "photos.kradalby.no";

  pgSuperUser = config.services.postgresql.superUser;

  immichBase = {
    environment = {
      NODE_ENV = "production";
      DB_HOSTNAME = containersHost;
      DB_PORT = toString config.services.postgresql.port;
      DB_USERNAME = dbuser;
      DB_DATABASE_NAME = dbname;
      REDIS_HOSTNAME = containersHost;
      REDIS_PORT = toString config.services.redis.servers.immich.port;
    };
    # only secrets need to be included, e.g. DB_PASSWORD, JWT_SECRET, MAPBOX_KEY
    environmentFiles = [ config.age.secrets.immich-env.path ];
    extraOptions = [
      "--network=host"
      "--add-host=immich-server:127.0.0.1"
      "--add-host=immich-microservices:127.0.0.1"
      "--add-host=immich-machine-learning:127.0.0.1"
      "--add-host=immich-web:127.0.0.1"
    ];
  };
in
{
  age.secrets.immich-env.file = ../../secrets/immich-env.age;
  age.secrets.immich-db-password.file = ../../secrets/immich-db-password.age;

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = [ dbname ];
    ensureUsers = [
      {
        name = dbuser;
        ensurePermissions."DATABASE ${dbname}" = "ALL PRIVILEGES";
      }
    ];
  };

  services.redis.servers.immich = {
    enable = true;
    port = 31640;
  };

  systemd.services.immich-init = {
    enable = true;
    description = "Set up paths & database access";
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
    before = [
      "${ociBackend}-immich-server.service"
      "${ociBackend}-immich-microservices.service"
      "${ociBackend}-immich-machine-learning.service"
      "${ociBackend}-immich-web.service"
      "${ociBackend}-immich-proxy.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      LoadCredential = [ "db_password:${dbPasswordFile}" ];
    };
    script = ''
      mkdir -p ${dataDir} ${uploadDir}
      echo "Set immich postgres user password"
      db_password="$(<"$CREDENTIALS_DIRECTORY/db_password")"
      ${pkgs.sudo}/bin/sudo -u ${pgSuperUser} ${pkgs.postgresql}/bin/psql postgres \
        -c "alter user ${dbuser} with password '$db_password'"
    '';
  };

  virtualisation.oci-containers.containers = {
    immich-server =
      immichBase
      // {
        image = "altran1502/immich-server:release";
        ports = [ "3001:3001" ];
        entrypoint = "/bin/sh";
        cmd = [ "./start-server.sh" ];
        volumes = [ "${uploadDir}:/usr/src/app/upload" ];
      };

    immich-microservices =
      immichBase
      // {
        image = "altran1502/immich-server:release";
        entrypoint = "/bin/sh";
        cmd = [ "./start-microservices.sh" ];
        volumes = [ "${uploadDir}:/usr/src/app/upload" ];
      };

    # TODO not working atm
    /*
      immich-machine-learning = immichBase // {
      image = "bertmelis1/immich-machine-learning-noavx:release"; # no AVX support
      # image = "altran1502/immich-machine-learning:release";
      entrypoint = "/bin/sh";
      cmd = [ "./entrypoint.sh" ];
      volumes = [ "${uploadDir}:/usr/src/app/upload" ];
      };
    */

    immich-web =
      immichBase
      // {
        image = "altran1502/immich-web:release";
        ports = [ "3000:3000" ];
        entrypoint = "/bin/sh";
        cmd = [ "./entrypoint.sh" ];
      };
  };

  systemd.services = {
    "${ociBackend}-immich-server" = {
      requires = [ "postgresql.service" "redis-immich.service" ];
      after = [ "postgresql.service" "redis-immich.service" ];
    };

    "${ociBackend}-immich-microservices" = {
      requires = [ "postgresql.service" "redis-immich.service" ];
      after = [ "postgresql.service" "redis-immich.service" ];
    };

    "${ociBackend}-immich-machine-learning" = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
    };
  };

  services.nginx.virtualHosts.${domain} = {
    enableACME = true;
    forceSSL = true;
    locations."/api" = {
      proxyPass = "http://localhost:3001";
      extraConfig = ''
        rewrite /api/(.*) /$1 break;
        client_max_body_size 50000M;
      '';
    };
    locations."/" = {
      proxyPass = "http://localhost:3000";
      extraConfig = ''
        client_max_body_size 50000M;
      '';
    };
  };
}
