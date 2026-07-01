#!/usr/bin/env python3
"""Quick-add an event to Google Calendar using natural language.

Uses the Calendar API events.quickAdd endpoint, so "dentist tomorrow 2pm" is
parsed by Google itself. Called by CalendarState.quickAddEvent(); the panel
re-syncs afterwards to pull the new event into khal.

    usage: gcal-add.py <natural language text...>
"""
import os
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gcal_common import API, api_post, get_token, primary_id  # noqa: E402


def main():
    text = " ".join(sys.argv[1:]).strip()
    if not text:
        return
    token = get_token()
    cal = primary_id(token)
    url = (API + "/calendars/" + urllib.parse.quote(cal) + "/events/quickAdd?"
           + urllib.parse.urlencode({"text": text}))
    ev = api_post(url, token)
    print("added:", ev.get("summary", text), ev.get("htmlLink", ""))


if __name__ == "__main__":
    main()
