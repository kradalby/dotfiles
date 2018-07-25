
# Go 1.10 Ubuntu
# https://github.com/golang/go/wiki/Ubuntu
if test -d "/usr/lib/go-1.10/bin"
    set -x PATH $PATH "/usr/lib/go-1.10/bin"
end

if test -d "/opt/ibm/notes"
    set -x PATH $PATH "/opt/ibm/notes"
end

if test -d "$HOME/git/kitty/linux-package/bin"
    set -x PATH $PATH "$HOME/git/kitty/linux-package/bin"
end
