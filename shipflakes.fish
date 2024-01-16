#!/usr/bin/env fish

# This script ships this directory to the machines, useful if Colmena isnt behaving

rg "= nixosBox" --no-heading | awk '{print $2}' | rg -v "#" | tr -d '"' | while read host
    if [ $host != "=" ]
        # echo "adding host to list: $host"
        set -a hosts $host
    end
end


if set -q argv[1]
    set host $argv[1]
    echo "Shipping to $host..."
    rsync -ah --delete --cvs-exclude --filter=':- .gitignore' . $host:/etc/nixos/.
else
    echo "Shipping flakes to $hosts"
    for host in $hosts
        echo "Shipping to $host..."
        rsync -ah --delete --cvs-exclude --filter=':- .gitignore' . $host:/etc/nixos/.
    end
end
