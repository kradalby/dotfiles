{
  pkgs,
  self,
  inputs,
}:
let
  work = self.homeConfigurations."ubuntu@kradalby-llm".config;
  fixture = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../home/mcp.nix
      ../../home/mutable-json.nix
      ({ lib, ... }: {
        options.my.packages.ai.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        options.my.packages.ai.codex = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        options.my.cooklang.recipes = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      })
      {
        home.username = "fixture";
        home.homeDirectory = "/fixture";
        home.stateVersion = "26.05";
        my.claudeMcpServers = work.my.claudeMcpServers;
        my.mcp.work = work.my.mcp.work;
      }
    ];
  };
  merge = pkgs.writeShellScript "merge-claude-mcp" ''
    set -euo pipefail
    run() { "$@"; }
    ${fixture.config.home.activation.mcpServers.data}
  '';
  hermesMerge = pkgs.writeShellScript "merge-hermes-mcp" ''
    set -euo pipefail
    run() { "$@"; }
    ${work.home.activation.hermesMcp.data}
  '';
in
assert !(work.my.mutableJson.claude-settings.value ? mcpServers);
assert work.my.claudeMcpServers.aperture.url == "http://ai.corp.ts.net/v1/mcp";
assert
  work.my.mutableJson.pi-mcp.value.mcpServers.superlogical.url
  == "https://www.superlogical.com/rex/community-mcp";
pkgs.runCommand "claude-mcp-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      gnused
      findutils
      jq
      yq-go
    ];
  }
  ''
    unset BASH_ENV ENV
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    mkdir -p "$HOME/.hermes"
    echo '{"model":{"default":"keep"},"mcp_servers":{"aperture":{"url":"http://ai.corp.ts.net/v1/mcp"}}}' > "$HOME/.hermes/config.yaml"
    sed "s|${work.home.homeDirectory}|$HOME|g" ${hermesMerge} > "$TMPDIR/hermes-merge"
    bash "$TMPDIR/hermes-merge"
    yq -o=json '.' "$HOME/.hermes/config.yaml" | jq -e '.model.default == "keep" and .mcp_servers.aperture.url == "http://ai.corp.ts.net/v1/mcp" and .mcp_servers.superlogical == {url:"https://www.superlogical.com/rex/community-mcp",auth:"oauth"}'
    before=$(sha256sum "$HOME/.hermes/config.yaml")
    bash "$TMPDIR/hermes-merge"
    test "$before" = "$(sha256sum "$HOME/.hermes/config.yaml")"
    echo '[]' > "$HOME/.hermes/config.yaml"
    before=$(sha256sum "$HOME/.hermes/config.yaml")
    if bash "$TMPDIR/hermes-merge"; then
      echo 'invalid Hermes config unexpectedly accepted' >&2
      exit 1
    fi
    test "$before" = "$(sha256sum "$HOME/.hermes/config.yaml")"
    sed "s|/fixture|$HOME|g" ${merge} > "$TMPDIR/merge"
    bash "$TMPDIR/merge"
    test "$(stat -c %a "$HOME/.claude.json")" = 600
    jq -e '.mcpServers.aperture == {type:"http",url:"http://ai.corp.ts.net/v1/mcp"} and (.mcpServers | has("picnic") or has("grafana") | not)' "$HOME/.claude.json"

    cat > "$HOME/.claude.json" <<'JSON'
    {"oauthAccount":{"accountUuid":"fixture"},"projects":{"/project":{"hasTrustDialogAccepted":true}},"customState":[1,2],"mcpServers":{"other":{"type":"stdio","command":"custom"},"aperture":{"type":"http","url":"http://old.invalid"}}}
    JSON
    before=$(jq -S 'del(.mcpServers.aperture,.mcpServers.picnic,.mcpServers.grafana,.mcpServers.nixos,.mcpServers.superlogical)' "$HOME/.claude.json")
    bash "$TMPDIR/merge"
    test "$before" = "$(jq -S 'del(.mcpServers.aperture,.mcpServers.picnic,.mcpServers.grafana,.mcpServers.nixos,.mcpServers.superlogical)' "$HOME/.claude.json")"
    jq -e '.mcpServers.aperture.url == "http://ai.corp.ts.net/v1/mcp"' "$HOME/.claude.json"
    before="$(sha256sum "$HOME/.claude.json") $(stat -c %i:%a:%Y "$HOME/.claude.json")"
    bash "$TMPDIR/merge"
    test "$before" = "$(sha256sum "$HOME/.claude.json") $(stat -c %i:%a:%Y "$HOME/.claude.json")"

    for invalid in "" '{' '[]' '{"mcpServers":[]}'; do
      printf '%s\n' "$invalid" > "$HOME/.claude.json"
      before=$(sha256sum "$HOME/.claude.json")
      if bash "$TMPDIR/merge"; then
        echo 'invalid client state unexpectedly accepted' >&2
        exit 1
      fi
      test "$before" = "$(sha256sum "$HOME/.claude.json")"
      test "$(find "$HOME" -name '.claude.json.*' | wc -l)" = 0
    done
    touch "$out"
  ''
