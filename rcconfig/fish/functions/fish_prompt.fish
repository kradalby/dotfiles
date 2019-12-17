function fish_prompt
	set d (date "+%m/%d/%y %H:%M:%S")
    set brmagenta FF55FF
    set bryellow FFFF55
    set brgreen 55FF55
    # kradalby@kramacbook ~/g/dotfiles (master=)
    echo
    set_color $brmagenta
    printf '%s ' $d
    set_color $bryellow
    printf $USER
    set_color green
    printf "@"
    set_color $brgreen
    printf (hostname)
    set_color brcyan
    echo
    printf '%s' (pwd)
    set_color normal
    printf '%s' (__fish_git_prompt)
    set_color $brmagenta
    echo
    echo "> "
end
