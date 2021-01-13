
alias osxphotos_missing_path 'osxphotos query --json --only-photos | jq ".[] | select((.path == null)and .path_edited == null)"'
