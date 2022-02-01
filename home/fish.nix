{ pkgs, config, ... }:
{

  imports = [ ../common/var.nix ];

  programs.fish = {
    enable = true;
    plugins = [
      # Need this when using Fish as a default macOS shell in order to pick
      # up ~/.nix-profile/bin
      {
        name = "nix-env";
        src = pkgs.fetchFromGitHub {
          owner = "lilyball";
          repo = "nix-env.fish";
          rev = "7b65bd228429e852c8fdfa07601159130a818cfa";
          sha256 = "sha256-RG/0rfhgq6aEKNZ0XwIqOaZ6K5S4+/Y5EEMnIdtfPhk=";
        };
      }
      {
        name = "abbr-tips";
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-abbreviation-tips";
          rev = "75f7f66ca092d53197c1a97c7d8e93b1402fdc15";
          sha256 = "sha256-uo8pAIwq7FRQNWHh+cvXAR9Imd2PvNmlrqEiDQHWvEY=";
        };
      }
      {
        name = "done";
        src = pkgs.fetchFromGitHub {
          owner = "franciscolourenco";
          repo = "done";
          rev = "d6abb267bb3fb7e987a9352bc43dcdb67bac9f06";
          sha256 = "sha256-6oeyN9ngXWvps1c5QAUjlyPDQwRWAoxBiVTNmZ4sG8E=";
        };
      }
    ];


    # for p in /run/current-system/sw/bin
    #   if not contains $p $fish_user_paths
    #     set -g fish_user_paths $p $fish_user_paths
    #   end
    # end

    loginShellInit =
      let
        fishReorderPath = path:
          "fish_add_path --move --prepend ${path}";

        path = [
          (fishReorderPath "/nix/var/nix/profiles/default/bin")
          (fishReorderPath "/etc/profiles/per-user/$USER/bin")
          (fishReorderPath "/run/current-system/sw/bin")
        ];
      in
      ''
        ${builtins.concatStringsSep "\n" path}
      '';

    shellInit = ''
      # if type -q ${pkgs.babelfish}
      # cat /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh | ${pkgs.babelfish}/bin/babelfish | tail -n +5 | source
      # end

      if test -f $HOME/Sync/fish/tokens.fish
          source $HOME/Sync/fish/tokens.fish
      end
    '';

    shellAliases =
      let
        pyyaml = pkgs.python3.withPackages
          (p: with p; [
            pyyaml
          ]);
      in
      {
        # cp = "cp -i";
        # mv = "mv -i";
        # rm = "rm -i";

        s = ''${pkgs.findutils}/bin/xargs ${pkgs.perl}/bin/perl -pi -E'';
        ag = "${pkgs.ripgrep}/bin/rg";
        cat = "${pkgs.bat}/bin/bat";
        du = "du -hs";
        ipython = "ipython --no-banner";
        ls = "${pkgs.exa}/bin/exa";
        mkdir = "mkdir -p";
        nvim = "nvim -p";
        ping = "${pkgs.prettyping}/bin/prettyping";
        vim = "nvim -p";
        watch = "${pkgs.viddy}/bin/viddy --differences";

        # TODO: Add if for platform
        tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";

        osxphotos_missing_path = ''osxphotos query --json --only-photos | ${pkgs.jq}/bin/jq ".[] | select((.path == null)and .path_edited == null)"'';
        yaml2json = "${pyyaml}/bin/python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' | ${pkgs.jq}/bin/jq";
      };

    # Abbreviate commonly used functions
    # An abbreviation will expand after <space> or <Enter> is hit
    shellAbbrs = config.my.shellAliases // { };

    # TODO: Figure out what this is renamed to
    functions = {
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      lcqjob = ''
        set query (printf '{job=~"%s.*"}' $argv[1])
        lcq $query $argv[2..-1]
      '';

      lcqapp = ''
        set query (printf '{app=~"%s.*"}' $argv[1])
        lcq $query $argv[2..-1]
      '';

      gc = ''
        if string length -q -- $GPG_FINGERPRINT
            git commit -S
        else
            git commit
        end
      '';
      gcm = ''
        if string length -q -- $GPG_FINGERPRINT
            git commit -S -m "$argv"
        else
            git commit -m "$argv"
        end
      '';

      gi = ''${pkgs.curl}/bin/curl -L -s https://www.gitignore.io/api/$argv'';

      push = ''${pkgs.git}/bin/git push origin -u (git rev-parse --abbrev-ref HEAD)'';
      yolo = ''${pkgs.git}/bin/git push -f origin (git rev-parse --abbrev-ref HEAD)'';

      rmkh = ''
        ${pkgs.gnused}/bin/sed -i $argv'd' ~/.ssh/known_hosts
      '';
    };
  };
}
