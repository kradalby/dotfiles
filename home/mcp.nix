{
  config,
  pkgs,
  lib,
  ...
}:
let
  ai = import ./ai.nix { inherit config lib; };
  jq = lib.getExe pkgs.jq;
  home = config.home.homeDirectory;
  desktopConfig = "${home}/Library/Application Support/Claude/claude_desktop_config.json";

  # Claude Desktop's config file only launches stdio servers; mcp-remote
  # bridges to the http one. --allow-http because the VIP is plain http.
  desktopServer =
    server:
    if server.type == "stdio" then
      {
        inherit (server) command args;
      }
    else
      {
        command = "${pkgs.nodejs}/bin/npx";
        args = [
          "-y"
          "mcp-remote@0.14.3"
          server.url
          "--allow-http"
        ];
        # npx runs the package's `#!/usr/bin/env node` bin; Desktop's PATH has no node.
        env.PATH = "${pkgs.nodejs}/bin:/usr/bin:/bin";
      };

  # Sets one key in a client-owned JSON file. Clients rewrite these files, so
  # they cannot be home.file symlinks, and mutableJson only seeds a missing
  # file, so an existing one would never get the server. Missing files are
  # skipped (the client creates them; the next switch fills them in).
  merge = file: path: value: ''
    f=${lib.escapeShellArg file}
    v=${lib.escapeShellArg (builtins.toJSON value)}
    if [ -f "$f" ] && ! ${jq} -e --argjson v "$v" '${path} == $v' "$f" >/dev/null; then
      tmp="$(mktemp "$f.XXXXXX")"
      if ${jq} --argjson v "$v" '${path} = $v' "$f" >"$tmp"; then
        run mv "$tmp" "$f"
      else
        rm -f "$tmp"
      fi
    fi
  '';
in
{
  home.activation.mcpServers = lib.hm.dag.entryAfter [ "writeBoundary" "mutableJson" ] (
    lib.concatStrings (
      lib.mapAttrsToList (
        name: server:
        merge "${home}/.claude.json" ".mcpServers.${name}" server
        + merge "${home}/.config/opencode/opencode.json" ".mcp.${name}" ai.opencode.mcp.${name}
        + lib.optionalString (config.my.mutableJson ? codex) ''
          if ! ${lib.getExe pkgs.master.codex} mcp get ${lib.escapeShellArg name} >/dev/null 2>&1; then
            run ${lib.getExe pkgs.master.codex} mcp add ${lib.escapeShellArg name} ${
              if server.type == "http" then
                "--url ${lib.escapeShellArg server.url}"
              else
                "-- ${lib.escapeShellArgs ([ server.command ] ++ server.args)}"
            }
          fi
        ''
      ) ai.claudeMcpServers
    )
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin (
      ''
        if [ -d ${lib.escapeShellArg (dirOf desktopConfig)} ] && [ ! -f ${lib.escapeShellArg desktopConfig} ]; then
          run install -m600 ${pkgs.writeText "empty.json" "{}"} ${lib.escapeShellArg desktopConfig}
        fi
      ''
      + lib.concatStrings (
        lib.mapAttrsToList (
          name: server: merge desktopConfig ".mcpServers.${name}" (desktopServer server)
        ) ai.claudeMcpServers
      )
    )
  );
}
