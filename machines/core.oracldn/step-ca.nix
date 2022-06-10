{ pkgs, config, lib, ... }:
let
  cfg = config.services.step-ca;

  domain = "ca.kradalby.no";
in
{
  options.services.step-ca.configFilePath = lib.mkOption {
    type = lib.types.path;
  };


  config = {
    age.secrets.step-ca-password.file = ../../secrets/step-ca-password.age;
    age.secrets.step-ca-config.file = ../../secrets/step-ca-config.age;

    environment.systemPackages = with pkgs; [ step-cli step-ca ];

    services.step-ca = {
      enable = true;
      package = pkgs.step-ca;

      address = "0.0.0.0";
      port = 38443;

      intermediatePasswordFile = config.age.secrets.step-ca-password.path;
      configFilePath = config.age.secrets.step-ca-config.path;

      settings = { };
    };

    systemd.services."step-ca" = {
      serviceConfig = {
        restartTriggers = [ ../../secrets/step-ca-config.age ../../secrets/step-ca-password.age ];
        LoadCredential = lib.mkForce [
          "intermediate_password:${cfg.intermediatePasswordFile}"
          "config:${cfg.configFilePath}"
        ];

        ExecStart = lib.mkForce [
          "" # override upstream
          "${cfg.package}/bin/step-ca \${CREDENTIALS_DIRECTORY}/config --password-file \${CREDENTIALS_DIRECTORY}/intermediate_password"
        ];
      };
    };
  };

}
