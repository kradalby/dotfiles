{
  fishPlugins = {
    # https://github.com/lilyball/nix-env.fish
    nixEnv = "7b65bd228429e852c8fdfa07601159130a818cfa";
    # https://github.com/gazorby/fish-abbreviation-tips
    abbrTips = "8ed76a62bb044ba4ad8e3e6832640178880df485";
  };

  ## home.ldn
  # https://github.com/dmunozv04/iSponsorBlockTV/pkgs/container/isponsorblocktv
  isponsor = "ghcr.io/dmunozv04/isponsorblocktv:v2.10.0";

  ## core.oracldn
  grafanaDashboards = {
    # https://grafana.com/grafana/dashboards/19727-incus/
    incus = {
      rev = "2";
      hash = "sha256-3+f11v3qfTmM6poCwjUAlQmyZNs9X0TwcCdxFTreyuQ=";
    };
    # https://grafana.com/grafana/dashboards/14348-sloth-slo-detail/
    sloth = {
      rev = "5";
      hash = "sha256-kmJoFy8ZmSKN0WsoBUQEepOpfNfmTjGciKFzhcFgeCU=";
    };
  };

  # https://github.com/umami-software/umami/pkgs/container/umami
  umami = "ghcr.io/umami-software/umami:3.3.1";
  # https://hub.docker.com/r/frooodle/s-pdf/tags
  stirling = "frooodle/s-pdf:2.14.3";
  ## pkgs
  pkgs = {
    overlays = {
      # https://github.com/rye/eb
      eb = "v0.5.0";
      # https://github.com/micropython/webrepl
      webreplCli = "1e09d9a1d90fe52aba11d1e659afbc95a50cf088";
      # https://github.com/cooklang/cookcli/releases
      cook = "0.33.1";
      # https://github.com/tailscale/tailscale
      # Ceiling is the newest tag whose go.mod stays at go 1.26.5: this is
      # built from pkgs.unstable, and 1.102.3 requires 1.26.6.
      tailscaleTools = "v1.102.2";
      # https://github.com/tailscale/squibble
      squibble = "141f5d618bc46223a6fc0eb1c4df4357e2f45e86";
      # https://github.com/tailscale/setec
      setec = "58bd74dcaa1a4e50589f5a3d0961cd30769246bd";
      # https://github.com/seruman/boo (installed as `ghostty-tab`)
      ghostty-tab = "3bc3b2ec1f1dfc75bd9f8e919f1150ae5d42cf6b";
      # https://github.com/bscott/pm-cli/releases
      pmCli = "0.2.6";
    };
  };
}
