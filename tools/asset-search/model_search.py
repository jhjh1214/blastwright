"""Search the Creator Store for free, script-free models and render a labelled thumbnail contact sheet.

Usage: python tools/asset-search/model_search.py <out.png> <keyword> [<keyword> ...]

Metadata filters (from the API, none guessed): type Model, free, hash-approved, hasScripts == false. (visibilityStatus is 1 for public models, unlike audio, so it is not filtered.)
Then every survivor's thumbnail is downloaded and tiled into one image with its number, so a human/Claude can
look at what the asset actually is before choosing. The printed table maps sheet numbers to asset ids.
A model is only ever *used* after this look plus the runtime script-stripping in Server/Props.luau.
"""
import io
import json
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

SEARCH = "https://apis.roblox.com/toolbox-service/v1/marketplace/10?limit=30&keyword={}"
DETAILS = "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds={}"
THUMBS = "https://thumbnails.roblox.com/v1/assets?assetIds={}&returnPolicy=PlaceHolder&size=250x250&format=Png&isCircular=false"
BLOCKLIST = ("minecraft", "fnaf", "undertale", "mario", "pokemon", "sonic", "zelda", "fortnite", "disney", "marvel",
             "nintendo", "among us", "half life", "skyrim", "doom", "halo")
MAX_ITEMS = 24


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "GameV1-asset-tool"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read()


def get_json(url):
    return json.loads(get(url))


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out, keywords = sys.argv[1], sys.argv[2:]

    # Round-robin across keywords so an early keyword cannot crowd out the rest.
    per_kw = [[i["id"] for i in get_json(SEARCH.format(urllib.parse.quote(kw))).get("data", [])] for kw in keywords]
    ordered = []
    for rank in range(max((len(x) for x in per_kw), default=0)):
        for ids in per_kw:
            if rank < len(ids) and ids[rank] not in ordered:
                ordered.append(ids[rank])

    rows, rejected = [], {"scripts": 0, "not free": 0, "not approved": 0, "ip name": 0, "other type": 0}
    for i in range(0, len(ordered), 40):
        for d in get_json(DETAILS.format(",".join(map(str, ordered[i : i + 40])))).get("data", []):
            a, c = d["asset"], d["creator"]
            name_l = a.get("name", "").lower()
            if a.get("typeId") != 10:
                rejected["other type"] += 1
            elif a.get("hasScripts"):
                rejected["scripts"] += 1
            elif not d.get("fiatProduct", {}).get("isFree"):
                rejected["not free"] += 1
            elif not a.get("isAssetHashApproved"):
                rejected["not approved"] += 1
            elif any(b in name_l for b in BLOCKLIST):
                rejected["ip name"] += 1
            else:
                rows.append((a["id"], a["name"], c["name"], c.get("isVerifiedCreator"), ordered.index(a["id"])))
    rows.sort(key=lambda r: r[4])
    rows = rows[:MAX_ITEMS]
    print(f"{len(rows)} candidates shown ({len(ordered)} searched; rejected {rejected})")

    thumbs = {}
    ids = [r[0] for r in rows]
    for i in range(0, len(ids), 20):
        for t in get_json(THUMBS.format(",".join(map(str, ids[i : i + 20])))).get("data", []):
            thumbs[t["targetId"]] = t.get("imageUrl") if t.get("state") == "Completed" else None

    cols, cell = 6, 250
    rows_n = max(1, (len(rows) + cols - 1) // cols)
    sheet = Image.new("RGB", (cols * cell, rows_n * (cell + 22)), (30, 30, 40))
    draw = ImageDraw.Draw(sheet)
    for n, (id_, name, creator, ver, _) in enumerate(rows):
        x, y = (n % cols) * cell, (n // cols) * (cell + 22)
        url = thumbs.get(id_)
        if url:
            try:
                img = Image.open(io.BytesIO(get(url))).convert("RGB").resize((cell, cell))
                sheet.paste(img, (x, y))
            except Exception as e:  # thumbnail failed: leave a blank tile
                draw.text((x + 6, y + 6), f"thumb error", fill=(255, 120, 120))
        else:
            draw.text((x + 6, y + 6), "no thumbnail", fill=(255, 200, 120))
        draw.rectangle((x, y, x + 30, y + 20), fill=(0, 0, 0))
        draw.text((x + 4, y + 4), str(n + 1), fill=(255, 255, 0))
        draw.text((x + 4, y + cell + 4), name[:34], fill=(230, 230, 240))
        print(f"  #{n + 1:>2}  {id_:>16}  {name[:46]:<46} by {creator}{' (verified)' if ver else ''}")
    sheet.save(out)
    print("sheet:", out)


if __name__ == "__main__":
    main()
