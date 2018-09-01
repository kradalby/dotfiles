set -x LC_ALL "en_US.UTF-8"
set -x LANG "en_US.UTF-8"

if not set -q TMPDIR
    set -g x TMPDIR /tmp
end

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

# macOS spesific settings
if test (uname) = "Darwin"
    source $HOME/.config/fish/osx.fish
end

# Linux spesific settings
if test (uname) = "Linux"
    source $HOME/.config/fish/linux.fish
end

# Ansible
if test -d $HOME/.ansible.cfg
    set -x ANSIBLE_HOST_KEY_CHECKING "False"
    set -x ANSIBLE_CONFIG "$HOME/.ansible.cfg"
end

set -x EDITOR "vim"
set -x GOPATH "$HOME/go"

# Sorce sensitive tokens
if test -f $HOME/Sync/tokens.fish
    source $HOME/Sync/tokens.fish
end

# Add directories to path if they exist
set BINDIRS = "$HOME/.npm-global/bin" \
    "$HOME/.npm-packages/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/git/dotfiles/bin" \
    "$HOME/bin" \
    "$HOME/.local/bin" \
    "$HOME/.config/composer/vendor/bin" \
    "$GOPATH/bin" \
    "$HOME/.gem/ruby/2.5.0/bin"

for bindir in $BINDIRS
    if test -d $bindir
         set -x PATH $PATH $bindir 
    end
end


# Source aliases
for file in $HOME/.config/fish/aliases/*
    source $file
end

# OPAM configuration
if test -d $HOME/.opam/opam-init
    source $HOME/.opam/opam-init/init.fish > /dev/null 2> /dev/null; or true
end
