# function __fish_prompt
#     set d (date "+%d/%m/%y %H:%M:%S")
#     set brmagenta FF55FF
#     set bryellow FFFF55
#     set brgreen 55FF55
#     echo
#     set_color $brmagenta
#     printf '%s ' $d
#     set_color $bryellow
#     printf $USER
#     set_color green
#     printf "@"
#     set_color $brgreen
#     printf (hostname)
#     if set -q WORKING_ENV
#         set_color $bryellow
#         printf " [ %s ]" $WORKING_ENV
#     end
#     echo
#     set_color brcyan
#     printf '%s' (pwd)
#     set_color normal
#     printf '%s' (__fish_git_prompt)
#     set_color $brmagenta
#     echo
#     echo "> "
# end
#
# function __fish_right_prompt
#     if not set -q KUBECONTEXT
#         if type -q kubectl
#             set --universal -x KUBECONTEXT (kubectl config current-context)
#         end
#     end
#
#     if set -q KUBECONTEXT
#         set_color brblue
#         printf '❄️  [ %s ]' $KUBECONTEXT
#     end
# end
