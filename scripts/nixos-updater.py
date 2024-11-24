import requests
import os
import socket
import json
from os import path as osp
from dataclasses import dataclass

"""
This updater consists of several parts: 

- Update checker: Check an url for update (if outPath is different from /run/current-system or some specified profile) or maybe use timestamp for update
- Nix copy --from: copy from remote. Need to specify remote url.
- Create a symlink: /run/next-system -> <new system derivation>
- Listen for POST request to trigger system switch (optional)
"""


@dataclass
class GarnixConfig:
    token: str


@dataclass
class Config:
    check_type: str
    check_url: str
    remote_url: str
    garnix: GarnixConfig
    hostname: str = socket.gethostname()


class Nix:
    def __init__(self, args):
        self.args = args

    def copy_from_remote(self):
        # run nix copy with subprocess
        pass

    def eval(self):


class Updater:
    def __init__(self, config: Config):
        self.config = config

        # TODO: Make this configurable
        self.current_drv = os.readlink("/run/current-system")
        self.next_dev = None

    # checkers take an url and returns the outPath of the latest success build
    def garnix_checker(self) -> str:
        domain = "garnix.io"
        build_endpoint = "/api/build/commit"

        # Latest commit from git

        # Check build status of this commit
        resp = requests.get(
            f"https://{domain}{build_endpoint}/40b1e9ff23aaa5f555420dd22414c3f137a02cfe"
        )
        # Raise error if status code is not valid

        # Fetch outPath from eval endpoint
        # TODO: In theory, this could be done by parsing raw log from garnix.

        # Try to evaluate locally if eval endpoint is not configured

        resp = resp.json()
        # TODO
        return "null"

    def hydra_checker(self) -> str:
        # TODO
        return "null"

    # Check for update
    def poll(self) -> str | None:
        cfg = self.config
        if cfg.check_type == "garnix":
            pass
        elif cfg.check_type == "hydra":
            pass
        else:
            pass
        pass


if __name__ == "__main__":
    pass
