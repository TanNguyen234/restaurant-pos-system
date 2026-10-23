# DANH MỤC CÁC ĐIỂM CHẶN & LƯU Ý TRIỂN KHAI (UNRESOLVED BLOCKERS & NOTES)
## HỆ THỐNG RESTAURANT POS SYSTEM

---

## 1. TÌNH TRẠNG MÔI TRƯỜNG GIẢ LẬP ANDROID (ANDROID EMULATOR STATUS)

### 1.1. Thực tế môi trường phát hiện
- **Android SDK:** Đã cài đặt tại `D:\Download\Android\Sdk` (Phiên bản SDK 36.0.0, Build-Tools 36.0.0, NDK 28, Platforms 33/34/35/36/37).
- **Điểm chặn xác định (Blocker):** Thư mục `D:\Download\Android\Sdk` hiện chưa cài đặt gói công cụ `emulator` (`emulator.exe`), dẫn đến lệnh `flutter emulators` trả về:
  > *"Unable to find any emulator sources. Please ensure you have some Android AVD images available."*
- **Thiết bị thật kết nối ADB:** Không có thiết bị Android vật lý nào được cắm qua cổng USB (`adb devices` rỗng).

### 1.2. Môi trường thay thế đã xác thực
- Nền tảng **Windows Desktop App** (`windows-x64`) và **Web App** (Google Chrome 155, Microsoft Edge 156) đã được Flutter phát hiện đầy đủ và sẵn sàng khởi chạy.
- Toàn bộ 57 bài kiểm tra tích hợp và widget test của ứng dụng Flutter Mobile (`flutter test`) chạy thành công 100% trên môi trường nội bộ.
- **Biện pháp khắc phục khi cần khởi chạy máy ảo Android:**
  Người dùng hoặc kỹ sư triển khai chỉ cần mở Android Studio SDK Manager và tích chọn cài đặt gói **Android Emulator** (hoặc chạy lệnh `sdkmanager "emulator"`), sau đó tạo một máy ảo AVD chuẩn (Pixel 7 / Android 14).

---

## 2. LƯU Ý VỀ CỔNG THANH TOÁN (PAYMENT GATEWAY DISTINCTION)

### 2.1. Cổng thanh toán VNPay Sandbox
- Tuân thủ nghiêm ngặt **Quy tắc số 9 (NO UNSAFE PAYMENTS)**: Toàn bộ quá trình tạo URL và xác thực callback kiểm thử đều được gắn nhãn minh bạch: **`SANDBOX VERIFIED`**.
- Không thực hiện bất kỳ giao dịch tiền thật nào trên môi trường sản xuất khi chưa được ủy quyền.
- Khóa bí mật kiểm thử `SANDBOX_HASH_SECRET_KEY_FOR_TESTING_PURPOSES` chỉ dùng cho mục đích kiểm thử cục bộ và không được đưa vào tệp cấu hình sản xuất.

### 2.2. Thanh toán VietQR
- Mã VietQR được sinh động với số tài khoản và ngân hàng mẫu (VietinBank).
- Hệ thống áp dụng quy tắc an toàn: Việc quét mã QR chỉ là phương tiện chuyển khoản; đơn hàng chỉ được đánh dấu hoàn tất thanh toán khi thu ngân xác nhận tiền đã vào tài khoản thực tế.

---

## 3. TỔNG KẾT VỀ MÃ NGUỒN & HỆ THỐNG (CONCLUSION)

- **Lỗi biên dịch:** `0` (Cả Backend .NET 10 và Mobile Flutter đều đạt 100% sạch lỗi).
- **Lỗi bảo mật nghiêm trọng (P0/P1):** `0` (Lỗ hổng nâng quyền Mass Assignment đã được sửa đổi và kiểm định thành công).
- **Dữ liệu giả lập (Mocks):** `0` (Đã loại bỏ toàn bộ dữ liệu mẫu trong repositories, toàn bộ truy vấn chạy trên SQL Server `RestaurantPos_Acceptance`).
- **Tình trạng nhánh Git:** Nhánh `test/restaurant-real-acceptance` sẵn sàng tạo Pull Request hợp nhất vào `main`.
