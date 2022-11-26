{
  pkgs,
  lib,
  config,
  ...
}: {
  services.postfix = lib.mkForce {
    enable = true;
    enableHeaderChecks = false;
    hostname = "${config.networking.hostName}.${config.networking.domain}";
    setSendmail = true;
    enableSubmission = false;
    relayHost = "spamvask.terrahost.no";
    networks = [
      "10.0.0.0/8"
      "100.64.0.0/10"
    ];
  };
}
