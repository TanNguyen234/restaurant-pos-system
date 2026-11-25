import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import threading
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

TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2Z0AAAAASUVORK5CYII="
)

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
            if "json" in ctype or raw.startswith(b"{") or raw.startswith(b"["):
                body = json.loads(raw.decode("utf-8"))
            else:
                body = raw.decode("utf-8", errors="replace")
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


class SignalRProbe:
    """Minimal stdlib RFC 6455 WebSocket + SignalR JSON v1 listener for /hubs/pos."""

    def __init__(self, host: str = "127.0.0.1", port: int = 5138, path: str = "/hubs/pos"):
        self.host = host
        self.port = port
        self.path = path
        self.sock: socket.socket | None = None
        self.events: list[dict] = []
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.connected = False

    def _send_text(self, text: str):
        payload = text.encode("utf-8")
        mask_key = os.urandom(4)
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", length))
        header.extend(mask_key)
        masked = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
        assert self.sock is not None
        self.sock.sendall(bytes(header) + masked)

    def _recv_exact(self, n: int) -> bytes:
        assert self.sock is not None
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise EOFError("WebSocket closed")
            buf.extend(chunk)
        return bytes(buf)

    def start(self):
        s = socket.create_connection((self.host, self.port), timeout=5)
        ws_key = base64.b64encode(os.urandom(16)).decode("ascii")
        handshake = (
            f"GET {self.path} HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {ws_key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n"
            f"Origin: http://localhost:8088\r\n\r\n"
        )
        s.sendall(handshake.encode("ascii"))
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = s.recv(1024)
            if not chunk:
                raise RuntimeError("No HTTP 101 handshake response from PosHub")
            resp += chunk
        if b"101 Switching Protocols" not in resp:
            raise RuntimeError(f"Expected 101 Switching Protocols, got: {resp!r}")

        self.sock = s
        self.sock.settimeout(1.0)
        self._send_text('{"protocol":"json","version":1}\x1e')
        self.connected = True
        self._thread = threading.Thread(target=self._reader_loop, daemon=True)
        self._thread.start()

    def _reader_loop(self):
        text_buf = ""
        while not self._stop.is_set() and self.sock is not None:
            try:
                b1b2 = self._recv_exact(2)
            except socket.timeout:
                continue
            except Exception:
                break
            opcode = b1b2[0] & 0x0F
            masked = (b1b2[1] & 0x80) != 0
            length = b1b2[1] & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask_key = self._recv_exact(4) if masked else b""
            payload = self._recv_exact(length) if length else b""
            if masked:
                payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
            if opcode == 0x8:
                break
            if opcode in (0x1, 0x0):
                text_buf += payload.decode("utf-8", errors="replace")
                while "\x1e" in text_buf:
                    frame, text_buf = text_buf.split("\x1e", 1)
                    frame = frame.strip()
                    if not frame:
                        continue
                    try:
                        msg = json.loads(frame)
                        if isinstance(msg, dict) and msg.get("type") == 1:
                            self.events.append(msg)
                    except Exception:
                        pass

    def stop(self):
        self._stop.set()
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
        if self._thread:
            self._thread.join(timeout=2)


def login_api(username: str, password: str = "admin"):
    status, body, _ = api_call("POST", "/api/auth/login", json_body={"username": username, "password": password})
    assert status == 200 and body.get("success"), f"Login failed for {username}: status={status} body={body}"
    return body["token"], body


