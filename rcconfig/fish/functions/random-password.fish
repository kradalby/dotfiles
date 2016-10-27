function random-password
    if test $argv[1] -gt 0
        openssl rand -hex $argv[1]
    else
        openssl rand -hex 30
    end
end
