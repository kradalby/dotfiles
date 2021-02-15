function mac-update
    cd ~/git/dotfiles or exit; git pull; cd - or exit
    echo "Running brew check to sync up software"
    cd ~/git/dotfiles or exit
    brew update
    brew cask update
    brew bundle install
    brew upgrade
    cd - or exit
end
