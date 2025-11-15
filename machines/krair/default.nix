# Personal Mac configuration
{...}: {
  imports = [
    ../../common/darwin/kradalby-base.nix
  ];

  # Configure SSH agent mux for personal machine
  # Watches /tmp for forwarded agents from kratail2 and automatically updates config
  services.ssh-agent-mux = {
    enable = true;
    agentSockets = [
      "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      "~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
      "~/.ssh/yubikey-agent.sock"
    ];
    watchForSSHForward = true; # Automatically detect and use forwarded agents
  };
}
