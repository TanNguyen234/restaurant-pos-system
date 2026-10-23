#!/usr/bin/env python3
"""
Adversarial Challenge Test Harness for Milestone R3:
Dedicated SQL Server Setup & API RBAC Integration

Targets:
1. JWT forgery, tampering, none-alg, expired, malformed tokens
2. RBAC boundary enforcement & role escalation across all 6 roles
3. Password change tamper attacks
4. SQL injection payloads & fuzzing on auth endpoints
5. Duplicate registration and registration privilege escalation probe
"""

import sys
import json
import time
import base64
import hmac
import hashlib
import urllib.request
import urllib.error

# Ensure UTF-8 output on Windows console
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_URL = "http://localhost:5138"
JWT_SECRET = "RestaurantPosSecretKeyForJwtAuthentication2026!@#$%^&*()_+"
JWT_ISSUER = "RestaurantPosApi"
JWT_AUDIENCE = "RestaurantPosClients"

def b64_url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

def create_raw_jwt(header: dict, payload: dict, secret: str = JWT_SECRET, sign: bool = True) -> str:
    h_bytes = json.dumps(header, separators=(',', ':')).encode('utf-8')
    p_bytes = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    h_b64 = b64_url_encode(h_bytes)
    p_b64 = b64_url_encode(p_bytes)
    signing_input = f"{h_b64}.{p_b64}"
    if not sign or header.get("alg") == "none":
        return f"{signing_input}."
    signature = hmac.new(secret.encode('utf-8'), signing_input.encode('utf-8'), hashlib.sha256).digest()
    s_b64 = b64_url_encode(signature)
    return f"{signing_input}.{s_b64}"

def http_request(method: str, path: str, body: dict = None, headers: dict = None) -> tuple:
    url = f"{BASE_URL}{path}"
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)
    data = json.dumps(body).encode('utf-8') if body is not None else None
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            latency = (time.time() - start_time) * 1000
            res_body = response.read().decode('utf-8')
            try:
                parsed = json.loads(res_body)
            except Exception:
                parsed = res_body
            return response.status, parsed, latency
    except urllib.error.HTTPError as e:
        latency = (time.time() - start_time) * 1000
        res_body = e.read().decode('utf-8')
        try:
            parsed = json.loads(res_body)
        except Exception:
            parsed = res_body
        return e.code, parsed, latency
    except Exception as ex:
        latency = (time.time() - start_time) * 1000
        return 0, str(ex), latency

