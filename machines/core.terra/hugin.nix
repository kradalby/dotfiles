{
  pkgs,
  config,
  ...
}: {
  age.secrets.hugin-tskey = {
    file = ../../secrets/hugin-tskey.age;
    owner = "storage";
  };

  services.hugin = {
    enable = true;
    tailscaleKeyPath = config.age.secrets.hugin-tskey.path;

    verbose = true;

    # package = pkgs.hugin;

    user = "storage";
    group = "storage";

    album = "/fast/hugin/album";
  };
}
