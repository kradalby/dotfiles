{
  pkgs,
  opencodeOverlay,
  hermesOverlay,
}:
let
  json = pkgs.formats.json { };
  opencodeOverlayFile = json.generate "aperture-opencode-overlay.json" opencodeOverlay;
  hermesOverlayFile = json.generate "aperture-hermes-overlay.json" hermesOverlay;
  validMcp = "http://ai.corp.ts.net/v1/mcp";
  validOpencode = {
    enabled_providers = [
      "aperture-anthropic"
      "aperture-openai"
      "aperture-openai-compatible"
    ];
    mcp.aperture = {
      type = "remote";
      url = validMcp;
    };
    provider = {
      aperture-anthropic.models."anthropic/claude-opus-5" = { };
      aperture-openai.models."openai/gpt-5.6-sol" = { };
      aperture-openai-compatible.models = {
        "deepseek/deepseek-v4-pro" = { };
        "google/gemini-3.7-flash" = { };
        "moonshotai/kimi-k3" = { };
        "zai/glm-5.3" = { };
      };
    };
  };
  validHermes = {
    mcp_servers.aperture.url = validMcp;
    providers = {
      aperture-claude.models = [ "anthropic/claude-opus-5" ];
      aperture-responses.models = [ "openai/gpt-5.6-sol" ];
      aperture-completions.models = [
        "deepseek/deepseek-v4-pro"
        "google/gemini-3.7-flash"
        "moonshotai/kimi-k3"
        "zai/glm-5.3"
      ];
    };
  };
  validResponseFile = json.generate "aperture-agent-config-valid.json" {
    apertureUrl = "http://ai.corp.ts.net";
    mcpEndpoint = validMcp;
    models = [ ];
    configs = {
      opencode = builtins.toJSON validOpencode;
      hermes = builtins.toJSON validHermes;
    };
  };
  malformedResponseFile = json.generate "aperture-agent-config-malformed.json" {
    mcpEndpoint = validMcp;
    configs = {
      opencode = "{";
      hermes = "{}";
    };
  };
  mismatchedMcpResponseFile = json.generate "aperture-agent-config-mismatched-mcp.json" {
    mcpEndpoint = validMcp;
    configs = {
      opencode = builtins.toJSON (validOpencode // { mcp.aperture.url = "http://wrong.invalid/mcp"; });
      hermes = builtins.toJSON (
        validHermes // { mcp_servers.aperture.url = "http://wrong.invalid/mcp"; }
      );
    };
  };

  package = pkgs.writeShellApplication {
    name = "aperture-agent-config-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      yq-go
    ];
    text = ''
      api_url="''${APERTURE_AGENT_CONFIG_URL:-http://ai.corp.ts.net/api/agent-config}"
      opencode_target="''${APERTURE_OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
      hermes_target="''${APERTURE_HERMES_CONFIG:-$HOME/.hermes/config.yaml}"
      stage="$(mktemp -d)"
      opencode_next=""
      opencode_backup=""
      hermes_next=""
      hermes_backup=""
      opencode_had_target=false
      hermes_had_target=false
      transaction_started=false
      transaction_complete=false

      rollback_transaction() {
        if test "$transaction_started" != true || test "$transaction_complete" = true; then
          return
        fi
        if test "$opencode_had_target" = true; then
          mv -f -- "$opencode_backup" "$opencode_target"
          opencode_backup=""
        else
          rm -f -- "$opencode_target"
        fi
        if test "$hermes_had_target" = true; then
          mv -f -- "$hermes_backup" "$hermes_target"
          hermes_backup=""
        else
          rm -f -- "$hermes_target"
        fi
        transaction_started=false
      }

      cleanup() {
        rollback_transaction
        rm -rf -- "$stage"
        test -z "$opencode_next" || rm -f -- "$opencode_next"
        test -z "$opencode_backup" || rm -f -- "$opencode_backup"
        test -z "$hermes_next" || rm -f -- "$hermes_next"
        test -z "$hermes_backup" || rm -f -- "$hermes_backup"
      }
      trap cleanup EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM

      live_pair_valid() {
        test -f "$opencode_target" &&
          test -f "$hermes_target" &&
          opencode_mcp="$(jq -er '.mcp.aperture.url | select(type == "string" and length > 0)' "$opencode_target")" &&
          jq -e '
            (.provider.ollama | type == "object") and
            (.agent.frontier.model == "aperture-openai/openai/gpt-5.6-sol") and
          (.agent["claude-opus"].model == "aperture-anthropic/anthropic/claude-opus-5") and
          (.agent.deepseek.model == "aperture-openai-compatible/deepseek/deepseek-v4-pro") and
          (.agent.gemini.model == "aperture-openai-compatible/google/gemini-3.7-flash") and
          (.agent.kimi.model == "aperture-openai-compatible/moonshotai/kimi-k3") and
          (.agent.glm.model == "aperture-openai-compatible/zai/glm-5.3")
          ' "$opencode_target" >/dev/null 2>&1 &&
          yq -o=json '.' "$hermes_target" 2>/dev/null |
            jq -e --arg mcp "$opencode_mcp" '
            (.mcp_servers.aperture.url == $mcp) and
            (._config_version == 39) and
            (.plugins.enabled | index("herdr-agent-state") != null) and
            (.skills.external_dirs | index("~/.agents/skills") != null) and
            (.model == { default: "frontier", provider: "moa" }) and
              (.moa.active_preset == "frontier") and
              (.moa.presets.frontier.aggregator.model == "openai/gpt-5.6-sol") and
              (.moa.presets.frontier.reference_models | map(.model)) == [
                "anthropic/claude-opus-5",
                "deepseek/deepseek-v4-pro",
                "google/gemini-3.7-flash",
                "moonshotai/kimi-k3",
                "zai/glm-5.3"
              ]
            ' >/dev/null 2>&1
      }

      build_candidates() {
        curl --fail --silent --show-error --location "$api_url" --output "$stage/response.json" || return 1
        jq -e '
          (.configs | type == "object") and
          (.configs.opencode | type == "string" and length > 0) and
          (.configs.hermes | type == "string" and length > 0) and
          (.mcpEndpoint | type == "string" and length > 0)
        ' "$stage/response.json" >/dev/null || return 1

        mcp_endpoint="$(jq -er '.mcpEndpoint' "$stage/response.json")" || return 1
        jq -e -r '.configs.opencode | fromjson' "$stage/response.json" >"$stage/opencode.generated.json" || return 1
        jq -e -r '.configs.hermes' "$stage/response.json" >"$stage/hermes.generated.yaml" || return 1
        yq -o=json '.' "$stage/hermes.generated.yaml" >"$stage/hermes.generated.json" || return 1

        jq -e --arg mcp "$mcp_endpoint" '
          (.enabled_providers | type == "array") and
          (.mcp.aperture.url == $mcp) and
          (.provider["aperture-openai"].models | has("openai/gpt-5.6-sol")) and
          (.provider["aperture-anthropic"].models | has("anthropic/claude-opus-5")) and
          (.provider["aperture-openai-compatible"].models | has("deepseek/deepseek-v4-pro")) and
          (.provider["aperture-openai-compatible"].models | has("google/gemini-3.7-flash")) and
          (.provider["aperture-openai-compatible"].models | has("moonshotai/kimi-k3")) and
          (.provider["aperture-openai-compatible"].models | has("zai/glm-5.3"))
        ' "$stage/opencode.generated.json" >/dev/null || return 1

        jq -e --arg mcp "$mcp_endpoint" '
          (.mcp_servers.aperture.url == $mcp) and
          (.providers["aperture-responses"].models | index("openai/gpt-5.6-sol") != null) and
          (.providers["aperture-claude"].models | index("anthropic/claude-opus-5") != null) and
          (.providers["aperture-completions"].models | index("deepseek/deepseek-v4-pro") != null) and
          (.providers["aperture-completions"].models | index("google/gemini-3.7-flash") != null) and
          (.providers["aperture-completions"].models | index("moonshotai/kimi-k3") != null) and
          (.providers["aperture-completions"].models | index("zai/glm-5.3") != null)
        ' "$stage/hermes.generated.json" >/dev/null || return 1

        jq -S -s '
          .[0] as $generated |
          ($generated * .[1]) |
          .enabled_providers = (($generated.enabled_providers + ["ollama"]) | unique)
        ' "$stage/opencode.generated.json" ${opencodeOverlayFile} >"$stage/opencode.json" || return 1
        jq -S -s '.[0] * .[1]' "$stage/hermes.generated.json" ${hermesOverlayFile} >"$stage/hermes.json" || return 1

        jq -e --arg mcp "$mcp_endpoint" '
          (.mcp.aperture.type == "remote") and
          (.mcp.aperture.url == $mcp) and
          (.mcp.aperture.enabled == true) and
          (.provider.ollama | type == "object") and
          (.enabled_providers | index("ollama") != null) and
          (.default_agent == "frontier") and
          (.agent | keys | (index("frontier") != null and index("claude-opus") != null and
            index("deepseek") != null and index("gemini") != null and
            index("kimi") != null and index("glm") != null))
        ' "$stage/opencode.json" >/dev/null || return 1
        jq -e --arg mcp "$mcp_endpoint" '
        (.mcp_servers.aperture.url == $mcp) and
        (._config_version == 39) and
        (.plugins.enabled | index("herdr-agent-state") != null) and
        (.skills.external_dirs | index("~/.agents/skills") != null) and
        (.model == { default: "frontier", provider: "moa" }) and
          (.moa.active_preset == "frontier") and
          (.moa.default_preset == "frontier") and
          (.moa.presets.frontier.reference_models | length == 5) and
          (.moa.presets.frontier.aggregator == {
            provider: "custom:aperture-responses",
            model: "openai/gpt-5.6-sol",
            reasoning_effort: "high"
          })
        ' "$stage/hermes.json" >/dev/null || return 1
        yq -o=yaml -P '.' "$stage/hermes.json" >"$stage/config.yaml" || return 1
        yq -e '.' "$stage/config.yaml" >/dev/null || return 1
      }

      install_candidates() {
        opencode_dir="$(dirname "$opencode_target")"
        hermes_dir="$(dirname "$hermes_target")"
        mkdir -p -- "$opencode_dir" "$hermes_dir" || return 1

        opencode_next="$(mktemp "$opencode_dir/.opencode.json.XXXXXX")" || return 1
        hermes_next="$(mktemp "$hermes_dir/.config.yaml.XXXXXX")" || return 1
        install -m0600 "$stage/opencode.json" "$opencode_next" || return 1
        install -m0600 "$stage/config.yaml" "$hermes_next" || return 1

        if test -e "$opencode_target"; then
          opencode_had_target=true
          opencode_backup="$(mktemp "$opencode_dir/.opencode.json.backup.XXXXXX")" || return 1
          cp --preserve=mode -- "$opencode_target" "$opencode_backup" || return 1
        fi
        if test -e "$hermes_target"; then
          hermes_had_target=true
          hermes_backup="$(mktemp "$hermes_dir/.config.yaml.backup.XXXXXX")" || return 1
          cp --preserve=mode -- "$hermes_target" "$hermes_backup" || return 1
        fi
        transaction_started=true

        if ! mv -f -- "$opencode_next" "$opencode_target"; then
          rollback_transaction
          return 1
        fi
        opencode_next=""
        if ! mv -f -- "$hermes_next" "$hermes_target"; then
          rollback_transaction
          return 1
        fi
        hermes_next=""
        transaction_complete=true
        test -z "$opencode_backup" || rm -f -- "$opencode_backup" || true
        opencode_backup=""
        test -z "$hermes_backup" || rm -f -- "$hermes_backup" || true
        hermes_backup=""
        return 0
      }

      if build_candidates && install_candidates; then
        echo "Updated OpenCode and Hermes from $api_url"
      elif live_pair_valid; then
        echo "warning: Aperture config refresh failed; keeping the last-known-good OpenCode and Hermes configs" >&2
      else
        echo "error: Aperture config refresh failed and no valid managed config pair exists" >&2
        exit 1
      fi
    '';
  };

  test =
    pkgs.runCommand "aperture-agent-config-sync-test"
      {
        nativeBuildInputs = [
          package
          pkgs.coreutils
          pkgs.jq
          pkgs.yq-go
        ];
      }
      ''
          export HOME="$TMPDIR/home"
          export APERTURE_OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
          export APERTURE_HERMES_CONFIG="$HOME/.hermes/config.yaml"

          APERTURE_AGENT_CONFIG_URL=file://${validResponseFile} aperture-agent-config-sync
          test "$(stat -c %a "$APERTURE_OPENCODE_CONFIG")" = 600
          test "$(stat -c %a "$APERTURE_HERMES_CONFIG")" = 600
          jq -e '
            .default_agent == "frontier" and
            .mcp.aperture == {
              enabled: true,
              type: "remote",
              url: "${validMcp}"
            } and
            (.provider | has("ollama")) and
            (.agent | keys) == ["claude-opus", "deepseek", "frontier", "gemini", "glm", "kimi"]
          ' "$APERTURE_OPENCODE_CONFIG" >/dev/null
          yq -o=json '.' "$APERTURE_HERMES_CONFIG" | jq -e '
        ._config_version == 39 and
        (.plugins.enabled | index("herdr-agent-state") != null) and
        (.skills.external_dirs | index("~/.agents/skills") != null) and
        .model == { default: "frontier", provider: "moa" } and
            .mcp_servers.aperture.url == "${validMcp}" and
            .moa.active_preset == "frontier" and
            (.moa.presets.frontier.reference_models | map(.model)) == [
              "anthropic/claude-opus-5",
              "deepseek/deepseek-v4-pro",
              "google/gemini-3.7-flash",
              "moonshotai/kimi-k3",
              "zai/glm-5.3"
            ]
          ' >/dev/null

          before="$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"
          APERTURE_AGENT_CONFIG_URL=file://${malformedResponseFile} aperture-agent-config-sync
          test "$before" = "$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"
          APERTURE_AGENT_CONFIG_URL=file://${mismatchedMcpResponseFile} aperture-agent-config-sync
          test "$before" = "$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"

          export APERTURE_OPENCODE_CONFIG="$TMPDIR/fresh/opencode.json"
          export APERTURE_HERMES_CONFIG="$TMPDIR/fresh/config.yaml"
          if APERTURE_AGENT_CONFIG_URL=file://${malformedResponseFile} aperture-agent-config-sync; then
            echo "malformed first refresh unexpectedly succeeded" >&2
            exit 1
          fi
          test ! -e "$APERTURE_OPENCODE_CONFIG"
          test ! -e "$APERTURE_HERMES_CONFIG"
          touch "$out"
      '';
in
package.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    tests = test;
  };
})
