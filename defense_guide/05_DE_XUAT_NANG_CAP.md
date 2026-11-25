# 05 — Tổng Kết 6 Nâng Cấp Đã Hoàn Thành & Lộ Trình Mở Rộng (v3)

> **Trạng thái hiện tại:** Toàn bộ **6 tính năng nâng cấp trọng điểm** đã được thiết kế, lập trình đầy đủ ở cả SQL Server (18 bảng), ASP.NET Core 10 Web API (+ SignalR Hub) và Flutter Client (Mobile / Web / Windows Desktop).

---

## 1. Bảng 6 Nâng Cấp Đã Triển Khai Hoàn Chỉnh

| Hạng mục | Tên tính năng | Implementation thực tế trong source code |
| :---: | :--- | :--- |
| **Đã xong #1** | **Real-Time Push bằng ASP.NET Core SignalR** | Backend: [PosHub.cs](file:///d:/Download/restaurant_pos_app/backend/Hubs/PosHub.cs) (`/hubs/pos`) + [PosRealtimeNotifier.cs](file:///d:/Download/restaurant_pos_app/backend/Services/PosRealtimeNotifier.cs) gắn vào `Order`, `Kds`, `Table`, `Payment`, `Product`, `Inventory` Controllers.<br/>Flutter: [realtime_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/realtime_service.dart) (`web_socket_channel` JSON Protocol v1) tự reload `KitchenDisplayPage`, `FloorTablePage`, `CashierPosTerminalPage` < 0.5s. |
| **Đã xong #2** | **Quản lý Kho & Định lượng Nguyên liệu (BOM / Recipe)** | SQL Server: thêm 3 bảng `Ingredients`, `ProductRecipes`, `StockTransactions` (12 nguyên liệu, 24 công thức, 3 phiếu nhập mẫu).<br/>Backend: [InventoryRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/InventoryRepository.cs) + [InventoryController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/InventoryController.cs) + trừ kho `DEDUCT` khi tạo/thêm món & hoàn kho `REFUND` khi hủy món trong [OrderRepository.cs](file:///d:/Download/restaurant_pos_app/backend/Models/OrderRepository.cs).<br/>Flutter: [admin_inventory_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_inventory_page.dart) cảnh báo tồn thấp, nhập/xuất/kiểm kê & gán công thức món. |
| **Đã xong #3** | **UI Tách/Gộp Bàn & Chuyển Món trực tiếp trên POS** | Flutter: bổ sung `_showMergeTableModal()` và `_showSplitTableModal()` trong [cashier_pos_terminal_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cashier/cashier_pos_terminal_page.dart) bên cạnh action sheet bàn ở [floor_table_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/table/floor_table_page.dart), gọi thẳng `POST /api/table/merge` và `POST /api/table/split`. |
| **Đã xong #4** | **Biểu đồ Doanh thu Trực quan & Xuất CSV Kế toán** | Backend: `GET /api/order/analytics?days=7` và `GET /api/order/export-csv` (UTF-8 BOM) trong [OrderController.cs](file:///d:/Download/restaurant_pos_app/backend/Api/Controllers/OrderController.cs).<br/>Flutter: [revenue_charts.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/widgets/revenue_charts.dart) (`RevenueAnalyticsPanel`) tích hợp vào [admin_order_list_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/admin/admin_order_list_page.dart). |
| **Đã xong #5** | **In Bill Nhiệt ESC/POS 80mm Qua Mạng LAN (TCP 9100)** | Flutter: [escpos_printer_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/escpos_printer_service.dart) + [escpos_socket_io.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/escpos_socket_io.dart) / [escpos_socket_stub.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/escpos_socket_stub.dart) tích hợp nút **In LAN** trong [receipt_printer_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/receipt_printer_service.dart) và modal cấu hình IP máy in trong [main.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/main.dart). |
| **Đã xong #6** | **QR Self-Order Tại Bàn Cho Thực Khách** | Backend: `[AllowAnonymous] POST /api/order/qr-self-order` giới hạn tần suất theo IP/bàn (8 req/phút, HTTP 429 khi spam).<br/>Flutter: [qr_table_session.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/qr_table_session.dart) đọc `?tableId=X`, hiển thị banner đặt món QR ở [home_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/home_page.dart), chốt đơn tại [order_checkout_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/order/order_checkout_page.dart), và sinh mã QR ngay trên [floor_table_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/table/floor_table_page.dart). |

---

## 2. Lộ Trình Mở Rộng Tương Lai (Phiên Bản Thương Mại v3)

- **Multi-Branch Tenant & Cloud Sync**: Quản lý chuỗi nhiều chi nhánh với phân quyền dữ liệu theo `BranchId` và dashboard hợp nhất toàn chuỗi.
- **Tích hợp Hóa đơn điện tử (e-Invoice) & Giao hàng đối tác (GrabFood / ShopeeFood Webhook)**: Đồng bộ đơn giao hàng bên ngoài thẳng vào hàng đợi KDS chung một nguồn chân lý.
- **Smart Kitchen Load Balancing**: Tự động ước lượng thời gian chờ từng món dựa trên số ticket đang nấu (`CookingStatus = 1`) và công suất bếp/bar.
