# 05 — Đề Xuất Nâng Cấp Hoàn Thiện Dự Án (Chờ Phê Duyệt)

> **Trạng thái:** Đây là lộ trình **đề xuất nâng cấp sau khi đã hoàn thành 100% Core Barem & sửa toàn bộ lỗi kiểm thử**. Chưa triển khai code cho các mục dưới đây cho tới khi bạn duyệt chọn ưu tiên.

---

## 1. Bảng Đề Xuất Nâng Cấp Theo Mức Độ Ưu Tiên

| Mức ưu tiên | Tên tính năng đề xuất | Giá trị thực tế cho đồ án & doanh nghiệp F&B | Phạm vi chỉnh sửa dự kiến |
| :---: | :--- | :--- | :--- |
| **P1 (Rất nên làm)** | **1. Real-Time Push bằng ASP.NET Core SignalR** | Thay vì KDS và Sơ đồ bàn phải polling định kỳ, khi Phục vụ gửi đơn hoặc Bếp bấm "Xong món", màn hình Bếp / Phục vụ / Thu ngân **nhảy trạng thái tức thì < 0.5 giây** kèm âm thanh chuông thông báo. | Backend: `PosHub` SignalR + inject vào `OrderController`/`KdsController`/`TableController`; Flutter: `signalr_netcore` listener trên KDS & FloorTable. |
| **P1 (Rất nên làm)** | **2. Quản lý Kho & Định lượng Nguyên liệu (BOM / Recipe)** | Mỗi món ăn gắn công thức định lượng (VD: *1 Cà phê sữa đá = 25g bột cafe + 30ml sữa đặc*). Khi thanh toán/chế biến sẽ tự động trừ tồn kho, cảnh báo nguyên liệu sắp hết cho Manager. | SQL Server: thêm `Ingredients`, `ProductRecipes`, `StockTransactions`; Backend: `InventoryController` + hook vào `OrderRepository`; Flutter: trang quản lý kho & cảnh báo ngưỡng tối thiểu. |
| **P2 (Nâng tầm UX)** | **3. Giao diện Trực quan Tách/Gộp Bàn & Chuyển Món trên POS** | Hiện Backend đã có sẵn API `/api/table/merge` và `/api/table/split` nhưng giao diện Flutter mới khai thác đầy đủ Chuyển bàn & Chờ bổ sung modal chọn từng món để **Tách hóa đơn theo nhóm khách** ngay trên màn hình bàn/POS. | Flutter: nâng cấp action sheet ở [floor_table_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/table/floor_table_page.dart) & [cashier_pos_terminal_page.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/views/cashier/cashier_pos_terminal_page.dart). |
| **P2 (Nâng tầm UX)** | **4. Dashboard Biểu Đồ Doanh Thu & Xuất Báo Cáo Excel/PDF** | Bổ sung biểu đồ doanh thu theo ngày/giờ/phương thức thanh toán (`fl_chart`) và nút xuất file Excel/PDF báo cáo Z-Report & đơn hàng phục vụ kế toán nhà hàng. | Backend: endpoint tổng hợp doanh thu theo khung giờ/ngày; Flutter Admin: biểu đồ trực quan + export CSV/PDF (`printing`/`pdf`). |
| **P2 (Thực chiến)** | **5. In Bill & In Phiếu Bếp ESC/POS Thật qua LAN/Bluetooth** | Hiện [receipt_printer_service.dart](file:///d:/Download/restaurant_pos_app/mobile/lib/services/receipt_printer_service.dart) đã hỗ trợ preview & in PDF hệ thống (`printing`). Có thể mở rộng kết nối thẳng máy in nhiệt khổ 58mm/80mm qua TCP/IP cổng 9100 hoặc Bluetooth. | Flutter: thêm driver ESC/POS network socket cho Windows Desktop & Android + cấu hình IP máy in quầy/bếp. |
| **P3 (Mở rộng)** | **6. QR Self-Order Tại Bàn Cho Thực Khách** | Mỗi bàn có mã QR dẫn tới Flutter Web kèm `?tableId=...` để khách tự quét mã gọi món tại bàn (vào trạng thái chờ Phục vụ/Bếp duyệt), giảm tải nhân viên giờ cao điểm. | Flutter Web: đọc query parameter `tableId` trong `main.dart` + khóa giỏ hàng theo bàn QR; Backend: rate-limit chống spam đơn QR. |

---

## 2. Gợi ý lựa chọn nhanh để vấn đáp xuất sắc nhất

- Nếu bạn còn **1–2 ngày** trước ngày bảo vệ: đề xuất làm **Mục 1 (SignalR Real-Time cho KDS & Bàn)** + **Mục 3 (Hoàn thiện UI Tách/Gộp bàn)**. Hai tính năng này rất "ăn hình" khi demo trực tiếp trước giảng viên và chạm đúng câu hỏi về tính thời gian thực của POS.
- Nếu còn **nhiều thời gian hơn**: làm thêm **Mục 2 (Định lượng nguyên liệu BOM & Tồn kho)** hoặc **Mục 4 (Biểu đồ doanh thu + Xuất báo cáo)** để hoàn thiện vòng đời ERP nhà hàng.
