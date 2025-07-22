#!/usr/bin/env python3
import time
import requests
import json

ENOWARS_URL = "https://9.enowars.com/scoreboard/scoreboard.json"
EXCLUDED_TEAMS = ["ENOOPFLAG"]

def fetch_enowars():
    resp = requests.get(ENOWARS_URL)
    resp.raise_for_status()
    return resp.json()

def to_ctftime_feed(enowars_json):
    teams = enowars_json.get("teams", [])
    feed = {
        "standings": []
    }

    ranking = 1
    for idx, team in enumerate(sorted(teams, key=lambda t: t["totalScore"], reverse=True)):
        if team['teamName'].lower() in list(map(lambda x: x.lower(), EXCLUDED_TEAMS)):
            continue
        entry = {
            "pos": ranking,
            "team": team["teamName"],
            "score": round(team["totalScore"], 4)
        }
        feed["standings"].append(entry)
        ranking +=1
    return feed

def main():
    enowars = fetch_enowars()
    ctftime = to_ctftime_feed(enowars)
    print(json.dumps(ctftime, indent=2))
    with open("scoreboard.json", "w") as f:
        json.dump(ctftime, f, indent=2)

if __name__ == "__main__":
    main()