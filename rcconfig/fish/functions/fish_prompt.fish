function fish_prompt
    # kradalby@kramacbook ~/g/dotfiles (master=)
    echo
    set_color brmagenta
    date "+%m/%d/%y %H:%M:%S"
    set_color bryellow
    printf $USER
    set_color green
    printf "@"
    set_color brgreen
    printf (hostname)
    set_color brmagenta
    printf ' %s' (prompt_pwd)
    set_color normal
    printf '%s' (__fish_git_prompt)
    set_color brmagenta
    echo " -> "
end
