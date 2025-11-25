{lib, ...}: {
  require = [
    ./avahi.nix
    ./ca.nix
    ./cpufreq.nix
    ./dns-ready.nix
    ./environment.nix
    ./fail2ban.nix
    ./firewall.nix
    ./lldp.nix
    ./mosh.nix
    ./network.nix
    ./resolved.nix
    ./nix.nix
    ./node-exporter.nix
    ./postfix.nix
    ./promtail.nix
    ./smartctl-exporter.nix
    ./ssh.nix
    ./systemd-exporter.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./tskey.nix
    ./users.nix
    ./util.nix
    # ./sendmail.nix
    # ./senddiscord.nix
  ];
}
