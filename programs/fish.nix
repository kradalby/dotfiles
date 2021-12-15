{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "fish-kubectl-completions";
        src = pkgs.fetchFromGitHub {
          owner = "evanlucas";
          repo = "fish-kubectl-completions";
          rev = "ced676392575d618d8b80b3895cdc3159be3f628";
          sha256 = "sha256-6oeyN9ngXWvps1c5QAUjlyPDQwRWAoxBiVTNmZ4sG8E=";
        };
      }
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

    shellInit = ''
      for p in /run/current-system/sw/bin
        if not contains $p $fish_user_paths
          set -g fish_user_paths $p $fish_user_paths
        end
      end

      if test -f $HOME/Sync/fish/tokens.fish
          source $HOME/Sync/fish/tokens.fish
      end
    '';

    shellAliases = {
      # cp = "cp -i";
      # mv = "mv -i";
      # rm = "rm -i";

      ag = "rg";
      cat = "bat";
      du = "du -hs";
      ipython = "ipython --no-banner";
      ls = "exa";
      mkdir = "mkdir -p";
      nvim = "nvim -p";
      ping = "prettyping";
      vim = "nvim -p";
      watch = "viddy --differences";

      # TODO: Add if for platform
      tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";

      osxphotos_missing_path = ''osxphotos query --json --only-photos | jq ".[] | select((.path == null)and .path_edited == null)"'';
      yaml2json = "python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' | jq";
    };

    # Abbreviate commonly used functions
    # An abbreviation will expand after <space> or <Enter> is hit
    shellAbbrs = {
      hm = "history merge";
      mp = "multipass";
      "..." = "cd ../..";

      ssh-rsakey = "ssh-keygen -t rsa -b 4096 -o -a 100";
      ssh-ed25519key = "ssh-keygen -t ed25519 -o -a 100";

      g = "git";
      ga = "git add";
      gap = "git add -p";
      gaa = "git add --update .";
      gco = "git checkout";
      gcob = "git checkout -b";
      gcom = "git checkout master";
      gd = "git diff";
      gb = "git branch";
      gbd = "git branch -d ";
      gp = "git pull";
      gss = "git status -s";
      gst = "git stash";
      gm = "git merge --no-ff";
      gr = "git rebase";
      grom = "git rebase origin/master";
      grc = "git rebase --continue";
      gra = "git rebase --abort";
      gfo = "git fetch origin";
      gfu = "git fetch upstream";
      gcum = "git checkout upstream/main";


      k = "kubectl";
      kg = "kubectl get";
      kga = "kubectl get pods -o wide --all-namespaces --sort-by=.spec.nodeName";
      kd = "kubectl describe";
      kdel = "kubectl delete";
      ke = "kubectl edit";
      kaf = "kubectl apply -f";
      kdelf = "kubectl delete -f";
      kubuntu = "kubectl run --generator=run-pod/v1 ubuntu-shell --rm -i --tty --image ubuntu -- bash";
      kbusy = "kubectl run --generator=run-pod/v1 busybox-shell --rm -i --tty --image busybox -- sh";

      kc = "kubectl config use-context";
      kgc = "kubectl config get-contexts";
      kcn = "kubectl config set-context --current --namespace";

      kl = "kubectl logs";
      klf = "kubectl logs -f";

      tf = "terraform";
      tfi = "terraform init";
      tfiu = "terraform init -upgrade";
      tfp = "terraform plan";
      tfa = "terraform apply";
      tfaaa = "terraform apply -auto-approve";
      tft = "terraform taint";

      lc = "logcli";
      lcq = "logcli query";
      lcl = "logcli labels";
      lcljob = "logcli labels job";
      lclapp = "logcli labels app";

      m = "make";
      n = "nvim";
      o = "open";
      p = "python3";
    };

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

      gi = ''curl -L -s https://www.gitignore.io/api/$argv'';

      push = ''git push origin -u (git rev-parse --abbrev-ref HEAD)'';
      yolo = ''git push -f origin (git rev-parse --abbrev-ref HEAD)'';

      rmkh = ''
        set -x sed sed
        if type -q gsed
            set -x sed gsed
        end
        $sed -i $argv'd' ~/.ssh/known_hosts
      '';
    };
  };
}
