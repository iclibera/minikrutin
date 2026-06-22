import mk

MONTHLY = "6782931965"
YEARLY = "6782932139"

def show(label, r):
    if r.get("error"):
        print(label, "ERROR", r.get("status"), [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:2])
    else:
        print(label, "OK", r.get("data", {}).get("id"))
    return r

# 1) Monthly localization (<=55 char description)
show("monthly loc", mk.req("POST", "/subscriptionLocalizations", {
    "data": {"type": "subscriptionLocalizations",
             "attributes": {"name": "Premium Aylık",
                            "description": "Aylık premium: rapor, grafikler, aile paylaşımı.",
                            "locale": "tr"},
             "relationships": {"subscription": {"data": {"type": "subscriptions", "id": MONTHLY}}}}}))

# 2) Prices — pick the closest TUR price point, body with relationships only
def set_price(sid, target):
    pp = mk.req("GET", f"/subscriptions/{sid}/pricePoints?filter[territory]=TUR&limit=8000")
    pts = pp.get("data", [])
    if not pts:
        print(sid, "no price points"); return
    def pof(pt):
        try: return float(pt["attributes"].get("customerPrice", "0"))
        except: return 0.0
    best = min(pts, key=lambda pt: abs(pof(pt) - target))
    print(sid, "price point", best["attributes"].get("customerPrice"))
    show(f"price {sid}", mk.req("POST", "/subscriptionPrices", {
        "data": {"type": "subscriptionPrices",
                 "relationships": {
                     "subscription": {"data": {"type": "subscriptions", "id": sid}},
                     "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": best["id"]}}}}}))

set_price(MONTHLY, 99.99)
set_price(YEARLY, 699.99)
print("DONE")
