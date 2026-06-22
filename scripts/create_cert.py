import base64, json
from pathlib import Path
import mk

csr = Path("/tmp/dist.csr").read_text()

for ctype in ("DISTRIBUTION", "IOS_DISTRIBUTION"):
    r = mk.req("POST", "/certificates", {
        "data": {"type": "certificates",
                 "attributes": {"certificateType": ctype, "csrContent": csr}}})
    if not r.get("error"):
        cid = r["data"]["id"]
        attrs = r["data"]["attributes"]
        content = attrs.get("certificateContent")
        Path("/tmp/dist.cer").write_bytes(base64.b64decode(content))
        print("CERT CREATED:", ctype, "| id:", cid, "| name:", attrs.get("name"))
        Path("/tmp/dist_cert_id.txt").write_text(cid)
        break
    else:
        print(ctype, "failed:", r.get("status"), [(e.get("code"), e.get("detail")) for e in r.get("errors", [])][:2])
