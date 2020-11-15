#!/usr/bin/env python3 -B

from github import Github  # https://github.com/PyGithub/PyGithub
import requests
import json
import sys
import os

gitea_url = "https://git.kradalby.no/api/v1"
gitea_token = os.environ["GITEA_MIRROR_TOKEN"]

github_username = "kradalby"
github_token = os.environ["GITHUB_MIRROR_TOKEN"]

ignore = ["G-Research"]

session = requests.Session()  # Gitea
session.headers.update(
    {
        "Content-type": "application/json",
        "Authorization": "token {0}".format(gitea_token),
    }
)

r = session.get("{0}/user".format(gitea_url))
if r.status_code != 200:
    print("Cannot get user details")
    exit(1)

gitea_uid = json.loads(r.text)["id"]
gh = Github(github_token)

for repo in gh.get_user().get_repos():
    # Mirror to Gitea if I haven't forked this repository from elsewhere
    ignore_repo = False

    if repo.organization and repo.organization.login not in ignore:
        name = repo.full_name.replace("/", "-")
    elif repo.owner and repo.owner.login == "kradalby":
        name = repo.name
    elif repo.owner and repo.owner.login not in ignore:
        name = repo.full_name.replace("/", "-")
    else:
        print(f"Ignoring: {repo.full_name}")
        ignore_repo = True

    if not ignore_repo and not repo.fork:
        print(f"Adding repo: {name}")
        m = {
            "repo_name": name,
            "description": repo.description or "not really known",
            "clone_addr": repo.clone_url,
            "mirror": True,
            "private": repo.private,
            "uid": gitea_uid,
        }

        if repo.private:
            m["auth_username"] = github_username
            m["auth_password"] = "{0}".format(github_token)

        jsonstring = json.dumps(m)

        r = session.post("{0}/repos/migrate".format(gitea_url), data=jsonstring)
        if r.status_code != 201:  # if not CREATED
            if r.status_code == 409:  # repository exists
                continue
            print(r.status_code, r.text, jsonstring)
