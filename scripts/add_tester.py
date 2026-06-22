import mk

APP_ID = "6782930552"
EMAIL = "selimmurselyavuz@gmail.com"
FIRST, LAST = "Selim", "Yavuz"

def errs(r): return [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:3]

# 1) Already a user?
users = mk.req("GET", f"/users?limit=200")
uid = next((u["id"] for u in users.get("data", []) if (u["attributes"].get("username") or "").lower() == EMAIL.lower()), None)
print("existing user:", uid)

# Pending invitations?
inv = mk.req("GET", "/userInvitations?limit=200")
pending = next((i for i in inv.get("data", []) if (i["attributes"].get("email") or "").lower() == EMAIL.lower()), None)

if not uid and not pending:
    r = mk.req("POST", "/userInvitations", {
        "data": {"type": "userInvitations",
                 "attributes": {"email": EMAIL, "firstName": FIRST, "lastName": LAST,
                                "roles": ["MARKETING"], "allAppsVisible": False, "provisioningAllowed": False},
                 "relationships": {"visibleApps": {"data": [{"type": "apps", "id": APP_ID}]}}}})
    print("invite:", "OK" if not r.get("error") else (r.get("status"), errs(r)))
else:
    print("invite skipped (user or pending invite exists)")

# 2) Internal beta group
groups = mk.req("GET", f"/apps/{APP_ID}/betaGroups?limit=200")
gid = next((g["id"] for g in groups.get("data", []) if g["attributes"].get("isInternalGroup")), None)
if not gid:
    g = mk.req("POST", "/betaGroups", {
        "data": {"type": "betaGroups",
                 "attributes": {"name": "MinikRutin İç Test", "isInternalGroup": True, "hasAccessToAllBuilds": True},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
    if g.get("error"):
        print("group create:", g.get("status"), errs(g))
        # retry without hasAccessToAllBuilds
        g = mk.req("POST", "/betaGroups", {
            "data": {"type": "betaGroups",
                     "attributes": {"name": "MinikRutin İç Test", "isInternalGroup": True},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})
        print("group create retry:", "OK" if not g.get("error") else (g.get("status"), errs(g)))
    gid = g.get("data", {}).get("id")
print("internal group:", gid)

# 3) Add beta tester to the internal group
if gid:
    t = mk.req("POST", "/betaTesters", {
        "data": {"type": "betaTesters",
                 "attributes": {"email": EMAIL, "firstName": FIRST, "lastName": LAST},
                 "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}})
    print("betaTester add:", "OK" if not t.get("error") else (t.get("status"), errs(t)))
print("DONE")