def run_tests():
    print("=" * 80)
    print("CHALLENGER 1: EMPIRICAL ADVERSARIAL RBAC & SECURITY HARNESS (R3)")
    print(f"Target Base URL: {BASE_URL}")
    print(f"Timestamp: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}")
    print("=" * 80)

    results = []

    def assert_test(test_id, category, description, passed, details, status_code):
        outcome = "PASS" if passed else "FAIL"
        print(f"[{outcome}] {test_id}: {description} (Status: {status_code})")
        if not passed:
            print(f"    --> Details: {details}")
        results.append({
            "id": test_id,
            "category": category,
            "description": description,
            "passed": passed,
            "statusCode": status_code,
            "details": details
        })

    # Preflight: Check if API is alive
    status, body, latency = http_request("GET", "/api/table/areas")
    if status == 0:
        print(f"[FATAL] Backend is not reachable at {BASE_URL}: {body}")
        sys.exit(1)
    print(f"[*] API Pre-flight OK (status={status}, latency={latency:.2f}ms)")

    # -------------------------------------------------------------------------
    # VECTOR A: JWT Token Attacks against /api/account/members
    # -------------------------------------------------------------------------
    print("\n--- VECTOR A: JWT Integrity, Tampering & Forgery Attacks ---")

    # A1: Missing token (Anonymous)
    st, resp, lat = http_request("GET", "/api/account/members")
    assert_test("JWT-01", "JWT", "Anonymous request with no auth header returns 401", st == 401, resp, st)

    # A2: Empty Bearer token
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": "Bearer "})
    assert_test("JWT-02", "JWT", "Empty Bearer header returns 401", st == 401, resp, st)

    # A3: Garbage string token
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": "Bearer NOT_A_REAL_JWT_TOKEN"})
    assert_test("JWT-03", "JWT", "Garbage string token returns 401", st == 401, resp, st)

    # A4: Wrong auth scheme (Basic)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": "Basic YWRtaW46YWRtaW4="})
    assert_test("JWT-04", "JWT", "Basic auth scheme returns 401", st == 401, resp, st)

    # A5: Incomplete JWT (2 parts only, missing signature)
    incomplete_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0"
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {incomplete_jwt}"})
    assert_test("JWT-05", "JWT", "Incomplete 2-part JWT returns 401", st == 401, resp, st)

    # Login as admin to get a valid token for tampering/truncating
    st_login, login_resp, _ = http_request("POST", "/api/auth/login", {"username": "admin", "password": "admin"})
    valid_admin_token = login_resp.get("token", "") if isinstance(login_resp, dict) else ""

    # A6: Truncated valid token
    if valid_admin_token:
        truncated_token = valid_admin_token[:-15]
        st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {truncated_token}"})
        assert_test("JWT-06", "JWT", "Truncated valid JWT returns 401", st == 401, resp, st)
    else:
        assert_test("JWT-06", "JWT", "Truncated valid JWT returns 401", False, "Could not obtain admin token", 0)

    # A7: Forged signature (Signed with an attacker HMAC secret)
    attacker_secret = "AttackerForgedSecretKey9876543210!@#$%^&*()_+"
    now_ts = int(time.time())
    forged_payload = {
        "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier": "1",
        "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name": "admin",
        "http://schemas.microsoft.com/ws/2008/06/identity/claims/role": "ADMIN",
        "role": "ADMIN",
        "iss": JWT_ISSUER,
        "aud": JWT_AUDIENCE,
        "exp": now_ts + 3600
    }
    forged_token = create_raw_jwt({"alg": "HS256", "typ": "JWT"}, forged_payload, secret=attacker_secret)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {forged_token}"})
    assert_test("JWT-07", "JWT", "Forged signature (attacker secret) returns 401", st == 401, resp, st)

    # A8: 'none' algorithm bypass attack
    none_token = create_raw_jwt({"alg": "none", "typ": "JWT"}, forged_payload, sign=False)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {none_token}"})
    assert_test("JWT-08", "JWT", "Algorithm 'none' token returns 401", st == 401, resp, st)

    # A9: Expired token (Past timestamp)
    expired_payload = dict(forged_payload)
    expired_payload["exp"] = now_ts - 3600  # 1 hour ago
    expired_token = create_raw_jwt({"alg": "HS256", "typ": "JWT"}, expired_payload, secret=JWT_SECRET)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {expired_token}"})
    assert_test("JWT-09", "JWT", "Expired token (exp in past) returns 401", st == 401, resp, st)

    # A10: Tampered payload with original signature
    if valid_admin_token and '.' in valid_admin_token:
        parts = valid_admin_token.split('.')
        # Tamper middle part
        tampered_token = f"{parts[0]}.{parts[1][:-4]}AAAA.{parts[2]}"
        st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {tampered_token}"})
        assert_test("JWT-10", "JWT", "Tampered payload with original signature returns 401", st == 401, resp, st)
    else:
        assert_test("JWT-10", "JWT", "Tampered payload returns 401", False, "Missing valid admin token", 0)

    # A11: Wrong Issuer
    wrong_iss_payload = dict(forged_payload)
    wrong_iss_payload["iss"] = "MaliciousIssuer"
    wrong_iss_token = create_raw_jwt({"alg": "HS256", "typ": "JWT"}, wrong_iss_payload, secret=JWT_SECRET)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {wrong_iss_token}"})
    assert_test("JWT-11", "JWT", "Token with invalid Issuer returns 401", st == 401, resp, st)

    # A12: Wrong Audience
    wrong_aud_payload = dict(forged_payload)
    wrong_aud_payload["aud"] = "MaliciousAudience"
    wrong_aud_token = create_raw_jwt({"alg": "HS256", "typ": "JWT"}, wrong_aud_payload, secret=JWT_SECRET)
    st, resp, lat = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {wrong_aud_token}"})
    assert_test("JWT-12", "JWT", "Token with invalid Audience returns 401", st == 401, resp, st)

    # -------------------------------------------------------------------------
    # VECTOR B: Role Privilege Escalation & Boundary Enforcement
    # -------------------------------------------------------------------------
    print("\n--- VECTOR B: Role Privilege Escalation & Boundary Checks ---")

    test_accounts = [
        ("admin", "admin", "ADMIN", True),
        ("manager01", "admin", "MANAGER", True),
        ("cashier_mai", "admin", "CASHIER", False),
        ("waiter_nam", "admin", "WAITER", False),
        ("kitchen", "admin", "KITCHEN", False),
        ("member_khang", "admin", "MEMBER", False)
    ]

    tokens_by_role = {}

    for username, password, expected_role, should_access_admin in test_accounts:
        st, body, _ = http_request("POST", "/api/auth/login", {"username": username, "password": password})
        if st != 200:
            assert_test(f"ROLE-LOGIN-{expected_role}", "RBAC", f"Login as {expected_role} ({username}) succeeds", False, body, st)
            continue
        token = body.get("token")
        tokens_by_role[expected_role] = token
        returned_role = body.get("role")
        assert_test(f"ROLE-LOGIN-{expected_role}", "RBAC", f"Login as {expected_role} returns role {returned_role}", returned_role == expected_role, body, st)

        # Test GET /api/account/members
        expected_status = 200 if should_access_admin else 403
        st_mem, body_mem, _ = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {token}"})
        desc_mem = f"Access /api/account/members as {expected_role} returns {expected_status}"
        assert_test(f"RBAC-MEM-{expected_role}", "RBAC", desc_mem, st_mem == expected_status, body_mem if st_mem != expected_status else "OK", st_mem)

        # Test GET /api/account/roles
        st_roles, body_roles, _ = http_request("GET", "/api/account/roles", headers={"Authorization": f"Bearer {token}"})
        desc_roles = f"Access /api/account/roles as {expected_role} returns {expected_status}"
        assert_test(f"RBAC-ROLE-{expected_role}", "RBAC", desc_roles, st_roles == expected_status, body_roles if st_roles != expected_status else "OK", st_roles)

        # Test GET /api/account/profile (should be accessible by all authenticated roles)
        st_prof, body_prof, _ = http_request("GET", "/api/account/profile", headers={"Authorization": f"Bearer {token}"})
        assert_test(f"RBAC-PROF-{expected_role}", "RBAC", f"Access /api/account/profile as {expected_role} returns 200", st_prof == 200, body_prof if st_prof != 200 else "OK", st_prof)

    # Role spoofing attempt via HTTP headers
    waiter_token = tokens_by_role.get("WAITER")
    if waiter_token:
        st, body, _ = http_request("GET", "/api/account/members", headers={
            "Authorization": f"Bearer {waiter_token}",
            "X-Role": "ADMIN",
            "Role": "ADMIN",
            "X-User-Role": "ADMIN"
        })
        assert_test("RBAC-HEADER-SPOOF", "RBAC", "Header spoofing (X-Role: ADMIN) as WAITER still returns 403", st == 403, body, st)

    # -------------------------------------------------------------------------
    # VECTOR C: Password Change Tamper & Credential Attacks
    # -------------------------------------------------------------------------
    print("\n--- VECTOR C: Password Change Tamper & Credential Attacks ---")

    # C1: Explicit username, incorrect old password
    st, body, _ = http_request("POST", "/api/auth/change-password", {
        "username": "waiter_nam",
        "oldPassword": "INCORRECT_OLD_PASSWORD_999",
        "newPassword": "ValidNewPassword123!"
    })
    assert_test("PWD-01", "PWD", "Incorrect old password with explicit username returns 400", st == 400, body, st)

    # C2: Authenticated JWT bearer (WAITER), incorrect old password
    if waiter_token:
        st, body, _ = http_request("POST", "/api/auth/change-password", {
            "oldPassword": "WRONG_PASSWORD_AGAIN",
            "newPassword": "ValidNewPassword123!"
        }, headers={"Authorization": f"Bearer {waiter_token}"})
        assert_test("PWD-02", "PWD", "Authenticated JWT with incorrect old password returns 400", st == 400, body, st)

    # C3: Non-existent username
    st, body, _ = http_request("POST", "/api/auth/change-password", {
        "username": "ghost_user_does_not_exist_999",
        "oldPassword": "random_password",
        "newPassword": "ValidNewPassword123!"
    })
    assert_test("PWD-03", "PWD", "Password change for non-existent username returns 400", st == 400, body, st)

    # C4: Missing fields (Empty body)
    st, body, _ = http_request("POST", "/api/auth/change-password", {})
    assert_test("PWD-04", "PWD", "Empty change-password request body returns 400", st == 400, body, st)

    # C5: Short new password (<6 characters)
    st, body, _ = http_request("POST", "/api/auth/change-password", {
        "username": "waiter_nam",
        "oldPassword": "admin",
        "newPassword": "123"
    })
    assert_test("PWD-05", "PWD", "Short new password (<6 chars) returns 400", st == 400, body, st)

    # -------------------------------------------------------------------------
    # VECTOR D: SQL Injection & Payload Fuzzing on Auth Endpoints
    # -------------------------------------------------------------------------
    print("\n--- VECTOR D: SQL Injection & Payload Fuzzing on Auth Endpoints ---")

    sqli_payloads = [
        ("SQLI-01", "Tautology payload", "' OR 1=1 --"),
        ("SQLI-02", "String tautology payload", "' OR '1'='1"),
        ("SQLI-03", "Comment truncation payload", "admin' --"),
        ("SQLI-04", "Block comment payload", "admin' /*"),
        ("SQLI-05", "Stacked query / command injection", "'; EXEC xp_cmdshell('dir'); --"),
        ("SQLI-06", "Stacked query DROP TABLE", "'; DROP TABLE Accounts; --"),
        ("SQLI-07", "UNION SELECT injection", "admin' UNION SELECT 1, 'admin', 'hash' --")
    ]

    for test_id, name, payload in sqli_payloads:
        # Test in login username
        st, body, _ = http_request("POST", "/api/auth/login", {"username": payload, "password": "anypassword"})
        passed = (st in [400, 401]) and st != 500 and st != 200
        assert_test(f"{test_id}-USER", "SQLI", f"{name} in login username safely rejected (no 500/200)", passed, body, st)

        # Test in login password
        st, body, _ = http_request("POST", "/api/auth/login", {"username": "admin", "password": payload})
        passed = (st in [400, 401]) and st != 500 and st != 200
        assert_test(f"{test_id}-PASS", "SQLI", f"{name} in login password safely rejected (no 500/200)", passed, body, st)

    # Special payload: 10,000 char long string
    huge_str = "A" * 10000
    st, body, _ = http_request("POST", "/api/auth/login", {"username": huge_str, "password": "password"})
    assert_test("FUZZ-01", "FUZZ", "10,000 character username payload handled safely (no 500)", st != 500, body, st)

    # Special payload: XSS script tags
    xss_payload = "<script>alert(1)</script>"
    st, body, _ = http_request("POST", "/api/auth/login", {"username": xss_payload, "password": "password"})
    assert_test("FUZZ-02", "FUZZ", "XSS payload in login username handled safely (no 500)", st in [400, 401] and st != 500, body, st)

    # -------------------------------------------------------------------------
    # VECTOR E: Duplicate Registration & Mass Assignment / Privilege Escalation
    # -------------------------------------------------------------------------
    print("\n--- VECTOR E: Duplicate Registration & Registration Role Probing ---")

    # E1: Duplicate username 'admin'
    st, body, _ = http_request("POST", "/api/auth/register", {
        "username": "admin",
        "password": "Password123!",
        "fullName": "Imposter Admin",
        "email": "imposter_admin@example.com"
    })
    assert_test("REG-01", "REG", "Register with existing username 'admin' returns 400", st == 400, body, st)

    # E2: Case-insensitive duplicate username 'ADMIN'
    st, body, _ = http_request("POST", "/api/auth/register", {
        "username": "ADMIN",
        "password": "Password123!",
        "fullName": "Imposter Admin Upper",
        "email": "imposter_admin_upper@example.com"
    })
    assert_test("REG-02", "REG", "Register with uppercase existing username 'ADMIN' returns 400", st == 400, body, st)

    # E3: Fresh user registration and immediate duplicate registration
    fresh_user = f"adv_user_{int(time.time())}"
    st, body, _ = http_request("POST", "/api/auth/register", {
        "username": fresh_user,
        "password": "Password123!",
        "fullName": "Adversarial Test User",
        "email": f"{fresh_user}@example.com"
    })
    assert_test("REG-03", "REG", f"Fresh registration of user '{fresh_user}' succeeds with 200", st == 200, body, st)

    # Re-register identical username
    st, body, _ = http_request("POST", "/api/auth/register", {
        "username": fresh_user,
        "password": "Password456!",
        "fullName": "Duplicate User",
        "email": f"{fresh_user}_diff@example.com"
    })
    assert_test("REG-04", "REG", f"Duplicate registration of username '{fresh_user}' returns 400", st == 400, body, st)

    # Re-register with duplicate email
    st, body, _ = http_request("POST", "/api/auth/register", {
        "username": f"{fresh_user}_newname",
        "password": "Password123!",
        "fullName": "Duplicate Email User",
        "email": f"{fresh_user}@example.com"
    })
    assert_test("REG-05", "REG", f"Registration with duplicate email returns 400", st == 400, body, st)

    # E4: PROBE PRIVILEGE ESCALATION VIA REGISTRATION MASS ASSIGNMENT
    # Can an unauthenticated caller create an ADMIN account by passing RoleCode: "ADMIN" or RoleId: 1?
    probe_admin_user = f"evil_admin_{int(time.time())}"
    st_reg_admin, body_reg_admin, _ = http_request("POST", "/api/auth/register", {
        "username": probe_admin_user,
        "password": "EvilPassword123!",
        "fullName": "Self Made Admin",
        "roleCode": "ADMIN",
        "roleId": 1
    })

    print(f"[*] Probe Registration with RoleCode='ADMIN': HTTP {st_reg_admin}, body: {body_reg_admin}")

    # Now attempt to login as probe_admin_user
    st_evil_login, body_evil_login, _ = http_request("POST", "/api/auth/login", {
        "username": probe_admin_user,
        "password": "EvilPassword123!"
    })

    evil_role = body_evil_login.get("role") if isinstance(body_evil_login, dict) else None
    evil_token = body_evil_login.get("token") if isinstance(body_evil_login, dict) else None
    print(f"[*] Probe Login as {probe_admin_user}: HTTP {st_evil_login}, Role={evil_role}")

    # Check if this user can access /api/account/members
    can_access_members = False
    if evil_token:
        st_evil_mem, _, _ = http_request("GET", "/api/account/members", headers={"Authorization": f"Bearer {evil_token}"})
        can_access_members = (st_evil_mem == 200)

    # Record the finding
    print(f"[*] Probe Can Access Members: {can_access_members}")
    results.append({
        "id": "PROBE-ROLE-MASS-ASSIGNMENT",
        "category": "SECURITY-AUDIT",
        "description": "Public registration accepts client-supplied RoleCode/RoleId",
        "passed": not can_access_members,  # If true, it means mass assignment privilege escalation exists!
        "statusCode": st_reg_admin,
        "details": f"Registered with roleCode='ADMIN' -> Assigned Role={evil_role}, Can Access Admin Members Endpoint={can_access_members}"
    })

    # Summary
    print("\n" + "=" * 80)
    print("ADVERSARIAL CHALLENGE EXECUTION SUMMARY")
    print("=" * 80)
    total_tests = len(results)
    passed_tests = sum(1 for r in results if r["passed"])
    failed_tests = total_tests - passed_tests

    print(f"Total Test Cases: {total_tests}")
    print(f"Passed:           {passed_tests}")
    print(f"Failed:           {failed_tests}")

    with open("artifacts/challenger_r3_results.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"Audit log saved to artifacts/challenger_r3_results.json")

    return failed_tests

if __name__ == "__main__":
    failed = run_tests()
    sys.exit(failed)
