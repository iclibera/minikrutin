import mk

BUNDLE = "7K8S93RL7N"
def errs(r): return [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:3]

# Existing capabilities
cur = mk.req("GET", f"/bundleIds/{BUNDLE}/bundleIdCapabilities?limit=50")
have = {c["attributes"].get("capabilityType") for c in cur.get("data", [])}
print("current capabilities:", have)

if "APPLE_ID_AUTH" not in have:
    r = mk.req("POST", "/bundleIdCapabilities", {
        "data": {"type": "bundleIdCapabilities",
                 "attributes": {"capabilityType": "APPLE_ID_AUTH",
                                "settings": [{"key": "APPLE_ID_AUTH_APP_CONSENT",
                                              "options": [{"key": "PRIMARY_APP_ID"}]}]},
                 "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": BUNDLE}}}}})
    print("add APPLE_ID_AUTH:", "OK" if not r.get("error") else (r.get("status"), errs(r)))
else:
    print("APPLE_ID_AUTH already present")
