#!/usr/bin/env fish
# similar script in Fish
# still under construction, need to quiet `git status` more effectively

function drone-repo -d 'Initiate drone repo with secrets'
    set stuff $argv[1]
    set repo $argv[2]
    set namespace $argv[3]

    echo "Initiating $repo"

    drone repo sync
    drone repo add $repo

    if test $stuff = "kube"
        if test $namespace = ""
            echo "Namespace must be set"
            exit 1
        end

        drone-docker-secrets $repo
        kubespace drone -n $namespace -r $repo
    else if test $stuff = "bin"
        drone-ssh-secrets $repo
    end
end
