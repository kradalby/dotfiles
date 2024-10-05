{...}:
# Config:
#  docker run --rm -v '/var/lib/isponsorblocktv:/app/data' -it ghcr.io/dmunozv04/isponsorblocktv:latest --setup-cli
{
  virtualisation.oci-containers.containers.isponsorblocktv = {
    image = (import ../../metadata/versions.nix).isponsor;
    autoStart = true;
    environment = {};
    volumes = [
      "/var/lib/isponsorblocktv:/app/data"
    ];
  };
}
