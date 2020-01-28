#!/usr/bin/env fish

for pkg in ansible gitlint tox black flake8 pylint pyre-check autopep8
    pipx install $pkg
end
