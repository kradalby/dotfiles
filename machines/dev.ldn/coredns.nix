{lib, ...}: {
  imports = [
    ../../common/coredns.nix
  ];

  # Ensure that lanbr0 is up before coredns starts.
  systemd.services.coredns.after = ["network-online.target" "sys-devices-virtual-net-lanbr0.device"];
  systemd.services.coredns.wants = ["network-online.target" "sys-devices-virtual-net-lanbr0.device"];
  my.coredns.bind = ["lanbr0" "iot0"];
}
