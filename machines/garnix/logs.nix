{ config, ... }:
{
  # CI build logs as plain text on its own tsnet node, so agents skip the JWT
  # dance. No app-level auth: the tag:garnixlogs grant is the trust boundary,
  # for reading logs and for re-running CI alike.
  services.garnixlogs = {
    enable = true;
    # Loopback, not the public vhost. Port read off the server config so they
    # cannot drift.
    garnixURL = "http://127.0.0.1:${toString config.services.garnixServer.port}";
    environmentFile = config.age.secrets.garnixlogs.path;
    # GitHub takes a check-suite rerequest only from the App, so retries sign
    # as garnix's own App; the key never leaves this host.
    githubAppIdFile = config.age.secrets.garnix-github-app-id.path;
    githubAppKeyFile = config.age.secrets.garnix-github-app-pk.path;
  };
}
