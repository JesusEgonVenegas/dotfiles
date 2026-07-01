#!/usr/bin/env python3
"""Delete a Google Calendar event, given its iCalUID (what khal exposes as {uid}).

Resolves the UID to a Google event id via events.list?iCalUID= and deletes it.
Only searches calendars you can write to, so read-only ones (e.g. holidays)
are left alone. Called by CalendarState.deleteEvent(); the panel re-syncs after.

    usage: gcal-del.py <iCalUID>
"""
import os
import sys
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gcal_common import API, api_get, calendars, get_token  # noqa: E402


def main():
    uid = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not uid:
        return
    token = get_token()
    for c in calendars(token):
        if c.get("accessRole") not in ("owner", "writer"):
            continue
        cal = c["id"]
        url = (API + "/calendars/" + urllib.parse.quote(cal) + "/events?"
               + urllib.parse.urlencode({"iCalUID": uid, "showDeleted": "false"}))
        for e in api_get(url, token).get("items", []):
            req = urllib.request.Request(
                API + "/calendars/" + urllib.parse.quote(cal) + "/events/" + e["id"],
                method="DELETE", headers={"Authorization": "Bearer " + token})
            urllib.request.urlopen(req)
            print("deleted:", e.get("summary", uid))
            return
    print("not found in a writable calendar:", uid)


if __name__ == "__main__":
    main()
