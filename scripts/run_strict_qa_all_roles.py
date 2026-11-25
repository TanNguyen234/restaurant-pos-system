import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(r"d:\Download\restaurant_pos_app")
BACKEND_DIR = ROOT / "backend"
WEB_BUILD_DIR = ROOT / "mobile" / "build" / "web"
SCREENSHOT_DIR = Path(
    r"C:\Users\VI TINH THANH AN\.gemini\antigravity\brain\6f60c25d-e6d0-4f57-83fa-0ddbf022928c\scratch\qa_screenshots"
)
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

API_BASE = "http://localhost:5138"
WEB_BASE = "http://localhost:8088"

# Minimal valid 1x1 PNG (68 bytes) for image upload check
TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2Z0AAAAASUVORK5CYII="
)

# Force UTF-8 console output on Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def api_call(method: str, path: str, token: str | None = None, json_body=None, raw_headers=None):
    url = f"{API_BASE}{path}"
    data = None
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if json_body is not None:
        data = json.dumps(json_body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if raw_headers:
        headers.update(raw_headers)
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            raw = resp.read()
            ctype = resp.headers.get("Content-Type", "")
            body = json.loads(raw.decode("utf-8")) if "json" in ctype or raw.startswith(b"{") or raw.startswith(b"[") else raw
            return resp.status, body, ctype
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            body = json.loads(raw.decode("utf-8"))
        except Exception:
            body = raw.decode("utf-8", errors="replace")
        return e.code, body, e.headers.get("Content-Type", "")


def api_multipart(method: str, path: str, token: str, fields: dict, files: list[tuple[str, str, bytes, str]] | None = None):
    boundary = f"----QABoundary{uuid.uuid4().hex}"
    parts = []
    for k, v in fields.items():
        parts.append(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode("utf-8")
        )
    if files:
        for field_name, filename, content, content_type in files:
            parts.append(
                (
                    f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field_name}\"; filename=\"{filename}\"\r\n"
                    f"Content-Type: {content_type}\r\n\r\n"
                ).encode("utf-8")
                + content
                + b"\r\n"
            )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    body_bytes = b"".join(parts)
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=body_bytes,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw.decode("utf-8"))
        except Exception:
            return e.code, raw.decode("utf-8", errors="replace")


def wait_http_200(url: str, timeout_s: float = 40.0):
    deadline = time.time() + timeout_s
    last_err = None
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=3) as resp:
                if resp.status == 200:
                    return
        except Exception as e:
            last_err = e
        time.sleep(0.5)
    raise RuntimeError(f"Service at {url} did not become healthy within {timeout_s}s: {last_err}")


def login_api(username: str, password: str = "admin"):
    status, body, _ = api_call("POST", "/api/auth/login", json_body={"username": username, "password": password})
    assert status == 200 and body.get("success"), f"Login failed for {username}: status={status} body={body}"
    return body["token"], body


