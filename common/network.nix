{ lib, ... }: {
  networking.useDHCP = false;

  # TODO: Re-evaluate if it turns less buggy later
  networking.useNetworkd = lib.mkDefault false;
}
