prev: final: let
  neo2-dts = {
    name = "NanoPi-neo2-h5-dts";
    patch = ./patches/arm64-dts-Add-sun50i-h5-nanopi-neo2-v1.1-device.patch;
  };
  neo2-dts-led = {
    name = "NanoPi-neo2-h5-dts-led";
    patch = ./patches/arm64-dts-sun50i-h5-nanopi-neo2-add-regulator-led-triger.patch;
  };
  h5-dts-cpu-opp-refs = {
    name = "h5-dts-cpu-opp-refs";
    patch = ./patches/arm64-dts-sun50i-h5-add-cpu-opp-refs.patch;
  };
  h5-dts-add-termal-zones = {
    name = "h5-dts-add-termal-zones";
    patch = ./patches/arm64-dts-sun50i-h5-add-termal-zones.patch;
  };
  h5-add-gpio-regulator-overclock = {
    name = "h5-add-gpio-regulator-overclock";
    patch = ./patches/arm64-dts-overlay-sun50i-h5-add-gpio-regulator-overclock.patch;
  };

  linux-nanopi-neo2 =
    prev.callPackage ./kernel.nix
    {
      # kernelPatches = [];
      kernelPatches = [
        neo2-dts
        neo2-dts-led
        # h5-dts-cpu-opp-refs
        # h5-dts-add-termal-zones
        # h5-add-gpio-regulator-overclock
      ];
    };
in {
  linuxPackagesNanopiNeo2 = prev.linuxPackagesFor linux-nanopi-neo2;

  uboot_NanopiNeo2 = prev.buildUBoot {
    defconfig = "nanopi_neo2_defconfig";
    # extraPatches = [./patches/arm64-rk3399-Add-support-NanoPi-R4s.patch];
    extraMeta = {
      platforms = ["aarch64-linux"];
      #license = lib.licenses.unfreeRedistributableFirmware;
    };
    BL31 = "${prev.armTrustedFirmwareAllwinner}/bl31.bin";
    filesToInstall = ["spl/u-boot-spl.bin" "u-boot.itb" "idbloader.img"];
  };
}
