import hashlib
from pathlib import Path
from urllib.request import Request, urlopen
import mk

SUBS = ["6782931965", "6782932139"]
SHOT = "/Users/iclibera/GitHub/minikrutin/screenshots/raw/02_summary.png"

def errs(r): return [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:2]

for sid in SUBS:
    print("\n== sub", sid, "==")

    # 1) 14-day free trial introductory offer (all territories)
    offer = mk.req("POST", "/subscriptionIntroductoryOffers", {
        "data": {"type": "subscriptionIntroductoryOffers",
                 "attributes": {"duration": "TWO_WEEKS", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    print("intro offer:", "OK" if not offer.get("error") else (offer.get("status"), errs(offer)))

    # 2) Review screenshot (clears "Missing Metadata")
    data = Path(SHOT).read_bytes()
    res = mk.req("POST", "/subscriptionAppStoreReviewScreenshots", {
        "data": {"type": "subscriptionAppStoreReviewScreenshots",
                 "attributes": {"fileName": "paywall.png", "fileSize": len(data)},
                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    if res.get("error"):
        print("review screenshot reserve:", res.get("status"), errs(res)); continue
    rid = res["data"]["id"]
    for op in res["data"]["attributes"].get("uploadOperations", []):
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        rq = Request(op["url"], data=chunk, method=op.get("method", "PUT"))
        for h in op.get("requestHeaders", []):
            rq.add_header(h["name"], h["value"])
        with urlopen(rq):
            pass
    c = mk.req("PATCH", f"/subscriptionAppStoreReviewScreenshots/{rid}", {
        "data": {"type": "subscriptionAppStoreReviewScreenshots", "id": rid,
                 "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print("review screenshot:", "OK" if not c.get("error") else (c.get("status"), errs(c)))

    # 3) Report state
    s = mk.req("GET", f"/subscriptions/{sid}")
    print("state:", s.get("data", {}).get("attributes", {}).get("state"))

print("\nDONE")
