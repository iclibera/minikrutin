#!/usr/bin/env python3
"""
App Store Connect API Helper

Handles JWT authentication and provides convenience methods for ALL
ASC API operations: builds, versions, metadata, age rating, review details,
screenshots, pricing, and review submission.

Usage:
    python3 asc_api.py <command> [args]

Commands:
    builds                          List recent builds
    build-status <id>               Check build processing status
    set-compliance <id>             Set usesNonExemptEncryption=false for a build
    versions                        List app store versions
    link-build <version_id> <build_id>   Link build to version
    submit <version_id>             Create and confirm review submission
    cancel-submission <id>          Cancel an existing submission
    submission-status               Check current submission status
    set-metadata <version_id>       Set all version localization metadata
    set-age-rating                  Set age rating declaration
    set-review-details <version_id> Set app review details (contact, demo account)
    set-copyright <version_id> <text> Set copyright on version
    set-categories                  Set primary/secondary categories
    set-content-rights              Set content rights declaration
    screenshot-sets <loc_id>        List screenshot sets for a localization
    upload-screenshot <set_id> <file> Upload a screenshot to a set
    full-submit                     Complete all forms and submit for review

Configuration:
    Reads from ~/.appstoreconnect/config.json:
    {
        "key_id": "YOUR_KEY_ID",
        "issuer_id": "YOUR_ISSUER_ID",
        "private_key_path": "/path/to/AuthKey.p8",
        "app_id": "YOUR_APP_ID",
        "app_name": "Your App Name",
        "bundle_id": "com.example.app"
    }
"""

import hashlib
import json
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

try:
    import jwt  # PyJWT
except ImportError:
    print("PyJWT not installed. Install with: pip3 install PyJWT cryptography")
    sys.exit(1)

BASE_URL = "https://api.appstoreconnect.apple.com/v1"
CONFIG_PATH = Path.home() / ".appstoreconnect" / "config.json"


def load_config():
    if not CONFIG_PATH.exists():
        print(f"Config not found at {CONFIG_PATH}")
        print("Create it with: key_id, issuer_id, private_key_path, app_id")
        sys.exit(1)
    return json.loads(CONFIG_PATH.read_text())


