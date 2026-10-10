{ pkgs, self }:
let
  work = self.homeConfigurations."ubuntu@kradalby-llm".config;
  fixture = self.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../home/mcp.nix
      ({ lib, ... }: {
        options.my.packages.ai.codex = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      })
      {
        home.username = "fixture";
        home.homeDirectory = "/fixture";
        home.stateVersion = "26.05";
        my.claudeMcpServers = work.my.claudeMcpServers;
      }
    ];
  };
  merge = pkgs.writeShellScript "merge-claude-mcp" ''
    set -euo pipefail
    run() { "$@"; }
    ${fixture.config.home.activation.mcpServers.data}
  '';
in
assert !(work.my.mutableJson.claude-settings.value ? mcpServers);
assert work.my.claudeMcpServers.aperture.url == "http://ai.corp.ts.net/v1/mcp";
pkgs.runCommand "claude-mcp-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      gnused
      findutils
      jq
    ];
  }
  ''
    unset BASH_ENV ENV
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    sed "s|/fixture|$HOME|g" ${merge} > "$TMPDIR/merge"
    bash "$TMPDIR/merge"
    test "$(stat -c %a "$HOME/.claude.json")" = 600
    jq -e '.mcpServers.aperture == {type:"http",url:"http://ai.corp.ts.net/v1/mcp"} and (.mcpServers | has("picnic"))' "$HOME/.claude.json"

    cat > "$HOME/.claude.json" <<'JSON'
    {"oauthAccount":{"accountUuid":"fixture"},"projects":{"/project":{"hasTrustDialogAccepted":true}},"customState":[1,2],"mcpServers":{"other":{"type":"stdio","command":"custom"},"aperture":{"type":"http","url":"http://old.invalid"}}}
    JSON
    before=$(jq -S 'del(.mcpServers.aperture,.mcpServers.picnic,.mcpServers.grafana)' "$HOME/.claude.json")
    bash "$TMPDIR/merge"
    test "$before" = "$(jq -S 'del(.mcpServers.aperture,.mcpServers.picnic,.mcpServers.grafana)' "$HOME/.claude.json")"
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
