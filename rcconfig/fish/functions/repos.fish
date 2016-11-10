#!/usr/bin/env fish
# similar script in Fish
# still under construction, need to quiet `git status` more effectively

function repos -d 'Do stuff in all the repos'
    set stuff $argv[1]
    if test $stuff = "pull"
        execute "pull"
    else if test $stuff = "status"
        execute "git status"
    else if test $stuff = "push"
        execute "git push"
    end
end

function pull
  git stash --quiet
  git pull
  git stash apply --quiet
end

function execute
    set command $argv[1]
    for dir in ./*/
        cd $dir
        figlet $dir
        git status -sb 2>/dev/null
        if [ $status -eq 0 ]
            set_color red
            echo "Updating $dir…"
            set_color normal
            eval $command
            echo \n\n\n\n
        end
        cd ..
    end
end
