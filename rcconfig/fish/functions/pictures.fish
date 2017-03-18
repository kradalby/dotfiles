function pictures
    set DIR (string join "" $TMPDIR pictures)
    set PDIR (string join "" "/private" $DIR)

    switch $argv[1]
        case "mount"
            if mount | grep "on $PDIR"
                echo "$DIR already mounted"
            else
                echo "$DIR is not mounted"
                mkdir -p $DIR
                sshfs seel:/storage/pictures $DIR
                echo "Mounted at $DIR"
            end
        case "umount"
            if mount | grep "on $PDIR"
                umount $DIR
            else
                echo "$DIR is not mounted"
            end
        case "cd"
            if mount | grep "on $PDIR"
                cd $DIR
            else
                echo "Pictures not mounted, run: pictures mount"
            end
        case "open"
            if mount | grep "on $PDIR"
                open $DIR
            else
                echo "Pictures not mounted, run: pictures mount"
            end
        case "ls"
            if mount | grep "on $PDIR"
                ls $DIR
            else
                echo "Pictures not mounted, run: pictures mount"
            end
        case "*"
            echo "Usage: pictures (mount|cd|open|ls)"
        end
end
