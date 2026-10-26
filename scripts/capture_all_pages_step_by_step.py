#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
STEP-BY-STEP REAL BROWSER SCREENSHOT HARNESS
Navigates through all 17 distinct screens/pages in the Restaurant POS application:
1.  Floor Table Map (FloorTablePage)
2.  Table Action Modal Sheet
3.  Home Menu & Catalog (HomePage)
4.  Home Search Results
5.  Product Detail Screen (ProductDetailPage)
6.  Category & Filter Page (CategoryPage)
7.  Cart Screen with Items (CartPage)
8.  Order Checkout & Payment Screen (OrderCheckoutPage)
9.  Order Detail & Receipt Screen (OrderDetailPage)
10. Operations Center BottomSheet (OperationsMenu)
11. Auth Login Screen (LoginPage)
12. Kitchen Display Screen (KitchenDisplayPage)
13. Admin Order Management (AdminOrderListPage)
14. Admin Category Management (AdminCategoryPage)
15. Admin Product Management (AdminProductPage)
16. Admin User & Role RBAC Management (AdminUserPage)
17. Offline SQLite Order Sync Screen (OrdersSyncPage)
"""

import os
import sys
import time

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

from playwright.sync_api import sync_playwright

WEB_URL = "http://localhost:8080"
OUTPUT_DIR = "artifacts/captured_pages"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def wait_for_flutter(page, timeout_sec=20):
    for _ in range(timeout_sec):
        time.sleep(1)
        try:
            rendered = page.evaluate('''() => {
                const fv = document.querySelector('flutter-view');
                if (fv && fv.shadowRoot && fv.shadowRoot.querySelector('canvas') !== null) return true;
                if (document.querySelector('flt-glass-pane') !== null) return true;
                return false;
            }''')
            if rendered:
                time.sleep(2)
                return True
        except:
            pass
    return False

def main():
    print("=" * 80)
    print("  CAPTURING ALL 17 PAGES STEP-BY-STEP VIA REAL GOOGLE CHROME DEVTOOLS")
    print("=" * 80)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            headless=True
        )

        # -----------------------------------------------------------------
        # CONTEXT A: MOBILE VIEWPORT (Pixel 7: 412 x 892, Touch enabled)
        # -----------------------------------------------------------------
        context_mobile = browser.new_context(
            viewport={"width": 412, "height": 892},
            is_mobile=True,
            has_touch=True,
            user_agent="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 Mobile Safari/537.36"
        )
        page = context_mobile.new_page()

        print("\n[Step 1/17] Loading Sơ đồ bàn ăn (FloorTablePage)...")
        page.goto(f"{WEB_URL}/#/", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p1 = os.path.join(OUTPUT_DIR, "page01_floor_table.png")
        page.screenshot(path=p1)
        print(f" -> Saved: {p1}")

        print("\n[Step 2/17] Tương tác mở Modal Sheet Thao tác Bàn ăn (Table Action Sheet)...")
        # Click on Table T1-01 card: approx x=120, y=320
        page.mouse.click(120, 320)
        time.sleep(2)
        p2 = os.path.join(OUTPUT_DIR, "page02_table_action_sheet.png")
        page.screenshot(path=p2)
        print(f" -> Saved: {p2}")

        # Close bottom sheet by clicking outside (x=200, y=100)
        page.mouse.click(200, 100)
        time.sleep(1)

        print("\n[Step 3/17] Điều hướng sang Trang chủ Thực đơn (HomePage)...")
        # Click Tab 2 (Home): x=123, y=850
        page.mouse.click(123, 850)
        time.sleep(2)
        p3 = os.path.join(OUTPUT_DIR, "page03_home_catalog.png")
        page.screenshot(path=p3)
        print(f" -> Saved: {p3}")

        print("\n[Step 4/17] Tương tác tìm kiếm món trên Trang chủ (Search Results)...")
        # Click search box: x=200, y=90
        page.mouse.click(200, 90)
        time.sleep(0.5)
        page.keyboard.type("Cà phê", delay=100)
        time.sleep(2)
        p4 = os.path.join(OUTPUT_DIR, "page04_home_search.png")
        page.screenshot(path=p4)
        print(f" -> Saved: {p4}")

        print("\n[Step 5/17] Mở Trang Chi Tiết Món Ăn (ProductDetailPage)...")
        page.goto(f"{WEB_URL}/#/product-detail", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p5 = os.path.join(OUTPUT_DIR, "page05_product_detail.png")
        page.screenshot(path=p5)
        print(f" -> Saved: {p5}")

        print("\n[Step 6/17] Mở Trang Thực đơn & Danh mục (CategoryPage)...")
        page.goto(f"{WEB_URL}/#/category", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p6 = os.path.join(OUTPUT_DIR, "page06_category_page.png")
        page.screenshot(path=p6)
        print(f" -> Saved: {p6}")

        print("\n[Step 7/17] Mở Màn hình Giỏ Hàng (CartPage)...")
        page.goto(f"{WEB_URL}/#/cart", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p7 = os.path.join(OUTPUT_DIR, "page07_cart_items.png")
        page.screenshot(path=p7)
        print(f" -> Saved: {p7}")

        print("\n[Step 8/17] Mở Màn hình Xác nhận Đặt món & Thanh toán (OrderCheckoutPage)...")
        page.goto(f"{WEB_URL}/#/checkout", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p8 = os.path.join(OUTPUT_DIR, "page08_order_checkout.png")
        page.screenshot(path=p8)
        print(f" -> Saved: {p8}")

        print("\n[Step 9/17] Mở Màn hình Chi tiết Hóa đơn Đơn hàng (OrderDetailPage)...")
        page.goto(f"{WEB_URL}/#/order-detail", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p9 = os.path.join(OUTPUT_DIR, "page09_order_detail.png")
        page.screenshot(path=p9)
        print(f" -> Saved: {p9}")

        print("\n[Step 10/17] Mở Trung tâm Vận hành Phân quyền (OperationsMenu Modal Sheet)...")
        page.goto(f"{WEB_URL}/#/", wait_until="domcontentloaded")
        wait_for_flutter(page)
        # Click FloatingActionButton: x=370, y=780
        page.mouse.click(370, 780)
        time.sleep(2)
        p10 = os.path.join(OUTPUT_DIR, "page10_operations_menu.png")
        page.screenshot(path=p10)
        print(f" -> Saved: {p10}")

        print("\n[Step 11/17] Mở Màn hình Đăng Nhập Hệ Thống (LoginPage)...")
        page.goto(f"{WEB_URL}/#/login", wait_until="domcontentloaded")
        wait_for_flutter(page)
        p11 = os.path.join(OUTPUT_DIR, "page11_auth_login.png")
        page.screenshot(path=p11)
        print(f" -> Saved: {p11}")

        print("\n[Step 17/17] Mở Màn hình Đồng bộ Ngoại tuyến SQLite (OrdersSyncPage)...")
        page.goto(f"{WEB_URL}/#/", wait_until="domcontentloaded")
        wait_for_flutter(page)
        # Click Tab 5 (Đồng bộ đơn): x=370, y=850
        page.mouse.click(370, 850)
        time.sleep(2)
        p17 = os.path.join(OUTPUT_DIR, "page17_orders_sync.png")
        page.screenshot(path=p17)
        print(f" -> Saved: {p17}")

        context_mobile.close()

        # -----------------------------------------------------------------
        # CONTEXT B: DESKTOP / TABLET POS (1280 x 800) DÀNH CHO KDS & ADMIN
        # -----------------------------------------------------------------
        context_desktop = browser.new_context(
            viewport={"width": 1280, "height": 800},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0 POS-Admin/2.0"
        )
        page_d = context_desktop.new_page()

        print("\n[Step 12/17] Mở Màn hình Bếp & Pha chế KDS (KitchenDisplayPage)...")
        page_d.goto(f"{WEB_URL}/#/kds", wait_until="domcontentloaded")
        wait_for_flutter(page_d)
        p12 = os.path.join(OUTPUT_DIR, "page12_kitchen_kds.png")
        page_d.screenshot(path=p12)
        print(f" -> Saved: {p12}")

        print("\n[Step 13/17] Mở Quản lý Đơn hàng Admin & Thu ngân (AdminOrderListPage)...")
        page_d.goto(f"{WEB_URL}/#/admin/orders", wait_until="domcontentloaded")
        wait_for_flutter(page_d)
        p13 = os.path.join(OUTPUT_DIR, "page13_admin_orders.png")
        page_d.screenshot(path=p13)
        print(f" -> Saved: {p13}")

        print("\n[Step 14/17] Mở Quản lý Danh mục Admin (AdminCategoryPage)...")
        page_d.goto(f"{WEB_URL}/#/admin/categories", wait_until="domcontentloaded")
        wait_for_flutter(page_d)
        p14 = os.path.join(OUTPUT_DIR, "page14_admin_categories.png")
        page_d.screenshot(path=p14)
        print(f" -> Saved: {p14}")

        print("\n[Step 15/17] Mở Quản lý Sản phẩm Admin (AdminProductPage)...")
        page_d.goto(f"{WEB_URL}/#/admin/products", wait_until="domcontentloaded")
        wait_for_flutter(page_d)
        p15 = os.path.join(OUTPUT_DIR, "page15_admin_products.png")
        page_d.screenshot(path=p15)
        print(f" -> Saved: {p15}")

        print("\n[Step 16/17] Mở Quản trị Người dùng & Phân quyền RBAC (AdminUserPage)...")
        page_d.goto(f"{WEB_URL}/#/admin/users", wait_until="domcontentloaded")
        wait_for_flutter(page_d)
        p16 = os.path.join(OUTPUT_DIR, "page16_admin_users.png")
        page_d.screenshot(path=p16)
        print(f" -> Saved: {p16}")

        context_desktop.close()
        browser.close()

    print("\n" + "=" * 80)
    print("  ALL 17 SCREENS CAPTURED SUCCESSFULLY TO artifacts/captured_pages/")
    print("=" * 80)

if __name__ == "__main__":
    main()
