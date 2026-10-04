import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tcPr.append(shd)

def create_document():
    doc = docx.Document()

    # Page Margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    # Styles
    normal_style = doc.styles['Normal']
    normal_font = normal_style.font
    normal_font.name = 'Segoe UI'
    normal_font.size = Pt(11)
    normal_font.color.rgb = RGBColor(0x33, 0x33, 0x33)

    # Title
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_title = p_title.add_run("TÀI LIỆU HƯỚNG DẪN KỸ THUẬT & PHÂN CÔNG COLLABORATOR\n")
    run_title.font.size = Pt(20)
    run_title.font.bold = True
    run_title.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D) # Navy Blue

    run_sub = p_title.add_run("HỆ THỐNG QUẢN LÝ NHÀ HÀNG & QUÁN CÀ PHÊ (RESTAURANT & CAFE POS)\n")
    run_sub.font.size = Pt(13)
    run_sub.font.bold = True
    run_sub.font.color.rgb = RGBColor(0x2B, 0x6C, 0xB0)

    run_meta = p_title.add_run("Nền tảng: Flutter (Dart) • SQLite on Device • ASP.NET Core 10 Web API • Microsoft SQL Server\n")
    run_meta.font.size = Pt(10)
    run_meta.font.italic = True
    run_meta.font.color.rgb = RGBColor(0x71, 0x80, 0x96)

    doc.add_paragraph()

    # SECTION 1
    h1 = doc.add_heading(level=1)
    r1 = h1.add_run("1. TỔNG QUAN DỰ ÁN & CÔNG NGHỆ BẮT BUỘC")
    r1.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    doc.add_paragraph(
        "Dự án nhằm mục tiêu xây dựng giải pháp công nghệ toàn diện cho nhà hàng, quán cà phê nhằm tối ưu "
        "quy trình gọi món (order), điều phối bếp/bar, quản lý giỏ hàng, in hóa đơn và thanh toán trực tiếp "
        "hoặc trực tuyến. Mọi thành viên tham gia (collaborator) bắt buộc tuân thủ đúng các công nghệ sau:"
    )

    p_tech = doc.add_paragraph()
    p_tech.add_run("• Mobile Frontend: ").bold = True
    p_tech.add_run("Flutter (Dart >= 3.13.1), hỗ trợ Android và iOS. Lưu trữ trên điện thoại bằng thư viện sqflite (SQLite).\n")
    p_tech.add_run("• Backend REST API: ").bold = True
    p_tech.add_run("C# ASP.NET Core 10 (net10.0), Entity Framework Core (Microsoft.EntityFrameworkCore.SqlServer 10.0.x).\n")
    p_tech.add_run("• Database Tập trung: ").bold = True
    p_tech.add_run("Microsoft SQL Server quản lý dữ liệu toàn hệ thống.\n")
    p_tech.add_run("• Cảnh báo quan trọng: ").bold = True
    p_tech.add_run("Giảng viên quy định sinh viên sử dụng công nghệ khác sẽ KHÔNG ĐƯỢC TÍNH ĐIỂM.")

    # Barem table
    doc.add_heading(level=2).add_run("1.1. Bảng Barem Điểm Chi Tiết (10 Điểm Gốc + Điểm Cộng)")
    
    headers = ["Nhóm Chức Năng", "Yêu Cầu / Tên Chức Năng", "Tính Chất", "Điểm", "Ghi Chú Kỹ Thuật"]
    data = [
        ["1. Xác thực", "Đăng ký người dùng", "Bắt buộc", "0.25 đ", "POST /api/auth/register, kiểm tra trùng"],
        ["", "Đăng nhập", "Bắt buộc", "0.25 đ", "POST /api/auth/login, lưu token SQLite"],
        ["", "Đổi mật khẩu", "Bắt buộc", "0.25 đ", "POST /api/auth/change-password"],
        ["", "Quản lý member & Role", "Bắt buộc", "0.75 đ", "Xem danh sách, phân quyền Admin/Member"],
        ["", "Thoát (Logout) & Phân quyền", "Bắt buộc", "0.75 đ", "Xóa session, điều hướng theo vai trò"],
        ["", "Xác thực Email & Quên mật khẩu", "Điểm cộng", "1.00 đ", "Mã OTP qua email"],
        ["", "Đăng nhập Gmail, FB, Zalo", "Điểm cộng", "1.50 đ", "OAuth2 mạng xã hội (3 * 0.5đ)"],
        ["2. Danh mục", "Xem, Thêm, Sửa, Xóa danh mục", "Bắt buộc", "1.00 đ", "CRUD danh mục đầy đủ"],
        ["", "Kiểm tra danh mục có sản phẩm", "Bắt buộc", "0.25 đ", "Chặn xóa nếu danh mục còn món"],
        ["", "Upload hình ảnh (Thêm, Xóa, Sửa)", "Điểm cộng", "0.75 đ", "Xóa ảnh cũ trên server wwwroot"],
        ["3. Sản phẩm", "Hiển thị có phân trang (Pagination)", "Bắt buộc", "0.50 đ", "Cuộn trang tải thêm (Lazy load)"],
        ["", "Thêm, Sửa, Xóa (Upload ảnh)", "Bắt buộc", "1.50 đ", "Upload ảnh mới, dọn ảnh cũ"],
        ["", "Kiểm tra sản phẩm trong đơn hàng", "Điểm cộng", "0.50 đ", "Ràng buộc không cho xóa nếu có đơn"],
        ["4. Trang chủ", "Danh mục, Món mới, Tìm kiếm", "Bắt buộc", "1.25 đ", "Phân trang đầy đủ (+0.5đ)"],
        ["", "Chi tiết & Sản phẩm liên quan", "Bắt buộc + Cộng", "0.75 đ", "Hiển thị gợi ý món cùng danh mục"],
        ["5. Giỏ hàng", "Nút thêm, Thêm giỏ, Badge số lượng", "Bắt buộc", "0.75 đ", "Lưu trữ SQLite cục bộ"],
        ["", "Xem, Sửa số lượng, Xóa món", "Bắt buộc", "1.00 đ", "Nút (+), (-), cập nhật tổng tiền"],
        ["", "Đặt hàng (Checkout), Chi tiết đơn", "Bắt buộc", "0.75 đ", "Lưu vào SQL Server, đổi trạng thái bàn"],
        ["", "Tìm kiếm đơn & Thanh toán Online", "Điểm cộng", "1.25 đ", "Tích hợp VietQR động & VNPayment"],
        ["6. Quản lý Đơn", "Xem danh sách, Cập nhật trạng thái", "Bắt buộc", "0.75 đ", "Đổi trạng thái chế biến/phục vụ"],
        ["", "Tìm kiếm đơn, Lọc theo ngày", "Điểm cộng", "0.50 đ", "DateRangePicker lọc doanh thu"]
    ]

    table = doc.add_table(rows=len(data) + 1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    # Header row formatting
    hdr_cells = table.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        set_cell_background(hdr_cells[i], "1A365D")
        for p in hdr_cells[i].paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            for run in p.runs:
                run.font.bold = True
                run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                run.font.size = Pt(9.5)

    # Data rows formatting
    for r_idx, row_data in enumerate(data):
        row_cells = table.rows[r_idx + 1].cells
        bg_color = "F7FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, val in enumerate(row_data):
            row_cells[c_idx].text = val
            set_cell_background(row_cells[c_idx], bg_color)
            for p in row_cells[c_idx].paragraphs:
                p.paragraph_format.space_before = Pt(2)
                p.paragraph_format.space_after = Pt(2)
                if c_idx in [2, 3]:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for run in p.runs:
                    run.font.size = Pt(9)
                    if "Bắt buộc" in val:
                        run.font.bold = True

    doc.add_paragraph()

    # SECTION 2: ARCHITECTURE CONVENTIONS
    h2 = doc.add_heading(level=1)
    h2.add_run("2. QUY CHUẨN KIẾN TRÚC & PHONG CÁCH CODE CỦA GIẢNG VIÊN").font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)

    doc.add_paragraph(
        "Để đảm bảo đúng 100% phong cách giảng viên yêu cầu (dựa trên phân tích mã nguồn mẫu TrekBikes), "
        "toàn bộ collaborator phải tuân theo cấu trúc sau:"
    )

    doc.add_heading(level=2).add_run("2.1. Phía Backend ASP.NET Core 10 Web API")
    p_be = doc.add_paragraph()
    p_be.add_run("1. BaseController: ").bold = True
    p_be.add_run("Cung cấp thuộc tính Provider trỏ tới SiteProvider qua HttpContext.RequestServices.\n")
    p_be.add_run("2. BaseRepository & Specific Repositories: ").bold = True
    p_be.add_run("Mỗi Repository (CategoryRepository, ProductRepository, OrderRepository...) kế thừa BaseRepository và nhận DbContext vào constructor.\n")
    p_be.add_run("3. BaseProvider & SiteProvider: ").bold = True
    p_be.add_run("SiteProvider tập hợp toàn bộ các Repository bằng cơ chế Lazy Initialization (ví dụ: public CategoryRepository Category => category ??= new CategoryRepository(Context);). Đăng ký Scoped trong Program.cs.\n")
    p_be.add_run("4. Helper xử lý ảnh: ").bold = True
    p_be.add_run("Lưu file ảnh vào wwwroot/images/{folder} và xóa file ảnh cũ khi cập nhật để tránh rác server.")

    doc.add_heading(level=2).add_run("2.2. Phía Mobile Flutter")
    p_fe = doc.add_paragraph()
    p_fe.add_run("1. Model DTOs: ").bold = True
    p_fe.add_run("Viết tay các class với named parameters, factory Model.fromMap(Map<String, dynamic> map) và Map<String, dynamic> toMap().\n")
    p_fe.add_run("2. Repository Pattern: ").bold = True
    p_fe.add_run("Class tĩnh hoặc service độc lập (CategoryRepository, ProductRepository) sử dụng thư viện http gọi API, parse dữ liệu sạch sẽ.\n")
    p_fe.add_run("3. SQLite Local DB (DatabaseHelper): ").bold = True
    p_fe.add_run("Dùng DatabaseHelper singleton khởi tạo SQLite, bảng CartItems lưu giỏ hàng offline, bảng LocalUserSession lưu phiên đăng nhập.\n")
    p_fe.add_run("4. State Management: ").bold = True
    p_fe.add_run("Dùng StatefulWidget + setState() chuẩn mực, trực quan, dễ bảo trì và dễ giải trình khi bảo vệ đồ án.")

    # SECTION 3: EXTENDED FEATURES
    doc.add_heading(level=1).add_run("3. CÁC TÍNH NĂNG MỞ RỘNG ĐÁNG LÀM (GIẢI TRÌNH ĐIỂM TƯƠNG ĐƯƠNG)").font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
    doc.add_paragraph(
        "Nhằm đạt điểm 10 tuyệt đối và thuyết phục hội đồng chấm điểm, nhóm triển khai 4 tính năng mở rộng F&B thực tế:\n"
        "1. Quản lý Sơ đồ Bàn & Khu vực (Floor/Table Map): Hiển thị bàn trống (xanh), có khách (đỏ), chuyển bàn và gộp bàn.\n"
        "2. Màn hình Bếp / Pha chế (Kitchen Display System - KDS): Bếp nhận món trực tiếp từ phục vụ, cập nhật trạng thái Chờ làm -> Đang nấu -> Hoàn thành.\n"
        "3. Thanh toán VietQR Động: Tự động sinh mã VietQR NAPAS 247 kèm số tiền và mã hóa đơn để khách chuyển khoản tức thì.\n"
        "4. In Hóa đơn Nhiệt ESC/POS & Xuất PDF: Xem trước và in hóa đơn thanh toán chuẩn nhà hàng."
    )

    # SECTION 4: 6 PHASES & ASSIGNMENT
    doc.add_heading(level=1).add_run("4. KẾ HOẠCH TRIỂN KHAI 6 PHASE & PHÂN CÔNG CÔNG VIỆC").font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
    
    phases = [
        ("Phase 1: Khởi tạo Hạ tầng & CSDL", "Ngày 1 - 2", "Chạy script SQL Server, tạo DbContext, cấu hình SQLite DatabaseHelper trên Flutter", "Fullstack Lead"),
        ("Phase 2: Nhóm Xác thực & Phân quyền", "Ngày 3 - 5", "API Auth (Register, Login, Password), Màn hình Login/Register, Session SQLite, Phân quyền Admin/Member", "Dev Backend & Dev Mobile 1"),
        ("Phase 3: Danh mục & Sản phẩm Admin", "Ngày 6 - 9", "Upload ảnh 3 trường hợp (Thêm/Sửa/Xóa), Phân trang sản phẩm, Chặn xóa khi có ràng buộc", "Dev Backend & Dev Mobile 2"),
        ("Phase 4: Trang chủ & Giỏ hàng SQLite", "Ngày 10 - 13", "Tìm kiếm phân trang, Món mới, Giỏ hàng lưu SQLite, Cập nhật số lượng (+/-), Checkout", "Dev Mobile 1 & Dev Mobile 2"),
        ("Phase 5: Quản lý Đơn hàng & Thanh toán", "Ngày 14 - 17", "Admin Order status, Lọc theo khoảng ngày, Tích hợp VietQR động và VNPayment Sandbox", "Dev Backend & Dev Mobile 1"),
        ("Phase 6: Mở rộng (Sơ đồ bàn, Bếp KDS) & Tổng duyệt", "Ngày 18 - 20", "Giao diện Bàn ăn, Màn hình Bếp, Xuất hóa đơn PDF, Test biên, Tổng duyệt nghiệm thu", "Toàn bộ thành viên")
    ]

    p_table = doc.add_table(rows=len(phases) + 1, cols=4)
    p_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    p_headers = ["Giai Đoạn", "Thời Gian", "Nội Dung Công Việc Chi Tiết", "Phụ Trách"]
    for i, title in enumerate(p_headers):
        p_table.rows[0].cells[i].text = title
        set_cell_background(p_table.rows[0].cells[i], "2B6CB0")
        for p in p_table.rows[0].cells[i].paragraphs:
            for run in p.runs:
                run.font.bold = True
                run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                run.font.size = Pt(9.5)

    for r_idx, (p_name, p_time, p_task, p_owner) in enumerate(phases):
        r_cells = p_table.rows[r_idx + 1].cells
        bg = "F7FAFC" if r_idx % 2 == 1 else "FFFFFF"
        for c_idx, text in enumerate([p_name, p_time, p_task, p_owner]):
            r_cells[c_idx].text = text
            set_cell_background(r_cells[c_idx], bg)
            for p in r_cells[c_idx].paragraphs:
                p.paragraph_format.space_before = Pt(2)
                p.paragraph_format.space_after = Pt(2)
                for run in p.runs:
                    run.font.size = Pt(9)
                    if c_idx == 0:
                        run.font.bold = True

    doc.add_paragraph()

    # SECTION 5: INSTALLATION & RUN GUIDE
    doc.add_heading(level=1).add_run("5. HƯỚNG DẪN CÀI ĐẶT & CHẠY THỬ NGHIỆM").font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
    doc.add_paragraph(
        "1. Khởi chạy CSDL SQL Server:\n"
        "   - Mở SSMS, mở file docs/04_THIET_KE_CO_SO_DU_LIEU_MERMAID.md và thực thi toàn bộ script T-SQL để tạo database RestaurantPosDb kèm dữ liệu mẫu.\n"
        "2. Khởi chạy Backend ASP.NET Core 10 Web API:\n"
        "   - cd backend\n"
        "   - dotnet run --urls \"http://localhost:5138\"\n"
        "3. Khởi chạy Mobile Flutter:\n"
        "   - cd mobile\n"
        "   - flutter pub get\n"
        "   - flutter run\n"
    )

    doc.save("D:/Download/restaurant_pos_app/docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx")
    print("Document successfully created at D:/Download/restaurant_pos_app/docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx")

if __name__ == "__main__":
    create_document()
