{ config, ... }:
{
  # garnixlogs serves this VM's CI build logs as plain text on its own tsnet
  # node, so an agent reads CI output with one unauthenticated curl:
  #
  #   curl http://garnixlogs/<repo>
  #   curl http://garnixlogs/$(git rev-parse HEAD)
  #   curl "http://garnixlogs/<build-id>?follow"
  #
  # It exists because garnix's auth is a two-step nobody gets right: the access
  # token is the password half of Basic auth against /api/auth/jwt, and only the
  # JWT that mints works as a Bearer token. Sent directly as a Bearer token the
  # access token reads as anonymous — public repos answer, private ones return
  # "not found", and the caller concludes the commit is missing.
  #
  # There is no app-level auth here, so the tag:garnixlogs grant in
  # ~/git/infrastructure is the entire trust boundary, and it exposes private
  # repositories' build output. garnix redacts nothing from build logs.
  services.garnixlogs = {
    enable = true;
    # Straight to the backend on loopback: the public vhost would leave the host
    # and come back through the same nginx. Read the port off the server config
    # so the two cannot drift.
    garnixURL = "http://127.0.0.1:${toString config.services.garnixServer.port}";
    environmentFile = config.age.secrets.garnixlogs.path;
  };
}
