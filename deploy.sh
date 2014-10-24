#!/bin/bash

CURRENT=~/git/dotfiles

function deploy() {
    ls -1 $CURRENT/rc/ | while read FILE;
        do
            rm ~/.$FILE
            ln -s $CURRENT/rc/$FILE ~/.$FILE
        done
}

function deploy_special() {

    if [ ! -d "~/.ssh" ]; then
        mkdir ~/.ssh
    fi

    ln -s $CURRENT/ssh/config ~/.ssh/
}

function prepare_vim_dir() {
    rm -rf ~/.vim
    mkdir ~/.vim
}

function install_vimplug() {
    mkdir -p ~/.vim/autoload
    curl -fLo ~/.vim/autoload/plug.vim \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    vim +PlugInstall
}


deploy
prepare_vim_dir
install_vimplug
deploy_special