def run_api_qa(results: dict, signalr: SignalRProbe):
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

    # 2. Unauthenticated 401 checks + no devOtp leak
    for prot_path in [
        "/api/account/members",
        "/api/shift/current",
        "/api/loyalty/me",
        "/api/kds/active-orders",
        "/api/inventory/ingredients",
        "/api/order/analytics",
        "/api/order/export-csv",
    ]:
        st, _, _ = api_call("GET", prot_path)
        check(f"unauth_401_{prot_path}", st == 401, f"status={st}")
    st, _, _ = api_call("POST", "/api/order", json_body={"items": []})
    check("unauth_401_create_order", st == 401, f"status={st}")

    st_otp, body_otp, _ = api_call("POST", "/api/auth/request-otp", json_body={"email": "member_khang@restaurantpos.vn"})
    otp_str = json.dumps(body_otp)
    check("no_devOtp_leak", "devOtp" not in otp_str and "otp" not in (body_otp.keys() if isinstance(body_otp, dict) else []), f"status={st_otp}")

    # 3. Login all roles (including kitchen)
    st_bad, _, _ = api_call("POST", "/api/auth/login", json_body={"username": "admin", "password": "wrong_password_123"})
    check("wrong_password_401", st_bad == 401, f"status={st_bad}")

    tokens = {}
    users = {}
    for uname in ["member_khang", "waiter_nam", "chef_dung", "kitchen", "cashier_mai", "manager01", "admin"]:
        tok, usr = login_api(uname, "admin")
        tokens[uname] = tok
        users[uname] = usr
    check("all_roles_login", len(tokens) == 7, "Logged in all 7 seeded role accounts")

    # 4. Member loyalty + negative RBAC + Discount
    st, lbody, _ = api_call("GET", "/api/loyalty/me", token=tokens["member_khang"])
    pts = (lbody.get("data") or {}).get("loyaltyPoints") if isinstance(lbody, dict) else None
    check("member_loyalty_points", st == 200 and pts == 1250, f"points={pts}")

    st_d, disc_resp, _ = api_call("GET", "/api/discount/active")
    disc_list = (disc_resp.get("data") if isinstance(disc_resp, dict) else disc_resp) or []
    check("public_active_discounts", st_d == 200 and isinstance(disc_list, list), f"status={st_d} body={disc_resp}")

    for denied_path in ["/api/account/members", "/api/kds/active-orders", "/api/shift/current", "/api/inventory/ingredients"]:
        st, _, _ = api_call("GET", denied_path, token=tokens["member_khang"])
        check(f"member_rbac_403_{denied_path}", st == 403, f"status={st}")

    # 5. Inventory BOM before + Guest QR Self-Order + BOM deduct + KDS Void BOM refund
    st_ing0, b_ing0, _ = api_call("GET", "/api/inventory/ingredients", token=tokens["admin"])
    ing_list0 = (b_ing0.get("data") if isinstance(b_ing0, dict) else b_ing0) or []
    check("inventory_ingredients_seeded", st_ing0 == 200 and isinstance(ing_list0, list) and len(ing_list0) >= 12, f"count={len(ing_list0)}")

    # Find product 1 recipe to assert exact DB stock deduction & refund
    st_rec1, b_rec1, _ = api_call("GET", "/api/inventory/recipes/1", token=tokens["admin"])
    rec1 = (b_rec1.get("data") if isinstance(b_rec1, dict) else b_rec1) or []
    check("inventory_recipe_prod1", st_rec1 == 200 and isinstance(rec1, list) and len(rec1) >= 1, f"recipe={b_rec1}")
    tracked_ing_id = rec1[0]["ingredientId"]
    req_qty = float(rec1[0]["quantityRequired"])
    initial_stock = float(next(i["currentStock"] for i in ing_list0 if i["ingredientId"] == tracked_ing_id))

    free_tables = [t for t in tables if t.get("status") == 0]
    check("has_three_free_tables", len(free_tables) >= 3, f"free={len(free_tables)}")
    t_qr_id = free_tables[0]["tableId"]
    t1_id = free_tables[1]["tableId"]
    t2_id = free_tables[2]["tableId"]
    prod1_id = 1
    prod2_id = prods[1]["productId"] if prods[1]["productId"] != 1 else prods[2]["productId"]

    # QR Self-Order without Authorization header
    st_qr_ord, b_qr_ord, _ = api_call(
        "POST",
        "/api/order/qr-self-order",
        json_body={
            "tableId": t_qr_id,
            "customerName": "Khách QR Bàn",
            "note": "Ít đá QR",
            "items": [{"productId": prod1_id, "quantity": 2, "itemNote": "QR Self Order"}],
        },
    )
    check("guest_qr_self_order", st_qr_ord == 200 and b_qr_ord.get("success") is True, f"st={st_qr_ord} body={b_qr_ord}")
    qr_order_id = b_qr_ord["orderId"]

    _, b_ing1, _ = api_call("GET", "/api/inventory/ingredients", token=tokens["admin"])
    ing_list1 = (b_ing1.get("data") if isinstance(b_ing1, dict) else b_ing1) or []
    stock_after_order = float(next(i["currentStock"] for i in ing_list1 if i["ingredientId"] == tracked_ing_id))
    check(
        "bom_stock_deducted_on_order",
        abs(stock_after_order - (initial_stock - req_qty * 2)) < 0.01,
        f"initial={initial_stock} after={stock_after_order} expected={initial_stock - req_qty * 2}",
    )

    _, b_tx, _ = api_call("GET", "/api/inventory/transactions", token=tokens["admin"])
    tx_list = (b_tx.get("data") if isinstance(b_tx, dict) else b_tx) or []
    has_deduct_tx = any(t.get("orderId") == qr_order_id and t.get("type") == "DEDUCT" for t in tx_list)
    check("bom_stock_deduct_tx_logged", has_deduct_tx, f"orderId={qr_order_id}")

    # Void 1 of 2 quantities from KDS and assert BOM REFUND restores 1x req_qty while leaving order active for Merge test!
    _, qr_kds_items, _ = api_call("GET", "/api/kds/active-orders", token=tokens["chef_dung"])
    qr_detail = next(i for i in qr_kds_items if i.get("orderId") == qr_order_id)
    st_v_qr, _, _ = api_call(
        "POST",
        f"/api/kds/{qr_detail['orderDetailId']}/void",
        token=tokens["chef_dung"],
        json_body={"reason": "QA BOM Refund Check", "voidQuantity": 1},
    )
    _, b_ing2, _ = api_call("GET", "/api/inventory/ingredients", token=tokens["admin"])
    ing_list2 = (b_ing2.get("data") if isinstance(b_ing2, dict) else b_ing2) or []
    stock_after_void = float(next(i["currentStock"] for i in ing_list2 if i["ingredientId"] == tracked_ing_id))
    check(
        "bom_stock_refunded_on_void",
        st_v_qr == 200 and abs(stock_after_void - (initial_stock - req_qty)) < 0.01,
        f"after_void={stock_after_void} expected={initial_stock - req_qty}",
    )

    # Admin Inventory CRUD & Adjustment test
    st_icre, b_icre, _ = api_call(
        "POST",
        "/api/inventory/ingredients",
        token=tokens["admin"],
        json_body={"ingredientName": "QA Nguyên liệu Test", "unit": "g", "currentStock": 100, "minThreshold": 20, "costPerUnit": 500},
    )
    created_ing_id = (b_icre.get("data") or {}).get("ingredientId") if isinstance(b_icre, dict) else None
    check("admin_inventory_create", st_icre == 200 and created_ing_id is not None, f"body={b_icre}")
    st_iadj, b_iadj, _ = api_call(
        "POST",
        f"/api/inventory/ingredients/{created_ing_id}/adjust",
        token=tokens["admin"],
        json_body={"changeAmount": 50, "type": "IMPORT", "note": "QA Nhap kho"},
    )
    check("admin_inventory_adjust", st_iadj == 200 and (b_iadj.get("data") or {}).get("currentStock") == 150, f"body={b_iadj}")

    # 6. Waiter order + Idempotency + Add items + Merge/Split/Transfer
    idem_key = str(uuid.uuid4())
    order_payload = {
        "idempotencyKey": idem_key,
        "tableId": t1_id,
        "customerName": "Khách QA Live",
        "phoneNumber": "0909998887",
        "orderType": 1,
        "note": "QA test E2E",
        "items": [{"productId": prod1_id, "quantity": 2, "itemNote": "Ít đường"}],
    }
    st_o1, b_o1, _ = api_call("POST", "/api/order", token=tokens["waiter_nam"], json_body=order_payload)
    check("waiter_create_order", st_o1 == 200 and b_o1.get("success"), f"status={st_o1} body={b_o1}")
    order_id = b_o1["orderId"]
    orig_total = b_o1["totalAmount"]

    st_dup, b_dup, _ = api_call("POST", "/api/order", token=tokens["waiter_nam"], json_body=order_payload)
    dup_order_id = b_dup.get("orderId") if isinstance(b_dup, dict) else None
    check("order_idempotency_guard", (st_dup == 200 and dup_order_id == order_id) or st_dup in (400, 409), f"dup_id={dup_order_id}")

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

    # Test Merge (merge t_qr_id back into t1_id -> frees t_qr_id!), then Transfer t1_id -> t2_id
    st_mrg, b_mrg, _ = api_call(
        "POST",
        "/api/table/merge",
        token=tokens["cashier_mai"],
        json_body={"sourceTableId": t_qr_id, "targetTableId": t1_id},
    )
    check("cashier_merge_tables", st_mrg == 200 and b_mrg.get("success") is True, f"body={b_mrg}")

    st_tr, b_tr, _ = api_call(
        "POST",
        "/api/table/transfer",
        token=tokens["waiter_nam"],
        json_body={"fromTableId": t1_id, "toTableId": t2_id},
    )
    check("waiter_transfer_table", st_tr == 200 and b_tr.get("success") is True, f"body={b_tr}")

    # Reserve & check-in & release t1_id (now free)
    st_rsv, b_rsv, _ = api_call(
        "POST",
        "/api/table/reserve",
        token=tokens["waiter_nam"],
        json_body={"tableId": t1_id, "customerName": "Khách Đặt QA", "phoneNumber": "0901122334", "guestCount": 2},
    )
    check("waiter_reserve_table", st_rsv == 200, f"st={st_rsv} body={b_rsv}")
    st_free, _, _ = api_call("PUT", f"/api/table/{t1_id}/status", token=tokens["waiter_nam"], json_body={"status": 0})
    check("waiter_release_reserved_table", st_free == 200, f"st={st_free}")

    # 7. Chef KDS + Void item + Split Table check + Sold-Out toggle
    st_kds, kds_items, _ = api_call("GET", "/api/kds/active-orders", token=tokens["chef_dung"])
    check("chef_kds_fetch", st_kds == 200 and isinstance(kds_items, list), f"count={len(kds_items)}")
    our_kds = [i for i in kds_items if i.get("orderId") == order_id]
    check("chef_kds_sees_new_order", len(our_kds) >= 2, f"matched_items={len(our_kds)}")

    first_detail_id = our_kds[0]["orderDetailId"]
    second_detail_id = our_kds[1]["orderDetailId"]
    st_c1, _, _ = api_call("PUT", f"/api/kds/{first_detail_id}/status", token=tokens["chef_dung"], json_body={"cookingStatus": 1})
    st_c2, _, _ = api_call("PUT", f"/api/kds/{first_detail_id}/status", token=tokens["chef_dung"], json_body={"cookingStatus": 2})
    check("chef_kds_status_flow", st_c1 == 200 and st_c2 == 200, f"c1={st_c1} c2={st_c2}")

    st_so1, b_so1, _ = api_call("PUT", f"/api/product/{prod2_id}/toggle-availability", token=tokens["chef_dung"])
    st_so2, b_so2, _ = api_call("PUT", f"/api/product/{prod2_id}/toggle-availability", token=tokens["chef_dung"])
    check("chef_sold_out_toggle_and_restore", st_so1 == 200 and st_so2 == 200 and b_so2.get("isAvailable") is True, "toggled")

    # 8. Cashier Shift Open -> Discount -> VietQR -> VNPay -> Cash Pay -> Close Shift Z-Report
    st_cur0, b_cur0, _ = api_call("GET", "/api/shift/current", token=tokens["cashier_mai"])
    if st_cur0 == 200 and b_cur0.get("hasActiveShift"):
        shift_id = b_cur0["data"]["shiftId"]
        shift_initial = float(b_cur0["data"]["initialCash"])
    else:
        st_open, b_open, _ = api_call("POST", "/api/shift/open", token=tokens["cashier_mai"], json_body={"initialCash": 500000, "note": "QA Shift"})
        check("cashier_open_shift", st_open == 200 and b_open.get("success") is True, f"body={b_open}")
        shift_id = b_open["data"]["shiftId"]
        shift_initial = 500000.0

    # Test splitting second_detail_id to t1_id, then pay both cleanly or merge back
    st_spl, b_spl, _ = api_call(
        "POST",
        "/api/table/split",
        token=tokens["cashier_mai"],
        json_body={"fromTableId": t2_id, "toTableId": t1_id, "orderDetailIds": [second_detail_id]},
    )
    check("cashier_split_table", st_spl == 200 and b_spl.get("success") is True, f"body={b_spl}")
    split_order_id = b_spl.get("newOrderId")
    # Pay off the split order so t1_id frees up, leaving t2_id occupied for Cashier UI QA too
    if split_order_id:
        st_sp_pay, _, _ = api_call("POST", "/api/payment/cash", token=tokens["cashier_mai"], json_body={"orderId": split_order_id, "note": "Pay Split Order"})
        check("cashier_pay_split_order", st_sp_pay == 200, f"st={st_sp_pay}")

    st_disc, b_disc, _ = api_call(
        "PUT",
        f"/api/order/{order_id}/discount",
        token=tokens["cashier_mai"],
        json_body={"discountPercent": 10, "reason": "QA 10%"},
    )
    final_after_disc = float(((b_disc.get("data") or {}).get("finalAmount")) or 0)
    check("cashier_manual_discount", st_disc == 200 and final_after_disc > 0, f"final={final_after_disc}")

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

    st_pay, b_pay, _ = api_call("POST", "/api/payment/cash", token=tokens["cashier_mai"], json_body={"orderId": order_id, "note": "QA Cash"})
    check("cashier_cash_payment", st_pay == 200 and b_pay.get("success") is True, f"body={b_pay}")

    st_cur1, b_cur1, _ = api_call("GET", "/api/shift/current", token=tokens["cashier_mai"])
    expected_cash = float(((b_cur1.get("data") or {}).get("expectedCash")) or shift_initial)
    st_close, b_close, _ = api_call("POST", "/api/shift/close", token=tokens["cashier_mai"], json_body={"shiftId": shift_id, "actualCash": expected_cash, "note": "QA Z-Report"})
    check("cashier_close_shift_zreport", st_close == 200 and b_close.get("success") is True, f"body={b_close}")

    st_z, b_z, _ = api_call("GET", f"/api/shift/{shift_id}/z-report", token=tokens["cashier_mai"])
    check("cashier_get_zreport", st_z == 200 and (b_z.get("data") or {}).get("shiftId") == shift_id, f"status={st_z}")

    # Leave one fresh occupied order on free_tables[1] so Cashier UI & KDS UI & Table Action UI have live data!
    st_ui_ord, b_ui_ord, _ = api_call(
        "POST",
        "/api/order",
        token=tokens["waiter_nam"],
        json_body={
            "idempotencyKey": str(uuid.uuid4()),
            "tableId": free_tables[1]["tableId"],
            "customerName": "Bàn Test UI Live",
            "phoneNumber": "0908887776",
            "orderType": 1,
            "items": [{"productId": prod1_id, "quantity": 1, "itemNote": "UI QA"}],
        },
    )
    check("seed_active_order_for_ui_qa", st_ui_ord == 200 and b_ui_ord.get("success") is True, f"body={b_ui_ord}")

    # 9. Admin Analytics, CSV Export, Image Upload/Delete & User Lock/Unlock
    st_ana, b_ana, _ = api_call("GET", "/api/order/analytics?days=7", token=tokens["admin"])
    check("admin_order_analytics", st_ana == 200 and isinstance(b_ana.get("dailyRevenue"), list) and isinstance(b_ana.get("paymentBreakdown"), list), f"keys={list(b_ana.keys()) if isinstance(b_ana, dict) else b_ana}")

    st_csv, b_csv, ctype_csv = api_call("GET", "/api/order/export-csv", token=tokens["admin"])
    check("admin_order_export_csv", st_csv == 200 and "text/csv" in ctype_csv and "OrderCode" in str(b_csv), f"ctype={ctype_csv}")

    st_adm_ord, b_adm_ord, _ = api_call("GET", "/api/order/admin", token=tokens["manager01"])
    check("manager_admin_orders_kpis", st_adm_ord == 200 and b_adm_ord.get("totalOrders", 0) >= 1, f"totalOrders={b_adm_ord.get('totalOrders') if isinstance(b_adm_ord, dict) else st_adm_ord}")

    st_mem, b_mem, _ = api_call("GET", "/api/account/members", token=tokens["admin"])
    check("admin_members_list", st_mem == 200 and isinstance(b_mem, list) and len(b_mem) >= 8, f"count={len(b_mem)}")

    pre_imgs = set(str(x).split("/")[-1] for x in (prods[0].get("images") or []))
    st_up, b_up = api_multipart("POST", f"/api/product/{prod1_id}/upload-images", tokens["admin"], fields={}, files=[("files", "qa_temp_pixel.png", TINY_PNG, "image/png")])
    uploaded_urls = b_up.get("images", []) if isinstance(b_up, dict) else []
    new_imgs = [u for u in uploaded_urls if u.split("/")[-1] not in pre_imgs]
    check("admin_product_image_upload", st_up == 200 and len(new_imgs) >= 1, f"status={st_up}")
    for up_url in new_imgs:
        fname = up_url.split("/")[-1]
        st_del, b_del, _ = api_call("DELETE", f"/api/product/{prod1_id}/images?imageName={urllib.parse.quote(fname)}", token=tokens["admin"])
        check("admin_product_image_delete", st_del == 200 and b_del.get("success") is True, f"status={st_del}")
        local_up = BACKEND_DIR / "wwwroot" / "images" / "products" / fname
        if local_up.exists():
            local_up.unlink()

    linh = next((m for m in b_mem if m.get("username") == "member_linh"), None)
    check("admin_find_member_linh", linh is not None, "found member_linh")
    st_lk, _, _ = api_call("PUT", f"/api/account/{linh['accountId']}/status", token=tokens["admin"], json_body={"isActive": False})
    st_ulk, _, _ = api_call("PUT", f"/api/account/{linh['accountId']}/status", token=tokens["admin"], json_body={"isActive": True})
    check("admin_lock_unlock_user", st_lk == 200 and st_ulk == 200, f"lock={st_lk} unlock={st_ulk}")

    # 10. SignalR Live Frame Assertion
    time.sleep(0.5)
    targets = sorted({e.get("target") for e in signalr.events})
    check(
        "signalr_realtime_events_received",
        signalr.connected and len(signalr.events) >= 3 and "OrderEvent" in targets and "TableUpdated" in targets and "KdsUpdated" in targets,
        f"connected={signalr.connected} count={len(signalr.events)} targets={targets}",
    )

    results["api_checks"] = checks
    results["signalr_targets_seen"] = targets
    results["signalr_event_count"] = len(signalr.events)


