{ ... }: {
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 60000;
      to = 61000;
    }
  ];
}