def generate_token(config):
    key_path = Path(config["private_key_path"]).expanduser()
    private_key = key_path.read_text()

    now = int(time.time())
    payload = {
        "iss": config["issuer_id"],
        "iat": now,
        "exp": now + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": config["key_id"]}

    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api_request(method, path, config, body=None, exit_on_error=True):
    """Make an ASC API request. Returns parsed JSON or exits on error."""
    token = generate_token(config)
    url = f"{BASE_URL}{path}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    data = json.dumps(body).encode() if body else None
    req = Request(url, data=data, headers=headers, method=method)

    try:
        with urlopen(req) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {"status": resp.status}
    except HTTPError as e:
        error_body = e.read().decode()
        try:
            error_json = json.loads(error_body)
            if exit_on_error:
                print(f"API Error {e.code}: {json.dumps(error_json, indent=2)}")
                sys.exit(1)
            return {"error": True, "status": e.code, "errors": error_json.get("errors", [])}
        except json.JSONDecodeError:
            if exit_on_error:
                print(f"API Error {e.code}: {error_body}")
                sys.exit(1)
            return {"error": True, "status": e.code, "raw": error_body}


# ── Builds ──────────────────────────────────────────────────────────────────

def list_builds(config):
    app_id = config["app_id"]
    result = api_request(
        "GET",
        f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5",
        config,
    )
    for build in result.get("data", []):
        attrs = build["attributes"]
        print(
            f"  {build['id']}: v{attrs.get('version', '?')} "
            f"({attrs.get('processingState', '?')}) "
            f"uploaded {attrs.get('uploadedDate', '?')}"
        )
    return result


def build_status(config, build_id):
    result = api_request("GET", f"/builds/{build_id}", config)
    attrs = result["data"]["attributes"]
    print(f"Build {build_id}:")
    print(f"  Version: {attrs.get('version')}")
    print(f"  Processing: {attrs.get('processingState')}")
    print(f"  Encryption: {attrs.get('usesNonExemptEncryption')}")
    return result


def set_compliance(config, build_id):
    body = {
        "data": {
            "type": "builds",
            "id": build_id,
            "attributes": {"usesNonExemptEncryption": False},
        }
    }
    result = api_request("PATCH", f"/builds/{build_id}", config, body, exit_on_error=False)
    if result.get("error") and result.get("status") == 409:
        print(f"Export compliance already set for build {build_id}")
    else:
        print(f"Export compliance set for build {build_id}")
    return result


def get_latest_valid_build(config):
    """Get the latest build that has processingState=VALID."""
    app_id = config["app_id"]
    result = api_request(
        "GET",
        f"/builds?filter[app]={app_id}&sort=-uploadedDate&limit=5",
        config,
    )
    for build in result.get("data", []):
        if build["attributes"].get("processingState") == "VALID":
            return build
    return None


# ── Versions ────────────────────────────────────────────────────────────────

def list_versions(config):
    app_id = config["app_id"]
    result = api_request(
        "GET",
        f"/apps/{app_id}/appStoreVersions"
        f"?filter[appStoreState]=READY_FOR_DISTRIBUTION,PREPARE_FOR_SUBMISSION,"
        f"WAITING_FOR_REVIEW,IN_REVIEW,DEVELOPER_REJECTED",
        config,
    )
    for version in result.get("data", []):
        attrs = version["attributes"]
        print(
            f"  {version['id']}: v{attrs.get('versionString', '?')} "
            f"({attrs.get('appStoreState', '?')})"
        )
    return result


def get_prepare_for_submission_version(config):
    """Get the version in PREPARE_FOR_SUBMISSION state."""
    app_id = config["app_id"]
    result = api_request(
        "GET",
        f"/apps/{app_id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION",
        config,
    )
    versions = result.get("data", [])
    return versions[0] if versions else None


def link_build(config, version_id, build_id):
    body = {"data": {"type": "builds", "id": build_id}}
    result = api_request(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        config,
        body,
    )
    print(f"Linked build {build_id} to version {version_id}")
    return result


# ── Metadata ────────────────────────────────────────────────────────────────

def set_copyright(config, version_id, copyright_text):
    body = {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "attributes": {"copyright": copyright_text},
        }
    }
    result = api_request("PATCH", f"/appStoreVersions/{version_id}", config, body)
    print(f"Copyright set: {copyright_text}")
    return result


def get_version_localizations(config, version_id):
    result = api_request(
        "GET",
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        config,
    )
    return result.get("data", [])


def set_version_localization(config, localization_id, attrs):
    """Set metadata on a version localization (description, keywords, etc.)."""
    body = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": localization_id,
            "attributes": attrs,
        }
    }
    result = api_request(
        "PATCH",
        f"/appStoreVersionLocalizations/{localization_id}",
        config,
        body,
    )
    print(f"Version localization updated: {list(attrs.keys())}")
    return result


def set_metadata(config, version_id, metadata):
    """Set all metadata for a version. metadata is a dict with keys:
    description, keywords, subtitle, supportUrl, marketingUrl, promotionalText, whatsNew
    """
    locs = get_version_localizations(config, version_id)
    if not locs:
        print("No localizations found for version")
        return
    loc = locs[0]  # en-US typically
    loc_id = loc["id"]

    # Filter out None values
    attrs = {k: v for k, v in metadata.items() if v is not None}
    return set_version_localization(config, loc_id, attrs)


# ── App Info ────────────────────────────────────────────────────────────────

def get_app_info(config):
    app_id = config["app_id"]
    result = api_request("GET", f"/apps/{app_id}/appInfos", config)
    infos = result.get("data", [])
    return infos[0] if infos else None


