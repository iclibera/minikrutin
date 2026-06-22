import mk

SUBS = {"6782931965": 99.99, "6782932139": 699.99}

terr = mk.req("GET", "/territories?limit=200")
ids = [t["id"] for t in terr.get("data", [])]
print("territories:", len(ids))

def errs(r): return [e.get("detail") for e in r.get("errors", [])][:1]

for sid, target in SUBS.items():
    print("\n== sub", sid, "==")
    # 1) Availability (all territories)
    av = mk.req("POST", "/subscriptionAvailabilities", {
        "data": {"type": "subscriptionAvailabilities",
                 "attributes": {"availableInNewTerritories": True},
                 "relationships": {
                     "subscription": {"data": {"type": "subscriptions", "id": sid}},
                     "availableTerritories": {"data": [{"type": "territories", "id": i} for i in ids]}}}})
    print("availability:", "OK" if not av.get("error") else (av.get("status"), errs(av)))

    # 2) Price (closest TUR point to target)
    pp = mk.req("GET", f"/subscriptions/{sid}/pricePoints?filter[territory]=TUR&limit=8000")
    pts = pp.get("data", [])
    best = min(pts, key=lambda p: abs(float(p["attributes"].get("customerPrice", "0")) - target))
    print("price point:", best["attributes"].get("customerPrice"))
    pr = mk.req("POST", "/subscriptionPrices", {
        "data": {"type": "subscriptionPrices",
                 "attributes": {"preserveCurrentPrice": False},
                 "relationships": {
                     "subscription": {"data": {"type": "subscriptions", "id": sid}},
                     "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": best["id"]}}}}})
    print("price:", "OK" if not pr.get("error") else (pr.get("status"), errs(pr)))

print("\nDONE")
