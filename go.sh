#!/usr/bin/env sh

go install golang.org/x/tools/gopls@latest@latest
go install github.com/mitchellh/gox@latest
go install mvdan.cc/sh/cmd/shfmt@latest
go install mvdan.cc/gofumpt@latest
go install github.com/fatih/hclfmt@latest
go install github.com/kradalby/kubespace@latest
go install cuelang.org/go/cmd/cue@latest
go install github.com/hashicorp/terraform-ls@latest
go install github.com/oligot/go-mod-upgrade@latest
go install github.com/jessfraz/dockfmt@latest
go install sigs.k8s.io/kind@latest@latest
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
go install github.com/monitoring-mixins/mixtool/cmd/mixtool@latest
go install github.com/brancz/gojsontoyaml@latest

# Tools for vscode-go
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/godoctor/godoctor@latest
go install honnef.co/go/tools/...@latest
go install golang.org/x/tools/cmd/guru@latest
go install golang.org/x/tools/cmd/gorename@latest
go install github.com/fatih/gomodifytags@latest
go install github.com/haya14busa/goplay/cmd/goplay@latest
go install github.com/josharian/impl@latest
go install github.com/tylerb/gotype-live@latest
go install github.com/rogpeppe/godef@latest
go install github.com/zmb3/gogetdoc@latest
go install github.com/sqs/goreturns@latest
go install winterdrache.de/goformat/goformat@latest
go install golang.org/x/lint/golint@latest
go install github.com/cweill/gotests/...@latest
go install github.com/mgechev/revive@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/davidrjenni/reftools/cmd/fillstruct@latest
go install github.com/uudashr/gopkgs/cmd/gopkgs@latest
go install github.com/ramya-rao-a/go-outline@latest
go install github.com/acroca/go-symbols@latest

go install github.com/bitnami/bcrypt-cli@latest
go install github.com/homeport/dyff/cmd/dyff@latest
