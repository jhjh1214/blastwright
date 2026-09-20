"""Search the Roblox Creator Store for short, free, non-music audio and print vetted candidates.

Usage: python tools/asset-search/audio_search.py <cue> <max_seconds> <keyword> [<keyword> ...] [--min=SECONDS] [--allow-music] [--library]
Writes nothing; prints a table. Filters (all from API metadata, none guessed):
  - typeId 3 (audio), free, no scripts flag
  - duration <= max_seconds (SFX, not tracks)
  - audioType SoundEffect or Unknown (uploader originals), no album, and artist is empty or the uploader themself.
    Label/distributor music always has an album and a different artist name, so it is rejected by this rule.
  - asset hash approved and publicly visible
  - name does not contain a well-known copyrighted game/franchise word (heuristic; a human still reviews)
  --library accepts Music-typed tracks WITH an album and a different artist (label/distributor uploads), but only from
  verified creators, and prints artist / album / audio type so a human can judge. It cannot prove licensing.
  --allow-music also accepts audioType "Music" (long loops are all typed that way) but only when there is no album and
  the artist is the uploader; provenance still cannot be audited from metadata, so review before use.
Duplicates across keywords are merged. Selection and registry entry stay a human/Claude decision.
"""
import json
import sys
import urllib.parse
import urllib.request

SEARCH = "https://apis.roblox.com/toolbox-service/v1/marketplace/3?limit=30&keyword={}"
DETAILS = "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds={}"


BLOCKLIST = ("half life", "minecraft", "fnaf", "undertale", "mario", "pokemon", "sonic", "zelda", "call of duty",
             "cod ", "fortnite", "valorant", "csgo", "counter strike", "portal", "halo", "doom", "skyrim", "gta",
             "among us", "sans", "tf2", "overwatch", "nintendo", "disney", "marvel")


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "GameV1-asset-tool"}), timeout=20) as r:
        return json.load(r)


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    allow_music = "--allow-music" in sys.argv
    library = "--library" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--min=") and a not in ("--allow-music", "--library")]
    min_secs = next((float(a[6:]) for a in sys.argv[1:] if a.startswith("--min=")), 0.15)
    cue, max_secs, keywords = args[0], float(args[1]), args[2:]

    ordered = []
    for kw in keywords:
        for item in get(SEARCH.format(urllib.parse.quote(kw))).get("data", []):
            if item["id"] not in ordered:
                ordered.append(item["id"])

    rows, rejected = [], {"music/artist": 0, "not approved": 0, "ip name": 0, "too long/short": 0, "not free": 0, "scripts": 0}
    for i in range(0, len(ordered), 40):
        batch = ordered[i : i + 40]
        for d in get(DETAILS.format(",".join(map(str, batch)))).get("data", []):
            a, c = d["asset"], d["creator"]
            ad = a.get("audioDetails", {})
            if a.get("typeId") != 3:
                continue
            name_l = a.get("name", "").lower()
            if not library and (ad.get("audioType") not in (("SoundEffect", "Unknown", "Music") if allow_music else ("SoundEffect", "Unknown")) or ad.get("musicAlbum") or ad.get("artist") not in ("", None, c["name"])):
                rejected["music/artist"] += 1
            elif library and (ad.get("audioType") not in ("Music", "Unknown") or not c.get("isVerifiedCreator")):
                rejected["music/artist"] += 1
            elif not a.get("isAssetHashApproved") or a.get("visibilityStatus") != 0:
                rejected["not approved"] += 1
            elif any(b in name_l for b in BLOCKLIST):
                rejected["ip name"] += 1
            elif not (min_secs <= a.get("duration", 0) <= max_secs):
                rejected["too long/short"] += 1
            elif not d.get("fiatProduct", {}).get("isFree"):
                rejected["not free"] += 1
            elif a.get("hasScripts"):
                rejected["scripts"] += 1
            else:
                rows.append((a["id"], a["name"], a.get("duration"), c["name"], c.get("isVerifiedCreator"), ordered.index(a["id"]), ad.get("artist"), ad.get("musicAlbum"), ad.get("audioType")))

    rows.sort(key=lambda r: r[5])
    print(f"CUE {cue}: {len(rows)} candidates ({len(ordered)} searched; rejected {rejected})")
    for id_, name, dur, creator, ver, rank, artist, album, atype in rows[:10]:
        extra = f" | artist={artist!r} album={(album or '')[:28]!r} type={atype}" if library else ""
        print(f"  {id_:>16}  {dur:>4}s  {name[:40]:<40} by {creator}{' (verified)' if ver else ''}{extra}")


if __name__ == "__main__":
    main()
