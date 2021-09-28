#!/usr/bin/env sh

pipx install poetry
# https://github.com/pipxproject/pipx/issues/20#issuecomment-705683989
pipx install ansible-core
pipx inject ansible-core toml
pipx install ansible-lint
pipx inject pipx ansible
# pipx install gitlint
# pipx install tox
pipx install black
# pipx install flake8
pipx install pylint
pipx install pyre-check
pipx install pygments
pipx install diffoscope
pipx install tldr
# pipx install autopep8
# :pipx install awscli

pipx install 'python-lsp-server[all]'
pipx inject python-lsp-server pyls-flake8 mypy-ls pyls-isort python-lsp-black pyls-memestra

pipx install jedi-language-server
