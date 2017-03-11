#!/usr/bin/env bash

extensions="Ionide.Ionide-fsharp
PeterJausovec.vscode-docker
abusaidm.html-snippets
bibhasdn.django-html
dbaeumer.vscode-eslint
donjayamanne.javadebugger
donjayamanne.python
eg2.tslint
eg2.vscode-npm-script
haaaad.ansible
hackwaly.ocaml
mrmlnc.vscode-stylefmt
ms-vscode.PowerShell
ms-vscode.cpptools
ms-vscode.csharp
msjsdiag.debugger-for-chrome
rbbit.typescript-hero
robertohuertasm.vscode-icons
sbrink.elm
seanmcbreen.Spell
akmittal.hugofy
shinnn.stylelint"

for ext in $extensions
do
    echo "Installing: $ext"
    code --install-extension $ext
done
