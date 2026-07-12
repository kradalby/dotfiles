# Personal Mac configuration
{pkgs, ...}: {
  imports = [
    ../../common/darwin/kradalby-base.nix
    ./rustic.nix
    ./claude-code.nix
  ];

  # Configure SSH agent mux for personal machine
  # Watches /tmp for forwarded agents from kratail2 and automatically updates config
  services.ssh-agent-mux = {
    enable = true;
    # stdout/stderr logs live under ~/Library/Logs/ssh-agent-mux*.log for quick debugging
    agentSockets = [
      "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      "~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
      "~/.ssh/yubikey-agent.sock"
    ];
    watchForSSHForward = true; # Automatically detect and use forwarded agents
  };

  homebrew = {
    casks = [
      "proton-mail-bridge"
    ];
  };

  home-manager.users.kradalby = {
    imports = [
      ../../home/herdr.nix
      ../../home/atuin.nix
    ];
    my.atuin.enable = true; # personal account (shared with dev.ldn)

    home.packages = with pkgs; [
      pm-cli
    ];
  };
}
