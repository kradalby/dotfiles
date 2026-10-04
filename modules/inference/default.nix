{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.inference;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  options.services.inference = {
    enable = lib.mkEnableOption "local inference through a Tailscale service";
    runner = lib.mkOption {
      type = lib.types.enum [ "ollama" ];
      default = "ollama";
      description = "Inference runner. Ollama is currently supported.";
    };
    acceleration = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "cuda"
        "rocm"
        "vulkan"
        "mlx"
        "metal"
      ];
      default = if isDarwin then "mlx" else "cpu";
      description = "Native backend; MLX also requires MLX-compatible model tags.";
    };
    serviceName = lib.mkOption {
      type = lib.types.strMatching "[a-z0-9]([a-z0-9-]*[a-z0-9])?";
      description = "VIP name, paired with a tailscale_service and grant in infrastructure/tailscale.";
      example = "llm-rpi5";
    };
    models = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[^[:space:]]+");
      default = [ ];
      description = "Explicit local Ollama tags to download; model weights are rebuildable cache.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Local runner port; clients connect through the VIP.";
    };
    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
      description = "Default context window in tokens. Clients can request a different size.";
    };
    parallelism = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Parallel requests per loaded model.";
    };
    maxLoadedModels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Maximum resident models; others load on demand.";
    };
    maxQueue = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Maximum queued requests before the runner returns an overload error.";
    };
    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "24h";
      description = "How long an idle model stays resident.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      internal = true;
      default = {
        OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
        OLLAMA_NUM_PARALLEL = toString cfg.parallelism;
        OLLAMA_MAX_LOADED_MODELS = toString cfg.maxLoadedModels;
        OLLAMA_MAX_QUEUE = toString cfg.maxQueue;
        OLLAMA_KEEP_ALIVE = cfg.keepAlive;
        OLLAMA_NO_CLOUD = "1";
      };
      description = "Serving settings shared by systemd and launchd.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models != [ ] && cfg.models == lib.unique cfg.models;
        message = "inference: declare at least one model, with no duplicate tags.";
      }
      {
        assertion =
          if isDarwin then
            lib.elem cfg.acceleration [
              "mlx"
              "metal"
            ]
            && (cfg.acceleration != "mlx" || pkgs.stdenv.hostPlatform.isAarch64)
          else
            lib.elem cfg.acceleration [
              "cpu"
              "cuda"
              "rocm"
              "vulkan"
            ];
        message = "inference: use cpu/cuda/rocm/vulkan on Linux, or mlx/metal on a supported Mac.";
      }
    ];
  };
}
