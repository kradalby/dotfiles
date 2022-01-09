{ modulesPath, ... }:
{
    imports = [
      # (modulesPath + "/virtualisation/vmware-image.nix")
      (modulesPath + "/virtualisation/virtualbox-image.nix")
      (modulesPath + "/virtualisation/vmware-guest.nix")
  ];
}

