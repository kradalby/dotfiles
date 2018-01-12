function screen
    switch $argv[1]
        case "laptop"
            eval "$HOME/.screenlayout/$argv[1].sh"
        case "desktop"
            eval "$HOME/.screenlayout/$argv[1].sh"
        case "projector"
            eval "$HOME/.screenlayout/$argv[1].sh"
        case "mirror"
            eval "$HOME/.screenlayout/$argv[1].sh"
    end
end
