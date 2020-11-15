#!/usr/bin/env sh

pipx install poetry
# https://github.com/pipxproject/pipx/issues/20#issuecomment-705683989
pipx install ansible-base
pipx install ansible-lint
pipx inject pipx ansible
pipx install gitlint
pipx install tox
pipx install black
pipx install flake8
pipx install pylint
pipx install pyre-check
pipx install autopep8
pipx install awscli
