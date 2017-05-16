# Homebrew
set -x PATH ""(brew --prefix)"/bin" $PATH

# GNU sed
set -x PATH "/usr/local/opt/gnu-sed/bin" $PATH

# GNU coreutils
set -x PATH "/usr/local/opt/coreutils/libexec/gnubin" $PATH

# Nvidia Cuda
# set -x PATH $PATH "/Developer/NVIDIA/CUDA-7.5/bin"

# Node
set -x NODE_PATH "/usr/local/lib/node" "/usr/local/lib/node_modules" $NODE_PATH

# Java home
set -x JAVA_HOME (/usr/libexec/java_home)

# MacTex
set -x PATH $PATH "/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin"

# Swiftenv root
# set -x SWIFTENV_ROOT "/usr/local/var/swiftenv"

# Swiftenv
# setenv SWIFTENV_ROOT "$HOME/.swiftenv"
# setenv PATH "$SWIFTENV_ROOT/bin" $PATH
# status --is-interactive; and . (swiftenv init -|psub)

# Lapis OpenResty
set -x LAPIS_OPENRESTY /usr/local/bin/openresty


# Manpath
# populate a local variable with directories from /etc/manpaths
set --local etc_manpaths
if test -f /etc/manpaths
    for dir in (cat /etc/manpaths)
        if test -d $dir
            set etc_manpaths $etc_manpaths $dir
        end
    end
end

# populate a local variable with content of each file in /etc/manpaths.d/* (filesort order)
set --local etc_manpathsd
if test -d /etc/manpaths.d
    for file in /etc/manpaths.d/*
        if test -d (cat $file)
            set etc_manpathsd $etc_manpathsd (cat $file)
        end
    end
end

set -x MANPATH $etc_manpaths $etc_manpathsd
