{ lib, flakes, ... }:
{
  require = [
    ./cpufreq.nix
    ./consul.nix
    ./users.nix
    ./ssh.nix
    ./environment.nix
    ./firewall.nix
    ./lldp.nix
    ./prometheus.nix
    ./promtail.nix
    ./nix.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./util.nix
    ./network.nix
    # ./sendmail.nix
    ./senddiscord.nix
  ];
}
