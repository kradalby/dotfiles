function run() {
    uptime | awk -F, '{sub(".*up ",x,$1);print $1 $2}'
}

run
