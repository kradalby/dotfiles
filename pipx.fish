#!/usr/bin/env fish

for pkg in ansible gitlint tox black flake8 pylint pyre-check autopep8 awscli
    pipx install $pkg
end
