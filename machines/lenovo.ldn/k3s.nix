{pkgs, ...}: {
  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [];
  };
  # "--kubelet-arg=v=4" # Optionally add additional args to k3s
  environment.systemPackages = [pkgs.k3s];
}
