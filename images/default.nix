{ inputs }:
let
  inherit (inputs) nixpkgs-stable nixos-raspberrypi image-config;
  hostModules = [
    inputs.tailscale.nixosModules.default
    ../common/bootstrap-common.nix
    (image-config + "/default.nix")
  ];

  pi =
    name: boardModules:
    (nixos-raspberrypi.lib.nixosSystemFull {
      modules =
        hostModules
        ++ boardModules
        ++ [
          nixos-raspberrypi.nixosModules.sd-image
          ../profiles/sd-card.nix
          ({ lib, ... }: { networking.hostName = lib.mkDefault name; })
        ];
    }).config.system.build.sdImage;

  server = nixpkgs-stable.lib.nixosSystem {
    system = "x86_64-linux";
    modules = hostModules ++ [
      ({ lib, ... }: {
        networking.hostName = lib.mkDefault "bootstrap";
        boot.initrd.availableKernelModules = [
          "ahci"
          "nvme"
          "sd_mod"
          "usb_storage"
          "xhci_pci"
          "virtio_pci"
          "virtio_blk"
          "virtio_scsi"
        ];
      })
    ];
  };
  raw = server.config.system.build.images.raw-efi;
  target = raw.passthru.config;
  installer = nixpkgs-stable.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ({ lib, ... }: {
        image.modules.iso-installer = {
          imports = hostModules;
          networking.hostName = lib.mkDefault target.networking.hostName;
          # The upstream live profile uses NetworkManager; the host profiles use networkd.
          networking.networkmanager.enable = lib.mkForce false;
          image.baseName = lib.mkForce "${target.networking.hostName}-installer";
          boot.zfs.forceImportRoot = false;
          # Each fresh join key produces a new ISO; favor build time.
          isoImage.squashfsCompression = "zstd -Xcompression-level 3";
          systemd.services.install-bootstrap = {
            description = "Install the mounted target and hand off the live identity";
            environment.TARGET_SYSTEM = toString target.system.build.toplevel;
            path = [ "/run/current-system/sw" ];
            serviceConfig.Type = "oneshot";
            script = builtins.readFile ./install.sh;
          };
        };
      })
    ];
  };
in
{
  x86_64-linux = {
    installer-iso = installer.config.system.build.images.iso-installer;
    raw-efi = raw;
  };
  aarch64-linux = {
    rpi4 = pi "bootstrap4" [
      nixos-raspberrypi.nixosModules.raspberry-pi-4.base
    ];
    rpi5 = pi "bootstrap5" [
      nixos-raspberrypi.nixosModules.raspberry-pi-5.base
      nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    ];
  };
}
