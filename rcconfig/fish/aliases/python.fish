
if test -e (which ipython)
    alias python ipython
    alias python3 ipython3
    alias py ipython
    alias py3 ipython3
    alias pyt (which python)
    alias pyt3 (which python3)
else
    alias py python
    alias py3 python3
end

alias pp pypy
alias pp3 pypy3

alias ve virtualenv
