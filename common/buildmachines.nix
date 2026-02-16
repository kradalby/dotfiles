# Remote build machines configuration
#
# Priority scheme (speedFactor):
#   10 = nix-rosetta-builder (local, set in kradalby-base.nix)
#    4 = LAN access (fast, only works on local network)
#    2 = Tailscale access (works everywhere, higher latency)
#
# NOTE: Host key verification requires base64-encoded keys.
# Generate with: base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub
[
  # dev.ldn via LAN (x86_64-linux)
  {
    hostName = "dev.ldn.fap.no";
    systems = ["x86_64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 4;
    speedFactor = 4;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhOclJpZVZmckN2bnFOYnV4RXIwNmM2RDEvbGhHbEVJdlM4Tk5RaHJtSnQ=";
  }

  # dev.ldn via Tailscale (x86_64-linux)
  {
    hostName = "dev-ldn.dalby.ts.net";
    systems = ["x86_64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhOclJpZVZmckN2bnFOYnV4RXIwNmM2RDEvbGhHbEVJdlM4Tk5RaHJtSnQ=";
  }

  # dev.oracfurt via Tailscale (aarch64-linux)
  {
    hostName = "dev-oracfurt.dalby.ts.net";
    systems = ["aarch64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUU2NXMvaFJuMzR2NVVOaFNJQzgvSk4vNDUyaExkcW4xMzFnVnFxQlRQbmwgcm9vdEBkZXYK";
  }
]
