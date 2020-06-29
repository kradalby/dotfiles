# Add directories to path if they exist
set BINDIRS = \
    "/usr/lib/go-1.10/bin" \
    "/usr/lib/go-1.12/bin" \
    "/usr/lib/go-1.13/bin" \
    "/usr/lib/go-1.14/bin" \
    "/opt/ibm/notes" \
    "/usr/share/swift/usr/bin" \
    "$HOME/dotnet" \
    "$HOME/.vim/plugged/fzf/bin/"

for bindir in $BINDIRS
    if test -d $bindir
         set -x PATH $bindir $PATH
    end
end

if grep -q Microsoft /proc/version
    set -x DOCKER_HOST "tcp://localhost:2375"
end

if test -f $HOME/.gr
    source $HOME/git/dotfiles-gr/config.fish
end
