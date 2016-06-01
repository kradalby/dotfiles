#!/usr/bin/env bash

CURRENT=$HOME/git/dotfiles

function deploy() {
    ls -1 $CURRENT/rc/ | while read FILE;
        do
            echo "Linking $FILE"
            rm ~/.$FILE
            ln -s $CURRENT/rc/$FILE ~/.$FILE
        done
}

function deploy_ssh() {

    if [ ! -d $HOME/.ssh ]; then
        mkdir ~/.ssh
    fi

    if [ -f $HOME/.ssh/config ]; then
        rm ~/.ssh/config
        ln -s $CURRENT/ssh/config ~/.ssh/config
    else
        ln -s $CURRENT/ssh/config ~/.ssh/config
    fi
}

function deploy_config() {
    if [ ! -d $HOME/.config ]; then
        mkdir ~/.config
    fi

    ls -1 $CURRENT/rcconfig/ | while read FILE;
        do
            echo "Linking $FILE"
            rm -rf ~/.$FILE
            ln -s $CURRENT/rcconfig/$FILE ~/.config/$FILE
        done
}

function prepare_vim_dir() {
    rm -rf ~/.vim
    mkdir ~/.vim
}

function install_vimplug() {
    mkdir -p ~/.vim/autoload
    curl --silent -fLo ~/.vim/autoload/plug.vim \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}


deploy
#prepare_vim_dir
install_vimplug
deploy_ssh
deploy_config
