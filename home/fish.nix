{
  pkgs,
  lib,
  config,
  ...
}: let
  versions = import ../metadata/versions.nix;
in {
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
          rev = versions.fishPlugins.nixEnv;
          sha256 = "sha256-RG/0rfhgq6aEKNZ0XwIqOaZ6K5S4+/Y5EEMnIdtfPhk=";
        };
      }
      {
        name = "abbr-tips";
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-abbreviation-tips";
          # NOTE: manual update required
          rev = versions.fishPlugins.abbrTips;
          sha256 = "sha256-F1t81VliD+v6WEWqj1c1ehFBXzqLyumx5vV46s/FZRU=";
        };
      }
      {
        name = "done";
        src = pkgs.fetchFromGitHub {
          owner = "franciscolourenco";
          repo = "done";
          # NOTE: manual update required
          rev = versions.fishPlugins.done;
          sha256 = "sha256-WA6DBrPBuXRIloO05UBunTJ9N01d6tO1K1uqojjO0mo=";
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

      tsdev = ''
        set num $argv[1]
        set rest $argv[2..-1]
        set dir /tmp/"ts$num"
        mkdir -p $dir
        go run ./cmd/tailscale --socket=$dir/ts.sock $rest
      '';

      tsddev = ''
        set num $argv[1]
        set rest $argv[2..-1]
        set dir /tmp/"ts$num"
        mkdir -p $dir
        go run ./cmd/tailscaled --socket=$dir/ts.sock --statedir=$dir --state=$dir/ts.state --tun=userspace-networking --verbose 10 $rest
      '';

      z = ''
        if command -v zed-preview > /dev/null
            zed-preview $argv
        else if command -v zed > /dev/null
            zed $argv
        else
            echo "Zed editor is not installed. Please install zed or zed-preview."
        end
      '';

      ssh-rebind = ''
        # Find all SSH agent sockets from forwarded sessions
        set -l agent_sockets (${pkgs.findutils}/bin/find /tmp/ssh-* -type s -name "agent.*" 2>/dev/null)

        if test (count $agent_sockets) -eq 0
            echo "Error: No forwarded SSH agent found" >&2
            return 1
        end

        # Get the most recently modified socket
        set -l newest_socket (${pkgs.coreutils}/bin/ls -t $agent_sockets | head -n 1)

        # Test if the socket is functional
        if test -S "$newest_socket"
            set -gx SSH_AUTH_SOCK $newest_socket
        else
            echo "Error: Found socket but it's not valid: $newest_socket" >&2
            return 1
        end
      '';
    };
  };
}
