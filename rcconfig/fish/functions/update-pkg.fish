function update-pkg
    # Ask for the administrator password upfront
    sudo -v

    command --search apt-get >/dev/null; and begin
        echo "Updating apt"
        sudo apt-get update
        sudo apt-get upgrade -y
    end

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

    command --search npm >/dev/null; and begin
        sudo -v
        echo "Updating npm"
        npm update -g npm
        npm update -g
    end

    command --search gem >/dev/null; and begin
        sudo -v
        echo "Updating gem/ruby"
        sudo gem update --system
        gem update
        gem cleanup
    end

    command --search pip2 >/dev/null; and begin
        sudo -v
        echo "Updating pip2/python2"
        pip2 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip2 install -U
    end

    command --search pip3 >/dev/null; and begin
        sudo -v
        echo "Updating pip3/python3"
        pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U
    end

    command --search opam >/dev/null; and begin
        sudo -v
        echo "Updating ocaml/opam"
        opam update
        opam upgrade -y
    end

end
