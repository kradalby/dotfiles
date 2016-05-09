
# Homebrew
set -x PATH ""(brew --prefix)"/bin" $PATH

# GNU sed
set -x PATH "/usr/local/opt/gnu-sed/bin" $PATH

# GNU coreutils
set -x PATH "/usr/local/opt/coreutils/libexec/gnubin" $PATH

set -x PATH "$HOME/git/dotfiles/bin" $PATH

# OVFTool VMware
set -x PATH $PATH "/Applications/VMware OVF Tool"

# Nvidia Cuda
set -x PATH $PATH "/Developer/NVIDIA/CUDA-7.5/bin"

# Node
set -x NODE_PATH "/usr/local/lib/node" "/usr/local/lib/node_modules" $NODE_PATH

# Java home
set -x JAVA_HOME (/usr/libexec/java_home)

# Swiftenv root
set -x SWIFTENV_ROOT "/usr/local/var/swiftenv"

# Ansible
set -x ANSIBLE_HOST_KEY_CHECKING "False"
set -x ANSIBLE_CONFIG "~/.ansible.cfg"

# Python
set -x VIRTUALENV_PYTHON "/usr/local/bin/python"

set -x EDITOR "vim"


# Aliases
alias tb 'nc termbin.com 9999'
alias cm 'curl --silent http://whatthecommit.com/index.txt'
alias fuck 'sudo (fc -ln -1)'
alias ehosts 'sudo vim /etc/hosts'
alias markdown 'python3 -m markdown -x markdown.extensions.tables'
alias s 'xargs perl -pi -E'

alias py python
alias py3 python3

alias rsakey 'ssh-keygen -t rsa -b 4096 -o -a 100'
alias ed25519key 'ssh-keygen -t ed25519 -o -a 100'

alias ga 'git add'
alias gaa 'git add .'
alias gc 'git commit'
alias gcm 'git commit -m'
alias gco 'git checkout'
alias gcob 'git checkout -b'
alias gcom 'git checkout master'
alias gd 'git diff'
alias gb 'git branch'
alias gbd 'git branch -d '
alias gp 'git pull'
alias gss 'git status -s'
alias gst 'git stash'