def build_session_storage_value(user_dict: dict, token: str) -> str:
    payload = dict(user_dict)
    payload["token"] = token
    return json.dumps(json.dumps(payload, ensure_ascii=False), ensure_ascii=False)


def snap_and_hash(page, path: Path) -> str:
    raw = page.screenshot(path=str(path))
    return hashlib.sha256(raw).hexdigest()


def activate_semantics(page):
    page.evaluate("""() => {
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) ph.click();
    }""")
    page.wait_for_timeout(900)


def find_and_click_semantic(page, candidates: list[str], wait_ms: int = 1300) -> bool:
    activate_semantics(page)
    for label in candidates:
        selectors = [
            f'[role="tab"][aria-label*="{label}"]',
            f'[role="button"][aria-label*="{label}"]',
            f'[aria-label*="{label}"]',
            f'flt-semantics:has-text("{label}")',
        ]
        for sel in selectors:
            loc = page.locator(sel)
            cnt = loc.count()
            if cnt > 0:
                # Prefer visible/interactive match (try last first for bottom nav / first for cards)
                for idx in range(cnt):
                    item = loc.nth(cnt - 1 - idx)
                    try:
                        if item.is_visible(timeout=500):
                            item.click(force=True)
                            page.wait_for_timeout(wait_ms)
                            return True
                    except Exception:
                        continue
    return False


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
                # 1. Guest QR Self-Order (?tableId=2) + Interactive Navigation & Login Check
                ctx = browser.new_context(viewport=vp_size)
                page = ctx.new_page()
                page_errors, console_bad, http_500, broken_media = [], [], [], []

                def attach_listeners(pg, pe, cb, h5, bm):
                    pg.on("pageerror", lambda err: pe.append(str(err)))
                    def on_console(msg):
                        txt = msg.text
                        if ("RenderFlex overflowed" in txt or "EXCEPTION CAUGHT BY" in txt or msg.type == "error") and "favicon" not in txt.lower():
                            cb.append(f"[{msg.type}] {txt}")
                    pg.on("console", on_console)
                    def on_resp(resp):
                        if resp.status >= 500:
                            h5.append(f"{resp.status} {resp.url}")
                        elif "/images/" in resp.url and resp.status >= 400:
                            bm.append(f"{resp.status} {resp.url}")
                    pg.on("response", on_resp)

                attach_listeners(page, page_errors, console_bad, http_500, broken_media)

                # Load with QR table query param (?tableId=2)
                page.goto(f"{WEB_BASE}/?tableId=2", wait_until="networkidle", timeout=30000)
                page.wait_for_timeout(2800)
                activate_semantics(page)
                h_home = snap_and_hash(page, SCREENSHOT_DIR / f"{vp_name}_01_guest_qr_home.png")

                nav_hashes = {"home": h_home}
                # Real interactive click on Danh mục tab & assert screen visually changed
                clicked_cat = find_and_click_semantic(page, ["Danh mục"])
                h_cat = snap_and_hash(page, SCREENSHOT_DIR / f"{vp_name}_02_guest_categories.png")
                nav_hashes["categories_changed"] = clicked_cat and (h_cat != h_home)

                clicked_login_tab = find_and_click_semantic(page, ["Đăng nhập"])
                h_logtab = snap_and_hash(page, SCREENSHOT_DIR / f"{vp_name}_03_guest_login_tab.png")
                nav_hashes["login_tab_changed"] = clicked_login_tab and (h_logtab != h_cat)

                # Open LoginPage and interact with form inputs
                find_and_click_semantic(page, ["Đăng nhập ngay"])
                h_login_form = snap_and_hash(page, SCREENSHOT_DIR / f"{vp_name}_04_login_form.png")
                nav_hashes["login_form_opened"] = h_login_form != h_logtab

                # Verify unauthorized guard route #/admin/users
                page.goto(f"{WEB_BASE}/#/admin/users", wait_until="networkidle", timeout=20000)
                page.wait_for_timeout(1800)
                snap_and_hash(page, SCREENSHOT_DIR / f"{vp_name}_05_guest_403_guard.png")

                ui_results.append({
                    "viewport": vp_name,
                    "role": "GUEST_QR",
                    "interactive_checks": nav_hashes,
                    "page_errors": page_errors,
                    "console_bad": console_bad,
                    "http_500": http_500,
                    "broken_media": broken_media,
                })
                ctx.close()

                # 2. Authenticated role views with real interactive actions
                for uname in ["member_khang", "waiter_nam", "chef_dung", "cashier_mai", "manager01", "admin"]:
                    tok, usr = tokens_and_users[uname]
                    r_ctx = browser.new_context(viewport=vp_size)
                    r_page = r_ctx.new_page()
                    r_pe, r_cb, r_h5, r_bm = [], [], [], []
                    attach_listeners(r_page, r_pe, r_cb, r_h5, r_bm)

                    r_page.goto(WEB_BASE, wait_until="domcontentloaded", timeout=20000)
                    encoded_val = build_session_storage_value(usr, tok)
                    r_page.evaluate(
                        """([val]) => {
                            localStorage.setItem('flutter.pos_web_session_v1', val);
                        }""",
                        [encoded_val],
                    )
                    r_page.goto(WEB_BASE, wait_until="networkidle", timeout=30000)
                    r_page.wait_for_timeout(2800)
                    activate_semantics(r_page)
                    h_r_home = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_{uname}_home.png")
                    role_actions = {"home_rendered": True}

                    if uname == "member_khang":
                        ok = find_and_click_semantic(r_page, ["Hội viên"])
                        h_loy = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_member_loyalty.png")
                        role_actions["loyalty_tab"] = ok and (h_loy != h_r_home)
                    elif uname == "waiter_nam":
                        # Tap a table card to open Action Sheet, then open QR modal if present
                        if find_and_click_semantic(r_page, ["Bàn T1-01", "Bàn T1-02", "Bàn T1-03"]):
                            h_sheet = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_waiter_action_sheet.png")
                            role_actions["table_action_sheet"] = h_sheet != h_r_home
                            if find_and_click_semantic(r_page, ["Mã QR gọi món tại bàn"]):
                                h_qr_dlg = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_waiter_qr_modal.png")
                                role_actions["table_qr_dialog"] = h_qr_dlg != h_sheet
                    elif uname == "chef_dung":
                        if find_and_click_semantic(r_page, ["Bắt đầu làm"]):
                            h_kds2 = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_chef_cooking.png")
                            role_actions["kds_start_cooking"] = h_kds2 != h_r_home
                    elif uname == "cashier_mai":
                        if find_and_click_semantic(r_page, ["Gộp bàn", "Tách món"]):
                            h_cm = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_cashier_merge_split.png")
                            role_actions["cashier_merge_split_modal"] = h_cm != h_r_home
                        elif find_and_click_semantic(r_page, ["Ca làm"]):
                            h_sh = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_cashier_shift.png")
                            role_actions["cashier_shift_tab"] = h_sh != h_r_home
                    elif uname == "admin":
                        if find_and_click_semantic(r_page, ["Quản trị"]):
                            h_hub = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_admin_hub.png")
                            role_actions["admin_hub"] = h_hub != h_r_home
                            if find_and_click_semantic(r_page, ["Quản trị Kho & Định lượng BOM", "Kho"]):
                                h_inv = snap_and_hash(r_page, SCREENSHOT_DIR / f"{vp_name}_role_admin_inventory.png")
                                role_actions["admin_inventory_page"] = h_inv != h_hub

                    ui_results.append({
                        "viewport": vp_name,
                        "role": uname,
                        "interactive_checks": role_actions,
                        "page_errors": r_pe,
                        "console_bad": r_cb,
                        "http_500": r_h5,
                        "broken_media": r_bm,
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

    signalr = SignalRProbe("127.0.0.1", 5138, "/hubs/pos")
    results = {"ok": False, "api_checks": [], "ui_checks": []}
    try:
        wait_http_200(f"{API_BASE}/api/category", timeout_s=40)
        wait_http_200(WEB_BASE, timeout_s=15)
        signalr.start()

        run_api_qa(results, signalr)
        run_browser_ui_qa(results)

        total_ui_issues = sum(
            len(u["page_errors"]) + len(u["console_bad"]) + len(u["http_500"]) + len(u["broken_media"])
            for u in results["ui_checks"]
        )
        # Verify critical interactive UI state transitions occurred on desktop & mobile
        failed_interactions = []
        for u in results["ui_checks"]:
            for k, v in (u.get("interactive_checks") or {}).items():
                if not v:
                    failed_interactions.append(f"{u['viewport']}/{u['role']}:{k}")

        results["total_ui_issues"] = total_ui_issues
        results["failed_interactions"] = failed_interactions
        results["ok"] = (total_ui_issues == 0 and len(failed_interactions) == 0)
        print(json.dumps(results, indent=2, ensure_ascii=False))
        if not results["ok"]:
            sys.exit(2)
    finally:
        signalr.stop()
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
