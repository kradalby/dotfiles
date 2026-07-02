# Builder registry for `rnb` (remote nix builder selector).
#
# Same fields as common/buildmachines.nix, plus:
#   name       - the short name you type: `rnb <name> -- nix build ...`
#   host       - groups endpoints of one machine so `--auto` picks one
#   hasRosetta - informational: the box has a local rosetta linux builder
#
# Rendered to ~/.config/rnb/builders.json by home/rnb.nix.
#
# Add an endpoint: copy a block, set name/hostName/speedFactor. Get the
# publicHostKey (base64) with:
#   ssh <host> base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub
#
# speedFactor convention (mirrors buildmachines.nix): 4 = LAN, 2 = tailscale.
[
  # dev.ldn via LAN (x86_64-linux; aarch64-linux via binfmt on dev.ldn)
  {
    name = "dev.ldn";
    host = "dev.ldn";
    hostName = "dev.ldn.fap.no";
    systems = ["x86_64-linux" "aarch64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 4;
    speedFactor = 4;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhOclJpZVZmckN2bnFOYnV4RXIwNmM2RDEvbGhHbEVJdlM4Tk5RaHJtSnQ=";
    hasRosetta = false;
  }

  # dev.ldn via Tailscale (works off-LAN, higher latency)
  {
    name = "dev-ldn";
    host = "dev.ldn";
    hostName = "dev-ldn.dalby.ts.net";
    systems = ["x86_64-linux" "aarch64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhOclJpZVZmckN2bnFOYnV4RXIwNmM2RDEvbGhHbEVJdlM4Tk5RaHJtSnQ=";
    hasRosetta = false;
  }

  # kratail2 via Tailscale (aarch64-darwin; local rosetta VM for linux)
  {
    name = "kratail2";
    host = "kratail2";
    hostName = "kratail2.dalby.ts.net";
    systems = ["aarch64-darwin"];
    sshUser = "kradalby";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 8;
    speedFactor = 2;
    supportedFeatures = ["big-parallel"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUh3NTFUQ1BmWkxnbm5ZLzc5ZHZGNDdOc0pFZmptNy9oWVdleUxmZ0J2bUE=";
    hasRosetta = true;
  }
]
