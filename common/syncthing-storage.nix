{
  config,
  lib,
  ...
}:
let
  cfg = import ../metadata/syncthing.nix;
  location =
    let
      components = lib.splitString "." config.networking.domain;
    in
    lib.elemAt components 0;
  tailscaleService = "syncthing-${location}";

  # bassan is the untrusted offsite mirror (a box at someone else's house). The
  # trusted senders share the storage folders to it *encrypted* — it stores only
  # ciphertext and never holds the key. bassan itself is the receiver, so it must
  # not add itself as an encrypted device (and never gets the passphrase secret).
  isBassan = config.networking.hostName == "storage" && config.networking.domain == "bassan.fap.no";

  # The passphrase is an age secret injected into the syncthing config at runtime
  # (never enters the nix store). Until it exists the encrypted sharing is inert,
  # so every trusted sender keeps building before the secret is created.
  encSecret = ../secrets/syncthing-storage-enc.age;
  shareEncrypted = !isBassan && builtins.pathExists encSecret;

  mirrorDevice = lib.optional shareEncrypted {
    name = "storage.bassan";
    encryptionPasswordFile = config.age.secrets.syncthing-storage-enc.path;
  };

  # storage folders: the plaintext peer set + the encrypted mirror.
  storageDevices = cfg.storage ++ mirrorDevice;

  # kradalby-Sync shares with every known device; keep bassan out of the
  # plaintext list and add it back encrypted. dev.oracfurt-cooklang only
  # accepts krair/kratail2, so sharing to it just produced a permanent
  # redial loop (SyncthingNoConnections noise).
  allDevices = builtins.attrNames config.services.syncthings.storage.settings.devices;
  syncDevices =
    (lib.filter (d: d != "storage.bassan" && d != "dev.oracfurt-cooklang") allDevices) ++ mirrorDevice;
in
{
  services = {
    syncthings.storage = {
      enable = true;
      user = "storage";
      group = "storage";
      dataDir = "/storage";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        inherit (cfg) devices;
        gui = {
          insecureSkipHostcheck = true;
          insecureAdminAccess = true;
        };
        # Folder set lives in metadata/syncthing.nix, shared with bassan's
        # receiveencrypted overrides so the two can never drift.
        folders = lib.mapAttrs (name: f: {
          inherit (f) id path;
          devices = if name == "kradalby - Sync" then syncDevices else storageDevices;
          type = "sendreceive";
        }) cfg.storageFolders;
      };
    };

    tailscale.services.${tailscaleService} = {
      endpoints = {
        "tcp:80" = "http://127.0.0.1:8384";
        # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
        "tcp:443" = "http://127.0.0.1:8384";
      };
    };
  };

  age.secrets = lib.mkIf shareEncrypted {
    # The syncthing config-updater (syncthing-storage-init) runs as the storage
    # user and reads this to inject the encryptionPassword; default root:root
    # 0400 gives it "permission denied", so hand it to that user.
    syncthing-storage-enc = {
      file = encSecret;
      owner = "storage";
    };
  };
}
