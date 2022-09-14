{ config, lib, ... }: {
  options = {
    my.shellAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        hm = "history merge";
        mp = "multipass";
        "..." = "cd ../..";

        nix-kramacbook = "darwin-rebuild switch --flake ~/.nixpkgs/.#kramacbook";

        ssh-rsakey = "ssh-keygen -t rsa -b 4096 -o -a 100";
        ssh-ed25519key = "ssh-keygen -t ed25519 -o -a 100";

        # Git
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
        gstc = "git stash clear";
        gm = "git merge --no-ff";
        gr = "git rebase";
        grom = "git rebase origin/master";
        grc = "git rebase --continue";
        gra = "git rebase --abort";
        gfo = "git fetch origin";
        gfu = "git fetch upstream";
        gcum = "git checkout upstream/main";
        gc = "git commit -s";
        gcm = "git commit -s -m";

        # Kubernetes
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

        # Terraform
        tf = "terraform";
        tfi = "terraform init";
        tfiu = "terraform init -upgrade";
        tfp = "terraform plan";
        tfa = "terraform apply";
        tfaaa = "terraform apply -auto-approve";
        tft = "terraform taint";

        # Logcli / Loki
        lc = "logcli";
        lcq = "logcli query";
        lcl = "logcli labels";
        lcljob = "logcli labels job";
        lclapp = "logcli labels app";

        # systemctl
        sc = "systemctl";
        scs = "systemctl status";
        scr = "systemctl restart";
        scsto = "systemctl stop";
        scsta = "systemctl start";

        # jouralctl
        j = "journalctl";
        ju = "journalctl -u";
        jfu = "journalctl -fu";


        m = "make";
        n = "nvim";
        o = "open";
        p = "python3";

      };
    };
  };

}
