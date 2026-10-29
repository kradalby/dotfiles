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
  # A /v1/models page: chat-capable models plus one served only over Messages.
  validResponseFile = json.generate "aperture-models-valid.json" {
    object = "list";
    data =
      map
        (id: {
          inherit id;
          display_name = id;
          object = "model";
          supported_endpoints = [
            "/v1/messages"
            "/v1/responses"
            "/v1/chat/completions"
          ];
          context_window_tokens = 1000000;
          max_output_tokens = 128000;
        })
        [
          "anthropic/claude-opus-5"
          "openai/gpt-5.6-sol"
          "zai/glm-5.3"
        ]
      ++ [
        {
          id = "anthropic/messages-only";
          supported_endpoints = [ "/v1/messages" ];
        }
      ];
  };
  malformedResponseFile = pkgs.writeText "aperture-models-malformed.json" "{";

  # Turns /v1/models into the catalog half of one tool's config. Aperture serves
  # most models on every protocol; both tools get one Chat Completions provider.
  generate = pkgs.writeText "aperture-catalog.jq" ''
    def chat:
      .data
      | map(select((.id | type) == "string" and (.supported_endpoints | type) == "array"))
      | map(select(.supported_endpoints | index("/v1/chat/completions") != null))
      | unique_by(.id);
    def limit:
      if (.context_window_tokens | type) == "number" and (.max_output_tokens | type) == "number"
      then {limit: {context: .context_window_tokens, output: .max_output_tokens}}
      else {} end;

    if (.data | type) != "array" then error("no model list")
    elif $tool == "opencode" then {
      "$schema": "https://opencode.ai/config.json",
      enabled_providers: ["aperture-openai-compatible"],
      mcp: {aperture: {type: "remote", url: $mcp}},
      provider: {
        "aperture-openai-compatible": {
          name: "Aperture",
          npm: "@ai-sdk/openai-compatible",
          options: {apiKey: "not-required", baseURL: "\($base)/v1"},
          models: (chat
            | map({key: .id, value: ({name: (.display_name // .id), tool_call: true} + limit)})
            | from_entries)
        }
      }
    }
    else {
      mcp_servers: {aperture: {url: $mcp}},
      providers: {
        "aperture-completions": {
          api: "\($base)/v1",
          api_key: "no-key-required",
          transport: "chat_completions",
          models: (chat | map(.id))
        }
      }
    }
    end
  '';

  package = pkgs.writeShellApplication {
    name = "aperture-agent-config-sync";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
      yq-go
    ];
    text = ''
      aperture_url="''${APERTURE_URL:-http://ai.corp.ts.net}"
      # /v1/models is the per-user catalog; Aperture's /api/ is admin-only.
      api_url="''${APERTURE_MODELS_URL:-$aperture_url/v1/models}"
      mcp_endpoint="$aperture_url/v1/mcp"
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

      # A pair is usable when the local overlays are intact, both tools share
      # one MCP endpoint, and each tool's default model is served and enabled.
      configs_valid() {
        jq -e --slurpfile overlay ${opencodeOverlayFile} '
          (.model | capture("^(?<provider>[^/]+)/(?<id>.+)$")) as $default |
          ((. * $overlay[0]) == .) and
          (.mcp.aperture.url | type == "string" and length > 0) and
          (.enabled_providers | type == "array" and
            index($default.provider) != null) and
          ((.disabled_providers // []) | type == "array" and index($default.provider) == null) and
          (.provider[$default.provider].models[$default.id] | type == "object")
        ' "$1" >/dev/null || return 1
        mcp="$(jq -er '.mcp.aperture.url' "$1")" || return 1
        jq -e --slurpfile overlay ${hermesOverlayFile} --arg mcp "$mcp" '
          .providers[.model.provider | ltrimstr("custom:")] as $provider |
          ((. * $overlay[0]) == .) and
          (.mcp_servers.aperture.url == $mcp) and
          ($provider | type == "object") and
          (if $provider | has("enabled") then
            $provider.enabled | if type == "string" then
              ascii_downcase | gsub("^\\s+|\\s+$"; "") |
              . as $flag | ["false", "0", "no", "off"] | index($flag) == null
            else . != false and . != null and . != 0 and . != [] and . != {}
            end
          else true end) and
          ($provider.models | type == "array" and index($overlay[0].model.default) != null)
        ' "$2" >/dev/null
      }

      live_pair_valid() {
        test -f "$opencode_target" &&
          test -f "$hermes_target" &&
          yq -o=json '.' "$hermes_target" >"$stage/hermes.live.json" 2>/dev/null &&
          configs_valid "$opencode_target" "$stage/hermes.live.json" >/dev/null 2>&1
      }

      build_candidates() {
        # Reach the cached-config fallback even when Aperture stops responding.
        curl --fail --silent --show-error --location \
          --connect-timeout 5 --max-time 20 \
          "$api_url" --output "$stage/response.json" || return 1
        for tool in opencode hermes; do
          jq -e --arg tool "$tool" --arg base "$aperture_url" --arg mcp "$mcp_endpoint" \
            -f ${generate} "$stage/response.json" >"$stage/$tool.generated.json" || return 1
        done

        jq -S -s '.[0] * .[1]' "$stage/opencode.generated.json" ${opencodeOverlayFile} >"$stage/opencode.json" || return 1
        jq -S -s '.[0] * .[1]' "$stage/hermes.generated.json" ${hermesOverlayFile} >"$stage/hermes.json" || return 1
        configs_valid "$stage/opencode.json" "$stage/hermes.json" || return 1
        jq -e --arg mcp "$mcp_endpoint" '.mcp.aperture.url == $mcp' "$stage/opencode.json" >/dev/null || return 1
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
          pkgs.python3
          pkgs.ruff
          pkgs.pyright
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        export APERTURE_OPENCODE_CONFIG="$HOME/.config/opencode/opencode.json"
        export APERTURE_HERMES_CONFIG="$HOME/.hermes/config.yaml"

        APERTURE_MODELS_URL=file://${validResponseFile} aperture-agent-config-sync
        test "$(stat -c %a "$APERTURE_OPENCODE_CONFIG")" = 600
        test "$(stat -c %a "$APERTURE_HERMES_CONFIG")" = 600
        jq -e '
          .model == "aperture-openai-compatible/openai/gpt-5.6-sol" and
          (has("agent") or has("default_agent") | not) and
          .mcp.aperture == {
            enabled: true,
            type: "remote",
            url: "${validMcp}"
          } and
          (.provider | keys) == ["aperture-openai-compatible"] and
          .enabled_providers == ["aperture-openai-compatible"] and
          (.provider["aperture-openai-compatible"].models | keys) ==
            ["anthropic/claude-opus-5", "openai/gpt-5.6-sol", "zai/glm-5.3"] and
          .provider["aperture-openai-compatible"].models["zai/glm-5.3"].limit == {
            context: 1000000,
            output: 128000
          }
        ' "$APERTURE_OPENCODE_CONFIG" >/dev/null
        yq -o=json '.' "$APERTURE_HERMES_CONFIG" | jq -e '
          ._config_version == ${toString hermesOverlay._config_version} and
          (.plugins.enabled | index("herdr-agent-state") != null) and
          (.skills.external_dirs | index("~/.agents/skills") != null) and
          .model == { default: "openai/gpt-5.6-sol", provider: "custom:aperture-completions" } and
          (has("moa") | not) and
          .mcp_servers.aperture.url == "${validMcp}" and
          (.providers | keys) == ["aperture-completions"] and
          .providers["aperture-completions"].models ==
            ["anthropic/claude-opus-5", "openai/gpt-5.6-sol", "zai/glm-5.3"]
        ' >/dev/null

        before="$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"
        APERTURE_MODELS_URL=file://${malformedResponseFile} aperture-agent-config-sync
        test "$before" = "$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"

        export APERTURE_OPENCODE_CONFIG="$TMPDIR/fresh/opencode.json"
        export APERTURE_HERMES_CONFIG="$TMPDIR/fresh/config.yaml"
        if APERTURE_MODELS_URL=file://${malformedResponseFile} aperture-agent-config-sync; then
          echo "malformed first refresh unexpectedly succeeded" >&2
          exit 1
        fi
        test ! -e "$APERTURE_OPENCODE_CONFIG"
        test ! -e "$APERTURE_HERMES_CONFIG"
        bash ${../../checks/aperture-agent-config-sync/test.sh} ${validResponseFile} ${malformedResponseFile}
        ruff check --select ANN,UP,SIM,B,I --line-length 100 ${../../checks/aperture-agent-config-sync/timeout.py}
        ruff format --check --line-length 100 ${../../checks/aperture-agent-config-sync/timeout.py}
        echo '{"typeCheckingMode":"strict"}' > "$TMPDIR/pyrightconfig.json"
        pyright --pythonpath ${pkgs.python3}/bin/python3 --project "$TMPDIR/pyrightconfig.json" ${../../checks/aperture-agent-config-sync/timeout.py}
        python3 ${../../checks/aperture-agent-config-sync/timeout.py} ${package}/bin/aperture-agent-config-sync ${validResponseFile}
        touch "$out"
      '';
in
package.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    tests = test;
  };
})
