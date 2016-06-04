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
set __fish_git_prompt_char_dirtystate ' dirty '
set __fish_git_prompt_char_stagedstate ' staged '
set __fish_git_prompt_char_untrackedfiles ' untrack '
set __fish_git_prompt_char_stashstate ' stash '
set __fish_git_prompt_char_upstream_ahead ' ahead '
set __fish_git_prompt_char_upstream_behind ' behind '

# OSX spesific settings
if test (uname) = "Darwin"
    source $HOME/.config/fish/osx.fish
end

# Python
set -x VIRTUALENV_PYTHON "/usr/local/bin/python"

# Ansible
set -x ANSIBLE_HOST_KEY_CHECKING "False"
set -x ANSIBLE_CONFIG "~/.ansible.cfg"

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
alias gm 'git merge --no-ff'
alias gr 'git rebase'
alias grom 'git rebase origin/master'
alias grc 'git rebase --continue'
alias gra 'git rebase --abort'
alias gfo 'git fetch origin'

# OPAM configuration
source $HOME/.opam/opam-init/init.fish > /dev/null 2> /dev/null; or true

