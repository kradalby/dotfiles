
alias osxphotos_missing_path 'osxphotos query --json --only-photos | jq ".[] | select((.path == null)and .path_edited == null)"'

alias nv 'neovide --frameless'

alias notify 'osascript -e \'tell app "System Events" to display alert "Command completed" message "Check the window for result."\''
