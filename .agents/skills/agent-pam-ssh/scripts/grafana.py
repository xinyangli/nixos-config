#!/usr/bin/env python3
"""Log in to Grafana as agent_pam_access and query metrics/logs.

Grafana is the OIDC client (it generates its own PKCE challenge), so the
agent only acts as the user-agent: follow Grafana's login redirect into
Kanidm, authenticate API calls with the agent_pam_access Kanidm token
(reusing ssh.py's cache), answer the consent prompt, and let Grafana
complete the code exchange. The resulting grafana_session cookie is cached
under .cache/agent-pam-ssh/.
"""

import argparse
import importlib.util
import json
import sys
import time
import urllib.parse
from http.cookiejar import MozillaCookieJar
from pathlib import Path

import requests

GRAFANA = "https://grafana.xiny.li"
AUTH_HOSTS = ("auth.xiny.li",)

spec = importlib.util.spec_from_file_location(
    "pamssh", Path(__file__).resolve().parent / "ssh.py"
)
pamssh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pamssh)

COOKIE_PATH = pamssh.CACHE_DIR / "grafana-cookies"
MAX_REDIRECTS = 15


def log(message):
    print(message, file=sys.stderr)


def load_cached_session(session):
    if not COOKIE_PATH.is_file():
        return False
    jar = MozillaCookieJar(COOKIE_PATH)
    try:
        jar.load(ignore_discard=True)
    except OSError:
        return False
    for cookie in jar:
        session.cookies.set_cookie(cookie)
    try:
        response = session.get(f"{GRAFANA}/api/user", timeout=15)
        if response.status_code == 200:
            return True
    except requests.RequestException:
        pass
    session.cookies.clear()
    return False


def save_session(session):
    jar = MozillaCookieJar(COOKIE_PATH)
    for cookie in session.cookies:
        jar.set_cookie(cookie)
    jar.save(ignore_discard=True)
    try:
        COOKIE_PATH.chmod(0o600)
    except OSError:
        pass


def consent_token(body):
    try:
        data = json.loads(body)
    except (ValueError, TypeError):
        return None
    return (data.get("ConsentRequested") or {}).get("consent_token")


def login(session):
    """Drive Grafana's OAuth login to a session cookie."""
    api_token = pamssh.cached_api_token() or pamssh.issue_api_token()
    headers = {"Authorization": f"Bearer {api_token}"}

    url = f"{GRAFANA}/login/generic_oauth"
    for _ in range(MAX_REDIRECTS):
        parts = urllib.parse.urlsplit(url)
        if parts.netloc in AUTH_HOSTS and parts.path.startswith("/ui/oauth2"):
            # /ui/oauth2 rejects Bearer identities; the API endpoint accepts them.
            url = urllib.parse.urlunsplit(
                (parts.scheme, parts.netloc, "/oauth2/authorise", parts.query, "")
            )
        try:
            if parts.netloc in AUTH_HOSTS:
                response = session.get(
                    url, headers=headers, allow_redirects=False, timeout=30
                )
            else:
                response = session.get(url, allow_redirects=False, timeout=30)
        except requests.RequestException as error:
            raise RuntimeError(f"login request failed: {error}") from error

        host = urllib.parse.urlsplit(url).netloc
        if response.status_code == 200 and host in AUTH_HOSTS:
            token = consent_token(response.content)
            if token:
                query = urllib.parse.urlencode({"token": token})
                url = f"https://{host}/oauth2/authorise/permit?{query}"
                continue
            raise RuntimeError(
                "Kanidm returned an unexpected consent page; "
                "authorise in a browser once and retry"
            )

        if response.is_redirect:
            location = response.headers["Location"]
            url = urllib.parse.urljoin(url, location)
            continue

        if host in AUTH_HOSTS:
            raise RuntimeError(
                f"Kanidm authorise returned HTTP {response.status_code}"
            )

        # Landed on Grafana without a redirect; exchange is done.
        break
    else:
        raise RuntimeError("login redirect loop exceeded limit")

    response = session.get(f"{GRAFANA}/api/user", timeout=15)
    if response.status_code != 200:
        raise RuntimeError(
            f"Grafana login did not yield a usable session: HTTP {response.status_code}"
        )


def grafana_session(refresh=False):
    session = requests.Session()
    pamssh.CACHE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not refresh and load_cached_session(session):
        log("Using the cached Grafana session.")
        return session
    login(session)
    save_session(session)
    log("Established a fresh Grafana session.")
    return session


def grafana_api(session):
    """grafana-client authenticated with the OIDC session's cookies."""
    try:
        from grafana_client import GrafanaApi
    except ImportError as error:
        raise RuntimeError(
            "grafana-client is required; run inside the repo devShell"
        ) from error
    api = GrafanaApi(auth=None, host="grafana.xiny.li", protocol="https")
    for cookie in session.cookies:
        api.client.s.cookies.set_cookie(cookie)
    return api


def cmd_user(session, _args):
    api = grafana_api(session)
    user = api.user.get_actual_user()
    orgs = api.user.get_actual_user_organisations()
    print(
        json.dumps(
            {"user": user.get("login"), "orgs": [org.get("name") for org in orgs]}
        )
    )


def cmd_datasources(session, _args):
    api = grafana_api(session)
    for source in api.datasource.list_datasources():
        print(f"{source['uid']}\t{source['type']}\t{source['name']}")


def cmd_query(session, args):
    """Instant PromQL query through the datasource proxy."""
    params = {"query": args.expr, "time": str(int(time.time()))}
    response = session.get(
        f"{GRAFANA}/api/datasources/proxy/uid/{args.uid}/api/v1/query",
        params=params,
        timeout=30,
    )
    print(json.dumps(response.json(), indent=None))


def cmd_logs(session, args):
    """Range LogQL query (last 15 minutes) through the datasource proxy."""
    end = int(time.time() * 1e9)
    start = end - 15 * 60 * 10**9
    params = {
        "query": args.expr,
        "limit": str(args.limit),
        "start": str(start),
        "end": str(end),
    }
    response = session.get(
        f"{GRAFANA}/api/datasources/proxy/uid/{args.uid}/loki/api/v1/query_range",
        params=params,
        timeout=30,
    )
    data = response.json()
    for stream in data.get("data", {}).get("result", []):
        labels = json.dumps(stream.get("stream", {}))
        for timestamp, line in stream.get("values", []):
            print(f"{labels}\t{line}")


def main():
    parser = argparse.ArgumentParser(
        description="Query Grafana metrics/logs as agent_pam_access"
    )
    parser.add_argument(
        "--refresh", action="store_true", help="ignore the cached session"
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    subcommands.add_parser("user", help="show the current Grafana user/org")
    subcommands.add_parser("datasources", help="list datasources")

    query = subcommands.add_parser("query", help="instant PromQL query")
    query.add_argument("uid", help="datasource uid")
    query.add_argument("expr", help="PromQL expression")

    logs = subcommands.add_parser("logs", help="instant LogQL query")
    logs.add_argument("uid", help="datasource uid")
    logs.add_argument("expr", help="LogQL expression")
    logs.add_argument("--limit", type=int, default=50)

    args = parser.parse_args()
    handlers = {
        "user": cmd_user,
        "datasources": cmd_datasources,
        "query": cmd_query,
        "logs": cmd_logs,
    }
    session = grafana_session(refresh=args.refresh)
    handlers[args.command](session, args)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, requests.RequestException) as error:
        log(f"grafana: {error}")
        sys.exit(1)
