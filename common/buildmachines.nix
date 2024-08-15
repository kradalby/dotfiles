# NOTE: Public host key verification seem broken from
# at least macOS, we need to add the key manually by
# adding the base64 key ourselves:
# base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub
[
  # {
  #   hostName = "core.terra.fap.no";
  #   systems = ["x86_64-linux"];
  #   sshUser = "root";
  #   sshKey = "/Users/kradalby/.ssh/id_ed25519";
  #   maxJobs = 5;
  #   supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
  #
  #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdFenhqcHM1OGFJcncxWnhnRFV1ajFXN1QzQng2WmJPNlEzNGEweGoyQkEgcm9vdEBjb3JlCg==";
  # }
  # {
  #   hostName = "core.tjoda.fap.no";
  #   systems = ["x86_64-linux"];
  #   sshUser = "root";
  #   sshKey = "/Users/kradalby/.ssh/id_ed25519";
  #   maxJobs = 3;
  #   supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
  #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJTcUVoTExkczhzaHc4SE1PU3BOOFVNQkZqTFBUQ3lnMVRqSEtxWHZtMVcgcm9vdEBuaXhvcwo=";
  # }
  # {
  #   hostName = "core.oracldn.fap.no";
  #   systems = ["aarch64-linux"];
  #   sshUser = "root";
  #   sshKey = "/Users/kradalby/.ssh/id_ed25519";
  #   maxJobs = 3;
  #   supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
  #   publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdFZTllSU1mNDYyWlFoRThObDlqeVVzY1J0VFRZZUFJUFJOMmt2TzNjZEMgcm9vdEBjb3JlCg==";
  # }
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
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUYzblJYcVhmbG9Wc2wxN1daV3hLSWtVOUFhNi85c1UxMm1ZS0J0cFN4NjYgcm9vdEBuaXhvcwo=";
  }
]
