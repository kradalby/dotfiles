{
  pkgs,
  config,
  ...
}: {
  # disabledModules = ["services/continuous-integration/github-runners.nix"];
  #
  # imports = [
  #   "${flakes.nixpkgs-unstable}/nixos/modules/services/continuous-integration/github-runners.nix"
  # ];

  age.secrets.github-headscale-token = {
    file = ../../secrets/github-headscale-token.age;
  };

  virtualisation.docker.enable = true;

  users.users.github-runner = {
    isSystemUser = true;
    group = "docker";
  };

  # The GitHub Actions self-hosted runner service.
  services.github-runners.headscale = {
    enable = true;
    package = pkgs.github-runner;
    url = "https://github.com/juanfont/headscale";
    replace = true;
    extraLabels = ["nixos" "docker"];
    user = "github-runner";

    # Justifications for the packages:
    extraPackages = with pkgs; [
      docker
      nix
      nodejs
      gawk
      git
    ];

    # Customize this to include your GitHub username so we can track
    # who is running which node.
    name = "kradalby-${config.networking.hostName}";

    # Replace this with the path to the GitHub Actions runner token on
    # your disk.
    tokenFile = config.age.secrets.github-headscale-token.path;
  };
}
