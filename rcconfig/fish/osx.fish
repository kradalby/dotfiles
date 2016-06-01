# Homebrew
set -x PATH ""(brew --prefix)"/bin" $PATH

# GNU sed
set -x PATH "/usr/local/opt/gnu-sed/bin" $PATH

# GNU coreutils
set -x PATH "/usr/local/opt/coreutils/libexec/gnubin" $PATH

# dotfiles bin
set -x PATH "$HOME/git/dotfiles/bin" $PATH

# Nvidia Cuda
set -x PATH $PATH "/Developer/NVIDIA/CUDA-7.5/bin"

# Node
set -x NODE_PATH "/usr/local/lib/node" "/usr/local/lib/node_modules" $NODE_PATH

# Java home
set -x JAVA_HOME (/usr/libexec/java_home)

# Swiftenv root
set -x SWIFTENV_ROOT "/usr/local/var/swiftenv"
