function __fish_below_git_pwd
    pwd | perl -p -E 's/^.*git\/\w+\/(.*)/$1:/g'
end
