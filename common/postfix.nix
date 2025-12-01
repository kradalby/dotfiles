{
  pkgs,
  lib,
  config,
  ...
}: {
  services.postfix = {
    enable = true;
    hostname = "${config.networking.hostName}.${config.networking.domain}";
    enableHeaderChecks = false;
    setSendmail = true;
    enableSubmission = false;
    settings.main.relayhost = ["smtp.fap.no:25"];
  };
}
