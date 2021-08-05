alias tb 'nc termbin.com 9999'
alias cm 'curl --silent http://whatthecommit.com/index.txt'
alias fuck 'sudo (fc -ln -1)'
alias ehosts 'sudo vim /etc/hosts'
alias markdown 'python3 -m markdown -x markdown.extensions.tables'
alias s 'xargs perl -pi -E'

alias rsakey 'ssh-keygen -t rsa -b 4096 -o -a 100'
alias ed25519key 'ssh-keygen -t ed25519 -o -a 100'

alias reload-fish 'source $HOME/.config/fish/config.fish'

alias simulator 'open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'

alias getsms 'curl https://api.smstore.kradalby.no/sms -s | jq --raw-output \'.[] | "\(.sender): \(.message)"\''


alias v 'vim'
alias c 'code'


alias mp 'multipass'

alias hm 'history merge'
