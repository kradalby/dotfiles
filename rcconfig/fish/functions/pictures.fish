function pictures
    switch $argv[1]
        case "mount"
            mkdir $TMPDIR/pictures/
            sshfs seel:/storage/pictures $TMPDIR/pictures/
            echo "Mounted at $TMPDIR/pictures"
        case "cd"
            cd $TMPDIR/pictures
        case "open"
            open $TMPDIR/pictures
        case "ls"
            ls $TMPDIR/pictures
        end
end
