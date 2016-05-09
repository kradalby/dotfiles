function set-dns
    if test $argv[1] = "google"
        sudo networksetup -setdnsservers (current_networkservice) 8.8.8.8 8.8.4.4
    else if test $argv[1] = "opendns"
        sudo networksetup -setdnsservers (current_networkservice) 208.67.222.222 208.67.220.220
    else if test $argv[1] = "adns"
        sudo networksetup -setdnsservers (current_networkservice) 198.101.242.72 23.253.163.53
    else if test $argv[1] = "dhcp"
        sudo networksetup -setdnsservers (current_networkservice) Empty
    else
        sudo networksetup -setdnsservers (current_networkservice) $argv
    end
    # Clean the DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
end
