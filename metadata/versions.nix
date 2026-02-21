{
  ## home
  # https://github.com/catthehacker/docker_images/pkgs/container/ubuntu
  act = rec {
    latest = "ghcr.io/catthehacker/ubuntu:act-latest";
    linux = latest;
    ubuntuLatest = latest;
    ubuntu2404 = "ghcr.io/catthehacker/ubuntu:act-24.04";
    ubuntu2204 = "ghcr.io/catthehacker/ubuntu:act-22.04";
    ubuntu2004 = "ghcr.io/catthehacker/ubuntu:act-20.04";
  };
  fishPlugins = {
    # https://github.com/lilyball/nix-env.fish
    nixEnv = "7b65bd228429e852c8fdfa07601159130a818cfa";
    # https://github.com/gazorby/fish-abbreviation-tips
    abbrTips = "8ed76a62bb044ba4ad8e3e6832640178880df485";
    # https://github.com/franciscolourenco/done
    done = "8061a345d8ed5843809df127489d7d17be03f97b";
  };

  ## home.ldn
  # https://github.com/dmunozv04/iSponsorBlockTV/pkgs/container/isponsorblocktv
  isponsor = "ghcr.io/dmunozv04/isponsorblocktv:v2.2.1";

  ## core.oracldn
  # https://github.com/umami-software/umami/pkgs/container/umami
  umami = "ghcr.io/umami-software/umami:postgresql-v2.13.2";
  # https://hub.docker.com/r/frooodle/s-pdf/tags
  stirling = "frooodle/s-pdf:0.29.0";
  # https://hub.docker.com/r/kradalby/glauth/tags
  glauth = "kradalby/glauth:v2.0.0-040322-arm64";
  # https://hub.docker.com/r/glauth/glauth/tags
  glauthUpstream = "glauth/glauth:v2.0.0";
  # https://hub.docker.com/r/kradalby/glauth-ui/tags
  glauthUi = "kradalby/glauth-ui:040322-2-arm64";

  ## dev.oracfurt
  # https://github.com/mealie-recipes/mealie/releases/tag/v2.6.0
  mealie = "ghcr.io/mealie-recipes/mealie:v2.6.0";

  ## pkgs
  pkgs = {
    overlays = {
      # https://github.com/rye/eb
      eb = "v0.5.0";
      # https://github.com/micropython/webrepl
      webreplCli = "1e09d9a1d90fe52aba11d1e659afbc95a50cf088";
      # https://github.com/cooklang/cookcli/releases
      cook = "0.22.0";
      # https://github.com/bradfitz/gitutil
      gitutil = "1625713288102f8642c0619f12fc83ad609bf71b";
      # https://github.com/JonaEnz/tailscale-restic-proxy
      tailscaleResticProxy = "7568fa9106768a017465ac6a00b5e20865bd4b4f";
      # https://github.com/tailscale/tailscale
      tailscaleTools = "d8324674610231c36dc010854e82f0c087637df1";
      # https://github.com/tailscale/squibble
      squibble = "4d5df9caa9931e8341ce65d7467681c0b225d22b";
      # https://github.com/tailscale/setec
      setec = "bc7a01a47c9cda0acbff2a49eda50708f59a47b1";
      # https://github.com/rustic-rs/rustic/releases
      rustic = "0.11.0";
    };

    homebridge = {
      # https://github.com/homebridge/homebridge/releases
      core = "1.8.4";
      # https://github.com/homebridge/homebridge-config-ui-x/releases
      configUi = "4.56.4";
      # https://github.com/arachnetech/homebridge-mqttthing/releases
      mqttthing = "1.1.47";
    };
  };
}
