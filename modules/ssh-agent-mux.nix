{
  pkgs,
  lib,
  config,
  machine,
  ...
}: let
  cfg = config.services.ssh-agent-mux;

  # The mux socket location
  muxSocket = cfg.listenPath;

  # Script to regenerate config with /tmp sockets and restart service
  updateConfigScript = pkgs.writeShellScript "ssh-agent-mux-update" ''
    CONFIG_FILE="$HOME/.config/ssh-agent-mux/ssh-agent-mux.toml"
    BASE_CONFIG_FILE="$HOME/.config/ssh-agent-mux/ssh-agent-mux-base.toml"

    # Find the most recent forwarded agent socket
    TMP_SOCKET=$(${pkgs.findutils}/bin/find /tmp/ssh-* -type s -name "agent.*" 2>/dev/null | ${pkgs.coreutils}/bin/ls -t 2>/dev/null | ${pkgs.coreutils}/bin/head -n 1)

    if [ -n "$TMP_SOCKET" ] && [ -S "$TMP_SOCKET" ]; then
      echo "Found forwarded SSH agent: $TMP_SOCKET"
      # Prepend tmp socket to the base config
      ${pkgs.gnused}/bin/sed 's|agent_sock_paths = \[|agent_sock_paths = [\n  "'"$TMP_SOCKET"'",|' "$BASE_CONFIG_FILE" > "$CONFIG_FILE"
    else
      # No tmp socket, use base config
      ${pkgs.coreutils}/bin/cp "$BASE_CONFIG_FILE" "$CONFIG_FILE"
    fi

    # Restart the service
    ${pkgs.coreutils}/bin/launchctl kickstart -k "gui/$(${pkgs.coreutils}/bin/id -u)/org.nix-community.home.ssh-agent-mux" 2>/dev/null || true
  '';

  # Watcher script using fswatch to monitor /tmp for ssh-* directories
  watcherScript = pkgs.writeShellScript "ssh-agent-mux-watcher" ''
    # Use fswatch to monitor /tmp for new ssh-* directories
    # --event Created: only trigger on new files/directories
    # --include: only watch for ssh- prefixed items
    ${pkgs.fswatch}/bin/fswatch -0 --event Created --include '/tmp/ssh-' /tmp | \
      while IFS= read -r -d "" event; do
        echo "Detected change in /tmp: $event"
        # Only update if it's actually an ssh agent directory
        if [[ "$event" == /tmp/ssh-* ]]; then
          echo "SSH agent directory detected, updating config..."
          ${updateConfigScript}
        fi
      done
  '';

  # Base configuration file (without /tmp sockets)
  baseConfigFile = pkgs.writeText "ssh-agent-mux-base.toml" ''
    # SSH agent socket paths to multiplex
    # Order matters: first agent is tried first
    agent_sock_paths = [
      ${lib.concatMapStringsSep "\n      " (sock: ''"${sock}",'') cfg.agentSockets}
    ]
    listen_path = "${muxSocket}"
    log_level = "${cfg.logLevel}"
  '';
in {
  options.services.ssh-agent-mux = {
    enable = lib.mkEnableOption "SSH agent multiplexer";

    agentSockets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        "~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
        "~/.ssh/yubikey-agent.sock"
      ];
      description = ''
        List of SSH agent socket paths to multiplex.
        Order matters: the first agent is tried first.
        Paths can use ~ for home directory expansion.
      '';
    };

    listenPath = lib.mkOption {
      type = lib.types.str;
      default = "~/.ssh/ssh-agent-mux.sock";
      description = "Path where ssh-agent-mux creates its multiplexed socket";
    };

    watchTmpSockets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Watch for forwarded SSH agent sockets in /tmp and automatically
        restart ssh-agent-mux to include them when they appear.
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.enum ["error" "warn" "info" "debug"];
      default = "info";
      description = "Log level for ssh-agent-mux";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${machine.username} = {config, ...}: let
      homeDir = config.home.homeDirectory;
    in {
      home.packages = [
        pkgs.ssh-agent-mux
      ];

      # Create the base config file
      xdg.configFile."ssh-agent-mux/ssh-agent-mux-base.toml".source = baseConfigFile;

      # Initial config file (will be updated by watcher if enabled)
      xdg.configFile."ssh-agent-mux/ssh-agent-mux.toml".source = baseConfigFile;

      # Set up launchd service to run ssh-agent-mux
      launchd.agents.ssh-agent-mux = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.ssh-agent-mux}/bin/ssh-agent-mux"
            "--config"
            "${homeDir}/.config/ssh-agent-mux/ssh-agent-mux.toml"
          ];
          KeepAlive = true;
          RunAtLoad = true;
          ProcessType = "Background";
          StandardOutPath = "${homeDir}/Library/Logs/ssh-agent-mux.log";
          StandardErrorPath = "${homeDir}/Library/Logs/ssh-agent-mux.error.log";
        };
      };

      # Optional: Set up fswatch-based watcher for /tmp/ssh-* directories
      launchd.agents.ssh-agent-mux-watcher = lib.mkIf cfg.watchTmpSockets {
        enable = true;
        config = {
          ProgramArguments = [
            "${watcherScript}"
          ];
          KeepAlive = true;
          RunAtLoad = true;
          ProcessType = "Background";
          StandardOutPath = "${homeDir}/Library/Logs/ssh-agent-mux-watcher.log";
          StandardErrorPath = "${homeDir}/Library/Logs/ssh-agent-mux-watcher.error.log";
        };
      };

      # Set SSH_AUTH_SOCK to the mux socket
      home.sessionVariables = {
        SSH_AUTH_SOCK = muxSocket;
      };

      # Add Fish functions for managing the mux
      programs.fish.functions = {
        ssh-agent-mux-restart = ''
          # Restart the launchd service
          launchctl kickstart -k gui/(id -u)/org.nix-community.home.ssh-agent-mux
          sleep 1
          echo "ssh-agent-mux restarted"
        '';

        ssh-agent-mux-status = ''
          if test -S "$HOME/.ssh/ssh-agent-mux.sock"
              echo "ssh-agent-mux socket: $HOME/.ssh/ssh-agent-mux.sock"
              echo ""
              echo "Available keys:"
              ssh-add -l
          else
              echo "ssh-agent-mux socket not found"
              echo "Check logs: tail ~/Library/Logs/ssh-agent-mux*.log"
          end
        '';

        ssh-agent-mux-update = lib.mkIf cfg.watchTmpSockets ''
          # Manually trigger config update
          ${updateConfigScript}
          echo "Configuration updated and service restarted"
        '';
      };
    };
  };
}
