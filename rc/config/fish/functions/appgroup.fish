function appgroup
    set comm Slack Discord Goofy Skype ChitChat Mail

    set base $comm "Safari Technology Preview" Spotify Stickies iTerm

    set group $$argv[1]

    if test $argv[2] = "start"
        for app in $group
            echo "Starting $app"
            open -a $app
        end
    else if test $argv[2] = "kill"
        for app in $group
            echo "Killing $app"
            osascript -e "quit app \"$app\""
        end
    end
end
