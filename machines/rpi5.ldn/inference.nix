{ pkgs, ... }:
{
  services.inference = {
    enable = true;
    runner = "ollama";
    acceleration = "cpu";
    # New Gemma bundles include a draft model; use the current runner without
    # moving the host's kernel or the rest of its stable package set.
    package = pkgs.unstable.ollama-cpu;
    serviceName = "llm-rpi5";
    models = [
      "qwen3.5:2b-q4_K_M"
      "gemma4:e2b-it-q4_K_M"
    ];
    contextLength = 4096;
    parallelism = 1;
    maxLoadedModels = 1;
    maxQueue = 8;
    keepAlive = "24h";
  };

  # Only downloadable model weights persist in /var/lib/ollama. They are cache,
  # so no backup or secret inputs are needed; clients own conversation history.
}
