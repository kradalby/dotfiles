#!/usr/bin/env sh

go get -u golang.org/x/tools/gopls@latest
go get -u github.com/mitchellh/gox
go get -u mvdan.cc/sh/cmd/shfmt
go get -u github.com/fatih/hclfmt
go get -u github.com/kradalby/kubespace
go get -u cuelang.org/go/cmd/cue
go get -u github.com/prometheus-community/promql-langserver/cmd/promql-langserver

# Tools for vscode-go
go get -u golang.org/x/tools/gopls
go get -u golang.org/x/tools/cmd/goimports
go get -u github.com/godoctor/godoctor
go get -u github.com/golangci/golangci-lint/cmd/golangci-lint
go get -u honnef.co/go/tools/...
go get -u golang.org/x/tools/cmd/guru
go get -u golang.org/x/tools/cmd/gorename
go get -u github.com/fatih/gomodifytags
go get -u github.com/haya14busa/goplay/cmd/goplay
go get -u github.com/josharian/impl
go get -u github.com/tylerb/gotype-live
go get -u github.com/rogpeppe/godef
go get -u github.com/zmb3/gogetdoc
go get -u github.com/sqs/goreturns
go get -u winterdrache.de/goformat/goformat
go get -u golang.org/x/lint/golint
go get -u github.com/cweill/gotests/...
go get -u github.com/mgechev/revive
go get -u github.com/go-delve/delve/cmd/dlv
go get -u github.com/davidrjenni/reftools/cmd/fillstruct
go get -u github.com/uudashr/gopkgs/cmd/gopkgs
go get -u github.com/ramya-rao-a/go-outline
go get -u github.com/acroca/go-symbols
