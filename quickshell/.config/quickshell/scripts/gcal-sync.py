#!/usr/bin/env python3
"""Pull Google Calendar events into local .ics vdirs for khal (offline reads).

One-way mirror: each selected Google calendar becomes a directory under
~/.local/share/calendars/ containing one .ics per event instance (recurring
events expanded via singleEvents). Each run wipes + rewrites, so deletions and
edits on Google propagate. Writes back to Google happen via gcal-add.py.

Run by the gcal-sync.service systemd unit (timer) and on panel open.
"""
import os
import re
import sys
import urllib.parse
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gcal_common import API, CAL_DIR, api_get, calendars, get_token  # noqa: E402

DAYS = 400


def slug(s):
    return re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower() or "cal"


def esc(t):
    return (t.replace("\\", "\\\\").replace("\n", "\\n")
             .replace(";", "\\;").replace(",", "\\,"))


def fmt(key, val):
    # All-day events carry {"date": "YYYY-MM-DD"}; timed carry RFC3339 dateTime.
    if "date" in val:
        return "%s;VALUE=DATE:%s" % (key, val["date"].replace("-", ""))
    dt = datetime.fromisoformat(val["dateTime"]).astimezone(timezone.utc)
    return "%s:%s" % (key, dt.strftime("%Y%m%dT%H%M%SZ"))


def write_event(cal_dir, ev):
    if ev.get("status") == "cancelled" or "start" not in ev:
        return
    uid = ev.get("iCalUID") or ev.get("id")
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//gcal-sync//EN",
             "BEGIN:VEVENT", "UID:" + uid,
             "SUMMARY:" + esc(ev.get("summary", "(no title)")),
             fmt("DTSTART", ev["start"]), fmt("DTEND", ev.get("end", ev["start"]))]
    if ev.get("location"):
        lines.append("LOCATION:" + esc(ev["location"]))
    if ev.get("description"):
        lines.append("DESCRIPTION:" + esc(ev["description"]))
    lines += ["END:VEVENT", "END:VCALENDAR"]
    fn = re.sub(r"[^A-Za-z0-9]+", "_", uid)[:80] + ".ics"
    with open(os.path.join(cal_dir, fn), "w") as f:
        f.write("\r\n".join(lines) + "\r\n")


def sync():
    token = get_token()
    now = datetime.now(timezone.utc)
    tmin = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    tmax = (now + timedelta(days=DAYS)).strftime("%Y-%m-%dT%H:%M:%SZ")
    os.makedirs(CAL_DIR, exist_ok=True)

    n_cal = n_ev = 0
    for c in calendars(token):
        if not c.get("selected"):
            continue
        n_cal += 1
        d = os.path.join(CAL_DIR, slug(c.get("summary", c["id"])))
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith(".ics"):
                os.remove(os.path.join(d, f))
        # vdir metadata so khal shows a nice name / colour.
        with open(os.path.join(d, "displayname"), "w") as fh:
            fh.write(c.get("summary", ""))
        if c.get("backgroundColor"):
            with open(os.path.join(d, "color"), "w") as fh:
                fh.write(c["backgroundColor"])

        params = {"singleEvents": "true", "orderBy": "startTime",
                  "timeMin": tmin, "timeMax": tmax, "maxResults": "2500"}
        base = API + "/calendars/" + urllib.parse.quote(c["id"]) + "/events?"
        url = base + urllib.parse.urlencode(params)
        while url:
            page = api_get(url, token)
            for ev in page.get("items", []):
                write_event(d, ev)
                n_ev += 1
            nxt = page.get("nextPageToken")
            url = base + urllib.parse.urlencode(dict(params, pageToken=nxt)) if nxt else None

    print("gcal-sync: %d calendars, %d events" % (n_cal, n_ev))


if __name__ == "__main__":
    sync()
