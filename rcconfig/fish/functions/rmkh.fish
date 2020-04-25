function rmkh
    set -x sed sed
    if type -q gsed
        set -x sed gsed
    end
    $sed -i $argv'd' ~/.ssh/known_hosts
end
