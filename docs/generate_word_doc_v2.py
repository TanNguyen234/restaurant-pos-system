import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
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

    # 1. Cấu hình lề trang chuẩn văn bản (Top: 2cm, Bottom: 2cm, Left: 3cm, Right: 2cm)
    for section in doc.sections:
        section.top_margin = Inches(0.79)     # ~2.0 cm
        section.bottom_margin = Inches(0.79)  # ~2.0 cm
        section.left_margin = Inches(1.18)    # ~3.0 cm
        section.right_margin = Inches(0.79)   # ~2.0 cm

    # 2. Cấu hình Style mặc định: Times New Roman, Size 13, Màu đen #000000, Dãn dòng 1.5
    normal_style = doc.styles['Normal']
    normal_font = normal_style.font
    normal_font.name = 'Times New Roman'
    normal_font.size = Pt(13)
    normal_font.color.rgb = RGBColor(0, 0, 0)
    normal_style.paragraph_format.line_spacing = 1.5
    normal_style.paragraph_format.space_after = Pt(6)

    def add_p(text, bold=False, italic=False, align=WD_ALIGN_PARAGRAPH.JUSTIFY):
        p = doc.add_paragraph()
        p.alignment = align
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(13)
        r.font.bold = bold
        r.font.italic = italic
        r.font.color.rgb = RGBColor(0, 0, 0)
        return p

    def add_h1(text):
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(16)
        r.font.bold = True
        r.font.color.rgb = RGBColor(0, 0, 0)
        return p

    def add_h2(text):
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(14)
        r.font.bold = True
        r.font.color.rgb = RGBColor(0, 0, 0)
        return p

    def add_h3(text):
        p = doc.add_paragraph()
        p.paragraph_format.line_spacing = 1.5
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(3)
        r = p.add_run(text)
        r.font.name = 'Times New Roman'
        r.font.size = Pt(13)
        r.font.bold = True
        r.font.italic = True
        r.font.color.rgb = RGBColor(0, 0, 0)
        return p

    # --- TIÊU ĐỀ BÌA TÀI LIỆU ---
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_title.paragraph_format.line_spacing = 1.5
    r_main_title = p_title.add_run("TÀI LIỆU ĐẶC TẢ KỸ THUẬT & HƯỚNG DẪN THỰC THI DỰ ÁN\n(COLLABORATOR HANDBOOK)\n")
    r_main_title.font.name = 'Times New Roman'
    r_main_title.font.size = Pt(18)
    r_main_title.font.bold = True
    r_main_title.font.color.rgb = RGBColor(0, 0, 0)

    r_sub = p_title.add_run("ĐỀ TÀI: XÂY DỰNG ỨNG DỤNG HỖ TRỢ NHÀ HÀNG, QUÁN CÀ PHÊ QUẢN LÝ VIỆC ORDER, TÍNH TIỀN VÀ PHỤC VỤ (RESTAURANT & CAFE POS)\n")
    r_sub.font.name = 'Times New Roman'
    r_sub.font.size = Pt(14)
    r_sub.font.bold = True
    r_sub.font.color.rgb = RGBColor(0, 0, 0)

    r_tech = p_title.add_run("Công nghệ bắt buộc: Flutter (Dart) • SQLite on Device • ASP.NET Core 10 Web API • Microsoft SQL Server\n")
    r_tech.font.name = 'Times New Roman'
    r_tech.font.size = Pt(12)
    r_tech.font.italic = True
    r_tech.font.color.rgb = RGBColor(0, 0, 0)

    add_p("---------------------------------------------------------------------------------------------------------------------------------", align=WD_ALIGN_PARAGRAPH.CENTER)

    # --- PHẦN 1: TỔNG QUAN VÀ BAREM ĐIỂM CHUẨN ---
    add_h1("1. TỔNG QUAN DỰ ÁN & BẢNG BAREM ĐIỂM CHI TIẾT")
    add_p(
        "Tài liệu này được biên soạn nhằm hướng dẫn trực tiếp cho tất cả các thành viên tham gia phát triển (collaborator), "
        "quy định rõ ràng quy chuẩn mã nguồn, luồng dữ liệu giữa các tầng, đặc tả API và phân công công việc cụ thể. "
        "Yêu cầu tiên quyết của giảng viên: Bắt buộc sử dụng đúng công nghệ Flutter (Dart), SQLite trên máy điện thoại, "
        "REST API C# ASP.NET Core 10 và cơ sở dữ liệu Microsoft SQL Server. Sinh viên sử dụng công nghệ khác sẽ không được tính điểm."
    )

    add_h2("1.1. Bảng Barem Điểm Bắt Buộc & Điểm Cộng (10 Điểm Gốc + 3.5 Điểm Cộng)")

    headers_barem = ["Nhóm Chức Năng", "Tên Chức Năng Cụ Thể", "Tính Chất", "Điểm", "Ghi Chú Kỹ Thuật"]
    barem_data = [
        ["1. Xác thực người dùng (Auth)", "Đăng ký người dùng", "Bắt buộc", "0.25 đ", "POST /api/auth/register, kiểm tra trùng username/email"],
        ["", "Đăng nhập", "Bắt buộc", "0.25 đ", "POST /api/auth/login, sinh token và lưu session vào SQLite"],
        ["", "Đổi mật khẩu", "Bắt buộc", "0.25 đ", "POST /api/auth/change-password, kiểm tra mật khẩu cũ"],
        ["", "Quản lý member", "Bắt buộc", "0.25 đ", "GET /api/member, xem thông tin người dùng"],
        ["", "Quản lý role người dùng", "Bắt buộc", "0.50 đ", "Phân quyền vai trò trong SQL Server"],
        ["", "Chức năng thoát (Logout)", "Bắt buộc", "0.25 đ", "Xóa session token trên thiết bị SQLite"],
        ["", "Phân quyền (Member & Admin)", "Bắt buộc", "0.50 đ", "Điều hướng giao diện theo Role (Admin sang Dashboard, Staff sang POS)"],
        ["", "Xác thực người dùng qua Email", "Điểm cộng", "0.50 đ", "Gửi mã OTP xác nhận tài khoản qua email"],
        ["", "Quên mật khẩu", "Điểm cộng", "0.50 đ", "Gửi mã reset mật khẩu qua email"],
        ["", "Đăng nhập bằng Gmail, FB, Zalo", "Điểm cộng", "1.50 đ", "OAuth2 tích hợp đăng nhập mạng xã hội (3 * 0.5đ)"],
        ["2. Danh mục (Admin)", "Hiển thị danh mục", "Bắt buộc", "0.25 đ", "GET /api/category, hiển thị dạng danh sách/lưới"],
        ["", "Thêm danh mục", "Bắt buộc", "0.25 đ", "POST /api/category, form nhập tên, mô tả, chọn ảnh"],
        ["", "Xóa danh mục", "Bắt buộc", "0.25 đ", "DELETE /api/category/{id}"],
        ["", "Kiểm tra danh mục có sản phẩm", "Bắt buộc", "0.25 đ", "Chặn xóa nếu danh mục đang chứa món ăn/uống"],
        ["", "Sửa danh mục", "Bắt buộc", "0.25 đ", "PUT /api/category/{id}, cập nhật thông tin"],
        ["", "Upload ảnh 3 trường hợp (Thêm/Sửa/Xóa)", "Điểm cộng", "0.75 đ", "Thêm: lưu wwwroot; Sửa: xóa ảnh cũ lưu mới; Xóa: xóa file ảnh vật lý"],
        ["3. Sản phẩm theo danh mục", "Hiển thị sản phẩm có phân trang", "Bắt buộc", "0.50 đ", "GET /api/product?page=x&pageSize=y, cuộn tải thêm"],
        ["", "Thêm sản phẩm (upload ảnh)", "Bắt buộc", "0.50 đ", "POST /api/product, lưu ảnh vật lý vào server"],
        ["", "Xóa sản phẩm (xóa ảnh kèm theo)", "Bắt buộc", "0.50 đ", "DELETE /api/product/{id}, xóa file ảnh trong wwwroot"],
        ["", "Sửa sản phẩm (ảnh mới xóa ảnh cũ)", "Bắt buộc", "0.50 đ", "PUT /api/product/{id}, dọn dẹp ảnh cũ không để rác server"],
        ["", "Kiểm tra sản phẩm trong đơn hàng", "Điểm cộng", "0.50 đ", "Chặn xóa nếu sản phẩm đã có trong bảng OrderDetails"],
        ["4. Hiển thị Trang chủ", "Danh mục sản phẩm", "Bắt buộc", "0.25 đ", "Thanh ngang danh mục đầu trang chủ"],
        ["", "Món mới nhất (có phân trang)", "Bắt buộc", "0.50 đ", "Sắp xếp theo ngày tạo mới, có phân trang"],
        ["", "Món theo danh mục (phân trang)", "Bắt buộc", "0.50 đ", "Bấm danh mục lọc sản phẩm tương ứng (+0.25đ phân trang)"],
        ["", "Tìm kiếm sản phẩm (phân trang)", "Bắt buộc", "0.50 đ", "Search bar tìm theo tên món (+0.25đ phân trang)"],
        ["", "Chi tiết sản phẩm", "Bắt buộc", "0.25 đ", "Hình lớn, giá, mô tả, nút thêm giỏ"],
        ["", "Sản phẩm liên quan (phân trang)", "Điểm cộng", "0.50 đ", "Gợi ý các món cùng danh mục bên dưới (+0.25đ phân trang)"],
        ["5. Giỏ hàng & Đặt hàng", "Đặt button thêm giỏ, thêm vào giỏ", "Bắt buộc", "0.50 đ", "Nút trực quan, lưu vào SQLite cục bộ"],
        ["", "Hiển thị số lượng trên icon giỏ hàng", "Bắt buộc", "0.25 đ", "Badge số lượng realtime trên AppBar"],
        ["", "Hiển thị giỏ hàng & Cập nhật SL", "Bắt buộc", "0.75 đ", "Danh sách món, nút (+) và (-) cập nhật tổng tiền tức thì"],
        ["", "Xóa sản phẩm trên giỏ hàng", "Bắt buộc", "0.25 đ", "Nút xóa hoặc vuốt xóa khỏi SQLite"],
        ["", "Chức năng đặt hàng (Checkout)", "Bắt buộc", "0.50 đ", "Chọn bàn, gửi đơn lên API, lưu vào SQL Server"],
        ["", "Chi tiết đơn hàng & Tìm kiếm đơn", "Bắt buộc", "0.50 đ", "Xem lại hóa đơn, tìm theo mã đơn (+0.25đ tìm kiếm)"],
        ["", "Thanh toán VNPay & VietQR", "Điểm cộng", "1.00 đ", "Tích hợp cổng VNPayment Sandbox và tạo mã VietQR động"],
        ["6. Quản lý Đơn hàng (Admin)", "Hiển thị danh sách đơn hàng", "Bắt buộc", "0.25 đ", "Xem toàn bộ đơn trong ngày theo thời gian thực"],
        ["", "Cập nhật trạng thái đơn hàng", "Bắt buộc", "0.50 đ", "Đổi trạng thái: Chờ xác nhận -> Đang nấu -> Hoàn thành"],
        ["", "Tìm kiếm đơn & Lọc theo ngày", "Điểm cộng", "0.50 đ", "DateRangePicker lọc ngày xem doanh thu (+0.25đ tìm kiếm)"]
    ]

    t_barem = doc.add_table(rows=len(barem_data) + 1, cols=len(headers_barem))
    t_barem.alignment = WD_TABLE_ALIGNMENT.CENTER
    t_barem.autofit = False

    # Định dạng Header
    hdr = t_barem.rows[0].cells
    for i, col_name in enumerate(headers_barem):
        hdr[i].text = col_name
        set_cell_background(hdr[i], "D9D9D9") # Xám nhạt công sở
        for p in hdr[i].paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.line_spacing = 1.5
            for r in p.runs:
                r.font.name = 'Times New Roman'
                r.font.size = Pt(11)
                r.font.bold = True
                r.font.color.rgb = RGBColor(0, 0, 0)

    # Định dạng Data Rows
    for r_i, row_vals in enumerate(barem_data):
        row_cells = t_barem.rows[r_i + 1].cells
        for c_i, val in enumerate(row_vals):
            row_cells[c_i].text = val
            for p in row_cells[c_i].paragraphs:
                p.paragraph_format.line_spacing = 1.2
                p.paragraph_format.space_after = Pt(2)
                if c_i in [2, 3]:
                    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for r in p.runs:
                    r.font.name = 'Times New Roman'
                    r.font.size = Pt(10.5)
                    r.font.color.rgb = RGBColor(0, 0, 0)
                    if "Bắt buộc" in val or "Điểm cộng" in val:
                        r.font.bold = True

    add_p("")

    # --- PHẦN 2: 10 LẦN TỰ PHẢN BIỆN THIẾT KẾ CSDL ---
    add_h1("2. QUÁ TRÌNH 10 LẦN TỰ PHẢN BIỆN & TỐI ƯU HÓA THIẾT KẾ DATABASE")
    add_p(
        "Nhằm xây dựng một cơ sở dữ liệu chuyên nghiệp, chuẩn mực công nghiệp và đáp ứng trọn vẹn mọi yêu cầu "
        "cứng lẫn mở rộng, nhóm phát triển đã tiến hành 10 vòng tự phản biện (Self-Critique & Stress Testing) "
        "đối với cấu trúc dữ liệu trước khi chốt thiết kế cuối cùng:"
    )

    critiques = [
        ("Phản biện 1: Tính vẹn toàn của phân quyền xác thực và Social Login",
         "Thiết kế ban đầu chỉ có RoleId trong bảng Accounts, thiếu các trường hỗ trợ Xác thực Email (Điểm cộng 0.5đ), Quên mật khẩu (0.5đ) và Đăng nhập mạng xã hội (Gmail, FB, Zalo 1.5đ). "
         "Giải pháp tối ưu: Bổ sung trực tiếp các cột IsEmailVerified, EmailVerificationToken, ResetPasswordToken, ResetPasswordExpiry, OAuthProvider, OAuthProviderId vào bảng Accounts. "
         "Nhờ đó, API có thể quản lý đầy đủ vòng đời bảo mật mà không làm phân mảnh bảng."),

        ("Phản biện 2: Cơ chế xóa danh mục và toàn vẹn dữ liệu sản phẩm",
         "Yêu cầu cứng bắt buộc: 'Kiểm tra danh mục có tồn tại sản phẩm trước khi xóa'. Nếu thiết lập khóa ngoại ON DELETE CASCADE, khi xóa danh mục toàn bộ sản phẩm bên trong sẽ bị xóa theo, vi phạm yêu cầu nghiệp vụ. "
         "Giải pháp tối ưu: Thiết lập khóa ngoại FK_Products_Categories với hành vi ON DELETE NO ACTION (hoặc RESTRICT). Đồng thời trong CategoryRepository, bắt buộc viết hàm kiểm tra HasProducts() trước khi thực thi lệnh Delete."),

        ("Phản biện 3: Quản lý vòng đời ảnh trên FileSystem máy chủ (3 trường hợp Thêm, Xóa, Sửa)",
         "Điểm cộng 0.75đ yêu cầu xử lý upload ảnh cả 3 trường hợp. Nhiều đồ án sinh viên chỉ lưu tên file mới mà quên xóa file cũ, dẫn tới phình to thư mục wwwroot gây lãng phí dung lượng. "
         "Giải pháp tối ưu: Viết class Helper.SaveImageAsync() và Helper.DeleteImage(). Khi sửa danh mục hoặc sản phẩm, hệ thống tự động đọc tên ảnh cũ trong DB và xóa file vật lý tương ứng trước khi lưu ảnh mới."),

        ("Phản biện 4: Kiểm tra sản phẩm có trong đơn hàng trước khi xóa (Bảo toàn số liệu kế toán)",
         "Yêu cầu cứng: 'Kiểm tra sản phẩm có trong đơn hàng trước khi xóa'. Trong nghiệp vụ nhà hàng, một món đã bán trong quá khứ không bao giờ được xóa cứng khỏi database vì sẽ làm sai lệch doanh thu lịch sử. "
         "Giải pháp tối ưu: Khóa ngoại FK_OrderDetails_Products đặt ON DELETE NO ACTION. Trong ProductRepository kiểm tra HasOrders(). Nếu đã từng có trong OrderDetails, API trả về lỗi 400 từ chối xóa và gợi ý chuyển cờ IsAvailable = 0 (tạm ngưng bán)."),

        ("Phản biện 5: Hiệu năng truy vấn phân trang (Pagination) và tìm kiếm trên Trang chủ",
         "Các yêu cầu 3.1, 4.2, 4.3, 4.4 đều đòi hỏi phân trang và tìm kiếm. Nếu bảng Products lên tới hàng nghìn món ăn, việc truy vấn COUNT(*) và OFFSET FETCH NEXT mà không có chỉ mục sẽ gây nghẽn cổ chai. "
         "Giải pháp tối ưu: Tạo 2 chỉ mục phi cụm (Non-Clustered Indexes): IX_Products_CategoryId và IX_Products_ProductName. Đảm bảo tốc độ phản hồi API dưới 50ms."),

        ("Phản biện 6: Đơn vị tiền tệ và độ chính xác tài chính trong nhà hàng Việt Nam",
         "Nhiều thiết kế dùng kiểu FLOAT hoặc REAL để lưu giá tiền, dẫn tới sai số làm tròn số thập phân. Trong khi đó tiền Việt Nam Đồng (VNĐ) không sử dụng phần thập phân xu/cắc. "
         "Giải pháp tối ưu: Toàn bộ các cột Price, UnitPrice, TotalAmount, FinalAmount, ExtraPrice đều sử dụng kiểu DECIMAL(18, 0). Không bao giờ xảy ra lỗi sai lệch 1 đồng khi cộng tổng tiền."),

        ("Phản biện 7: Hỗ trợ linh hoạt giữa Khách ăn tại bàn (Dine-In) và Mang về (Takeaway)",
         "Nếu bảng Orders bắt buộc TableId NOT NULL, hệ thống sẽ thất bại khi khách hàng hoặc tài xế mua cà phê mang đi (không ngồi bàn). "
         "Giải pháp tối ưu: Cột TableId trong bảng Orders cho phép giá trị NULL. Thêm cột OrderType (1: Tại bàn, 2: Mang về, 3: Giao tận nơi). Khi OrderType = 2, TableId có thể bỏ trống."),

        ("Phản biện 8: Tùy biến món ăn (Topping, Size, Đường/Đá) đặc thù quán trà sữa & cà phê",
         "Một món như Trà đào có thể có nhiều biến thể: Size M hoặc L, 50% đường, thêm trân châu (+10k). Nếu chỉ lưu ProductId và Quantity thì không thể truyền đạt chính xác xuống quầy pha chế. "
         "Giải pháp tối ưu: Thiết kế bảng ProductAttributes (lưu các tùy chọn Size, Topping kèm phụ thu ExtraPrice) và cột ItemNote trong bảng OrderDetails để nhân viên ghi chú chi tiết từng ly đồ uống."),

        ("Phản biện 9: Màn hình Bếp / Pha chế (Kitchen Display System - KDS) thời gian thực",
         "Đơn hàng gửi xuống bếp cần biết món nào đang chờ, món nào đang nấu, món nào đã xong. "
         "Giải pháp tối ưu: Bổ sung cột CookingStatus trong OrderDetails (0: Chờ nấu, 1: Đang làm, 2: Đã xong) kèm mốc thời gian StartedCookingAt và FinishedCookingAt. Bếp trưởng có thể bấm chuyển trạng thái độc lập từng món."),

        ("Phản biện 10: Tích hợp thanh toán trực tuyến kép: VietQR NAPAS 247 và VNPayment Gateway",
         "Điểm cộng 1.0đ yêu cầu tích hợp cả VietQR và VNPayment. Bảng thanh toán cần lưu lại mã tham chiếu giao dịch và trạng thái đối soát. "
         "Giải pháp tối ưu: Thiết kế bảng Payments với cột PaymentMethod ('Cash', 'VietQR', 'VNPay'), TransactionRef (lưu mã giao dịch ngân hàng / vnp_TxnRef) và Status (0: Chờ, 1: Thành công, 2: Hủy).")
    ]

    for title, desc in critiques:
        add_h2(title)
        add_p(desc)

    # --- PHẦN 3: ĐẶC TẢ KIẾN TRÚC MÃ NGUỒN THEO PHONG CÁCH CỦA THẦY ---
    add_h1("3. QUY CHUẨN KIẾN TRÚC MÃ NGUỒN CỦA GIẢNG VIÊN")
    add_p(
        "Dựa trên phân tích mã nguồn chuẩn mực tại thư mục mẫu TrekBikes và WebApi, "
        "tất cả collaborator phải tuyệt đối tuân theo quy tắc phân tầng sau:"
    )

    add_h2("3.1. Phía Backend ASP.NET Core 10 Web API (net10.0)")
    add_p(
        "1. BaseController: Nằm tại WebApi.Api.Controllers, kế thừa ControllerBase. Cung cấp thuộc tính Provider: "
        "protected SiteProvider Provider => provider ??= HttpContext.RequestServices.GetRequiredService<SiteProvider>();.\n"
        "2. RestaurantPosContext: Kế thừa DbContext, khai báo đầy đủ các DbSet cho 10 bảng dữ liệu.\n"
        "3. BaseRepository & Specific Repositories: Mỗi bảng có một Repository riêng (CategoryRepository, ProductRepository, OrderRepository...) "
        "kế thừa BaseRepository và nhận DbContext vào constructor.\n"
        "4. BaseProvider & SiteProvider: SiteProvider đóng vai trò Facade tập hợp tất cả các Repository bằng cơ chế Lazy Loading. "
        "Đăng ký Scoped trong Program.cs: builder.Services.AddScoped<SiteProvider>();.\n"
        "5. Program.cs: Cấu hình CORS AllowAll, UseStaticFiles() để phục vụ ảnh từ wwwroot, và MapControllers()."
    )

    add_h2("3.2. Phía Mobile Flutter (Dart)")
    add_p(
        "1. Model Entity: Viết tay class với named parameters, factory Model.fromMap(Map<String, dynamic> map) và toMap(). Không dùng thư viện sinh mã ngoài.\n"
        "2. Repository Pattern: Sử dụng thư viện http gọi API, parse JSON bằng jsonDecode(rs.body), xử lý ngoại lệ mạng sạch sẽ.\n"
        "3. DatabaseHelper (SQLite on Device): Sử dụng thư viện sqflite và path, thiết kế theo mẫu Singleton Pattern. "
        "Quản lý bảng cart_items lưu giỏ hàng offline, user_session lưu phiên đăng nhập và offline_orders lưu đơn chờ đồng bộ.\n"
        "4. State Management: Sử dụng StatefulWidget kết hợp setState() đúng như phương pháp giảng dạy, trực quan và dễ bảo vệ trước hội đồng."
    )

    # --- PHẦN 4: HƯỚNG DẪN CHI TIẾT TỪNG BƯỚC CHO COLLABORATOR ---
    add_h1("4. HƯỚNG DẪN TRIỂN KHAI TỪNG FILE & PHÂN CÔNG COLLABORATOR")
    add_p(
        "Để đảm bảo tiến độ và không bị xung đột mã nguồn (merge conflict), dự án được phân chia thành 6 Phase rõ ràng. "
        "Mỗi collaborator mở đúng file được phân công để làm việc:"
    )

    steps = [
        ("Phase 1: Khởi tạo Cơ sở dữ liệu & Base Project (Ngày 1 - 2)",
         "Phụ trách: Fullstack Lead / Database Admin\n"
         "- Mở SQL Server Management Studio (SSMS), mở file RestaurantPosDb.sql tại thư mục gốc dự án.\n"
         "- Thực thi toàn bộ lệnh để tạo database RestaurantPosDb và nạp sẵn 10 dòng dữ liệu mẫu cho mỗi bảng.\n"
         "- Kiểm tra chuỗi kết nối trong backend/appsettings.json đảm bảo kết nối thành công tới SQL Server.\n"
         "- Chạy thử lệnh: dotnet build tại thư mục backend và flutter pub get tại thư mục mobile."),

        ("Phase 2: Nhóm Xác thực người dùng & Phân quyền (Ngày 3 - 5)",
         "Phụ trách: Backend Dev 1 & Mobile Dev 1\n"
         "- Backend: Viết AccountRepository.cs trong backend/Models, tạo AuthController.cs xử lý đăng ký, đăng nhập băm mật khẩu, đổi mật khẩu, phân quyền Role.\n"
         "- Mobile: Tạo mobile/lib/views/auth/login_page.dart và register_page.dart. Khi đăng nhập thành công, lưu token vào DatabaseHelper (bảng user_session). "
         "Kiểm tra role: nếu Admin điều hướng sang AdminDashboard, nếu Staff/Member điều hướng sang Menu bán hàng."),

        ("Phase 3: Quản lý Danh mục & Sản phẩm Admin (Ngày 6 - 9)",
         "Phụ trách: Backend Dev 2 & Mobile Dev 2\n"
         "- Backend: Viết CategoryController.cs và ProductController.cs. Bắt buộc kiểm tra ràng buộc HasProducts() khi xóa danh mục và HasOrders() khi xóa sản phẩm. "
         "Xử lý lưu file ảnh vào wwwroot/images và dọn dẹp file ảnh cũ.\n"
         "- Mobile: Tạo AdminCategoryPage.dart và AdminProductPage.dart. Tích hợp cuộn phân trang (ScrollController tải thêm 10 món mỗi lần) và form chọn ảnh từ thư viện máy."),

        ("Phase 4: Trang chủ & Quản lý Giỏ hàng SQLite (Ngày 10 - 13)",
         "Phụ trách: Mobile Dev 1 & Mobile Dev 2\n"
         "- Tạo HomePage.dart: Thanh tìm kiếm sản phẩm phân trang, danh mục cuộn ngang, danh sách món mới nhất.\n"
         "- Tạo ProductDetailPage.dart: Hiển thị hình ảnh lớn, chọn Size/Topping, nút Thêm vào giỏ.\n"
         "- Tạo CartPage.dart: Đọc trực tiếp từ SQLite cart_items. Nút (+) và (-) cập nhật số lượng và tính lại tổng tiền ngay lập tức. Badge giỏ hàng trên AppBar cập nhật realtime.\n"
         "- Xây dựng form Checkout chọn Bàn phục vụ, gửi đơn hàng lên POST /api/order."),

        ("Phase 5: Quản lý Đơn hàng & Tích hợp Thanh toán (Ngày 14 - 17)",
         "Phụ trách: Backend Dev 1 & Mobile Dev 1\n"
         "- Backend: Viết OrderController.cs với các hàm cập nhật trạng thái đơn (Mới -> Đang nấu -> Hoàn thành), lọc đơn theo khoảng ngày DateRangePicker.\n"
         "- Tích hợp VietQR: Sinh mã QR ngân hàng động theo URL img.vietqr.io kèm số tiền và mã hóa đơn.\n"
         "- Tích hợp VNPayment Sandbox: Tạo URL thanh toán bảo mật với chữ ký HMAC-SHA512.\n"
         "- Mobile: Màn hình OrderDetailPage.dart hiển thị mã QR cho khách quét tiền tại bàn."),

        ("Phase 6: Tính năng Mở rộng (Sơ đồ bàn, Bếp KDS) & Tổng duyệt (Ngày 18 - 20)",
         "Phụ trách: Toàn bộ thành viên nhóm\n"
         "- Tạo FloorTablePage.dart: Hiển thị sơ đồ bàn theo khu vực (Bàn trống màu xanh, Có khách màu đỏ, Đặt trước màu vàng).\n"
         "- Tạo KitchenDisplayPage.dart: Màn hình dành cho đầu bếp nhận order và bấm 'Đang nấu' / 'Đã nấu xong'.\n"
         "- Xuất phiếu hóa đơn thanh toán PDF.\n"
         "- Rà soát lại toàn bộ 37 tiêu chí trong bảng barem điểm, kiểm tra các trường hợp bắt lỗi biên và tổng duyệt trước khi nộp đồ án.")
    ]

    for p_title, p_content in steps:
        add_h2(p_title)
        add_p(p_content)

    # --- PHẦN 5: HƯỚNG DẪN KHỞI CHẠY VÀ KIỂM THỬ ---
    add_h1("5. HƯỚNG DẪN CÀI ĐẶT, KHỞI CHẠY & KIỂM THỬ HỆ THỐNG")
    add_p(
        "1. Khởi chạy Cơ sở dữ liệu SQL Server:\n"
        "   - Mở SSMS, mở file RestaurantPosDb.sql và bấm Execute (F5). Kiểm tra 10 bảng đã có đủ 10 dòng dữ liệu mẫu.\n"
        "2. Khởi chạy Backend ASP.NET Core 10 Web API:\n"
        "   - Mở terminal: cd backend\n"
        "   - Chạy lệnh: dotnet run --urls \"http://localhost:5138\"\n"
        "   - Truy cập kiểm tra API danh mục: http://localhost:5138/api/category\n"
        "3. Khởi chạy Ứng dụng Flutter:\n"
        "   - Mở terminal: cd mobile\n"
        "   - Chạy lệnh: flutter pub get\n"
        "   - Kiểm tra mã nguồn: flutter analyze (đạt 0 lỗi)\n"
        "   - Chạy ứng dụng: flutter run\n"
        "4. Lưu ý khi test trên máy ảo Android:\n"
        "   - Máy ảo Android sử dụng địa chỉ 10.0.2.2 để kết nối vào localhost của máy tính: http://10.0.2.2:5138/api/...\n"
        "   - Máy ảo Windows hoặc trình duyệt Web dùng trực tiếp: http://localhost:5138/api/..."
    )

    doc.save("D:/Download/restaurant_pos_app/docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx")
    print("Document successfully created at D:/Download/restaurant_pos_app/docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx")

if __name__ == "__main__":
    create_document()
