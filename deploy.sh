#!/usr/bin/env bash

CURRENT=$HOME/git/dotfiles

function deploy() {
    ls -1 $CURRENT/rc/ | while read FILE;
        do
            echo "Linking $FILE"
            rm ~/.$FILE
            ln -s $CURRENT/rc/$FILE ~/.$FILE
        done
    echo "Linking vimrc to neovim"
    ln -s $CURRENT/rc/vimrc $HOME/.config/nvim/init.vim
}

function deploy_ssh() {

    if [ ! -d $HOME/.ssh ]; then
        mkdir -p ~/.ssh
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
        mkdir -p ~/.config
    fi

    ls -1 $CURRENT/rcconfig/ | while read FILE;
        do
            echo "Linking $FILE"
            rm -rf ~/.config/$FILE
            ln -s $CURRENT/rcconfig/$FILE ~/.config/$FILE
        done
}

function prepare_vim_dir() {
    rm -rf ~/.vim
    mkdir ~/.vim
}

function install_vimplug() {
    # Vim
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    # Neovim
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}


deploy
#prepare_vim_dir
install_vimplug
deploy_ssh
deploy_config
