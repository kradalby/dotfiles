#!/bin/bash

CURRENT=~/git/dotfiles

function deploy() {
    ls -1 $CURRENT/rc/ | while read FILE;
        do
            rm ~/.$FILE
            ln -s $CURRENT/rc/$FILE ~/.$FILE
        done
}

function install_vim_markdown() {
    rm -r ~/.vim
    mkdir ~/.vim
    wget https://github.com/plasticboy/vim-markdown/archive/master.tar.gz -O ~/.vim/vim_markdown.tar.gz
    tar --strip=1 -zxf ~/.vim/vim_markdown.tar.gz -C ~/.vim/
    rm ~/.vim/vim_markdown.tar.gz
}

deploy
install_vim_markdown
