
# Go 1.10 Ubuntu
# https://github.com/golang/go/wiki/Ubuntu

# Add directories to path if they exist
set BINDIRS = \
    "/usr/lib/go-1.10/bin" \
    "/opt/ibm/notes" \
    "/usr/share/swift/usr/bin" \
    "$HOME/git/kitty/linux-package/bin"

for bindir in $BINDIRS
    if test -d $bindir
         set -x PATH $PATH $bindir 
    end
end

if grep -q Microsoft /proc/version
    set -x DOCKER_HOST "tcp://localhost:2375"
  end
