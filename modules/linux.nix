{
  imports = [
    ./inference
    ./inference/linux.nix
    ./mqtt-exporter
    ./oci-usage-exporter.nix
    ./energyd.nix
    ./tailscale-proxy.nix
    ./vhost.nix
    ./restic-jobs.nix
    ./restic-jobs-linux.nix
    ./sqlite-backup

    ./cook-server.nix
    ./syncthing-nixos.nix
  ];
}
