function htpass -d "Takes username, gives htpasswd line"
    if test -n $argv[1]
        read_password "Password: "
        printf "$argv[1]:"
        set hash (openssl passwd -apr1 $pass)
        echo "$hash"
    else
        echo "Gief username"
    end
end


function read_password # prompt targetVar

    echo -n $argv[1]
    stty -echo
    head -n 1 | read -g pass
    stty echo
    echo

end
