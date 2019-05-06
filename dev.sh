#!/usr/bin/env fish

# https://github.com/vscode-langservers/vscode-css-languageserver-bin
# https://github.com/redhat-developer/yaml-language-server
# https://github.com/sourcegraph/javascript-typescript-langserver


####################
# NODE
####################
npm install --global \
typescript \
npm-check \
elm-format \
eslint \
eslint-config-prettier \
eslint-plugin-prettier \
git-open \
diff-so-fancy \
yarn \
vscode-css-languageserver-bin \
yaml-language-server \
dockerfile-language-server-nodejs \
ocaml-language-server \
bash-language-server \
stylelint \
stylelint-config-prettier \
prettier \
esy \
bsb-native \
bs-platform

####################
# GO
####################
set -gx GO111MODULE off

# Go buffalo
go get -u -v github.com/gobuffalo/buffalo/buffalo
go get github.com/gobuffalo/pop/...
go install github.com/gobuffalo/pop/soda

set -gx GO111MODULE on

# Go Language Server
# go install github.com/saibing/bingo
go get -u golang.org/x/tools/cmd/gopls

# Go multi linter
go get github.com/golangci/golangci-lint/cmd/golangci-lint
go get -u honnef.co/go/tools/cmd/staticcheck

go get github.com/mitchellh/gox

rm go.mod go.sum


####################
# PIP
####################
pip3 install -U -r pip3.txt

####################
#  GEM
####################
gem install --user-install tmuxinator
