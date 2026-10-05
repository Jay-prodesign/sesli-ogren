#!/usr/bin/env python3
"""Secret-safe live Supabase anonymous-auth checkpoint probe.

Uses only the client-safe project URL + publishable key. It creates exactly one
anonymous auth user/session, verifies the returned access token resolves to the
same user through /auth/v1/user, and prints no key, access token, or refresh
token.

Environment:
  SUPABASE_URL
  SUPABASE_PUBLISHABLE_KEY

This is external auth-service evidence. The production Flutter mapping from the
Supabase subject to AuthenticatedLearner/LearnerId remains separately inspected
and is exercised by the app runtime boot check in the M5 batch.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import urllib.error
import urllib.request
from urllib.parse import urlparse

UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-"
    r"[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
)


def fail(message: str, code: int = 1):
    print(json.dumps({"status": "FAIL", "reason": message}, sort_keys=True))
    raise SystemExit(code)


def request_json(req: urllib.request.Request) -> dict:
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        try:
            parsed = json.loads(detail)
            safe = parsed.get("msg") or parsed.get("message") or parsed.get("error")
        except Exception:
            safe = f"HTTP {exc.code}"
        fail(f"Supabase Auth request failed: {safe or ('HTTP ' + str(exc.code))}")
    except Exception as exc:
        fail(f"Supabase Auth request failed: {exc.__class__.__name__}")
    try:
        value = json.loads(body)
    except Exception:
        fail("Supabase Auth returned non-JSON content")
    if not isinstance(value, dict):
        fail("Supabase Auth returned an unexpected response shape")
    return value


def main() -> None:
    url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    key = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    if not url or not key:
        fail("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required", 2)

    parsed = urlparse(url)
    if parsed.scheme not in {"https", "http"} or not parsed.netloc:
        fail("SUPABASE_URL is not a valid HTTP(S) project URL", 2)

    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    signup = urllib.request.Request(
        f"{url}/auth/v1/signup",
        data=b"{}",
        headers=headers,
        method="POST",
    )
    created = request_json(signup)

    access_token = created.get("access_token")
    refresh_token = created.get("refresh_token")
    user = created.get("user")
    if not isinstance(access_token, str) or not access_token:
        fail("anonymous sign-in did not return an access token")
    if not isinstance(refresh_token, str) or not refresh_token:
        fail("anonymous sign-in did not return a refresh token")
    if not isinstance(user, dict):
        fail("anonymous sign-in did not return a user")

    user_id = user.get("id")
    if not isinstance(user_id, str) or not UUID_RE.fullmatch(user_id):
        fail("anonymous sign-in did not return a UUID user id")
    if user.get("is_anonymous") is not True:
        fail("returned user is not marked anonymous")

    verify_headers = {
        "apikey": key,
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
    }
    verify = urllib.request.Request(
        f"{url}/auth/v1/user",
        headers=verify_headers,
        method="GET",
    )
    verified = request_json(verify)
    if verified.get("id") != user_id:
        fail("authenticated /user subject does not match created anonymous user")
    if verified.get("is_anonymous") is not True:
        fail("verified authenticated user is not marked anonymous")

    fingerprint = hashlib.sha256(user_id.encode("utf-8")).hexdigest()[:16]
    print(
        json.dumps(
            {
                "status": "PASS",
                "project_host": parsed.netloc,
                "anonymous_user": True,
                "authenticated_user_endpoint_verified": True,
                "user_id_uuid": True,
                "user_id_sha256_prefix": fingerprint,
                "tokens_logged": False,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
