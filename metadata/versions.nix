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
  };

  ## home.ldn
  # https://github.com/dmunozv04/iSponsorBlockTV/pkgs/container/isponsorblocktv
  isponsor = "ghcr.io/dmunozv04/isponsorblocktv:v2.6.1";

  ## core.oracldn
  # https://github.com/umami-software/umami/pkgs/container/umami
  umami = "ghcr.io/umami-software/umami:postgresql-v2.20.2";
  # https://hub.docker.com/r/frooodle/s-pdf/tags
  stirling = "frooodle/s-pdf:2.7.2";
  ## dev.oracfurt
  # https://github.com/mealie-recipes/mealie/releases/tag/v3.12.0
  mealie = "ghcr.io/mealie-recipes/mealie:v3.12.0";

  ## pkgs
  pkgs = {
    overlays = {
      # https://github.com/rye/eb
      eb = "v0.5.0";
      # https://github.com/micropython/webrepl
      webreplCli = "1e09d9a1d90fe52aba11d1e659afbc95a50cf088";
      # https://github.com/cooklang/cookcli/releases
      cook = "0.26.0";
      # https://github.com/bradfitz/gitutil
      gitutil = "275daa41cc6eb3ed7bc80e0319907b182b5f75ce";
      # https://github.com/JonaEnz/tailscale-restic-proxy
      tailscaleResticProxy = "7568fa9106768a017465ac6a00b5e20865bd4b4f";
      # https://github.com/tailscale/tailscale
      tailscaleTools = "d8324674610231c36dc010854e82f0c087637df1";
      # https://github.com/tailscale/squibble
      squibble = "3ac5157f405ef27663ca4cd967352136506d0962";
      # https://github.com/tailscale/setec
      setec = "dcd97e42f2518bc1d304089a5380fa6ad4c03602";
      # https://github.com/seruman/boo
      boo = "3bc3b2ec1f1dfc75bd9f8e919f1150ae5d42cf6b";
      # https://github.com/bscott/pm-cli/releases
      pmCli = "0.2.3";
      # https://github.com/rtk-ai/rtk/releases
      rtk = "0.29.0";
      # https://github.com/rustic-rs/rustic/releases
      rustic = "0.11.1";
    };

    homebridge = {
      # https://github.com/homebridge/homebridge/releases
      core = "1.11.2";
      # https://github.com/homebridge/homebridge-config-ui-x/releases
      configUi = "4.56.4";
      # https://github.com/arachnetech/homebridge-mqttthing/releases
      mqttthing = "1.1.49";
    };
  };
}
