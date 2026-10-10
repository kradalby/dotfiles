{ pkgs, self }:
let
  ai = import ../../home/ai.nix;
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
      }
    ];
  };
  migrate = pkgs.writeShellScript "migrate-claude-path" ''
    set -euo pipefail
    run() { "$@"; }
    ${fixture.config.home.activation.claudePath.data}
  '';
in
pkgs.runCommand "claude-path-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      gnused
      jq
    ];
  }
  ''
    mkdir -p "$TMPDIR/wrappers" "$TMPDIR/system"
    cat > "$TMPDIR/wrappers/sudo" <<'SH'
    #!${pkgs.bash}/bin/bash
    printf '%s\n' wrapper-selected
    SH
    chmod +x "$TMPDIR/wrappers/sudo"
    ln -s ${pkgs.sudo}/bin/sudo "$TMPDIR/system/sudo"
    declared=${pkgs.lib.escapeShellArg ai.claude.env.PATH}
    mapped="''${declared//\/run\/wrappers\/bin/$TMPDIR/wrappers}"
    mapped="''${mapped//\/run\/current-system\/sw\/bin/$TMPDIR/system}"
    selected=$(env -i PATH="$mapped" ${pkgs.bash}/bin/bash --noprofile --norc -c 'command -v sudo')
    test "$selected" = "$TMPDIR/wrappers/sudo"
    test "$(env -i PATH="$mapped" ${pkgs.bash}/bin/bash --noprofile --norc -c 'sudo -n -l')" = wrapper-selected

    if env -i PATH="$TMPDIR/system" ${pkgs.bash}/bin/bash --noprofile --norc -c 'sudo -n -l' >"$TMPDIR/control.log" 2>&1; then
      echo 'the non-setuid sudo control unexpectedly succeeded' >&2
      exit 1
    fi
    test ! -u ${pkgs.sudo}/bin/sudo
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.claude"
    sed "s|/fixture|$HOME|g" ${migrate} > "$TMPDIR/migrate"
    jq -n --arg path ${pkgs.lib.escapeShellArg (pkgs.lib.removePrefix "/run/wrappers/bin:" ai.claude.env.PATH)} \
      '{env:{PATH:$path,KEEP:"value"},permissions:{allow:["custom"]}}' > "$HOME/.claude/settings.json"
    before=$(jq -S 'del(.env.PATH)' "$HOME/.claude/settings.json")
    bash "$TMPDIR/migrate"
    jq -e --arg path ${pkgs.lib.escapeShellArg ai.claude.env.PATH} '.env.PATH == $path' "$HOME/.claude/settings.json"
    test "$before" = "$(jq -S 'del(.env.PATH)' "$HOME/.claude/settings.json")"
    jq '.env.PATH = "/custom/bin"' "$HOME/.claude/settings.json" > "$TMPDIR/custom.json"
    mv "$TMPDIR/custom.json" "$HOME/.claude/settings.json"
    before=$(sha256sum "$HOME/.claude/settings.json")
    bash "$TMPDIR/migrate"
    test "$before" = "$(sha256sum "$HOME/.claude/settings.json")"
    touch "$out"
  ''