def set_categories(config, app_info_id, primary_category_id, secondary_category_id=None):
    """Set primary and optional secondary category on the app info."""
    relationships = {
        "primaryCategory": {
            "data": {"type": "appCategories", "id": primary_category_id}
        }
    }
    if secondary_category_id:
        relationships["secondaryCategory"] = {
            "data": {"type": "appCategories", "id": secondary_category_id}
        }
    body = {
        "data": {
            "type": "appInfos",
            "id": app_info_id,
            "relationships": relationships,
        }
    }
    result = api_request("PATCH", f"/appInfos/{app_info_id}", config, body)
    print(f"Categories set: primary={primary_category_id}, secondary={secondary_category_id}")
    return result


def get_app_info_localizations(config, app_info_id):
    result = api_request(
        "GET",
        f"/appInfos/{app_info_id}/appInfoLocalizations",
        config,
    )
    return result.get("data", [])


def set_app_info_localization(config, loc_id, attrs):
    """Set privacy policy URL, privacy policy text on app info localization."""
    body = {
        "data": {
            "type": "appInfoLocalizations",
            "id": loc_id,
            "attributes": attrs,
        }
    }
    result = api_request("PATCH", f"/appInfoLocalizations/{loc_id}", config, body)
    print(f"App info localization updated: {list(attrs.keys())}")
    return result


def set_content_rights(config):
    """Set content rights declaration to DOES_NOT_USE_THIRD_PARTY_CONTENT."""
    app_id = config["app_id"]
    body = {
        "data": {
            "type": "apps",
            "id": app_id,
            "attributes": {
                "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"
            },
        }
    }
    result = api_request("PATCH", f"/apps/{app_id}", config, body, exit_on_error=False)
    if not result.get("error"):
        print("Content rights declaration set")
    return result


# ── Age Rating ──────────────────────────────────────────────────────────────

def get_age_rating_declaration(config, app_info_id):
    result = api_request(
        "GET",
        f"/appInfos/{app_info_id}/ageRatingDeclaration",
        config,
    )
    return result.get("data")


def set_age_rating(config, app_info_id, rating_attrs=None):
    """Set ALL age rating fields in a single request.

    If rating_attrs is None, sets everything to NONE/false (clean 4+ rating).

    IMPORTANT: ALL fields must be set in a single PATCH. The string enum fields use
    NONE/INFREQUENT_OR_MILD/FREQUENT_OR_INTENSE. The boolean fields use true/false.
    """
    declaration = get_age_rating_declaration(config, app_info_id)
    if not declaration:
        print("No age rating declaration found")
        return None

    decl_id = declaration["id"]

    if rating_attrs is None:
        rating_attrs = {
            # String enum fields (NONE / INFREQUENT_OR_MILD / FREQUENT_OR_INTENSE)
            "violenceCartoonOrFantasy": "NONE",
            "violenceRealistic": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
            "profanityOrCrudeHumor": "NONE",
            "matureOrSuggestiveThemes": "NONE",
            "horrorOrFearThemes": "NONE",
            "medicalOrTreatmentInformation": "NONE",
            "alcoholTobaccoOrDrugUseOrReferences": "NONE",
            "gamblingSimulated": "NONE",
            "sexualContentOrNudity": "NONE",
            "sexualContentGraphicAndNudity": "NONE",
            "contests": "NONE",
            "gunsOrOtherWeapons": "NONE",
            # Boolean fields
            "gambling": False,
            "unrestrictedWebAccess": False,
            "lootBox": False,
            "messagingAndChat": False,
            "parentalControls": False,
            "healthOrWellnessTopics": False,
            "userGeneratedContent": False,
            "ageAssurance": False,
            "advertising": False,
        }

    body = {
        "data": {
            "type": "ageRatingDeclarations",
            "id": decl_id,
            "attributes": rating_attrs,
        }
    }
    result = api_request("PATCH", f"/ageRatingDeclarations/{decl_id}", config, body)
    print(f"Age rating set (declaration {decl_id})")
    return result


# ── Review Details ──────────────────────────────────────────────────────────

def get_review_detail(config, version_id):
    result = api_request(
        "GET",
        f"/appStoreVersions/{version_id}/appStoreReviewDetail",
        config,
        exit_on_error=False,
    )
    if result.get("error"):
        return None
    return result.get("data")


