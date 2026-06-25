# Minimum every NixOS box needs — access, identity, DNS/time hygiene, the nix
# settings, host metrics, and a small system toolset (../pkgs/base.nix). This is
# the lean base the minimal ts1p appliance imports on its own; servers layer
# ../profiles/server.nix on top, and workstations additionally get the
# home-manager userland. Excludes fail2ban (deleted), avahi (opt-in per machine),
# and the heavier exporters/mail (server profile).
{...}: {
  imports = [
    ./ca.nix
    ./cpufreq.nix
    ./dns-ready.nix
    ./environment.nix
    ./firewall.nix
    ./lldp.nix
    ./mosh.nix
    ./network.nix
    ./resolved.nix
    ./nix.nix
    ./node-exporter.nix
    ./ssh.nix
    ./time.nix
    ./timezone.nix
    ./tmp.nix
    ./tmux.nix
    ./tskey.nix
    ./users.nix
    ./util.nix

    ../pkgs/base.nix
  ];
}
