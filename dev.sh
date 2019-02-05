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
eslint \
git-open \
vscode-css-languageserver-bin \
yaml-language-server \
javascript-typescript-langserver 

####################
# GO
####################
go install github.com/saibing/bingo
rm go.mod go.sum


####################
# PIP
####################
pip3 install -U -r pip3.txt