def set_review_details(config, version_id, details):
    """Set review details (contact info, demo account, notes).

    details dict keys:
    - contactFirstName, contactLastName, contactPhone, contactEmail
    - demoAccountName, demoAccountPassword
    - notes
    """
    existing = get_review_detail(config, version_id)

    if existing:
        # Update existing
        body = {
            "data": {
                "type": "appStoreReviewDetails",
                "id": existing["id"],
                "attributes": details,
            }
        }
        result = api_request(
            "PATCH",
            f"/appStoreReviewDetails/{existing['id']}",
            config,
            body,
        )
        print("Review details updated")
    else:
        # Create new
        body = {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": details,
                "relationships": {
                    "appStoreVersion": {
                        "data": {
                            "type": "appStoreVersions",
                            "id": version_id,
                        }
                    }
                },
            }
        }
        result = api_request("POST", "/appStoreReviewDetails", config, body)
        print("Review details created")

    return result


# ── Screenshots ─────────────────────────────────────────────────────────────

def get_screenshot_sets(config, localization_id):
    result = api_request(
        "GET",
        f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets",
        config,
    )
    return result.get("data", [])


def create_screenshot_set(config, localization_id, display_type):
    body = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization_id,
                    }
                }
            },
        }
    }
    result = api_request("POST", "/appScreenshotSets", config, body)
    print(f"Screenshot set created: {display_type}")
    return result


def upload_screenshot(config, set_id, file_path):
    """Upload a screenshot to an existing screenshot set.

    Flow: reserve -> upload chunks -> commit with MD5.
    """
    file_path = Path(file_path)
    file_data = file_path.read_bytes()
    file_size = len(file_data)
    file_name = file_path.name

    # 1. Reserve
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size,
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            },
        }
    }
    result = api_request("POST", f"/appScreenshotSets/{set_id}/appScreenshots", config, body)
    screenshot_id = result["data"]["id"]
    upload_ops = result["data"]["attributes"].get("uploadOperations", [])
    print(f"Screenshot reserved: {screenshot_id} ({file_name}, {file_size} bytes)")

    # 2. Upload chunks
    for op in upload_ops:
        url = op["url"]
        offset = op["offset"]
        length = op["length"]
        chunk = file_data[offset : offset + length]

        headers_list = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = Request(url, data=chunk, method=op.get("method", "PUT"))
        for k, v in headers_list.items():
            req.add_header(k, v)
        with urlopen(req) as resp:
            pass
    print(f"Screenshot uploaded: {file_name}")

    # 3. Commit with MD5 checksum (plain string, NOT object)
    md5_hash = hashlib.md5(file_data).hexdigest()
    body = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": md5_hash,
            },
        }
    }
    result = api_request("PATCH", f"/appScreenshots/{screenshot_id}", config, body)
    print(f"Screenshot committed: {file_name} (MD5: {md5_hash})")
    return result


# ── Submissions ─────────────────────────────────────────────────────────────

def submit_for_review(config, version_id):
    app_id = config["app_id"]

    # Cancel existing submissions
    existing = api_request(
        "GET",
        f"/reviewSubmissions?filter[app]={app_id}",
        config,
    )
    for sub in existing.get("data", []):
        state = sub["attributes"].get("state", "")
        if state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            cancel_body = {
                "data": {
                    "type": "reviewSubmissions",
                    "id": sub["id"],
                    "attributes": {"canceled": True},
                }
            }
            api_request("PATCH", f"/reviewSubmissions/{sub['id']}", config, cancel_body)
            print(f"Cancelled existing submission: {sub['id']}")

    # Create submission
    body = {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}}
            },
        }
    }
    sub = api_request("POST", "/reviewSubmissions", config, body)
    sub_id = sub["data"]["id"]
    print(f"Created submission: {sub_id}")

    # Add version item
    body = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": sub_id}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                },
            },
        }
    }
    api_request("POST", "/reviewSubmissionItems", config, body)
    print(f"Added version {version_id} to submission")

    # Confirm
    body = {
        "data": {
            "type": "reviewSubmissions",
            "id": sub_id,
            "attributes": {"submitted": True},
        }
    }
    result = api_request("PATCH", f"/reviewSubmissions/{sub_id}", config, body,
                         exit_on_error=False)
    if result.get("error"):
        print(f"Submission confirmation failed: {json.dumps(result, indent=2)}")
        return result
    state = result["data"]["attributes"]["state"]
    print(f"Submission confirmed: {state}")
    return result


