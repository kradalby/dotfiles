{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [../common/var.nix];

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
          # NOTE: manual update required
          rev = "7b65bd228429e852c8fdfa07601159130a818cfa";
          sha256 = "sha256-RG/0rfhgq6aEKNZ0XwIqOaZ6K5S4+/Y5EEMnIdtfPhk=";
        };
      }
      {
        name = "abbr-tips";
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-abbreviation-tips";
          # NOTE: manual update required
          rev = "8ed76a62bb044ba4ad8e3e6832640178880df485";
          sha256 = "sha256-F1t81VliD+v6WEWqj1c1ehFBXzqLyumx5vV46s/FZRU=";
        };
      }
      {
        name = "done";
        src = pkgs.fetchFromGitHub {
          owner = "franciscolourenco";
          repo = "done";
          # NOTE: manual update required
          rev = "d47f4d6551cccb0e46edfb14213ca0097ee22f9a";
          sha256 = "sha256-VSCYsGjNPSFIZSdLrkc7TU7qyPVm8UupOoav5UqXPMk=";
        };
      }
    ];

    loginShellInit = let
      fishReorderPath = path: "fish_add_path --move --prepend ${path}";

      path =
        [
          (fishReorderPath "/opt/homebrew/sbin")
          (fishReorderPath "/nix/var/nix/profiles/default/bin")
          (fishReorderPath "/etc/profiles/per-user/$USER/bin")
          (fishReorderPath "/run/current-system/sw/bin")
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          # Where sudo lives, needed for linux.
          (fishReorderPath "/run/wrappers/bin")
        ];
    in ''
      ${builtins.concatStringsSep "\n" path}
    '';

    shellInit = ''
      if test -f $HOME/Sync/fish/tokens.fish
          source $HOME/Sync/fish/tokens.fish
      end
    '';

    shellAliases = let
      pyyaml =
        pkgs.python3.withPackages
        (p:
          with p; [
            pyyaml
          ]);
    in {
      s = ''${pkgs.findutils}/bin/xargs ${pkgs.perl}/bin/perl -pi -E'';
      ag = "${pkgs.ripgrep}/bin/rg";
      cat = "${pkgs.bat}/bin/bat";
      du = "du -hs";
      ipython = "ipython --no-banner";
      ls = "${pkgs.eza}/bin/eza";
      mkdir = "mkdir -p";
      nvim = "nvim -p";
      ping = "${pkgs.prettyping}/bin/prettyping";
      vim = "nvim -p";
      watch = "${pkgs.viddy}/bin/viddy --shell ${pkgs.fish}/bin/fish --differences";

      osxphotos_missing_path = builtins.concatStringsSep " | " [
        ''osxphotos query --json --only-photos''
        ''${pkgs.jq}/bin/jq ".[] | select((.path == null)and .path_edited == null)"''
      ];
      yaml2json = builtins.concatStringsSep " | " [
        "${pyyaml}/bin/python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)'"
        "${pkgs.jq}/bin/jq"
      ];

      tailscale =
        if pkgs.stdenv.isDarwin
        then "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        else "tailscale";
      ts = "tailscale";
      tss = "tailscale status";
      tsp = "tailscale ping";
    };

    # Abbreviate commonly used functions
    # An abbreviation will expand after <space> or <Enter> is hit
    shellAbbrs = config.my.shellAliases // {};

    # TODO: Figure out what this is renamed to
    functions = {
      mkcd = "mkdir -p $argv[1]; and cd $argv[1]";

      gi = ''${pkgs.curl}/bin/curl -L -s https://www.gitignore.io/api/$argv'';

      push = ''${pkgs.git}/bin/git push origin -u (${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)'';
      yolo = ''${pkgs.git}/bin/git push -f origin (${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)'';

      rmkh = ''
        ${pkgs.gnused}/bin/sed -i $argv'd' ~/.ssh/known_hosts
      '';

      ragenix-update-key = ''
        set host $argv[1]
        set hostDash (echo $host | ${pkgs.gnused}/bin/sed 's/\./-/g')

        set sshKey (ssh-keyscan -t ed25519 $host.fap.no | ${pkgs.gnused}/bin/sed 's/.*ssh/ssh/')

        echo "New key: $sshKey"

        set sedString "/$hostDash = \"ssh-ed25519/c\ $hostDash = \"$sshKey\";"

        ${pkgs.gnused}/bin/sed -i $sedString secrets.nix

        ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt secrets.nix
        ${pkgs.ragenix}/bin/ragenix --rekey
      '';

      flakepush = ''
        nix flake update
        git add flake.lock
        git commit -m "nix: flake update"
        git push
      '';

      docker-clean = ''
        docker images | ag none | awk '{print $3}' | xargs docker rmi
        docker rm -f (docker ps -a -q)
        docker network prune -f
      '';

      docker-reset = ''
        docker system prune -af
        colima stop
        colima start --vm-type vz --cpu 6 --memory 12 --disk 100
      '';
    };
  };
}
