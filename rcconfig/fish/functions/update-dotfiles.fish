function update-dotfiles

    echo "Pulling dotfiles"
    cd ~/git/dotfiles
    git pull
    cd -

    echo "Updating vim"
    vim -c "PlugInstall" -c "q" -c "q" > /dev/null



    # command --search apt-get >/dev/null; and begin
    #     echo "Updating apt"
    #     sudo apt-get update
    #     sudo apt-get upgrade -y
    # end

end
