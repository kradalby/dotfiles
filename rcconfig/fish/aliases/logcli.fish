alias lc "logcli"
alias lcq "logcli query"
alias lcl "logcli labels"
alias lcljob "logcli labels job"
alias lclapp "logcli labels app"

function lcqjob
    set query (printf '{job=~"%s.*"}' $argv[1])
    lcq $query $argv[2..-1]
end

function lcqapp
    set query (printf '{app=~"%s.*"}' $argv[1])
    lcq $query $argv[2..-1]
end
