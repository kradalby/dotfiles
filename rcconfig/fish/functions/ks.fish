function ks
    set -xg KUBECONFIG "$HOME/.kube/$argv[1]"
end
