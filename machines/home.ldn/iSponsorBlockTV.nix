{...}:
# Config:
#  docker run --rm -v '/var/lib/isponsorblocktv:/app/data' -it ghcr.io/dmunozv04/isponsorblocktv:latest --setup-cli
{
  virtualisation.oci-containers.containers.isponsorblocktv = {
    image = "ghcr.io/dmunozv04/isponsorblocktv:latest";
    # user = config.users.users.stirling.uid;
    autoStart = true;
    # ports = [
    #   "${toString port}:8080/tcp"
    # ];
    environment = {};
    volumes = [
      "/var/lib/isponsorblocktv:/app/data"
    ];
  };
}
