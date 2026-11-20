# TODO(install): placeholder so the host evaluates before the machine exists.
# Replace with `nixos-generate-config --no-filesystems` output; disko.nix owns
# the filesystems.
{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
