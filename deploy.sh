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
    mkdir -p ~/.vim
    mkdir -p ~/.vim-tmp
}

function install_vimplug() {
    # Vim
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    # Neovim
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

function install_tmuxpm() {
    mkdir -p $HOME/.tmux/plugins
    git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
}

function link_neovim() {
    mkdir -p $HOME/.config/nvim
    rm -rf $HOME/.config/nvim/init.vim
    ln -s $CURRENT/rc/vimrc $HOME/.config/nvim/init.vim
}


deploy
#prepare_vim_dir
install_vimplug
install_tmuxpm
link_neovim
deploy_ssh
deploy_config
