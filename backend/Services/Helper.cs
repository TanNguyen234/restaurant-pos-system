namespace WebApi.Services;

public static class Helper
{
    public static readonly string[] AllowedImageExtensions = { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
    public const long MaxImageSizeBytes = 5 * 1024 * 1024; // 5 MB

    private static string? _webRootPath;

    public static void ConfigureWebRoot(string webRootPath)
    {
        if (!string.IsNullOrWhiteSpace(webRootPath))
        {
            _webRootPath = webRootPath;
        }
    }

    /// <summary>
    /// Xác định thư mục wwwroot thật chứa ảnh. Khi backend chạy từ thư mục khác (ví dụ bin/Debug) thì WebRootPath mặc định
    /// có thể trỏ tới bản sao rỗng; hàm này tìm ngược lên các thư mục cha để gặp wwwroot/images của dự án.
    /// Ảnh tải lên và ảnh được phục vụ luôn dùng chung kết quả này.
    /// </summary>
    public static string LocateWebRoot(string? configuredWebRoot, string contentRoot)
    {
        static bool HasImages(string wwwroot) => Directory.Exists(Path.Combine(wwwroot, "images"));

        if (!string.IsNullOrWhiteSpace(configuredWebRoot) && HasImages(configuredWebRoot)) return configuredWebRoot;

        var starts = new[] { contentRoot, AppContext.BaseDirectory, Directory.GetCurrentDirectory() };
        foreach (var start in starts)
        {
            if (string.IsNullOrWhiteSpace(start)) continue;
            var dir = new DirectoryInfo(start);
            for (int depth = 0; depth < 7 && dir != null; depth++, dir = dir.Parent)
            {
                var direct = Path.Combine(dir.FullName, "wwwroot");
                if (HasImages(direct)) return direct;
                var nested = Path.Combine(dir.FullName, "backend", "wwwroot");
                if (HasImages(nested)) return nested;
            }
        }

        if (!string.IsNullOrWhiteSpace(configuredWebRoot)) return configuredWebRoot;
        return Path.Combine(contentRoot, "wwwroot");
    }

    /// <summary>Tạo sẵn thư mục ảnh sản phẩm và danh mục để việc lưu ảnh không phụ thuộc vào có thư mục từ trước.</summary>
    public static void EnsureImageFolders()
    {
        var root = ResolveWebRoot();
        Directory.CreateDirectory(Path.Combine(root, "images", "products"));
        Directory.CreateDirectory(Path.Combine(root, "images", "categories"));
    }

    private static string ResolveWebRoot()
    {
        if (!string.IsNullOrWhiteSpace(_webRootPath)) return _webRootPath;
        var cwdWwwroot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        if (Directory.Exists(cwdWwwroot)) return cwdWwwroot;
        return Path.Combine(AppContext.BaseDirectory, "wwwroot");
    }

    public static bool ValidateImage(IFormFile? file, out string? errorMessage)
    {
        if (file == null || file.Length == 0)
        {
            errorMessage = "Tệp tin hình ảnh không tồn tại hoặc bị rỗng";
            return false;
        }

        string ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedImageExtensions.Contains(ext))
        {
            errorMessage = $"Định dạng hình ảnh '{ext}' không được hỗ trợ. Chỉ chấp nhận: {string.Join(", ", AllowedImageExtensions)}";
            return false;
        }

        if (file.Length > MaxImageSizeBytes)
        {
            errorMessage = $"Dung lượng ảnh vượt quá giới hạn tối đa 5MB (kích thước hiện tại: {file.Length / (1024 * 1024)}MB)";
            return false;
        }

        // Magic bytes validation
        try
        {
            using var stream = file.OpenReadStream();
            byte[] header = new byte[12];
            int read = stream.Read(header, 0, header.Length);
            bool validMagic =
                (read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) || // JPEG
                (read >= 4 && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) || // PNG
                (read >= 4 && header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x38) || // GIF
                (read >= 12 && header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
                               header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50); // WEBP

            if (!validMagic)
            {
                errorMessage = "Nội dung tệp tin không phải định dạng ảnh hợp lệ (JPEG, PNG, GIF, WEBP)";
                return false;
            }
        }
        catch
        {
            errorMessage = "Không thể đọc tệp tin hình ảnh tải lên";
            return false;
        }

        errorMessage = null;
        return true;
    }

    public static async Task<string> SaveImageAsync(IFormFile file, string folder = "images")
    {
        if (!ValidateImage(file, out string? validationError))
        {
            throw new ArgumentException(validationError);
        }

        string ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        string fileName = Guid.NewGuid().ToString("N") + ext;
        string targetDir = Path.Combine(ResolveWebRoot(), folder);
        if (!Directory.Exists(targetDir))
        {
            Directory.CreateDirectory(targetDir);
        }
        string fullPath = Path.Combine(targetDir, fileName);
        using (var stream = new FileStream(fullPath, FileMode.CreateNew))
        {
            await file.CopyToAsync(stream);
        }
        return fileName;
    }

    public static void DeleteImage(string? fileName, string folder = "images")
    {
        if (string.IsNullOrWhiteSpace(fileName)) return;

        string cleanFileName = Path.GetFileName(fileName.Trim());
        if (string.IsNullOrEmpty(cleanFileName)) return;

        // Bảo vệ ảnh mặc định hệ thống không bị xóa dù có truyền đường dẫn kèm thư mục
        if (cleanFileName.StartsWith("default_", StringComparison.OrdinalIgnoreCase) ||
            cleanFileName.StartsWith("sample_", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        string fullPath = Path.Combine(ResolveWebRoot(), folder, cleanFileName);
        if (File.Exists(fullPath))
        {
            try
            {
                File.Delete(fullPath);
            }
            catch
            {
                // Bỏ qua lỗi khóa file nếu đang được sử dụng
            }
        }
    }
}
