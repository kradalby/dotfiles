#!/usr/bin/env bash

extensions="Ionide.Ionide-fsharp
PeterJausovec.vscode-docker
abusaidm.html-snippets
bibhasdn.django-html
dbaeumer.vscode-eslint
donjayamanne.python
eg2.tslint
mrmlnc.vscode-stylefmt
ms-vscode.PowerShell
ms-vscode.cpptools
ms-vscode.csharp
msjsdiag.debugger-for-chrome
rbbit.typescript-hero
robertohuertasm.vscode-icons
shinnn.stylelint"

for ext in $extensions
do
    echo "Installing: $ext"
    code --install-extension $ext
done
