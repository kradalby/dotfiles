{ lib, flakes, ... }:
{
  require = [
    ./network.nix
    ./cpufreq.nix
    ./users.nix
    ./ssh.nix
    ./environment.nix
    ./firewall.nix
    ./lldp.nix
    ./node-exporter.nix
    ./smartctl-exporter.nix
    ./promtail.nix
    ./nix.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./util.nix
    # ./sendmail.nix
    ./senddiscord.nix
    ./consul.nix
  ];
}
