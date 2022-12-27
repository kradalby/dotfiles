{
  stdenv,
  buildPackages,
  fetchurl,
  perl,
  buildLinux,
  modDirVersionArg ? null,
  ...
} @ args:
with stdenv.lib;
  buildLinux (args
    // rec {
      #version = "5.13-rc7";
      version = "6.1.1";
      #extraMeta.branch = "5.10";

      # modDirVersion needs to be x.y.z, will always add .0
      modDirVersion =
        if (modDirVersionArg == null)
        then builtins.replaceStrings ["-"] [".0-"] version
        else modDirVersionArg;

      src = fetchurl {
        url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
        sha256 = "";
      };

      # Should the testing kernels ever be built on Hydra?
      extraMeta.hydraPlatforms = [];
    }
    // (args.argsOverride or {}))
