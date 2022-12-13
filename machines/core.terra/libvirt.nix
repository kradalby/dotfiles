{...}: {
  security.polkit.enable = true;

  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      ovmf.enable = true;
      swtpm.enable = true;
    };
  };
}
