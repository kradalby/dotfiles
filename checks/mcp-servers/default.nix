{ pkgs }:
let
  home = "/tmp/mcp-servers-test";
  disabledAi = import ../../home/ai.nix {
    lib = pkgs.lib;
    config.my.packages.ai.enable = false;
    config.my.mcp.work = false;
  };
  workAi = import ../../home/ai.nix {
    lib = pkgs.lib;
    config.my.packages.ai.enable = false;
    config.my.mcp.work = true;
  };
  # Exercise Desktop registration on the Linux CI builder too.
  registration =
    isDarwin:
    import ../../home/mcp.nix {
      pkgs = pkgs // {
        stdenv.hostPlatform = {
          inherit isDarwin;
          isLinux = !isDarwin;
        };
      };
      lib = pkgs.lib // {
        hm.dag.entryAfter = _: data: { inherit data; };
      };
      config = {
        home.homeDirectory = home;
        home.profileDirectory = "${home}/.nix-profile";
        my.packages.ai.enable = true;
        my.packages.ai.codex = false;
        my.mcp.work = false;
        my.mutableJson = { };
        my.claudeMcpServers = { };
      };
    };
in
assert !(disabledAi.claudeMcpServers ? nixos);
assert !(disabledAi.opencode.mcp ? nixos);
assert !(disabledAi.codex.mcp_servers ? nixos);
assert workAi.claudeMcpServers == { };
assert workAi.opencode.mcp == { };
assert workAi.codex.mcp_servers == { };
pkgs.runCommand "mcp-server-registration-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  mkdir -p ${home}/.config/opencode "${home}/Library/Application Support/Claude"
  echo '{"mcpServers":{"existing":{"command":"keep"}},"other":42}' >${home}/.claude.json
  echo '{"mcp":{"existing":{"command":"keep"}},"other":42}' >${home}/.config/opencode/opencode.json
  run() { "$@"; }
  ${(registration false).config.home.activation.mcpServers.data}
  ${(registration true).config.home.activation.mcpServers.data}
  ${(registration true).config.home.activation.mcpServers.data}

  jq -e '.other == 42 and .mcpServers.existing.command == "keep"' ${home}/.claude.json
  jq -e '.other == 42 and .mcp.existing.command == "keep"' ${home}/.config/opencode/opencode.json
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcpServers.nixos.type == "stdio" and .mcpServers.nixos.command == $command' ${home}/.claude.json
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcp.nixos.type == "local" and .mcp.nixos.command == [$command]' ${home}/.config/opencode/opencode.json
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcpServers.nixos.command == $command and .mcpServers.nixos.args == []' \
    "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  for server in grafana picnic; do
    jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
      '.mcpServers[$server].url == $url' ${home}/.claude.json
    jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
      '.mcpServers[$server].args | index($url) != null' \
      "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  done
  jq -e '.mcp.grafana.url == "http://grafana-mcp.dalby.ts.net/mcp" and (.mcp | has("picnic") | not)' \
    ${home}/.config/opencode/opencode.json
  touch $out
''
