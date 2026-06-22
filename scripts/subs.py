import json, mk

APP_ID = "6782930552"
cfg = mk.cfg()

def show(label, r):
    if r.get("error"):
        errs = r.get("errors", [])
        print(label, "ERROR", r.get("status"), [(e.get("code"), e.get("detail")) for e in errs][:2])
        return None
    print(label, "OK", r.get("data", {}).get("id"))
    return r["data"]["id"]

# 1) Subscription group
grp = mk.req("POST", "/subscriptionGroups", {
    "data": {"type": "subscriptionGroups",
             "attributes": {"referenceName": "MinikRutin Premium"},
             "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
# Reuse if it already exists
if grp.get("error"):
    existing = mk.req("GET", f"/apps/{APP_ID}/subscriptionGroups")
    gid = existing.get("data", [{}])[0].get("id") if existing.get("data") else None
    print("group exists/reuse:", gid)
else:
    gid = grp["data"]["id"]
    print("group created:", gid)

if not gid:
    print("No group; aborting."); raise SystemExit

# group localization (display name)
gl = mk.req("POST", "/subscriptionGroupLocalizations", {
    "data": {"type": "subscriptionGroupLocalizations",
             "attributes": {"name": "MinikRutin Premium", "locale": "tr"},
             "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
show("group localization", gl)

PRODUCTS = [
    {"productId": "com.iclibera.minikrutin.premium.monthly", "name": "Premium Aylik",
     "period": "ONE_MONTH", "display": "Premium Aylık",
     "desc": "PDF doktor raporu, gelişmiş grafikler, hatırlatmalar ve aile paylaşımı.", "target": 99.99},
    {"productId": "com.iclibera.minikrutin.premium.yearly", "name": "Premium Yillik",
     "period": "ONE_YEAR", "display": "Premium Yıllık",
     "desc": "Tüm premium özellikler, yıllık avantajlı fiyatla.", "target": 699.99},
]

for p in PRODUCTS:
    print("\n==", p["productId"], "==")
    sub = mk.req("POST", "/subscriptions", {
        "data": {"type": "subscriptions",
                 "attributes": {"name": p["name"], "productId": p["productId"],
                                "subscriptionPeriod": p["period"], "familySharable": True,
                                "groupLevel": 1},
                 "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
    sid = show("subscription", sub)
    if not sid:
        # maybe exists already; look it up
        subs = mk.req("GET", f"/subscriptionGroups/{gid}/subscriptions")
        sid = next((s["id"] for s in subs.get("data", []) if s["attributes"].get("productId") == p["productId"]), None)
        print("reuse subscription:", sid)
    if not sid:
        continue

    # localization
    sl = mk.req("POST", "/subscriptionLocalizations", {
        "data": {"type": "subscriptionLocalizations",
                 "attributes": {"name": p["display"], "description": p["desc"], "locale": "tr"},
                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    show("localization", sl)

    # price points for Turkey
    pp = mk.req("GET", f"/subscriptions/{sid}/pricePoints?filter[territory]=TUR&limit=8000&include=territory")
    pts = pp.get("data", [])
    if not pts:
        print("NO PRICE POINTS (Paid Apps Agreement may be required)"); continue
    def price_of(pt):
        try: return float(pt["attributes"].get("customerPrice", "0"))
        except: return 0.0
    best = min(pts, key=lambda pt: abs(price_of(pt) - p["target"]))
    print("chosen price point:", best["id"], best["attributes"].get("customerPrice"))

    pr = mk.req("POST", "/subscriptionPrices", {
        "data": {"type": "subscriptionPrices",
                 "attributes": {"startDate": None, "preserveCurrentPrice": False},
                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                   "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": best["id"]}}}}})
    show("price", pr)

print("\nDONE")
