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
        watch = "${pkgs.viddy}/bin/viddy --shell ${pkgs.fish}/bin/fish --differences";

        # TODO: Add if for platform
        tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";

        osxphotos_missing_path = builtins.concatStringsSep " | " [
          ''osxphotos query --json --only-photos''
          ''${pkgs.jq}/bin/jq ".[] | select((.path == null)and .path_edited == null)"''
        ];
        yaml2json = builtins.concatStringsSep " | " [
          "${pyyaml}/bin/python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)'"
          "${pkgs.jq}/bin/jq"
        ];

        agenix = "${pkgs.nix}/bin/nix run github:ryantm/agenix -- --rekey";
      };

    # Abbreviate commonly used functions
    # An abbreviation will expand after <space> or <Enter> is hit
    shellAbbrs = config.my.shellAliases // { };

    # TODO: Figure out what this is renamed to
    functions =
      let
        oofTime = pkgs.writers.writePython3 "test_python3"
          {
            libraries = [ ];
          } ''
          import datetime
          import math

          start = 7
          end = 17

          target_start = 18
          target_end = 23


          def time_in_range(
                  start: datetime.time,
                  end: datetime.time,
                  time: datetime.time) -> bool:
              """Return true if time is in the range [start, end]"""
              if start <= end:
                  return start <= time <= end
              else:
                  return start <= time or time <= end


          def new_time(now: datetime.datetime) -> datetime.datetime:

              new_value = ((now.hour - start) / (end - start)) * \
                  (target_end - target_start) + target_start

              new_date = now - datetime.timedelta(days=1)

              return new_date.replace(hour=math.ceil(new_value))


          if __name__ == "__main__":
              now = datetime.datetime.now()

              start_time = datetime.time(start, 0, 0)
              end_time = datetime.time(end, 0, 0)

              if time_in_range(start_time, end_time, now.time()):
                  print(new_time(now).strftime("%Y-%m-%dT%H:%M:%S"), end="")
              else:
                  print(now.strftime("%Y-%m-%dT%H:%M:%S"), end="")
        '';
      in
      {
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
              ${pkgs.git}/bin/git commit -S
          else
              ${pkgs.git}/bin/git commit
          end
        '';

        gcm = ''
          if string length -q -- $GPG_FINGERPRINT
              ${pkgs.git}/bin/git commit -S -m "$argv"
          else
              ${pkgs.git}/bin/git commit -m "$argv"
          end
        '';

        dtgc = ''
          env GIT_AUTHOR_DATE=(${oofTime}) GIT_COMMITTER_DATE=(${oofTime}) ${pkgs.git}/bin/git commit $argv
        '';

        gi = ''${pkgs.curl}/bin/curl -L -s https://www.gitignore.io/api/$argv'';

        push = ''${pkgs.git}/bin/git push origin -u (${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)'';
        yolo = ''${pkgs.git}/bin/git push -f origin (${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)'';

        rmkh = ''
          ${pkgs.gnused}/bin/sed -i $argv'd' ~/.ssh/known_hosts
        '';

        k3s-fetch-merge-config = ''
          set host $argv[1]
          set target $argv[2]

          echo "Updating target $target with config from $host"

          set rconfig (ssh $host "cat /etc/rancher/k3s/k3s.yaml | yq -c")

          set cert_auth_data (echo $rconfig | ${pkgs.jq}/bin/jq -r '.clusters[0].cluster."certificate-authority-data"')
          set client_cert_data (echo $rconfig | ${pkgs.jq}/bin/jq -r '.users[0].user."client-certificate-data"')
          set client_key_data (echo $rconfig | ${pkgs.jq}/bin/jq -r '.users[0].user."client-key-data"')

          set lconfig (cat $HOME/.kube/config | ${pkgs.yq}/bin/yq -c)

          echo "Moving $HOME/.kube/config to $HOME/.kube/config.bak"
          mv $HOME/.kube/config $HOME/.kube/config.bak

          echo "Writing new config to $HOME/.kube/config"
          echo $lconfig \
            | ${pkgs.jq}/bin/jq "(.clusters[] | select(.name == \"$target\")).cluster.\"certificate-authority-data\" |= \"$cert_auth_data\"" \
            | ${pkgs.jq}/bin/jq "(.users[] | select(.name == \"$target-admin\")).user.\"client-certificate-data\" |= \"$client_cert_data\"" \
            | ${pkgs.jq}/bin/jq "(.users[] | select(.name == \"$target-admin\")).user.\"client-key-data\" |= \"$client_key_data\"" \
            | ${pkgs.yq}/bin/yq --yaml-output \
            > $HOME/.kube/config
        '';

        agenix-update-key = ''
          set host $argv[1]
          set hostDash (echo $host | ${pkgs.gnused}/bin/sed 's/\./-/g')

          set sshKey (ssh-keyscan -t ed25519 $host.fap.no | ${pkgs.gnused}/bin/sed 's/.*ssh/ssh/')

          echo "New key: $sshKey"

          set sedString "/$hostDash = \"ssh-ed25519/c\ $hostDash = \"$sshKey\";"

          ${pkgs.gnused}/bin/sed -i $sedString secrets.nix

          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt secrets.nix
          nix run github:ryantm/agenix -- --rekey
        '';
      };
  };
}
