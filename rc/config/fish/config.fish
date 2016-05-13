# Configure fish
set normal (set_color normal)
set magenta (set_color magenta)
set yellow (set_color yellow)
set green (set_color green)
set red (set_color red)
set gray (set_color -o black)

# Fish git prompt
set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_showuntrackedfiles 'yes'
set __fish_git_prompt_showupstream 'yes'
set __fish_git_prompt_color_branch yellow
set __fish_git_prompt_color_upstream_ahead green
set __fish_git_prompt_color_upstream_behind red

# # Status Chars
set __fish_git_prompt_char_dirtystate 'æ'
set __fish_git_prompt_char_stagedstate '→'
set __fish_git_prompt_char_untrackedfiles 'ø'
set __fish_git_prompt_char_stashstate '↩'
set __fish_git_prompt_char_upstream_ahead '+'
set __fish_git_prompt_char_upstream_behind '-'


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