def run_api_qa(results: dict):
    checks = []

    def check(name: str, ok: bool, detail: str = ""):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})
        if not ok:
            raise AssertionError(f"API QA FAILED [{name}]: {detail}")

    # 1. Public Catalog & Table & Image Integrity
    st, cats, _ = api_call("GET", "/api/category")
    check("public_categories", st == 200 and isinstance(cats, list) and len(cats) >= 5, f"count={len(cats) if isinstance(cats, list) else cats}")

    st, prods_resp, _ = api_call("GET", "/api/product?page=1&pageSize=100")
    prods = prods_resp.get("data", []) if isinstance(prods_resp, dict) else []
    check("public_products", st == 200 and len(prods) >= 34, f"count={len(prods)}")

    st, feat, _ = api_call("GET", "/api/product/featured")
    check("public_featured", st == 200 and isinstance(feat, list) and len(feat) > 0, f"count={len(feat) if isinstance(feat, list) else feat}")

    st, areas, _ = api_call("GET", "/api/table/areas")
    st2, tables, _ = api_call("GET", "/api/table")
    check("public_tables_areas", st == 200 and st2 == 200 and len(areas) >= 3 and len(tables) >= 10, f"areas={len(areas)} tables={len(tables)}")

    # Verify every seeded category icon and product image loads cleanly with HTTP 200
    checked_imgs = set()
    broken_imgs = []
    for c in cats:
        icon = (c.get("icon") or "").strip()
        if icon and "default_" not in icon:
            img_path = f"/images/categories/{icon}"
            if img_path not in checked_imgs:
                checked_imgs.add(img_path)
                try:
                    with urllib.request.urlopen(f"{API_BASE}{img_path}", timeout=5) as r:
                        data = r.read()
                        if r.status != 200 or len(data) < 200:
                            broken_imgs.append(f"{img_path}:len={len(data)}")
                except Exception as ex:
                    broken_imgs.append(f"{img_path}:{ex}")
    for p in prods:
        raw_img = (p.get("imageUrl") or "").strip()
        gallery = p.get("images") or []
        candidates = []
        if raw_img:
            candidates.extend([s.strip() for s in raw_img.replace(",", ";").split(";") if s.strip()])
        if isinstance(gallery, list):
            for g in gallery:
                gs = str(g).strip()
                if gs:
                    candidates.append(gs.split("/")[-1])
        for img in candidates:
            if not img or "default_" in img:
                continue
            img_path = f"/images/products/{img}"
            if img_path not in checked_imgs:
                checked_imgs.add(img_path)
                try:
                    with urllib.request.urlopen(f"{API_BASE}{img_path}", timeout=5) as r:
                        data = r.read()
                        if r.status != 200 or len(data) < 200:
                            broken_imgs.append(f"{img_path}:len={len(data)}")
                except Exception as ex:
                    broken_imgs.append(f"{img_path}:{ex}")
    check("all_catalog_images_200", len(broken_imgs) == 0, f"checked={len(checked_imgs)} broken={broken_imgs}")

    # 2. Negative unauthenticated checks + no devOtp leak
    for prot_path in ["/api/account/members", "/api/shift/current", "/api/loyalty/me", "/api/kds/active-orders"]:
        st, _, _ = api_call("GET", prot_path)
        check(f"unauth_401_{prot_path}", st == 401, f"status={st}")
    st, _, _ = api_call("POST", "/api/order", json_body={"items": []})
    check("unauth_401_create_order", st == 401, f"status={st}")

    st_otp, body_otp, _ = api_call("POST", "/api/auth/request-otp", json_body={"email": "member_khang@restaurantpos.vn"})
    otp_str = json.dumps(body_otp)
    check("no_devOtp_leak", "devOtp" not in otp_str and "otp" not in (body_otp.keys() if isinstance(body_otp, dict) else []), f"status={st_otp} keys={list(body_otp.keys()) if isinstance(body_otp, dict) else ''}")

    # 3. Login all 6 roles + invalid password check
    st_bad, _, _ = api_call("POST", "/api/auth/login", json_body={"username": "admin", "password": "wrong_password_123"})
    check("wrong_password_401", st_bad == 401, f"status={st_bad}")

    tokens = {}
    users = {}
    for uname in ["member_khang", "waiter_nam", "chef_dung", "cashier_mai", "manager01", "admin"]:
        tok, usr = login_api(uname, "admin")
        tokens[uname] = tok
        users[uname] = usr
    check("all_6_roles_login", len(tokens) == 6, "Logged in member, waiter, chef, cashier, manager, admin")

    # 4. Member loyalty + negative RBAC + VNPay/VietQR
    st, lbody, _ = api_call("GET", "/api/loyalty/me", token=tokens["member_khang"])
    pts = (lbody.get("data") or {}).get("loyaltyPoints") if isinstance(lbody, dict) else None
    check("member_loyalty_points", st == 200 and pts == 1250, f"points={pts}")

    for denied_path in ["/api/account/members", "/api/kds/active-orders", "/api/shift/current"]:
        st, _, _ = api_call("GET", denied_path, token=tokens["member_khang"])
        check(f"member_rbac_403_{denied_path}", st == 403, f"status={st}")

    # 5. Waiter order lifecycle + IdempotencyKey + Add Items + Table Transfer
    free_tables = [t for t in tables if t.get("status") == 0]
    check("has_two_free_tables", len(free_tables) >= 2, f"free={len(free_tables)}")
    t1_id = free_tables[0]["tableId"]
    t2_id = free_tables[1]["tableId"]
    prod1_id = prods[0]["productId"]
    prod2_id = prods[1]["productId"]
    idem_key = str(uuid.uuid4())

    order_payload = {
        "idempotencyKey": idem_key,
        "tableId": t1_id,
        "customerName": "Khách QA Live",
        "phoneNumber": "0909998887",
        "orderType": 1,
        "note": "QA test E2E",
        "items": [
            {"productId": prod1_id, "quantity": 2, "itemNote": "Ít đường"},
        ],
    }
    st_o1, b_o1, _ = api_call("POST", "/api/order", token=tokens["waiter_nam"], json_body=order_payload)
    check("waiter_create_order", st_o1 == 200 and b_o1.get("success"), f"status={st_o1} body={b_o1}")
    order_id = b_o1["orderId"]
    orig_total = b_o1["totalAmount"]

    # Duplicate IdempotencyKey submission must NOT duplicate a new orderId
    st_dup, b_dup, _ = api_call("POST", "/api/order", token=tokens["waiter_nam"], json_body=order_payload)
    dup_order_id = b_dup.get("orderId") if isinstance(b_dup, dict) else None
    check(
        "order_idempotency_guard",
        (st_dup == 200 and dup_order_id == order_id) or st_dup in (400, 409),
        f"dup_status={st_dup} orig_id={order_id} dup_id={dup_order_id}",
    )

    st_bytbl, b_bytbl, _ = api_call("GET", f"/api/order/by-table/{t1_id}", token=tokens["waiter_nam"])
    check("waiter_order_by_table", st_bytbl == 200 and b_bytbl.get("hasActiveOrder") is True, f"body={b_bytbl}")

    st_add, b_add, _ = api_call(
        "POST",
        f"/api/order/{order_id}/add-items",
        token=tokens["waiter_nam"],
        json_body=[{"productId": prod2_id, "quantity": 1, "itemNote": "QA added item"}],
    )
    new_total = ((b_add.get("data") or {}).get("totalAmount")) if isinstance(b_add, dict) else 0
    check("waiter_add_items", st_add == 200 and new_total > orig_total, f"orig={orig_total} new={new_total}")

    st_tr, b_tr, _ = api_call(
        "POST",
        "/api/table/transfer",
        token=tokens["waiter_nam"],
        json_body={"fromTableId": t1_id, "toTableId": t2_id},
    )
    check("waiter_transfer_table", st_tr == 200 and b_tr.get("success") is True, f"body={b_tr}")

    st_w403, _, _ = api_call("GET", "/api/account/members", token=tokens["waiter_nam"])
    check("waiter_rbac_403_admin_users", st_w403 == 403, f"status={st_w403}")

    # 6. Chef KDS + Void item + Sold-Out toggle (and restore)
    st_kds, kds_items, _ = api_call("GET", "/api/kds/active-orders", token=tokens["chef_dung"])
    check("chef_kds_fetch", st_kds == 200 and isinstance(kds_items, list), f"count={len(kds_items) if isinstance(kds_items, list) else kds_items}")
    our_kds = [i for i in kds_items if i.get("orderId") == order_id]
    check("chef_kds_sees_new_order", len(our_kds) >= 2, f"matched_items={len(our_kds)}")

    first_detail_id = our_kds[0]["orderDetailId"]
    second_detail_id = our_kds[1]["orderDetailId"]
    st_c1, _, _ = api_call("PUT", f"/api/kds/{first_detail_id}/status", token=tokens["chef_dung"], json_body={"cookingStatus": 1})
    st_c2, _, _ = api_call("PUT", f"/api/kds/{first_detail_id}/status", token=tokens["chef_dung"], json_body={"cookingStatus": 2})
    check("chef_kds_status_flow", st_c1 == 200 and st_c2 == 200, f"c1={st_c1} c2={st_c2}")

    st_void, b_void, _ = api_call(
        "POST",
        f"/api/kds/{second_detail_id}/void",
        token=tokens["chef_dung"],
        json_body={"reason": "QA void check", "voidQuantity": 1},
    )
    after_void_total = ((b_void.get("data") or {}).get("totalAmount")) if isinstance(b_void, dict) else 0
    check("chef_kds_void_recomputes_total", st_void == 200 and after_void_total == orig_total, f"after_void={after_void_total} expected={orig_total}")

    st_so1, b_so1, _ = api_call("PUT", f"/api/product/{prod2_id}/toggle-availability", token=tokens["chef_dung"])
    st_so2, b_so2, _ = api_call("PUT", f"/api/product/{prod2_id}/toggle-availability", token=tokens["chef_dung"])
    check(
        "chef_sold_out_toggle_and_restore",
        st_so1 == 200 and st_so2 == 200 and b_so2.get("isAvailable") is True,
        f"t1={b_so1.get('isAvailable')} t2={b_so2.get('isAvailable')}",
    )

    st_c403, _, _ = api_call("POST", "/api/shift/open", token=tokens["chef_dung"], json_body={"initialCash": 100000})
    check("chef_rbac_403_shift", st_c403 == 403, f"status={st_c403}")

    # 7. Cashier Shift Open -> Discount -> VietQR -> VNPay Sandbox URL -> Cash Pay -> Close Shift Z-Report
    st_cur0, b_cur0, _ = api_call("GET", "/api/shift/current", token=tokens["cashier_mai"])
    if st_cur0 == 200 and b_cur0.get("hasActiveShift"):
        shift_id = b_cur0["data"]["shiftId"]
        shift_initial = float(b_cur0["data"]["initialCash"])
    else:
        st_open, b_open, _ = api_call("POST", "/api/shift/open", token=tokens["cashier_mai"], json_body={"initialCash": 500000, "note": "QA Shift"})
        check("cashier_open_shift", st_open == 200 and b_open.get("success") is True, f"body={b_open}")
        shift_id = b_open["data"]["shiftId"]
        shift_initial = 500000.0

    st_disc, b_disc, _ = api_call(
        "PUT",
        f"/api/order/{order_id}/discount",
        token=tokens["cashier_mai"],
        json_body={"discountPercent": 10, "reason": "QA 10%"},
    )
    final_after_disc = float(((b_disc.get("data") or {}).get("finalAmount")) or 0)
    check("cashier_manual_discount", st_disc == 200 and final_after_disc < orig_total and final_after_disc > 0, f"final={final_after_disc}")

    st_qr, b_qr, _ = api_call("GET", f"/api/payment/vietqr/{order_id}", token=tokens["cashier_mai"])
    qr_data = (b_qr.get("data") or {}) if isinstance(b_qr, dict) else {}
    qr_url = qr_data.get("qrImageUrl") or qr_data.get("qrUrl") or ""
    check("cashier_vietqr", st_qr == 200 and "img.vietqr.io" in qr_url, f"qrUrl={qr_url[:80]}")

    st_vnp, b_vnp, _ = api_call(
        "POST",
        "/api/payment/vnpay/create-url",
        token=tokens["cashier_mai"],
        json_body={"orderId": order_id, "orderInfo": "QA VNPay Test"},
    )
    vnp_url = (b_vnp.get("paymentUrl") or "") if isinstance(b_vnp, dict) else ""
    check("cashier_vnpay_sandbox_url", st_vnp == 200 and "sandbox.vnpayment.vn" in vnp_url and "vnp_SecureHash=" in vnp_url, f"status={st_vnp}")

    st_pay, b_pay, _ = api_call(
        "POST",
        "/api/payment/cash",
        token=tokens["cashier_mai"],
        json_body={"orderId": order_id, "note": "QA Cash Payment"},
    )
    check("cashier_cash_payment", st_pay == 200 and b_pay.get("success") is True, f"body={b_pay}")

    st_cur1, b_cur1, _ = api_call("GET", "/api/shift/current", token=tokens["cashier_mai"])
    expected_cash = float(((b_cur1.get("data") or {}).get("expectedCash")) or (shift_initial + final_after_disc))
    st_close, b_close, _ = api_call(
        "POST",
        "/api/shift/close",
        token=tokens["cashier_mai"],
        json_body={"shiftId": shift_id, "actualCash": expected_cash, "note": "QA Z-Report Close"},
    )
    check("cashier_close_shift_zreport", st_close == 200 and b_close.get("success") is True, f"body={b_close}")

    st_z, b_z, _ = api_call("GET", f"/api/shift/{shift_id}/z-report", token=tokens["cashier_mai"])
    check("cashier_get_zreport", st_z == 200 and (b_z.get("data") or {}).get("shiftId") == shift_id, f"status={st_z}")

    # 8. Admin & Manager Orders + Category/Product + Image Upload Cleanup + User Status Toggle
    st_adm_ord, b_adm_ord, _ = api_call("GET", "/api/order/admin", token=tokens["manager01"])
    check(
        "manager_admin_orders_kpis",
        st_adm_ord == 200 and b_adm_ord.get("totalOrders", 0) >= 1 and isinstance(b_adm_ord.get("topProducts"), list),
        f"totalOrders={b_adm_ord.get('totalOrders') if isinstance(b_adm_ord, dict) else st_adm_ord}",
    )

    st_mem, b_mem, _ = api_call("GET", "/api/account/members", token=tokens["admin"])
    check("admin_members_list", st_mem == 200 and isinstance(b_mem, list) and len(b_mem) >= 8, f"count={len(b_mem) if isinstance(b_mem, list) else st_mem}")

    # Upload 1x1 PNG to product 1 and immediately delete that uploaded image cleanly
    st_up, b_up = api_multipart(
        "POST",
        f"/api/product/{prod1_id}/upload-images",
        tokens["admin"],
        fields={},
        files=[("files", "qa_temp_pixel.png", TINY_PNG, "image/png")],
    )
    uploaded_urls = b_up.get("images", []) if isinstance(b_up, dict) else []
    check("admin_product_image_upload", st_up == 200 and len(uploaded_urls) >= 1, f"status={st_up} body={b_up}")
    for up_url in uploaded_urls:
        fname = up_url.split("/")[-1]
        st_del, b_del, _ = api_call("DELETE", f"/api/product/{prod1_id}/images?imageName={urllib.parse.quote(fname)}", token=tokens["admin"])
        check("admin_product_image_delete", st_del == 200 and b_del.get("success") is True, f"status={st_del} body={b_del}")
        local_up = BACKEND_DIR / "wwwroot" / "images" / "products" / fname
        if local_up.exists():
            local_up.unlink()

    # Toggle active status of member_linh and restore immediately
    linh = next((m for m in b_mem if m.get("username") == "member_linh"), None)
    check("admin_find_member_linh", linh is not None, "found member_linh")
    linh_id = linh["accountId"]
    st_lk, _, _ = api_call("PUT", f"/api/account/{linh_id}/status", token=tokens["admin"], json_body={"isActive": False})
    st_ulk, _, _ = api_call("PUT", f"/api/account/{linh_id}/status", token=tokens["admin"], json_body={"isActive": True})
    check("admin_lock_unlock_user", st_lk == 200 and st_ulk == 200, f"lock={st_lk} unlock={st_ulk}")

    results["api_checks"] = checks
    results["api_tokens_verified"] = list(tokens.keys())


