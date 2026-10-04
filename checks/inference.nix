{ pkgs, self }:
let
  inherit (pkgs) lib;
  models = [
    "qwen3.5:2b-q4_K_M"
    "gemma4:e2b-it-q4_K_M"
  ];
  base = self.inputs.nixpkgs-stable.lib.nixosSystem {
    modules = [
      self.inputs.tailscale.nixosModules.default
      ../modules/inference
      ../modules/inference/linux.nix
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nixpkgs.config.allowUnfree = true;
        system.stateVersion = "26.05";
        services.tailscale.enable = true;
        services.inference = {
          enable = true;
          serviceName = "llm-test";
          inherit models;
          healthCheck.enable = false;
        };
      }
    ];
  };
  valid =
    system:
    lib.all (a: a.assertion || !(lib.hasPrefix "inference:" a.message)) system.config.assertions;
  change = module: base.extendModules { modules = [ module ]; };
  health = change {
    services.inference.healthCheck.enable = lib.mkForce true;
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "textfile" ];
      extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-textfile" ];
    };
  };
  mac = self.darwinConfigurations.kratail2.extendModules {
    modules = [
      {
        services.inference = {
          enable = true;
          acceleration = "mlx";
          serviceName = "llm-test";
          models = [ "gemma4:e2b-mlx" ];
          port = 21434;
          proxyPort = 21435;
        };
      }
    ];
  };
  pi = self.nixosConfigurations.rpi5-ldn.config;
in
assert valid base;
assert valid health;
assert base.config.services.ollama.loadModels == models;
assert
  base.config.services.tailscale.services.llm-test.endpoints."tcp:80" == "http://127.0.0.1:11434";
assert
  !(valid (change {
    networking.firewall.enable = false;
  }));
assert
  !(valid (change {
    networking.firewall.trustedInterfaces = [ "eth0" ];
  }));
assert
  !(valid (change {
    networking.firewall.allowedTCPPorts = [ 11434 ];
  }));
assert
  !(valid (change {
    networking.firewall.interfaces.eth0.allowedTCPPorts = [ 11434 ];
  }));
assert
  !(valid (change {
    networking.firewall.allowedTCPPortRanges = [
      {
        from = 11000;
        to = 12000;
      }
    ];
  }));
assert
  !(valid (change {
    services.ollama.host = lib.mkForce "127.0.0.1";
  }));
assert
  (change { services.inference.acceleration = "cuda"; }).config.services.ollama.package.drvPath
  == base.pkgs.ollama-cuda.drvPath;
assert valid mac;
assert lib.all (host: lib.isString host.system.drvPath) (
  builtins.attrValues self.darwinConfigurations
);
assert
  mac.config.launchd.user.agents.inference.serviceConfig.ProgramArguments == [
    "/Applications/Ollama.app/Contents/Resources/ollama"
    "serve"
  ];
assert
  mac.config.launchd.user.agents.inference.serviceConfig.EnvironmentVariables.OLLAMA_HOST
  == "127.0.0.1:21434";
assert
  mac.config.services.tailscales.kradalby.services.llm-test.endpoints."tcp:80"
  == "http://127.0.0.1:21435";
assert pi.services.ollama.loadModels == models;
assert pi.services.ollama.environmentVariables.OLLAMA_MAX_LOADED_MODELS == "1";
assert pi.services.ollama.environmentVariables.OLLAMA_NUM_PARALLEL == "1";
assert pi.services.ollama.environmentVariables.OLLAMA_NO_CLOUD == "1";
pkgs.runCommand "inference-config-check" { } ''
  test -x ${health.config.systemd.services.inference-healthcheck.serviceConfig.ExecStart}
  touch $out
''
