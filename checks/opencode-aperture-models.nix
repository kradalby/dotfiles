{ pkgs }:
let
  # A route-duplicated chat model plus one served only over Messages.
  catalog = (pkgs.formats.json { }).generate "aperture-models.json" {
    data = [
      {
        id = "zai/glm-5.3";
        supported_endpoints = [ "/v1/chat/completions" ];
        context_window_tokens = 1000000;
        max_output_tokens = 128000;
      }
      {
        id = "zai/glm-5.3";
        supported_endpoints = [ "/v1/chat/completions" ];
      }
      {
        id = "anthropic/messages-only";
        supported_endpoints = [ "/v1/messages" ];
      }
    ];
  };
in
pkgs.runCommand "opencode-aperture-models"
  {
    nativeBuildInputs = [
      pkgs.master.opencode
      pkgs.python3
      pkgs.jq
    ];
  }
  ''
    export HOME="$TMPDIR" XDG_CONFIG_HOME="$TMPDIR/.config" XDG_CACHE_HOME="$TMPDIR/.cache"
    export OPENCODE_DISABLE_MODELS_FETCH=true
    mkdir -p "$XDG_CONFIG_HOME/opencode/plugin" srv/v1
    cp ${../pkgs/scripts/opencode-aperture-models.js} "$XDG_CONFIG_HOME/opencode/plugin/"
    cp ${catalog} srv/v1/models
    python3 -m http.server -b 127.0.0.1 -d srv 8765 &
    until python3 -c 'import socket; socket.create_connection(("127.0.0.1", 8765))' 2>/dev/null; do sleep 0.1; done

    aperture() {
      APERTURE_URL=$1 opencode api --standalone model.list |
        jq -c '[.data[] | select(.providerID == "aperture-openai-compatible") | {id, limit}]'
    }
    aperture http://127.0.0.1:8765 >live
    test "$(cat live)" = '[{"id":"zai/glm-5.3","limit":{"context":1000000,"output":128000}}]'
    kill %1

    # Unreachable Aperture: the cached catalog still serves.
    aperture http://127.0.0.1:1 >cached
    cmp live cached
    touch "$out"
  ''
