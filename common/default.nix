{ lib, flakes, ... }:
{
  require = [
    ./cpufreq.nix
    ./users.nix
    ./ssh.nix
    ./firewall.nix
    ./lldp.nix
    ./prometheus.nix
    ./dns.nix
    ./nix.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./util.nix
  ];
}
