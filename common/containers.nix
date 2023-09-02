{pkgs, ...}: {
  virtualisation.oci-containers.backend = "docker";
  virtualisation.docker.package = pkgs.unstable.docker_24;
}
