{ lib, ... }:
{
  imports = [ ../../common/syncthing-storage.nix ];

  # Untrusted offsite host: receive the folders encrypted. bassan stores only
  # ciphertext and never holds the key (the trusted senders set the passphrase;
  # see common/syncthing-storage.nix). receiveencrypted also implies the mirror
  # never propagates local changes back to the primaries.
  # Derived from the shared folder set in metadata/syncthing.nix, so a folder
  # added there can never silently stay sendreceive (i.e. unencrypted) here.
  services.syncthings.storage.settings.folders = lib.mapAttrs (_: _: {
    type = lib.mkForce "receiveencrypted";
  }) (import ../../metadata/syncthing.nix).storageFolders;
}
