function swap
    tmp=`mktemp`
    mv $1 $tmp
    mv $2 $1
    mv $tmp $2
end
