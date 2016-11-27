function random-password
    if test $argv[1] -gt 0
        string sub --length $argv[1] (openssl rand -base64 48)
    else
        openssl rand -base64 48
    end
end
