{ pkgs }:
let
  home = "/tmp/mcp-servers-test";
  # Exercise Desktop registration on the Linux CI builder too.
  registration =
    isDarwin:
    import ../../home/mcp.nix {
      pkgs = pkgs // {
        stdenv.hostPlatform = { inherit isDarwin; };
      };
      lib = pkgs.lib // {
        hm.dag.entryAfter = _: data: { inherit data; };
      };
      config = {
        home.homeDirectory = home;
        my.packages.ai.codex = false;
      };
    };
in
pkgs.runCommand "mcp-server-registration-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  mkdir -p ${home}/.config/opencode "${home}/Library/Application Support/Claude"
  echo '{"mcpServers":{"existing":{"command":"keep"}},"other":42}' >${home}/.claude.json
  echo '{"mcp":{"existing":{"command":"keep"}},"other":42}' >${home}/.config/opencode/opencode.json
  run() { "$@"; }
  ${(registration false).home.activation.mcpServers.data}
  ${(registration true).home.activation.mcpServers.data}
  ${(registration true).home.activation.mcpServers.data}

  jq -e '.other == 42 and .mcpServers.existing.command == "keep"' ${home}/.claude.json
  jq -e '.other == 42 and .mcp.existing.command == "keep"' ${home}/.config/opencode/opencode.json
  for server in grafana picnic; do
    for file in ${home}/.claude.json ${home}/.config/opencode/opencode.json; do
      jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
        '(.mcpServers // .mcp)[$server].url == $url' "$file"
    done
    jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
      '.mcpServers[$server].args | index($url) != null' \
      "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  done
  touch $out
''
