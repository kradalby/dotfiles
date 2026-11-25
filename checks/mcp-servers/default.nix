{ pkgs }:
let
  home = "/tmp/mcp-servers-test";
  disabledAi = import ../../home/ai.nix {
    lib = pkgs.lib;
    config.my.packages.ai.enable = false;
    config.my.mcp.work = false;
    config.my.cooklang.recipes = null;
    config.my.mail.triage.enable = false;
  };
  workAi = import ../../home/ai.nix {
    lib = pkgs.lib;
    config.my.packages.ai.enable = false;
    config.my.mcp.work = true;
    config.my.cooklang.recipes = null;
    config.my.mail.triage.enable = false;
  };
  cookAi = import ../../home/ai.nix {
    lib = pkgs.lib;
    config.home.profileDirectory = "${home}/.nix-profile";
    config.my.packages.ai.enable = false;
    config.my.mcp.work = false;
    config.my.cooklang.recipes = "/recipes";
    config.my.mail.triage.enable = true;
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
        my.cooklang.recipes = "/recipes";
        my.mail.triage.enable = true;
        my.mutableJson.pi-mcp.value.mcpServers.superlogical = disabledAi.claudeMcpServers.superlogical;
        my.claudeMcpServers = { };
      };
    };
in
assert !(disabledAi.claudeMcpServers ? nixos);
assert !(disabledAi.opencode.mcp.servers ? nixos);
assert !(disabledAi.codex.mcp_servers ? nixos);
assert !(disabledAi.claudeMcpServers ? cook);
assert !(disabledAi.opencode.mcp.servers ? cook);
assert !(disabledAi.codex.mcp_servers ? cook);
assert !(disabledAi.opencode.mcp.servers ? mail);
assert cookAi.opencode.mcp.servers.mail.command == [ "${home}/.nix-profile/bin/apple-mailbox-mcp" ];
assert cookAi.claudeMcpServers.cook.command == "${home}/.nix-profile/bin/cook-mcp";
assert cookAi.opencode.mcp.servers.cook.command == [ "${home}/.nix-profile/bin/cook-mcp" ];
assert cookAi.codex.mcp_servers.cook.command == "${home}/.nix-profile/bin/cook-mcp";
assert
  workAi.claudeMcpServers == {
    superlogical = {
      type = "http";
      url = "https://www.superlogical.com/rex/community-mcp";
    };
  };
assert
  workAi.opencode.mcp.servers == {
    superlogical = {
      type = "remote";
      url = "https://www.superlogical.com/rex/community-mcp";
    };
  };
assert
  workAi.codex.mcp_servers == {
    superlogical.url = "https://www.superlogical.com/rex/community-mcp";
  };
assert disabledAi.codex.mcp_servers.superlogical == workAi.codex.mcp_servers.superlogical;
pkgs.runCommand "mcp-server-registration-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  mkdir -p ${home}/.config/opencode "${home}/Library/Application Support/Claude"
  mkdir -p ${home}/.pi/agent
  echo '{"mcpServers":{"existing":{"command":"keep"}},"other":42}' >${home}/.pi/agent/mcp.json
  echo '{"mcpServers":{"existing":{"command":"keep"}},"other":42}' >${home}/.claude.json
  echo '{"mcp":{"servers":{"existing":{"command":"keep"}}},"other":42}' >${home}/.config/opencode/opencode.json
  run() { "$@"; }
  ${(registration false).config.home.activation.mcpServers.data}
  ${(registration true).config.home.activation.mcpServers.data}
  ${(registration true).config.home.activation.mcpServers.data}

  jq -e '.other == 42 and .mcpServers.existing.command == "keep"' ${home}/.claude.json
  jq -e '.other == 42 and .mcp.servers.existing.command == "keep"' ${home}/.config/opencode/opencode.json
  jq -e '.mcpServers.superlogical == {type:"http",url:"https://www.superlogical.com/rex/community-mcp"}' ${home}/.claude.json
  jq -e '.mcp.servers.superlogical == {type:"remote",url:"https://www.superlogical.com/rex/community-mcp"}' ${home}/.config/opencode/opencode.json
  jq -e '.other == 42 and .mcpServers.existing.command == "keep" and .mcpServers.superlogical == {type:"http",url:"https://www.superlogical.com/rex/community-mcp"}' ${home}/.pi/agent/mcp.json
  jq -e '.mcpServers.superlogical.args | index("https://www.superlogical.com/rex/community-mcp") != null' \
    "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcpServers.nixos.type == "stdio" and .mcpServers.nixos.command == $command' ${home}/.claude.json
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcp.servers.nixos.type == "local" and .mcp.servers.nixos.command == [$command]' ${home}/.config/opencode/opencode.json
  jq -e --arg command "${home}/.nix-profile/bin/mcp-nixos" \
    '.mcpServers.nixos.command == $command and .mcpServers.nixos.args == []' \
    "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  jq -e --arg command "${home}/.nix-profile/bin/cook-mcp" \
    '.mcpServers.cook.type == "stdio" and .mcpServers.cook.command == $command' ${home}/.claude.json
  for server in grafana picnic; do
    jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
      '.mcpServers[$server].url == $url' ${home}/.claude.json
    jq -e --arg server "$server" --arg url "http://$server-mcp.dalby.ts.net/mcp" \
      '.mcpServers[$server].args | index($url) != null' \
      "${home}/Library/Application Support/Claude/claude_desktop_config.json"
  done
  jq -e '.mcp.servers.mail.type == "local" and .permissions == [{action:"mail_*",resource:"*",effect:"deny"}]' ${home}/.config/opencode/opencode.json
  jq -e '.mcp.servers.grafana.url == "http://grafana-mcp.dalby.ts.net/mcp" and (.mcp.servers | has("picnic") | not)' \
    ${home}/.config/opencode/opencode.json
  touch $out
''
