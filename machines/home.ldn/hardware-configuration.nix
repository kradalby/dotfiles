{ config, modulesPath, ... }:
{
  imports = [ ../../common/rpi4-hardware-configuration.nix ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
}

