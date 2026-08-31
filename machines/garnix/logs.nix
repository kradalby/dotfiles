{ config, ... }:
{
  # CI build logs as plain text on its own tsnet node, so agents skip the JWT
  # dance. No app-level auth: the tag:garnixlogs grant is the trust boundary.
  services.garnixlogs = {
    enable = true;
    # Loopback, not the public vhost. Port read off the server config so they
    # cannot drift.
    garnixURL = "http://127.0.0.1:${toString config.services.garnixServer.port}";
    environmentFile = config.age.secrets.garnixlogs.path;
  };
}
