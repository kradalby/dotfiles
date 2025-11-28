# NOTE: Public host key verification seem broken from
# at least macOS, we need to add the key manually by
# adding the base64 key ourselves:
# base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub
[
  {
    hostName = "dev.oracfurt.fap.no";
    systems = ["aarch64-linux"];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 3;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUU2NXMvaFJuMzR2NVVOaFNJQzgvSk4vNDUyaExkcW4xMzFnVnFxQlRQbmwgcm9vdEBkZXYK";
  }
  {
    hostName = "dev.ldn.fap.no";
    systems = [
      "x86_64-linux"
      # "aarch64-linux"
    ];
    sshUser = "root";
    sshKey = "/Users/kradalby/.ssh/id_ed25519";
    maxJobs = 3;
    supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUhOclJpZVZmckN2bnFOYnV4RXIwNmM2RDEvbGhHbEVJdlM4Tk5RaHJtSnQ=";
  }
]
