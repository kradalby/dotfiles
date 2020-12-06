set -x LC_ALL "en_US.UTF-8"
set -x LANG "en_US.UTF-8"

if not set -q TMPDIR
    set -g -x TMPDIR /tmp
end

if gpg --list-keys 09F62DC067465735 >/dev/null 2>&1
    set -xg GPG_TTY (tty)
    set -xg GPG_FINGERPRINT 09F62DC067465735
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
set -x GO111MODULE on
# set -x PYTHON3USERBASE "$HOME/.pip3"
# set -x PYTHON2USERBASE "$HOME/.pip2"
# set -x PYTHONUSERBASE $PYTHON3USERBASE
# set -x PIP_USER 1
set -x NODE_PATH "$HOME/.npm-packages/lib/node_modules"

# Sorce sensitive tokens
if test -f $HOME/Sync/fish/tokens.fish
    source $HOME/Sync/fish/tokens.fish
end

# Add directories to path if they exist
set BINDIRS = \
# "$PYTHON3USERBASE/bin" \
# "$PYTHON2USERBASE/bin" \
    "$HOME/.npm-packages/bin" \
    "$HOME/.config/yarn/global/node_modules/.bin" \
    "$HOME/.yarn/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/git/dotfiles/bin" \
    "$HOME/bin" \
    "$HOME/.local/bin" \
    "$HOME/.config/composer/vendor/bin" \
    "$GOPATH/bin" \
    "$HOME/.dotnet/tools" \
    "$HOME/.gem/ruby/2.6.0/bin"

for bindir in $BINDIRS
    if test -d $bindir; and not contains $bindir $PATH
         set -x PATH $bindir $PATH
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


if type -q prettyping
    alias ping prettyping
end

if type -q bat
    alias cat bat
end

if type -q lsd
    alias ls "lsd --icon never"
end

if type -q nvim
    alias vim nvim
    set -x EDITOR "nvim"
end

# if type -q dog
#     alias dig dog
# end

if type -q ag
    set -xg FZF_DEFAULT_COMMAND 'ag -g ""'
end

# Prompt
if type -q starship
    starship init fish | source
end
