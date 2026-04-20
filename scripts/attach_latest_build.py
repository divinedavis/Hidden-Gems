"""Attach the latest processed iOS build to the iOS 1.0 App Store version
so the App Store marketing icon (and the ASC Apps dashboard thumbnail)
picks up the new app icon from the binary."""
from __future__ import annotations
import os, sys, time, pathlib, json
import jwt, requests

CONFIG = pathlib.Path("/Users/divinedavis/Desktop/Hidden Gems/scripts/asc-config.env")
BASE = "https://api.appstoreconnect.apple.com/v1"

def load_cfg():
    cfg = {}
    for line in CONFIG.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"): continue
        k, _, v = line.partition("=")
        cfg[k.strip()] = os.path.expandvars(v.strip().strip('"').strip("'"))
    return cfg

def token(cfg):
    pk = pathlib.Path(cfg["ASC_KEY_PATH"]).expanduser().read_text()
    now = int(time.time())
    return jwt.encode(
        {"iss": cfg["ASC_ISSUER_ID"], "iat": now, "exp": now + 15*60, "aud": "appstoreconnect-v1"},
        pk, algorithm="ES256", headers={"kid": cfg["ASC_KEY_ID"], "typ": "JWT"}
    )

def api(method, t, path, params=None, body=None):
    r = requests.request(
        method, f"{BASE}{path}",
        headers={"Authorization": f"Bearer {t}", "Content-Type": "application/json"},
        params=params or {}, json=body, timeout=30,
    )
    if r.status_code >= 400:
        print(f"{method} {path} -> {r.status_code}\n{r.text}", file=sys.stderr)
        r.raise_for_status()
    return r.json() if r.text else {}

def main():
    cfg = load_cfg()
    t = token(cfg)
    app_id = cfg["ASC_APP_ID"]

    # 1) Find the iOS App Store version (platform IOS).
    versions = api("GET", t, f"/apps/{app_id}/appStoreVersions",
                   {"filter[platform]": "IOS", "limit": 20})
    if not versions.get("data"):
        sys.exit("no appStoreVersions for this app")
    ver = versions["data"][0]
    ver_id = ver["id"]
    print(f"version: {ver['attributes']['versionString']} ({ver['attributes']['appStoreState']}) id={ver_id}")

    # 2) Find the latest iOS build for this app, preferring processed ones.
    builds = api("GET", t, "/builds",
                 {"filter[app]": app_id, "sort": "-uploadedDate",
                  "limit": 10, "filter[preReleaseVersion.platform]": "IOS"})
    if not builds.get("data"):
        sys.exit("no builds for this app")

    target = None
    for b in builds["data"]:
        state = b["attributes"].get("processingState")
        valid = b["attributes"].get("expired") is False
        v = b["attributes"].get("version")
        print(f"  build {v}: state={state} expired={b['attributes'].get('expired')}")
        if state == "VALID" and valid and target is None:
            target = b
    if target is None:
        sys.exit("no VALID (processed) build yet — try again in a few minutes")

    build_id = target["id"]
    print(f"attaching build {target['attributes']['version']} (id={build_id}) to version {ver_id}")

    # 3) PATCH the relationship.
    api("PATCH", t, f"/appStoreVersions/{ver_id}/relationships/build",
        body={"data": {"type": "builds", "id": build_id}})
    print("attached.")

    # 4) Confirm.
    cur = api("GET", t, f"/appStoreVersions/{ver_id}/build")
    print("current build on version:", cur.get("data", {}).get("id"))

if __name__ == "__main__":
    main()
