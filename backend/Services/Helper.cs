namespace WebApi.Services;

public static class Helper
{
    public static readonly string[] AllowedImageExtensions = { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
    public const long MaxImageSizeBytes = 5 * 1024 * 1024; // 5 MB

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

        errorMessage = null;
        return true;
    }

    public static string RandomString(int len)
    {
        string pattern = "0123456789abcdefghijklmnopqrstuvwxyz";
        char[] arr = new char[len];
        Random rand = new Random();
        for (int i = 0; i < len; i++)
        {
            arr[i] = pattern[rand.Next(0, pattern.Length)];
        }
        return string.Join(string.Empty, arr);
    }

    public static async Task<string> SaveImageAsync(IFormFile file, string folder = "images")
    {
        if (!ValidateImage(file, out string? validationError))
        {
            throw new ArgumentException(validationError);
        }

        string ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        string fileName = RandomString(16) + ext;
        string targetDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", folder);
        if (!Directory.Exists(targetDir))
        {
            Directory.CreateDirectory(targetDir);
        }
        string fullPath = Path.Combine(targetDir, fileName);
        using (var stream = new FileStream(fullPath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }
        return fileName;
    }

    public static void DeleteImage(string fileName, string folder = "images")
    {
        if (string.IsNullOrEmpty(fileName)) return;
        string fullPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", folder, fileName);
        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }
    }
}
