# Java home
set -x JAVA_HOME (/usr/libexec/java_home)


set BINDIRS = \
    "/usr/local/bin" \
    "/usr/local/opt/gnu-sed/bin" \
    "/usr/local/opt/gnu-tar/libexec/gnubin" \
    "$HOME/bin/flutter/bin" \
    "/usr/local/opt/ruby/bin" \
    "/usr/local/lib/ruby/gems/2.6.0/bin" \
    "/Library/TeX/Distributions/.DefaultTeX/Contents/Programs/texbin" \
    "/Users/kradalby/Library/Python/3.7/bin" \
    "/Applications/VMware OVF Tool" \
    "/Applications/VMware Fusion.app/Contents/Library/VMware OVF Tool" \
    "/usr/local/opt/coreutils/libexec/gnubin"

for bindir in $BINDIRS
    if test -d $bindir; and not contains $bindir $PATH
         set -x PATH $bindir $PATH
    end
end

if type -q brew
    set brew_path ""(brew --prefix)"/bin"
    if not contains $brew_path $PATH
        set -x $brew_path PATH  $PATH
    end
end

# QT
set qt_path "/usr/local/opt/qt/bin"
if test -d $qt_path
    if not contains $qt_path $PATH
  set -x PATH $PATH $qt_path
    end
  set -gx LDFLAGS "-L/usr/local/opt/qt/lib"
  set -gx CPPFLAGS "-I/usr/local/opt/qt/include"
end
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
