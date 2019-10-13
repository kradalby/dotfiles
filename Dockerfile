FROM ubuntu:latest

RUN apt update
RUN apt install -y vim git curl tar xz-utils

RUN useradd -m ubuntu
USER ubuntu
ENV HOME /home/ubuntu
WORKDIR /home/ubuntu

RUN curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

RUN mkdir -p ~/git/dotfiles
COPY . git/dotfiles
RUN ls git
RUN ls ~/git/dotfiles
RUN cp ~/git/dotfiles/rc/vimrc ~/.vimrc
RUN vim +'PlugInstall --sync' +qa

RUN tar -vcJf dotfiles.tar.xz .vim git
RUN ls -lah dotfiles.tar.xz
