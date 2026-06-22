"""MinikRutin-scoped ASC config + helpers (reuses the skill's asc_api module)."""
import sys, json
from pathlib import Path

SKILL = "/Users/iclibera/.claude/skills/ios-app-lifecycle/scripts"
sys.path.insert(0, SKILL)
import asc_api  # noqa: E402

APP_ID = "6782930552"

def cfg():
    base = json.loads((Path.home() / ".appstoreconnect/config.json").read_text())
    base["app_id"] = APP_ID
    base["app_name"] = "MinikRutin"
    base["bundle_id"] = "com.iclibera.minikrutin"
    return base

def req(method, path, body=None, exit_on_error=False):
    return asc_api.api_request(method, path, cfg(), body, exit_on_error=exit_on_error)
