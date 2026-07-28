#!/usr/bin/env python3
"""Fail unless a Play store version code already exists as an uploaded artifact.

`make promote-android` releases an existing build to alpha/beta by writing the
target track with `--version_codes_to_retain`, without uploading anything. If
the code was never uploaded, Play rejects the track update with a generic
error that says nothing about where the code was supposed to come from. Check
it up front so the failure names the code and the run that should have
produced it.

This talks to the Play Developer API directly rather than through fastlane:
the check has to run before supply opens its own edit, and supply exposes no
read-only entry point for the list of uploaded bundles. Authentication uses
the same service-account JSON supply uses, and the RS256 assertion is signed
with the openssl CLI, so nothing beyond python3 is required.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"


def fail(message):
    print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def sign_rs256(payload, private_key_pem):
    """Sign with the service account key. openssl needs the key in a file."""
    fd, path = tempfile.mkstemp(suffix=".pem")
    try:
        os.write(fd, private_key_pem.encode("utf-8"))
        os.close(fd)
        result = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", path, "-binary"],
            input=payload,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        fail("openssl is not on PATH; it is required to sign the Play API token")
    finally:
        os.unlink(path)

    if result.returncode != 0:
        fail(f"openssl could not sign the Play API token: {result.stderr.decode().strip()}")
    return result.stdout


def request(url, token=None, method="GET", data=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if data is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace").strip()
        fail(f"Play API {method} {url} failed with HTTP {exc.code}: {detail}")
    except urllib.error.URLError as exc:
        fail(f"Play API {method} {url} could not be reached: {exc.reason}")
    return json.loads(body) if body else {}


def access_token(key):
    now = int(time.time())
    audience = key.get("token_uri", TOKEN_URL)
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(
        json.dumps(
            {
                "iss": key["client_email"],
                "scope": SCOPE,
                "aud": audience,
                "iat": now,
                "exp": now + 3600,
            }
        ).encode()
    )
    signing_input = f"{header}.{claims}".encode("ascii")
    assertion = f"{header}.{claims}.{b64url(sign_rs256(signing_input, key['private_key']))}"
    body = urllib.parse.urlencode(
        {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        }
    ).encode()
    return request(audience, method="POST", data=body)["access_token"]


def uploaded_version_codes(package_name, token):
    """Every version code Play has an artifact for, bundles and apks alike."""
    edit = request(f"{API}/{package_name}/edits", token=token, method="POST", data=b"")
    edit_id = edit["id"]
    try:
        codes = set()
        for kind, field in (("bundles", "bundles"), ("apks", "apks")):
            listing = request(f"{API}/{package_name}/edits/{edit_id}/{kind}", token=token)
            for artifact in listing.get(field) or []:
                codes.add(int(artifact["versionCode"]))
        return codes
    finally:
        # Read-only check: never leave the throwaway edit hanging around.
        try:
            request(f"{API}/{package_name}/edits/{edit_id}", token=token, method="DELETE")
        except SystemExit:
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-key", required=True, help="Play service account JSON")
    parser.add_argument("--package-name", required=True)
    parser.add_argument(
        "--version-code",
        required=True,
        type=int,
        help="Store version code (VERSION_CODE_OFFSET + raw build number)",
    )
    args = parser.parse_args()

    try:
        with open(args.json_key, encoding="utf-8") as handle:
            key = json.load(handle)
    except OSError as exc:
        fail(f"could not read the Play service account key {args.json_key}: {exc}")
    except json.JSONDecodeError as exc:
        fail(f"the Play service account key {args.json_key} is not valid JSON: {exc}")

    for field in ("client_email", "private_key"):
        if not key.get(field):
            fail(f"the Play service account key {args.json_key} has no '{field}'")

    codes = uploaded_version_codes(args.package_name, access_token(key))
    if args.version_code not in codes:
        newest = max(codes) if codes else "none"
        fail(
            f"store version code {args.version_code} has never been uploaded to "
            f"{args.package_name}, so there is nothing to release.\n"
            f"       A build only becomes releasable once a ci-release run has uploaded "
            f"it to the internal track.\n"
            f"       Check that the ci-release run for this build number finished "
            f"successfully.\n"
            f"       Highest uploaded code for this package: {newest}."
        )

    print(f"store version code {args.version_code} is uploaded to {args.package_name}")


if __name__ == "__main__":
    main()
