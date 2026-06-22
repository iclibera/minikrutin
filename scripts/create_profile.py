import base64, uuid
from pathlib import Path
import mk

BUNDLE_ID_RES = "7K8S93RL7N"     # com.iclibera.minikrutin
CERT_ID = Path("/tmp/dist_cert_id.txt").read_text().strip()
NAME = "MinikRutin App Store"

# Delete any existing profile with the same name first.
existing = mk.req("GET", "/profiles?limit=200")
for p in existing.get("data", []):
    if p["attributes"].get("name") == NAME:
        mk.req("DELETE", f"/profiles/{p['id']}")
        print("deleted old profile", p["id"])

r = mk.req("POST", "/profiles", {
    "data": {"type": "profiles",
             "attributes": {"name": NAME, "profileType": "IOS_APP_STORE"},
             "relationships": {
                 "bundleId": {"data": {"type": "bundleIds", "id": BUNDLE_ID_RES}},
                 "certificates": {"data": [{"type": "certificates", "id": CERT_ID}]}}}})
if r.get("error"):
    print("ERROR", r.get("status"), [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:3])
    raise SystemExit(1)

attrs = r["data"]["attributes"]
content = base64.b64decode(attrs["profileContent"])
profiles_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
profiles_dir.mkdir(parents=True, exist_ok=True)
out = profiles_dir / f"{attrs.get('uuid', uuid.uuid4().hex)}.mobileprovision"
out.write_bytes(content)
print("PROFILE CREATED:", r["data"]["id"], "| name:", attrs.get("name"), "| uuid:", attrs.get("uuid"))
print("installed at:", out)
