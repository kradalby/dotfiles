{
  lib,
  flakes,
  ...
}: {
  require = [
    ./ca.nix
    ./dns-ready.nix
    ./network.nix
    ./cpufreq.nix
    ./users.nix
    ./ssh.nix
    ./mosh.nix
    ./environment.nix
    ./firewall.nix
    ./lldp.nix
    ./node-exporter.nix
    ./smartctl-exporter.nix
    ./systemd-exporter.nix
    ./promtail.nix
    ./nix.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./util.nix
    ./postfix.nix
    ./consul.nix
    ./avahi.nix
    # ./sendmail.nix
    # ./senddiscord.nix
  ];
}
