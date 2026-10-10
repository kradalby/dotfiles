{ pkgs, self }:
let
  linux = self.inputs.nixpkgs-stable.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      ../../modules/syncthing-nixos.nix
      {
        services.syncthings.fixture = {
          enable = true;
          user = "fixture";
          configDir = "/fixture/config";
          guiAddress = "http://127.0.0.1:1";
          guiPasswordFile = "/fixture/gui-password";
          settings = {
            devices.peer.id = "PEER";
            folders.fixture = {
              path = "/fixture/data";
              devices = [
                {
                  name = "peer";
                  encryptionPasswordFile = "/fixture/encryption-password";
                }
              ];
              ignorePatterns = [ "node_modules" ];
            };
          };
        };
      }
    ];
  };
  # Evaluate the Darwin initializer with Linux tools; no launchd jobs are run.
  darwin = pkgs.lib.evalModules {
    modules = [
      ../../modules/syncthing-darwin.nix
      {
        config._module.args.pkgs = pkgs;
        options.launchd.user.agents = pkgs.lib.mkOption {
          type = pkgs.lib.types.attrsOf pkgs.lib.types.attrs;
        };
        options.environment.etc = pkgs.lib.mkOption { type = pkgs.lib.types.attrsOf pkgs.lib.types.attrs; };
        config.services.syncthing = {
          enable = true;
          configDir = "/fixture/config";
          guiAddress = "http://127.0.0.1:1";
          folders.fixture = {
            path = "/fixture/data";
            ignorePatterns = [ "node_modules" ];
          };
        };
      }
    ];
  };
in
pkgs.runCommand "syncthing-init-test"
  {
    nativeBuildInputs = with pkgs; [
      python3
      ruff
      pyright
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I --line-length 100 ${./test.py}
    ruff format --check --line-length 100 ${./test.py}
    echo '{"typeCheckingMode":"strict"}' > "$TMPDIR/pyrightconfig.json"
    pyright --pythonpath ${pkgs.python3}/bin/python3 --project "$TMPDIR/pyrightconfig.json" ${./test.py}
    python3 ${./test.py} \
      ${linux.config.systemd.services.syncthing-fixture-init.serviceConfig.ExecStart} \
      ${darwin.config.launchd.user.agents.syncthing-init.command} \
      ${pkgs.curl}/bin/curl ${pkgs.bash}/bin/bash
    touch "$out"
  ''
