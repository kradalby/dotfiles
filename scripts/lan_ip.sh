#!/bin/bash

ostype() { echo $OSTYPE | tr '[A-Z]' '[a-z]'; }

export SHELL_PLATFORM='unknown'

case "$(ostype)" in
    *'linux'*   ) SHELL_PLATFORM='linux'    ;;
    *'darwin'*  ) SHELL_PLATFORM='osx'      ;;
    *'bsd'*     ) SHELL_PLATFORM='bsd'      ;;
esac

shell_is_linux() { [[ $SHELL_PLATFORM == 'linux' || $SHELL_PLATFORM == 'bsd' ]]; }
shell_is_osx()   { [[ $SHELL_PLATFORM == 'osx' ]]; }
shell_is_bsd()   { [[ $SHELL_PLATFORM == 'bsd' || $SHELL_PLATFORM == 'osx' ]]; }


function run() {
    if shell_is_bsd || shell_is_osx ; then
        all_nics=$(ifconfig 2>/dev/null | awk -F':' '/^[a-z]/ && !/^lo/ { print $1 }')
        for nic in ${all_nics[@]}; do
            ipv4s_on_nic=$(ifconfig ${nic} 2>/dev/null | awk '$1 == "inet" { print $2 }')
            for lan_ip in ${ipv4s_on_nic[@]}; do
                [[ -n "${lan_ip}" ]] && break
            done
            [[ -n "${lan_ip}" ]] && break
        done
    else
        # Get the names of all attached NICs.
        all_nics="$(ip addr show | cut -d ' ' -f2 | tr -d :)"
        all_nics=(${all_nics[@]//lo/})   # Remove lo interface.

        for nic in "${all_nics[@]}"; do
            # Parse IP address for the NIC.
            lan_ip="$(ip addr show ${nic} | grep '\<inet\>' | tr -s ' ' | cut -d ' ' -f3)"
            # Trim the CIDR suffix.
            lan_ip="${lan_ip%/*}"
            # Only display the last entry
            lan_ip="$(echo "$lan_ip" | tail -1)"

            [ -n "$lan_ip" ] && break
        done
    fi

    echo "${lan_ip-N/a}"
    return 0
}

run
