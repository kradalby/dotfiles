alias k 'kubectl'
alias kg 'kubectl get'
alias kga 'kubectl get pods -o wide --all-namespaces --sort-by=.spec.nodeName'
alias kd 'kubectl describe'
alias kdel 'kubectl delete'
alias ke 'kubectl edit'
alias kaf 'kubectl apply -f'
alias kdelf 'kubectl delete -f'
alias kubuntu 'kubectl run --generator=run-pod/v1 ubuntu-shell --rm -i --tty --image ubuntu -- bash'
alias kbusy 'kubectl run --generator=run-pod/v1 busybox-shell --rm -i --tty --image busybox -- sh'

alias kc 'kubectl config use-context'
alias kgc 'kubectl config get-contexts'
alias kcn 'kubectl config set-context --current --namespace'

alias kl 'kubectl logs'
alias klf 'kubectl logs -f'
