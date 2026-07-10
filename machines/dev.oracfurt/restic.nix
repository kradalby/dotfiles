{...}: let
  paths = [
    "/etc/nixos"
    # tsidp runs with DynamicUser; /var/lib/tsidp is a symlink whose target
    # is the real state — backing up the symlink stored ~20 bytes.
    "/var/lib/private/tsidp"
    "/var/lib/cook-server"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-dev-oracfurt-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta =
      mkJob "jotta"
      // {
        targetHost = "531e044d80bba9c63ec9d1ff2dd12c96";
        # Jotta egress is paid/slow: verify metadata only, monthly. The REST
        # repos get the read-data checks.
        check = {
          args = [];
          interval = "monthly";
        };
      };
  };
}
