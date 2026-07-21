{ lib, ... }:
{
  imports = [ ../../common/syncthing-storage.nix ];

  # Untrusted offsite host: receive the folders encrypted. bassan stores only
  # ciphertext and never holds the key (the trusted senders set the passphrase;
  # see common/syncthing-storage.nix). receiveencrypted also implies the mirror
  # never propagates local changes back to the primaries.
  # ponytail: enumerated per-folder — if a folder is added to
  # common/syncthing-storage.nix, add its mkForce line here too, else it silently
  # stays sendreceive (and unencrypted) on the mirror.
  services.syncthings.storage.settings.folders = {
    "/storage/software".type = lib.mkForce "receiveencrypted";
    "/storage/pictures".type = lib.mkForce "receiveencrypted";
    "/storage/backup".type = lib.mkForce "receiveencrypted";
    "/storage/books".type = lib.mkForce "receiveencrypted";
    "kradalby - Sync".type = lib.mkForce "receiveencrypted";
  };
}
