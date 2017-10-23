function rdp -d "Connect to a RDP server"
    if test (count $argv) -le 1
        echo "Need more arguments: [username] [server]"
    else if test (count $argv) = 2
        echo "Connecting to: $argv[2]"
        set command "xfreerdp +clipboard /u:$argv[1] /h:1050 /w:1920 /v:$argv[2] /p:"
        echo -n Password:
        read --silent password
        echo
        echo $command
        eval $command$password
    end
end

