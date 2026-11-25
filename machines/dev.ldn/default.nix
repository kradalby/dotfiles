{
  config,
  ...
}:
{
  imports = [
    ../../profiles/dev
    ../../common/incus-vm-ldn.nix
  ];

  networking = {
    hostName = "dev";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.27";
          prefixLength = 24;
        }
      ];
      ipv4.routes = [
        {
          address = "10.65.0.1";
          prefixLength = 32;
        }
      ];
    };
  };

  # Build aarch64-linux here (qemu emulation) so `rnb dev.ldn` can serve arm
  # builds; binfmt auto-advertises it via extra-platforms. Slow but handy.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.tailscale = {
    # 192.168.156.0/24 = the IoT VLAN (unifi vlan 156); routed here so
    # core.oracldn's tasmota/homewizard exporters can reach *.ldn devices.
    # Needs the unifi LAN->IoT firewall to permit the probe.
    advertiseRoutes = [
      "10.65.0.0/16"
      "192.168.156.0/24"
      "2a02:6b66:7019::/64"
    ];
    # tag:server comes from the incus-vm-ldn.nix baseline.
    tags = [ "tag:deployer" ];
  };

  # Keeps Remote Control and the claude.ai connectors.
  my.dev.claudeLogin = true;

  # Offsite repo name on Jotta — house convention, nothing host-identifying
  # on the provider side.
  services.restic.jobs.jotta.targetHost = "24265df668ee1063b968320aa77677cf";

  services.syncthings.personal.settings.folders."cooklang-recipes" = {
    id = "cooklang-recipes";
    path = "/home/kradalby/cooklang";
    devices = [ "dev.oracfurt-cooklang" ];
    type = "sendreceive";
  };

  home-manager.users.kradalby = {
    my.cooklang.recipes = "/home/kradalby/cooklang";
    # This is the box the fleet is deployed from, so it is the one that wants
    # standing role agents. Each is briefed from that repo's own
    # .agents/skills/<role>/SKILL.md, so the rules live with the thing they
    # act on.
    my.ac.permagents = [
      {
        repo = "dotfiles";
        role = "deploy";
      }
      {
        repo = "dotfiles";
        role = "triage";
      }
      {
        repo = "sfiber";
        role = "deploy";
      }
    ];

    # infrastructure has no deploy role — tofu is applied by hand, per module —
    # but it is worked on continuously, so keep its main agent standing, beside
    # the dotfiles agents.
    my.ac.mainSessions = [
      {
        repo = "infrastructure";
        session = "dotfiles";
        tab = "infra";
      }
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  # nixos-raspberrypi prebuilt kernel/firmware. Scoped here, not fleet-wide:
  # trusting the key lets that cache substitute any path, so only hosts that
  # actually build rpi closures carry it.
  nix.settings = {
    substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