def cancel_submission(config, submission_id):
    body = {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"canceled": True},
        }
    }
    result = api_request(
        "PATCH", f"/reviewSubmissions/{submission_id}", config, body
    )
    print(f"Cancelled submission {submission_id}")
    return result


def submission_status(config):
    app_id = config["app_id"]
    result = api_request(
        "GET",
        f"/reviewSubmissions?filter[app]={app_id}",
        config,
    )
    for sub in result.get("data", []):
        attrs = sub["attributes"]
        print(f"  {sub['id']}: {attrs.get('state', '?')}")
    return result


# ── Full Submit (all-in-one) ────────────────────────────────────────────────

def full_submit(config):
    """Attempt to fill all forms and submit. Returns list of errors that
    could not be auto-fixed."""
    errors_remaining = []

    # 1. Get version
    version = get_prepare_for_submission_version(config)
    if not version:
        print("ERROR: No version in PREPARE_FOR_SUBMISSION state")
        return ["No version in PREPARE_FOR_SUBMISSION state"]
    version_id = version["id"]
    print(f"Version: {version_id} ({version['attributes'].get('versionString')})")

    # 2. Get latest valid build
    build = get_latest_valid_build(config)
    if not build:
        print("ERROR: No VALID build found")
        return ["No VALID build found - upload a build first"]
    build_id = build["id"]
    print(f"Build: {build_id} (v{build['attributes'].get('version')})")

    # 3. Set export compliance
    set_compliance(config, build_id)

    # 4. Link build to version
    link_build(config, version_id, build_id)

    # 5. Set copyright if missing
    copyright_val = version["attributes"].get("copyright")
    if not copyright_val:
        import datetime
        year = datetime.datetime.now().year
        app_name = config.get("app_name", "Developer")
        set_copyright(config, version_id, f"{year} {app_name}")

    # 6. Set content rights
    set_content_rights(config)

    # 7. Attempt submission
    result = submit_for_review(config, version_id)
    if result.get("error"):
        errors = result.get("errors", [])
        for err in errors:
            detail = err.get("detail", "Unknown error")
            code = err.get("code", "")
            print(f"Submission error: {code} - {detail}")
            errors_remaining.append(f"{code}: {detail}")

    return errors_remaining


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    config = load_config()
    cmd = sys.argv[1]

    commands = {
        "builds": lambda: list_builds(config),
        "build-status": lambda: build_status(config, sys.argv[2]),
        "set-compliance": lambda: set_compliance(config, sys.argv[2]),
        "versions": lambda: list_versions(config),
        "link-build": lambda: link_build(config, sys.argv[2], sys.argv[3]),
        "submit": lambda: submit_for_review(config, sys.argv[2]),
        "cancel-submission": lambda: cancel_submission(config, sys.argv[2]),
        "submission-status": lambda: submission_status(config),
        "set-copyright": lambda: set_copyright(config, sys.argv[2], sys.argv[3]),
        "set-categories": lambda: set_categories(config, sys.argv[2], sys.argv[3],
                                                  sys.argv[4] if len(sys.argv) > 4 else None),
        "set-content-rights": lambda: set_content_rights(config),
        "full-submit": lambda: full_submit(config),
    }

    if cmd in commands:
        commands[cmd]()
    else:
        print(f"Unknown command: {cmd}")
        print(f"Available: {', '.join(commands.keys())}")
        sys.exit(1)


if __name__ == "__main__":
    main()
