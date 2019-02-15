#!/usr/bin/env fish

# https://github.com/vscode-langservers/vscode-css-languageserver-bin
# https://github.com/redhat-developer/yaml-language-server
# https://github.com/sourcegraph/javascript-typescript-langserver


####################
# NODE
####################
npm update --global \
typescript \
npm-check \
elm-format \
eslint \
git-open \
diff-so-fancy \
yarn \
vscode-css-languageserver-bin \
yaml-language-server \
javascript-typescript-langserver

####################
# GO
####################
set -x GO111MODULE off

# Go buffalo
go get -u -v github.com/gobuffalo/buffalo/buffalo
go get github.com/gobuffalo/pop/...
go install github.com/gobuffalo/pop/soda

set -x GO111MODULE on

# Go Language Server
go install github.com/saibing/bingo
rm go.mod go.sum


####################
# PIP
####################
pip3 install -U -r pip3.txt
