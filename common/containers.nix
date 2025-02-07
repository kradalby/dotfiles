{pkgs, ...}: {
  virtualisation.oci-containers.backend = "docker";
  virtualisation.docker = {
    package = pkgs.docker;
    enable = true;
    autoPrune = {
      enable = true;
      flags = ["--all"];
    };
  };
}
