# Lets wt move the interactive shell into the worktree it lands in.
function wt --wraps wt --description "Git worktree helper"
    set -l f (mktemp)
    WT_CD_FILE=$f command wt $argv
    set -l s $status
    read -l dir <$f
    rm -f $f
    test -n "$dir"; and cd $dir
    return $s
end
