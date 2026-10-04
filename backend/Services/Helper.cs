namespace WebApi.Services;

public static class Helper
{
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
        string ext = Path.GetExtension(file.FileName);
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
