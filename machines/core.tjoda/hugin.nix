# hugin serves the Munin-generated gallery off the 850 EVO. It is a tsnet app
# (kraweb), so it joins the tailnet as its own node `hugin` and exposes
# /metrics there — no VIP, same shape as hvor/krapage on core.oracldn.
{ config, ... }:
let
  # Munin writes the gallery hugin serves, so Munin's targetFolder and hugin's
  # contentDir have to name the same directory. Derived from one value here
  # because nothing at runtime enforces the agreement: when they disagree the
  # site still builds and every image 404s.
  contentDir = "/pictures/hugin";
  picturesDir = dirOf contentDir; # /pictures — both disks are mounted under it
  sourceFolder = "album"; # /pictures/album, the raw export; never served
in
{
  age.secrets.hugin-tskey = {
    file = ../../secrets/hugin-tskey.age;
    owner = config.services.hugin.user;
  };

  age.secrets.hugin-env = {
    file = ../../secrets/hugin-env.age;
    owner = config.services.hugin.user;
  };

  services.hugin = {
    enable = true;
    inherit contentDir;
    tailscaleKeyPath = config.age.secrets.hugin-tskey.path;
    # HUGIN_TOKEN_MAPBOX, exposed to the frontend via /tokens.
    environmentFile = config.age.secrets.hugin-env.path;
  };

  # Munin is installed by hand at ~/bin/munin and run manually. Not because it
  # resists packaging — it is a static musl binary that needs no Swift here —
  # but because the only build it publishes today is a CI artifact: auth-gated,
  # ephemeral URL, and deleted after 7 days, so fetchurl cannot pin it. A v*
  # tag makes static-release.yml publish munin-linux-{amd64,arm64} and
  # SHA256SUMS as release assets, and then this becomes an ordinary derivation.
  # sourceFolder/targetFolder are relative to the working directory, hence the
  # cd:
  #   cd /pictures && munin --config /etc/munin/munin.json --json
  # --json writes JSON and no images, which is what a URL-format change needs;
  # without it Munin may re-encode every scaled image. It rewrites all of the
  # JSON, not just index.json — the per-photo sidecars carry URLs too.
  environment.etc."munin/munin.json".text = builtins.toJSON {
    inherit sourceFolder;
    targetFolder = baseNameOf contentDir;
    diff = true;
    jpegCompression = 1;
    concurrency = 3;
    logLevel = "debug";
    peopleFiles = [ "${picturesDir}/${sourceFolder}/people.json" ];
    people = [ ];
  };
}
