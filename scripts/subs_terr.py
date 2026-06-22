import mk

SUBS = ["6782931965", "6782932139"]
def errs(r): return [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:2]

for sid in SUBS:
    print("\n== sub", sid, "==")
    av = mk.req("GET", f"/subscriptions/{sid}/subscriptionAvailability")
    aid = av.get("data", {}).get("id") if not av.get("error") else None
    if aid:
        d = mk.req("DELETE", f"/subscriptionAvailabilities/{aid}")
        print("deleted old availability:", "OK" if not d.get("error") else (d.get("status"), errs(d)))
    # Turkey only
    new = mk.req("POST", "/subscriptionAvailabilities", {
        "data": {"type": "subscriptionAvailabilities",
                 "attributes": {"availableInNewTerritories": False},
                 "relationships": {
                     "subscription": {"data": {"type": "subscriptions", "id": sid}},
                     "availableTerritories": {"data": [{"type": "territories", "id": "TUR"}]}}}})
    print("new availability (TUR):", "OK" if not new.get("error") else (new.get("status"), errs(new)))
    s = mk.req("GET", f"/subscriptions/{sid}")
    print("state:", s.get("data", {}).get("attributes", {}).get("state"))

print("\nDONE")
