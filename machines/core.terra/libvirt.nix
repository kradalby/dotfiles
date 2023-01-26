{ config, ... }: {
  security.polkit.enable = true;

  virtualisation.libvirtd = {
    enable = true;

    allowedBridges = [
      "virbr0"
      config.my.lan
    ];

    qemu = {
      ovmf.enable = true;
      swtpm.enable = true;
    };
  };
}
