function upgrade-packages
    # Ask for the administrator password upfront
    sudo -v

    command --search softwareupdate >/dev/null; and begin
        echo "Updating macOS"
        sudo softwareupdate -i -a
    end

    command --search mas >/dev/null; and begin
        echo "Updating Mac App Store"
        mas upgrade
    end

    command --search brew >/dev/null; and begin
        sudo -v
        echo "Updating brew"
        brew update
        brew upgrade
        brew cleanup
        brew cask cleanup
        brew prune
    end

    command --search yarn >/dev/null; and begin
        sudo -v
        echo "Updating yarn"
        yarn global upgrade
    end

    # TODO: RubyGems
    # command --search gem >/dev/null; and begin
    #     sudo -v
    #     echo "Updating gem/ruby"
    #     sudo gem update --system
    #     gem update
    #     gem cleanup
    # end

    command --search pipx >/dev/null; and begin
        sudo -v
        echo "Updating pipx"
        pipx upgrade-all
    end

    # TODO: Go

    poetry self update

end
