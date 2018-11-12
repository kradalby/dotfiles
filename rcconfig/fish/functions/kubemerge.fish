function kubemerge
    set -e KUBECONFIG
    for file in $argv[1..-1]
        set -x KUBECONFIG "$KUBECONFIG:$file"
    end
    
    kubectl config view --flatten > $TMPDIR/kubeconfig
    cp $HOME/.kube/config $HOME/.kube/config.bak
    cp $TMPDIR/kubeconfig $HOME/.kube/config
    set -e KUBECONFIG
end

