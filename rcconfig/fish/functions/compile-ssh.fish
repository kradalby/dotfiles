function compile-ssh
    set dir (pwd)
    cd $HOME/git/dotfiles
    cat $HOME/git/dotfiles/ssh/config.d/* > $HOME/git/dotfiles/ssh/config
    git diff $HOME/git/dotfiles/ssh/config
    cd $dir
end
