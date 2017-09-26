#!/usr/bin/env bash

extensions="Ionide.Ionide-fsharp
James-Yu.latex-workshop
PeterJausovec.vscode-docker
Zignd.html-css-class-completion
abusaidm.html-snippets
be5invis.toml
bibhasdn.django-html
christian-kohler.path-intellisense
dbaeumer.vscode-eslint
donjayamanne.javadebugger
donjayamanne.python
eg2.tslint
eg2.vscode-npm-script
freebroccolo.reasonml
haaaad.ansible
mrmlnc.vscode-stylefmt
ms-vscode.cpptools
ms-vscode.csharp
ms-vscode.PowerShell
msjsdiag.debugger-for-chrome
rbbit.typescript-hero
robertohuertasm.vscode-icons
saviorisdead.RustyCode
sbrink.elm
shinnn.stylelint"

for ext in $extensions
do
    echo "Installing: $ext"
    code --install-extension $ext
done
