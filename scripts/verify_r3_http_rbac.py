#!/usr/bin/env python3
"""
Milestone R3 HTTP Integration Test Suite: Real API Authentication & RBAC Verification
Zero external dependencies (uses standard library urllib, json, time, base64).
Executes against ASP.NET Core API on port 5138 with database RestaurantPos_Acceptance.
"""

import os
import sys
import json
import time
import base64
import urllib.request
import urllib.error
from typing import Dict, Any, Tuple, Optional, List

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_URL = os.environ.get("POS_API_BASE_URL", "http://localhost:5138")
DEFAULT_PASSWORD = os.environ.get("POS_DEFAULT_PASSWORD", "Password123@")
ALT_PASSWORD = os.environ.get("POS_ALT_PASSWORD", "admin")
OUTPUT_PATH = "artifacts/r3_http_rbac_results.json"


def sanitize_data(data: Any) -> Any:
    if isinstance(data, dict):
        sanitized = {}
        for k, v in data.items():
            if k.lower() in ("password", "oldpassword", "newpassword", "secret"):
                sanitized[k] = "[REDACTED]"
            elif k.lower() in ("token", "jwt"):
                sanitized[k] = "[REDACTED_JWT]"
            elif isinstance(v, (dict, list)):
                sanitized[k] = sanitize_data(v)
            else:
                sanitized[k] = v
        return sanitized
    elif isinstance(data, list):
        return [sanitize_data(x) for x in data]
    return data


def decode_jwt_payload(token: str) -> Dict[str, Any]:
    try:
        parts = token.split(".")
        if len(parts) < 2:
            return {}
        payload_b64 = parts[1]
        rem = len(payload_b64) % 4
        if rem > 0:
            payload_b64 += "=" * (4 - rem)
        decoded = base64.urlsafe_b64decode(payload_b64.encode("utf-8")).decode("utf-8")
        return json.loads(decoded)
    except Exception:
        return {}


def invoke_http(method: str, endpoint: str, body: Optional[Dict[str, Any]] = None,
                token: Optional[str] = None) -> Tuple[int, str, float]:
    url = f"{BASE_URL.rstrip('/')}/{endpoint.lstrip('/')}"
    headers = {"Accept": "application/json"}
    data_bytes = None

    if body is not None:
        headers["Content-Type"] = "application/json"
        data_bytes = json.dumps(body).encode("utf-8")

    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    t0 = time.perf_counter()
    status_code = 0
    resp_text = ""

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            t1 = time.perf_counter()
            status_code = response.getcode()
            resp_text = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        t1 = time.perf_counter()
        status_code = e.code
        resp_text = e.read().decode("utf-8", errors="replace")
    except Exception as e:
        t1 = time.perf_counter()
        status_code = 500
        resp_text = str(e)

    duration_ms = round((t1 - t0) * 1000.0, 2)
    return status_code, resp_text, duration_ms


