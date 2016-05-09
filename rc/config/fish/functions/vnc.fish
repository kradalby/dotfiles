function vnc -d "Connect to a VNC server"
    # Checking for TigerVNC instead of OSX builtin
    if test -e "$HOME/Applications/TigerVNC Viewer 1.5.0.app/Contents/MacOS/TigerVNC Viewer"
        echo "Using TigerVNC"
        set vnc_command "$HOME/Applications/TigerVNC\ Viewer\ 1.5.0.app/Contents/MacOS/TigerVNC\ Viewer "
    else if test -e "$HOME/Applications/TigerVNC Viewer 1.6.0.app/Contents/MacOS/TigerVNC Viewer"
        echo "Using TigerVNC"
        set vnc_command "$HOME/Applications/TigerVNC\ Viewer\ 1.6.0.app/Contents/MacOS/TigerVNC\ Viewer "
    else
        set vnc_command "open vnc://"
    end

    if test (count $argv) = 1
        echo "Connecting to: localhost:$argv[1]"
        set host "localhost"
        eval "$vnc_command$host:$argv[1]"
    else if test (count $argv) = 2
        echo "Connecting to: $argv[1]:$argv[2]"
        eval "$vnc_command$argv[1]:$argv[2]"
    end
end

