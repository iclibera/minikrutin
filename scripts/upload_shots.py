import hashlib
from pathlib import Path
from urllib.request import Request, urlopen
import mk

VER_LOC = "c65539ff-2ed1-40a1-848b-59ef92732fb3"
DISPLAY = "APP_IPHONE_67"
RAW = "/Users/iclibera/GitHub/minikrutin/screenshots/raw"
SHOTS = ["01_today", "02_summary", "03_report", "05_quicklog", "06_feeding"]

cfg = mk.cfg()

# Reuse or create the set.
sets = mk.asc_api.get_screenshot_sets(cfg, VER_LOC)
set_id = next((s["id"] for s in sets if s["attributes"].get("screenshotDisplayType") == DISPLAY), None)
if not set_id:
    set_id = mk.asc_api.create_screenshot_set(cfg, VER_LOC, DISPLAY)["data"]["id"]

# Clear any half-reserved screenshots in the set.
existing = mk.req("GET", f"/appScreenshotSets/{set_id}/appScreenshots")
for sc in existing.get("data", []):
    mk.req("DELETE", f"/appScreenshots/{sc['id']}")

def upload(path):
    data = Path(path).read_bytes()
    name = Path(path).name
    body = {"data": {"type": "appScreenshots",
                     "attributes": {"fileName": name, "fileSize": len(data)},
                     "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}}
    r = mk.req("POST", "/appScreenshots", body)
    if r.get("error"):
        print("reserve error", name, r); return False
    sid = r["data"]["id"]
    for op in r["data"]["attributes"].get("uploadOperations", []):
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        rq = Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        for h in op.get("requestHeaders", []):
            rq.add_header(h["name"], h["value"])
        with urlopen(rq):
            pass
    md5 = hashlib.md5(data).hexdigest()
    c = mk.req("PATCH", f"/appScreenshots/{sid}",
               {"data": {"type": "appScreenshots", "id": sid,
                         "attributes": {"uploaded": True, "sourceFileChecksum": md5}}})
    if c.get("error"):
        print("commit error", name, c); return False
    print("uploaded", name)
    return True

ok = all(upload(f"{RAW}/{n}.png") for n in SHOTS)
print("ALL OK" if ok else "SOME FAILED")
