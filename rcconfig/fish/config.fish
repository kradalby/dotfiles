set -x LC_ALL "en_US.UTF-8"
set -x LANG "en_US.UTF-8"

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

# Sorce sensitive tokens
source $HOME/Sync/tokens.fish

# dotfiles bin
set -x PATH "$HOME/git/dotfiles/bin" $PATH

# Source aliases
for file in $HOME/.config/fish/aliases/*
    source $file
end

# OPAM configuration
source $HOME/.opam/opam-init/init.fish > /dev/null 2> /dev/null; or true
