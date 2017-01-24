function update-pkg
    echo "Updating macOS"
    sudo softwareupdate -i -a

    echo "Updating brew"
    brew update
    brew upgrade --all
    brew cleanup
    brew cask cleanup
    brew prune

    echo "Updating npm"
    npm update -g npm
    npm update -g

    echo "Updating gem/ruby"
    sudo gem update --system
    gem update
    gem cleanup

    echo "Updating pip2/python2"
    pip2 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip2 install -U

    echo "Updating pip3/python3"
    pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U
end
