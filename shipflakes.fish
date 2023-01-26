#!/usr/bin/env fish

# This script ships this directory to the machines, useful if Colmena isnt behaving

rg "= nixosBox" --no-heading | awk '{print $2}' | rg -v "#" | tr -d '"' | while read host
    rsync -avh --progress --delete --cvs-exclude --filter=':- .gitignore' . $host:/etc/nixos/.
end
