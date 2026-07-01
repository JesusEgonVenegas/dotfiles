"""Shared helpers for the Google Calendar <-> khal bridge.

Reuses the OAuth material vdirsyncer already obtained: the refresh token lives in
~/.local/share/vdirsyncer/google_token and the client id/secret in the vdirsyncer
config. We only ever need the Calendar REST API (CalDAV is blocked for OAuth
clients), and the refresh token means no more browser logins.
"""
import json
import os
import re
import time
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
TOKEN_FILE = os.path.join(HOME, ".local/share/vdirsyncer/google_token")
VD_CONFIG = os.path.join(HOME, ".config/vdirsyncer/config")
CAL_DIR = os.path.join(HOME, ".local/share/calendars")
API = "https://www.googleapis.com/calendar/v3"
REFRESH_URL = "https://oauth2.googleapis.com/token"


def _creds():
    txt = open(VD_CONFIG).read()
    cid = re.search(r'client_id\s*=\s*"([^"]+)"', txt).group(1)
    sec = re.search(r'client_secret\s*=\s*"([^"]+)"', txt).group(1)
    return cid, sec


def get_token():
    """Return a valid access token, refreshing (and re-persisting) if needed."""
    d = json.load(open(TOKEN_FILE))
    if d.get("access_token") and d.get("expires_at", 0) > time.time() + 60:
        return d["access_token"]

    cid, sec = _creds()
    body = urllib.parse.urlencode({
        "client_id": cid, "client_secret": sec,
        "refresh_token": d["refresh_token"], "grant_type": "refresh_token",
    }).encode()
    with urllib.request.urlopen(urllib.request.Request(REFRESH_URL, data=body)) as r:
        tok = json.load(r)
    d["access_token"] = tok["access_token"]
    d["expires_at"] = time.time() + tok.get("expires_in", 3600)
    # Google doesn't re-issue the refresh token on refresh — keep the old one.
    tmp = TOKEN_FILE + ".tmp"
    json.dump(d, open(tmp, "w"))
    os.replace(tmp, TOKEN_FILE)
    return d["access_token"]


def api_get(url, token):
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def api_post(url, token):
    req = urllib.request.Request(url, data=b"", method="POST",
                                 headers={"Authorization": "Bearer " + token,
                                          "Content-Length": "0"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def calendars(token):
    return api_get(API + "/users/me/calendarList", token).get("items", [])


def primary_id(token):
    for c in calendars(token):
        if c.get("primary"):
            return c["id"]
    return "primary"
