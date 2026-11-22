{ inputs }:
let
  inherit (inputs) nixpkgs-stable nixos-raspberrypi image-config;
  installed = [
    inputs.ragenix.nixosModules.age
    inputs.tailscale.nixosModules.default
    ../common/bootstrap-common.nix
    (image-config + "/default.nix")
  ];

  pi =
    name: boardModules:
    (nixos-raspberrypi.lib.nixosSystemFull {
      modules =
        installed
        ++ boardModules
        ++ [
          nixos-raspberrypi.nixosModules.sd-image
          ({ lib, ... }: { networking.hostName = lib.mkDefault name; })
        ];
    }).config.system.build.sdImage;

  server = nixpkgs-stable.lib.nixosSystem {
    system = "x86_64-linux";
    modules = installed ++ [
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
      ({ pkgs, lib, ... }: {
        image.modules.iso-installer = {
          image.baseName = lib.mkForce "${target.networking.hostName}-installer";
          boot.zfs.forceImportRoot = false;
          # Each fresh join key produces a new ISO; favor build time.
          isoImage.squashfsCompression = "zstd -Xcompression-level 3";
          isoImage.storeContents = [ target.system.build.toplevel ];
          isoImage.contents = [
            {
              source = pkgs.writeText "target-system" (toString target.system.build.toplevel);
              target = "/provision/target-system";
            }
          ]
          ++ lib.optional (builtins.pathExists (image-config + "/installer-identity.age")) {
            source = image-config + "/installer-identity.age";
            target = "/provision/installer-identity.age";
          };
          environment.systemPackages = [ pkgs.age ];
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
      ../profiles/sd-card.nix
    ];
    rpi5 = pi "bootstrap5" [
      nixos-raspberrypi.nixosModules.raspberry-pi-5.base
      nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    ];
  };
}
