#!/usr/bin/env python3
"""Enable automatic TestFlight distribution for an internal beta group.

Reads credentials from ``scripts/asc-config.env`` (key id, issuer id,
team id, bundle id) and flips ``hasAccessToAllBuilds=true`` on the
named internal group so every new build is automatically available
to its testers. Idempotent — safe to run multiple times.

Usage:
    python3 scripts/asc_auto_distribute.py "Hidden Gems"
"""
from __future__ import annotations

import os
import sys
import time
import pathlib
import jwt
import requests


CONFIG_PATH = pathlib.Path(__file__).resolve().parent / "asc-config.env"
API_BASE = "https://api.appstoreconnect.apple.com/v1"


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        raise SystemExit(f"missing {CONFIG_PATH}. copy from .example and fill in.")
    cfg: dict = {}
    for line in CONFIG_PATH.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        # strip surrounding quotes + expand $HOME
        value = value.strip().strip('"').strip("'")
        value = os.path.expandvars(value)
        cfg[key.strip()] = value
    return cfg


def make_token(cfg: dict) -> str:
    key_path = pathlib.Path(cfg["ASC_KEY_PATH"]).expanduser()
    private_key = key_path.read_text()
    # ASC API tokens must be <= 20 minutes. Use 15 for safety.
    now = int(time.time())
    payload = {
        "iss": cfg["ASC_ISSUER_ID"],
        "iat": now,
        "exp": now + 15 * 60,
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": cfg["ASC_KEY_ID"], "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api_get(token: str, path: str, params: dict | None = None) -> dict:
    r = requests.get(
        f"{API_BASE}{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params or {},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def api_patch(token: str, path: str, body: dict) -> dict:
    r = requests.patch(
        f"{API_BASE}{path}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=body,
        timeout=30,
    )
    if r.status_code >= 400:
        raise SystemExit(f"PATCH {path} failed: {r.status_code} {r.text}")
    return r.json() if r.text else {}


def find_app_id(token: str, bundle_id: str) -> str:
    data = api_get(token, "/apps", {"filter[bundleId]": bundle_id})
    apps = data.get("data", [])
    if not apps:
        raise SystemExit(f"no app in ASC with bundle id {bundle_id}")
    return apps[0]["id"]


def find_internal_group(token: str, app_id: str, group_name: str) -> dict:
    # The nested /apps/{id}/betaGroups endpoint rejects filter[name],
    # so we pull everything (up to 200) and filter client-side.
    data = api_get(token, f"/apps/{app_id}/betaGroups", {"limit": 200})
    groups = data.get("data", [])
    internal = [
        g for g in groups
        if g.get("attributes", {}).get("name") == group_name
        and g.get("attributes", {}).get("isInternalGroup")
    ]
    if internal:
        return internal[0]
    # fall back to any group with that name
    for group in groups:
        if group.get("attributes", {}).get("name") == group_name:
            return group
    names = [g.get("attributes", {}).get("name") for g in groups]
    raise SystemExit(
        f"no beta group named {group_name!r} on this app. existing groups: {names}"
    )


def enable_auto_distribute(token: str, group: dict) -> dict:
    group_id = group["id"]
    attrs = group.get("attributes", {})
    if attrs.get("hasAccessToAllBuilds"):
        return {"already_enabled": True, "group_id": group_id}
    body = {
        "data": {
            "type": "betaGroups",
            "id": group_id,
            "attributes": {"hasAccessToAllBuilds": True},
        }
    }
    api_patch(token, f"/betaGroups/{group_id}", body)
    return {"already_enabled": False, "group_id": group_id}


def main() -> None:
    group_name = sys.argv[1] if len(sys.argv) > 1 else "Hidden Gems"
    cfg = load_config()
    bundle_id = cfg.get("ASC_BUNDLE_ID")
    if not bundle_id:
        raise SystemExit("ASC_BUNDLE_ID missing from config")

    token = make_token(cfg)
    app_id = find_app_id(token, bundle_id)
    print(f"app id: {app_id}")

    group = find_internal_group(token, app_id, group_name)
    attrs = group.get("attributes", {})
    print(
        f"group: {attrs.get('name')!r} "
        f"(id={group['id']}, internal={attrs.get('isInternalGroup')}, "
        f"hasAccessToAllBuilds={attrs.get('hasAccessToAllBuilds')})"
    )

    result = enable_auto_distribute(token, group)
    if result["already_enabled"]:
        print("auto-distribute was already on. nothing to do.")
    else:
        print("auto-distribute turned on. future builds will ship to this group automatically.")


if __name__ == "__main__":
    main()