def build_session_storage_value(user_dict: dict, token: str) -> str:
    payload = dict(user_dict)
    payload["token"] = token
    # shared_preferences_web reads JSON-encoded string values under flutter.<key>
    return json.dumps(json.dumps(payload, ensure_ascii=False), ensure_ascii=False)


def run_browser_ui_qa(results: dict):
    ui_results = []
    tokens_and_users = {}
    for uname in ["member_khang", "waiter_nam", "chef_dung", "cashier_mai", "manager01", "admin"]:
        tok, usr = login_api(uname, "admin")
        tokens_and_users[uname] = (tok, usr)

    viewports = [
        ("mobile", {"width": 390, "height": 844}),
        ("desktop", {"width": 1280, "height": 800}),
    ]

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, channel="chrome")
        try:
            for vp_name, vp_size in viewports:
                # 1. Guest flow + Interactive UI Login test
                ctx = browser.new_context(viewport=vp_size)
                page = ctx.new_page()
                page_errors = []
                console_bad = []
                http_500 = []
                broken_media = []

                def attach_listeners(pg):
                    pg.on("pageerror", lambda err: page_errors.append(str(err)))
                    def on_console(msg):
                        txt = msg.text
                        if "RenderFlex overflowed" in txt or "EXCEPTION CAUGHT BY" in txt or msg.type == "error":
                            # Ignore benign favicon 404
                            if "favicon" not in txt.lower():
                                console_bad.append(f"[{msg.type}] {txt}")
                    pg.on("console", on_console)
                    def on_resp(resp):
                        if resp.status >= 500:
                            http_500.append(f"{resp.status} {resp.url}")
                        elif "/images/" in resp.url and resp.status >= 400:
                            broken_media.append(f"{resp.status} {resp.url}")
                    pg.on("response", on_resp)

                attach_listeners(page)
                page.goto(WEB_BASE, wait_until="networkidle", timeout=30000)
                page.wait_for_timeout(3000)
                page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_01_guest_home.png"))

                # Activate Flutter semantics so accessibility nodes become queryable/clickable
                page.evaluate("""() => {
                    const ph = document.querySelector('flt-semantics-placeholder');
                    if (ph) ph.click();
                }""")
                page.wait_for_timeout(1200)

                semantics_count = page.evaluate("() => document.querySelectorAll('flt-semantics').length")

                # Navigate Guest bottom tabs if semantics exposed
                for tab_label, shot_name in [
                    ("Danh mục", f"{vp_name}_02_guest_categories.png"),
                    ("Hội viên", f"{vp_name}_03_guest_loyalty.png"),
                    ("Đăng nhập", f"{vp_name}_04_guest_login.png"),
                ]:
                    loc = page.locator(f'flt-semantics:has-text("{tab_label}")').last
                    if loc.count() > 0:
                        loc.click(force=True)
                        page.wait_for_timeout(1500)
                    page.screenshot(path=str(SCREENSHOT_DIR / shot_name))

                # Click "Đăng nhập ngay" button from Profile guest view if visible to screenshot LoginPage
                login_btn = page.locator('flt-semantics:has-text("Đăng nhập ngay")').first
                if login_btn.count() > 0:
                    login_btn.click(force=True)
                    page.wait_for_timeout(1500)
                    page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_05_login_screen.png"))

                # Unauthorized direct hash route check (#/admin/users as Guest)
                page.goto(f"{WEB_BASE}/#/admin/users", wait_until="networkidle", timeout=20000)
                page.wait_for_timeout(2000)
                page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_06_guest_403_guard.png"))

                ui_results.append({
                    "viewport": vp_name,
                    "role": "GUEST",
                    "semantics_nodes": semantics_count,
                    "page_errors": list(page_errors),
                    "console_bad": list(console_bad),
                    "http_500": list(http_500),
                    "broken_media": list(broken_media),
                })
                ctx.close()

                # 2. Authenticated role views via real JWT session
                for role_idx, uname in enumerate(["member_khang", "waiter_nam", "chef_dung", "cashier_mai", "manager01", "admin"]):
                    tok, usr = tokens_and_users[uname]
                    r_ctx = browser.new_context(viewport=vp_size)
                    r_page = r_ctx.new_page()
                    r_page_errors, r_console_bad, r_http_500, r_broken_media = [], [], [], []
                    r_page.on("pageerror", lambda err: r_page_errors.append(str(err)))
                    r_page.on(
                        "console",
                        lambda msg: r_console_bad.append(f"[{msg.type}] {msg.text}")
                        if ("RenderFlex overflowed" in msg.text or "EXCEPTION CAUGHT BY" in msg.text or (msg.type == "error" and "favicon" not in msg.text.lower()))
                        else None,
                    )
                    r_page.on(
                        "response",
                        lambda resp: r_http_500.append(f"{resp.status} {resp.url}")
                        if resp.status >= 500
                        else (r_broken_media.append(f"{resp.status} {resp.url}") if "/images/" in resp.url and resp.status >= 400 else None),
                    )

                    # Pre-populate SharedPreferences session in localStorage before loading app
                    r_page.goto(WEB_BASE, wait_until="domcontentloaded", timeout=20000)
                    encoded_val = build_session_storage_value(usr, tok)
                    r_page.evaluate(
                        """([val]) => {
                            localStorage.setItem('flutter.pos_web_session_v1', val);
                        }""",
                        [encoded_val],
                    )
                    r_page.goto(WEB_BASE, wait_until="networkidle", timeout=30000)
                    r_page.wait_for_timeout(3000)
                    r_page.evaluate("""() => {
                        const ph = document.querySelector('flt-semantics-placeholder');
                        if (ph) ph.click();
                    }""")
                    r_page.wait_for_timeout(1200)
                    r_page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_role_{uname}_home.png"))

                    # Extra tab screenshots for key multi-tab roles
                    if uname == "member_khang":
                        t = r_page.locator('flt-semantics:has-text("Hội viên")').last
                        if t.count() > 0:
                            t.click(force=True)
                            r_page.wait_for_timeout(1800)
                            r_page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_role_member_loyalty.png"))
                    elif uname == "cashier_mai":
                        t = r_page.locator('flt-semantics:has-text("Ca làm")').last
                        if t.count() > 0:
                            t.click(force=True)
                            r_page.wait_for_timeout(1800)
                            r_page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_role_cashier_shift.png"))
                    elif uname == "admin":
                        t = r_page.locator('flt-semantics:has-text("Quản trị")').last
                        if t.count() > 0:
                            t.click(force=True)
                            r_page.wait_for_timeout(1800)
                            r_page.screenshot(path=str(SCREENSHOT_DIR / f"{vp_name}_role_admin_hub.png"))

                    ui_results.append({
                        "viewport": vp_name,
                        "role": uname,
                        "page_errors": r_page_errors,
                        "console_bad": r_console_bad,
                        "http_500": r_http_500,
                        "broken_media": r_broken_media,
                    })
                    r_ctx.close()
        finally:
            browser.close()

    results["ui_checks"] = ui_results


