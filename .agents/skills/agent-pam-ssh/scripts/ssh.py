#!/usr/bin/env python3
"""SSH as agent_pam_access using Kanidm API tokens and browserless opkssh."""

import argparse
import base64
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import http.cookiejar

SERVICE_ACCOUNT = "agent_pam_access"
MANAGER = "xin"
ACCOUNT_ID = "a9b5e8c8-1f96-49ca-911b-b8dcd737da86"
ISSUER = "https://auth.xiny.li/oauth2/openid/opkssh"
AUDIENCE = "opkssh"
AUTH_BASE = "https://auth.xiny.li"
TOKEN_LIFETIME = dt.timedelta(hours=6)
RENEW_BEFORE_EXPIRY = 60
REPO_ROOT = Path(__file__).resolve().parents[4]
CACHE_DIR = REPO_ROOT / ".cache" / "agent-pam-ssh"
TOKEN_PATH = CACHE_DIR / "api-token"
KEY_PATH = CACHE_DIR / "id_ecdsa"
CERT_PATH = CACHE_DIR / "id_ecdsa-cert.pub"


def log(message):
    print(message, file=sys.stderr)


def atomic_write(path, content):
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def jwt_payload(token):
    try:
        encoded = token.split(".")[1]
        encoded += "=" * (-len(encoded) % 4)
        return json.loads(base64.urlsafe_b64decode(encoded))
    except (IndexError, ValueError, UnicodeDecodeError, json.JSONDecodeError):
        return {}


def cached_api_token():
    try:
        token = TOKEN_PATH.read_text().strip()
        payload = jwt_payload(token)
        expiry = int(payload.get("expiry", payload.get("exp", 0)))
        if (
            expiry > time.time() + RENEW_BEFORE_EXPIRY
            and payload.get("account_id") == ACCOUNT_ID
            and payload.get("purpose") == "readonly"
        ):
            return token
    except (FileNotFoundError, OSError, ValueError):
        pass
    return None


def certificate_is_valid():
    if not KEY_PATH.is_file() or not CERT_PATH.is_file():
        return False
    result = subprocess.run(
        ["opkssh", "inspect", str(CERT_PATH)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return False
    expiry = re.search(r"(?m)^(\d+) = .* = exp$", result.stdout)
    if not expiry:
        expiry = re.search(r'"exp":\s*(\d+)', result.stdout)
    audience = re.search(
        rf'"aud":\s*"{re.escape(AUDIENCE)}"|Audience:\s*{re.escape(AUDIENCE)}',
        result.stdout,
    )
    return bool(
        expiry
        and int(expiry.group(1)) > time.time() + RENEW_BEFORE_EXPIRY
        and ACCOUNT_ID in result.stdout
        and ISSUER in result.stdout
        and audience
    )


def issue_api_token():
    expiry = dt.datetime.now(dt.timezone.utc) + TOKEN_LIFETIME
    expiry_text = expiry.strftime("%Y-%m-%dT%H:%M:%SZ")
    result = subprocess.run(
        [
            "kanidm",
            "service-account",
            "api-token",
            "generate",
            "--name",
            MANAGER,
            SERVICE_ACCOUNT,
            "agent-pam-ssh",
            expiry_text,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip()
        if "Privileges have expired" in details:
            raise RuntimeError(
                "Kanidm privileges for xin have expired. "
                "Run `kanidm reauth -D xin` and retry."
            )
        raise RuntimeError(
            "Could not issue the API token. If xin's Kanidm session expired, "
            "run `kanidm login -D xin` and retry.\n" + details
        )
    match = re.search(
        r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",
        result.stdout,
    )
    if not match:
        raise RuntimeError("Kanidm did not return an API token in the expected format")
    token = match.group(0)
    payload = jwt_payload(token)
    if payload.get("account_id") != ACCOUNT_ID or payload.get("purpose") != "readonly":
        raise RuntimeError("Kanidm returned a token for an unexpected account or purpose")
    atomic_write(TOKEN_PATH, token)
    log(f"Issued a readonly API token; expires {expiry_text}.")
    return token


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        return None


def request_certificate(api_token):
    KEY_PATH.unlink(missing_ok=True)
    CERT_PATH.unlink(missing_ok=True)
    process = subprocess.Popen(
        [
            "opkssh",
            "login",
            "kanidm",
            "--disable-browser-open",
            "--private-key-file",
            str(KEY_PATH),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    try:
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        output = []
        login_url = None
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if not selector.select(deadline - time.monotonic()):
                break
            line = process.stdout.readline()
            if not line:
                break
            output.append(line)
            if "Open your browser to:" in line:
                login_url = line.split("Open your browser to:", 1)[1].strip()
                break
        if not login_url:
            raise RuntimeError(
                "opkssh did not start its local authorization listener:\n"
                + "".join(output).strip()
            )

        cookie_jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cookie_jar), NoRedirect()
        )

        def request(url, authenticate=False):
            headers = {"Authorization": f"Bearer {api_token}"} if authenticate else {}
            req = urllib.request.Request(url, headers=headers)
            try:
                with opener.open(req, timeout=20) as response:
                    return response.status, dict(response.headers), response.read()
            except urllib.error.HTTPError as error:
                return error.code, dict(error.headers), error.read()

        status, headers, _ = request(login_url)
        if status != 302:
            raise RuntimeError(f"Unexpected opkssh login response: HTTP {status}")
        authorization = urllib.parse.urlsplit(headers["Location"])
        authorize_url = urllib.parse.urlunsplit(
            (
                authorization.scheme,
                authorization.netloc,
                "/oauth2/authorise",
                authorization.query,
                "",
            )
        )
        status, headers, body = request(authorize_url, authenticate=True)
        if status == 200:
            consent = json.loads(body)["ConsentRequested"]
            permit_url = AUTH_BASE + "/oauth2/authorise/permit?" + urllib.parse.urlencode(
                {"token": consent["consent_token"]}
            )
            status, headers, _ = request(permit_url, authenticate=True)
        if status != 302:
            raise RuntimeError(f"Kanidm OIDC authorization failed: HTTP {status}")
        status, _, _ = request(headers["Location"])
        if status != 200:
            raise RuntimeError(f"opkssh callback failed: HTTP {status}")
        remaining = process.communicate(timeout=30)[0]
        output.append(remaining)
        if process.returncode != 0:
            raise RuntimeError("opkssh login failed:\n" + "".join(output).strip())
        if not certificate_is_valid():
            raise RuntimeError("opkssh produced an invalid or unexpected certificate")
        log("Issued a fresh opkssh certificate.")
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(
        description="SSH as agent_pam_access with cached Kanidm/opkssh credentials"
    )
    parser.add_argument("host", nargs="?", default="agate", help="default: agate")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="optional remote command")
    args = parser.parse_args()
    CACHE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(CACHE_DIR, 0o700)

    with (CACHE_DIR / "lock").open("a") as lock_file:
        os.chmod(lock_file.fileno(), 0o600)
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        if certificate_is_valid():
            log("Using the cached opkssh certificate.")
        else:
            api_token = cached_api_token() or issue_api_token()
            request_certificate(api_token)

    hostname = args.host if "." in args.host else f"{args.host}.u.xiny.li"
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    ssh = [
        "ssh",
        "-o",
        "IdentitiesOnly=yes",
        "-i",
        str(KEY_PATH),
        f"{SERVICE_ACCOUNT}@{hostname}",
        *command,
    ]
    os.execvp("ssh", ssh)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        log(f"agent-pam-ssh: {error}")
        sys.exit(1)
