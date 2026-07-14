# Single source of truth for the local ollama models served from kratail2 and
# the opencode provider that consumes them. This is the one place to read or
# change how the local models are configured.
#
#   server    - serving knobs applied by machines/kratail2 (ollama agent)
#   defaults  - per-model behaviour, overridable per entry below
#   models    - the models to serve; each is offered once per context size as
#               its own ollama tag (`<short>:<n>k`, num_ctx-pinned) with a
#               matching opencode entry
#
# Both consumers expand `variants`, so the served num_ctx tags and the opencode
# model list can never drift. Add a model or a size by editing `models`.
rec {
  # Applied by the ollama launchd agent on kratail2.
  server = {
    host = "127.0.0.1:11434"; # loopback only; tailnet reaches it via serve
    keepAlive = "2h"; # how long a model stays resident after its last request
  };

  # Per-model behaviour; any entry in `models` may override these.
  defaults = {
    vision = false;
    tools = true; # tool / function calling
    reasoning = true; # thinking
    output = 8192; # max output tokens (opencode limit.output)
  };

  models = [
    {
      base = "qwen3.6:35b-mlx"; # pulled / created on kratail2
      short = "qwen35b";
      label = "qwen3.6 35b";
      vision = true;
      contexts = [
        32768
        131072
        262144
      ];
    }
    {
      base = "gemma4:31b-mlx";
      short = "gemma31b";
      label = "gemma4 31b";
      # vision defaults false — gemma4 mlx builds are text-only
      contexts = [
        32768
        131072
      ];
    }
  ];

  # ollama tag / opencode model id for a model at a context size, e.g.
  # "qwen35b:128k".
  tag = m: ctx: "${m.short}:${toString (ctx / 1024)}k";

  # Flattened (model × context) list both consumers map over, with `defaults`
  # merged into each model first.
  variants = builtins.concatMap (
    m0:
    let
      m = defaults // m0;
    in
    map (ctx: {
      inherit (m)
        base
        label
        vision
        tools
        reasoning
        output
        ;
      context = ctx;
      tag = tag m ctx;
    }) m.contexts
  ) models;
}