def main():
    backend_env = os.environ.copy()
    backend_env["ALLOWED_ORIGINS"] = "http://localhost:8088,http://127.0.0.1:8088,http://localhost:5138"

    backend_log = open(SCREENSHOT_DIR.parent / "qa_backend.log", "w", encoding="utf-8")
    web_log = open(SCREENSHOT_DIR.parent / "qa_web.log", "w", encoding="utf-8")

    backend_proc = subprocess.Popen(
        ["dotnet", "run", "--project", str(BACKEND_DIR / "WebApi.csproj"), "--no-build", "--urls", API_BASE],
        cwd=str(BACKEND_DIR),
        env=backend_env,
        stdout=backend_log,
        stderr=subprocess.STDOUT,
    )
    web_proc = subprocess.Popen(
        [sys.executable, "-m", "http.server", "8088", "--directory", str(WEB_BUILD_DIR)],
        cwd=str(ROOT),
        stdout=web_log,
        stderr=subprocess.STDOUT,
    )

    results = {"ok": False, "api_checks": [], "ui_checks": []}
    try:
        wait_http_200(f"{API_BASE}/api/category", timeout_s=40)
        wait_http_200(WEB_BASE, timeout_s=15)

        run_api_qa(results)
        run_browser_ui_qa(results)

        total_ui_issues = sum(
            len(u["page_errors"]) + len(u["console_bad"]) + len(u["http_500"]) + len(u["broken_media"])
            for u in results["ui_checks"]
        )
        results["total_ui_issues"] = total_ui_issues
        results["ok"] = (total_ui_issues == 0)
        print(json.dumps(results, indent=2, ensure_ascii=False))
        if not results["ok"]:
            sys.exit(2)
    finally:
        for proc in (web_proc, backend_proc):
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
        backend_log.close()
        web_log.close()


if __name__ == "__main__":
    main()
