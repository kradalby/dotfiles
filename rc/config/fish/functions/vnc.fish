function vnc -d "Connect to a VNC server"
    if test (count $argv) = 1
        echo "Connecting to: localhost:$argv[1]"
        open vnc://localhost:$argv[1]
    else if test (count $argv) = 2
        echo "Connecting to: $argv[1]:$argv[2]"
        open vnc://$argv[1]:$argv[2]
    end
end

