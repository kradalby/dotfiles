# `nix run .#cache-arm [host]` — build the aarch64 nixos hosts and push their
# whole closure to tsnixcache, so garnix CI and deploys substitute instead of
# rebuilding under emulation. Run from a dotfiles checkout (builds the CURRENT
# tree); on the Mac the aarch64-linux builds offload to the rosetta VM. This
# decouples the cache from CI — warm it on demand, no laptop dependency.
#
#   nix run .#cache-arm            # all arm hosts
#   nix run .#cache-arm rpi5.ldn   # just one
{
  pkgs,
  inputs,
  system,
}:
let
  cfgs = inputs.self.nixosConfigurations;
  # aarch64 hosts, minus the dot-free dupes garnix needs (rpi5.ldn -> rpi5-ldn).
  # Reads each host's arch only (upstream of pkgs, so no recursion) — add an arm
  # host, nothing to edit.
  isDupe =
    name:
    builtins.any (n: pkgs.lib.hasInfix "." n && builtins.replaceStrings [ "." ] [ "-" ] n == name) (
      builtins.attrNames cfgs
    );
  armHosts = builtins.filter (
    n: !isDupe n && cfgs.${n}.config.nixpkgs.hostPlatform.system == "aarch64-linux"
  ) (builtins.attrNames cfgs);

  cache-arm = pkgs.writeShellApplication {
    name = "cache-arm";
    runtimeInputs = [ inputs.tsnixcache.packages.${system}.default ];
    text = ''
      cache="''${TSNIXCACHE:-http://tsnixcache}"
      all=(${builtins.concatStringsSep " " armHosts})
      targets=("''${all[@]}")
      if [ $# -ge 1 ]; then
        targets=("$1")
      fi

      failed=()
      for host in "''${targets[@]}"; do
        echo "==> building $host (aarch64-linux)"
        if ! out=$(nix build ".#nixosConfigurations.\"$host\".config.system.build.toplevel" \
            --no-link --print-out-paths --builders-use-substitutes -L); then
          echo "!! build failed: $host" >&2
          failed+=("$host")
          continue
        fi
        echo "==> pushing $host closure to $cache"
        if ! tsnixcache push --to "$cache" "$out"; then
          echo "!! push failed: $host" >&2
          failed+=("$host")
          continue
        fi
        echo "==> cached: $host"
      done

      if [ ''${#failed[@]} -ne 0 ]; then
        echo "FAILED: ''${failed[*]}" >&2
        exit 1
      fi
      echo "all cached: ''${targets[*]}"
    '';
  };
in
{
  type = "app";
  program = "${cache-arm}/bin/cache-arm";
}