def main():
    print("=" * 76)
    print("  RESTAURANT POS - REAL HTTP INTEGRATION & RBAC ACCEPTANCE TEST SUITE")
    print(f"  Target: {BASE_URL} | Dedicated DB: RestaurantPos_Acceptance")
    print("=" * 76)
    print()

    results: List[Dict[str, Any]] = []
    role_tokens: Dict[str, str] = {}
    ts = int(time.time())

    def record_test(test_id: str, category: str, description: str,
                    expected_status: List[int], status: int, resp_body: str,
                    duration_ms: float, extra_ok: bool = True, note: str = ""):
        passed = (status in expected_status) and extra_ok
        verdict = "PASS" if passed else "FAIL"
        color = "\033[92m" if passed else "\033[91m"
        reset = "\033[0m"

        exp_str = "/".join(str(x) for x in expected_status)
        print(f"{color}[{verdict}] {test_id:<8} | HTTP {status} (Expected: {exp_str}) | {duration_ms:7.2f} ms | {description}{reset}")
        if not passed:
            print(f"    Response: {resp_body[:300]}")
            if note:
                print(f"    Note: {note}")

        results.append({
            "test_id": test_id,
            "category": category,
            "description": description,
            "expected_status": expected_status,
            "actual_status": status,
            "duration_ms": duration_ms,
            "verdict": verdict,
            "note": note if not passed else ""
        })

    # Phase 0: Pre-flight
    print("--- Phase 0: Pre-flight Connectivity ---")
    st, body, dur = invoke_http("GET", "/api/table/areas")
    record_test("PRE-01", "Preflight", f"Verify API server online on {BASE_URL}", [200], st, body, dur)
    if st != 200:
        print(f"\nCRITICAL: API is unreachable at {BASE_URL}. Start 'dotnet run' on port 5138 first.")
        sys.exit(1)

    # Phase 1: Registration
    print("\n--- Phase 1: User Registration Flows ---")
    reg_username = f"test_member_{ts}"
    reg_payload = {
        "username": reg_username,
        "password": DEFAULT_PASSWORD,
        "fullName": "Acceptance Test Member",
        "email": f"member_{ts}@restaurantpos.vn",
        "phoneNumber": "0987654321",
        "roleCode": "MEMBER"
    }
    st, body, dur = invoke_http("POST", "/api/auth/register", reg_payload)
    record_test("REG-01", "Registration", f"Register new account ({reg_username})", [200, 201], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/register", reg_payload)
    record_test("REG-02", "Registration", "Reject duplicate username registration", [400], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/register", {"username": ""})
    record_test("REG-03", "Registration", "Reject empty registration payload", [400], st, body, dur)

    # Phase 2: Role Authentication
    print("\n--- Phase 2: Authentication & Token Issuance for All 6 Roles ---")
    roles_spec = [
        ("ADMIN", "admin", "admin"),
        ("MANAGER", "manager01", "manager01"),
        ("CASHIER", "cashier_mai", "cashier_mai"),
        ("WAITER", "waiter_nam", "waiter_lan"),
        ("KITCHEN", "kitchen", "chef_dung"),
        ("MEMBER", "member_khang", reg_username)
    ]

    for idx, (role_name, u_name, fallback_u) in enumerate(roles_spec, start=1):
        test_id = f"AUTH-{idx:02d}"
        active_u = u_name
        st, body, dur = invoke_http("POST", "/api/auth/login", {"username": active_u, "password": DEFAULT_PASSWORD})

        if st == 401 and ALT_PASSWORD:
            st, body, dur = invoke_http("POST", "/api/auth/login", {"username": active_u, "password": ALT_PASSWORD})

        if st != 200 and fallback_u != u_name:
            active_u = fallback_u
            st, body, dur = invoke_http("POST", "/api/auth/login", {"username": active_u, "password": DEFAULT_PASSWORD})
            if st == 401 and ALT_PASSWORD:
                st, body, dur = invoke_http("POST", "/api/auth/login", {"username": active_u, "password": ALT_PASSWORD})

        has_token = False
        claims = {}
        if st == 200:
            try:
                data = json.loads(body)
                if "token" in data and data["token"]:
                    has_token = True
                    tok = data["token"]
                    role_tokens[role_name] = tok
                    claims = decode_jwt_payload(tok)
            except Exception:
                pass

        extra_ok = has_token and bool(claims)
        record_test(test_id, "Authentication", f"Login as {role_name} (user: {active_u}) & verify JWT",
                    [200], st, body, dur, extra_ok, f"Token missing or invalid claims ({claims})")

    # Phase 3: Negative Auth
    print("\n--- Phase 3: Negative Authentication Scenarios ---")
    st, body, dur = invoke_http("POST", "/api/auth/login", {"username": "admin", "password": "WrongPassword999!"})
    record_test("AUTH-07", "NegativeAuth", "Reject login with wrong password", [401], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/login", {"username": "ghost_user_non_existent", "password": "any"})
    record_test("AUTH-08", "NegativeAuth", "Reject non-existent username", [401], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/login", {})
    record_test("AUTH-09", "NegativeAuth", "Reject empty credentials", [400], st, body, dur)

    # Phase 4: Password Change Lifecycle
    print("\n--- Phase 4: Password Change Lifecycle (Safe Test Account) ---")
    st, body, dur = invoke_http("POST", "/api/auth/login", {"username": reg_username, "password": DEFAULT_PASSWORD})
    test_user_tok = json.loads(body).get("token", "") if st == 200 else ""

    st, body, dur = invoke_http("POST", "/api/auth/change-password",
                                {"oldPassword": "WrongOldPassword!", "newPassword": "BrandNewSecret123@"},
                                token=test_user_tok)
    record_test("PWD-01", "PasswordChange", "Reject wrong old password", [400, 401], st, body, dur)

    new_pwd = "BrandNewSecret123@"
    st, body, dur = invoke_http("POST", "/api/auth/change-password",
                                {"oldPassword": DEFAULT_PASSWORD, "newPassword": new_pwd},
                                token=test_user_tok)
    record_test("PWD-02", "PasswordChange", "Successfully change password with correct credentials", [200], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/login", {"username": reg_username, "password": DEFAULT_PASSWORD})
    record_test("PWD-03", "PasswordChange", "Verify old password invalidated (401)", [401], st, body, dur)

    st, body, dur = invoke_http("POST", "/api/auth/login", {"username": reg_username, "password": new_pwd})
    new_token_ok = (st == 200) and ("token" in json.loads(body))
    record_test("PWD-04", "PasswordChange", "Verify new password authenticates & returns JWT", [200], st, body, dur, new_token_ok)

    # Phase 5: RBAC Boundary Enforcement
    print("\n--- Phase 5: RBAC Boundary Enforcement (/api/account/members) ---")
    st, body, dur = invoke_http("GET", "/api/account/members")
    record_test("RBAC-01", "RBAC", "Deny unauthenticated call (No Header)", [401], st, body, dur)

    st, body, dur = invoke_http("GET", "/api/account/members", token="garbage.invalid.token")
    record_test("RBAC-02", "RBAC", "Deny malformed/tampered JWT", [401], st, body, dur)

    admin_tok = role_tokens.get("ADMIN")
    st, body, dur = invoke_http("GET", "/api/account/members", token=admin_tok)
    arr_ok = False
    if st == 200:
        try:
            arr_ok = isinstance(json.loads(body), list)
        except Exception:
            pass
    record_test("RBAC-03", "RBAC", "Allow ADMIN token (200 OK + members list)", [200], st, body, dur, arr_ok)

    mgr_tok = role_tokens.get("MANAGER")
    st, body, dur = invoke_http("GET", "/api/account/members", token=mgr_tok)
    record_test("RBAC-04", "RBAC", "Allow MANAGER token (200 OK)", [200], st, body, dur)

    for r_name in ["CASHIER", "WAITER", "KITCHEN", "MEMBER"]:
        tok = role_tokens.get(r_name)
        if not tok:
            print(f"Skipping RBAC test for {r_name} (token missing)")
            continue
        test_id = f"RBAC-{len(results)+1:02d}"
        st, body, dur = invoke_http("GET", "/api/account/members", token=tok)
        record_test(test_id, "RBAC", f"Enforce 403 Forbidden for role {r_name}", [403], st, body, dur)

    # Report Summary
    print("\n" + "=" * 76)
    print("                       INTEGRATION TEST SUMMARY REPORT")
    print("=" * 76)
    passed_count = sum(1 for r in results if r["verdict"] == "PASS")
    failed_count = sum(1 for r in results if r["verdict"] == "FAIL")
    total_count = len(results)
    avg_dur = round(sum(r["duration_ms"] for r in results) / total_count, 2) if total_count else 0

    print(f"Total Executed : {total_count}")
    print(f"Passed         : {passed_count}")
    print(f"Failed         : {failed_count}")
    print(f"Average Latency: {avg_dur} ms")

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "target_url": BASE_URL,
            "database": "RestaurantPos_Acceptance",
            "summary": {"total": total_count, "passed": passed_count, "failed": failed_count, "avg_duration_ms": avg_dur},
            "tests": results
        }, f, indent=2, ensure_ascii=False)

    print(f"\nDetailed JSON report saved to: {OUTPUT_PATH}")
    if failed_count > 0:
        print(f"\n[RESULT] FAILED: {failed_count} test(s) failed.")
        sys.exit(1)
    else:
        print(f"\n[RESULT] SUCCESS: All {passed_count} integration test assertions passed 100%!")
        sys.exit(0)


if __name__ == "__main__":
    main()
