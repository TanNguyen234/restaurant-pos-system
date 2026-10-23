using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;

namespace WebApi.Models;

public class AccountRepository : BaseRepository
{
    public AccountRepository(RestaurantPosContext context) : base(context) { }

    /// <summary>
    /// Băm mật khẩu bằng thuật toán chuẩn SHA-256 (tương thích 100% với kịch bản SQL nạp mẫu)
    /// </summary>
    public static string HashPassword(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, 210_000, HashAlgorithmName.SHA256, 32);
        return $"pbkdf2$210000${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    private static bool VerifyPassword(string password, string stored)
    {
        var components = stored.Split('$');
        if (components.Length == 4 && components[0] == "pbkdf2" &&
            int.TryParse(components[1], out var rounds) && rounds >= 100_000 && rounds <= 1_000_000)
        {
            try
            {
                var salt = Convert.FromBase64String(components[2]);
                var expected = Convert.FromBase64String(components[3]);
                if (salt.Length != 16 || expected.Length != 32) return false;
                var supplied = Rfc2898DeriveBytes.Pbkdf2(password, salt, rounds, HashAlgorithmName.SHA256, 32);
                return CryptographicOperations.FixedTimeEquals(supplied, expected);
            }
            catch (FormatException) { return false; }
        }

        // One-time migration for legacy SHA256 hashes stored in RestaurantPosDb.sql.
        if (stored.Length != 64) return false;
        byte[] legacy;
        try { legacy = Convert.FromHexString(stored); }
        catch (FormatException) { return false; }
        var computed = SHA256.HashData(Encoding.UTF8.GetBytes(password));
        return CryptographicOperations.FixedTimeEquals(legacy, computed);
    }

    /// <summary>
    /// Xác thực đăng nhập tài khoản
    /// </summary>
    public Account? Login(string username, string password)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return null;

        var account = context.Accounts
            .FirstOrDefault(a => a.Username.ToLower() == username.Trim().ToLower() && a.IsActive);

        if (account == null) return null;

        // Kiểm tra khớp mật khẩu băm SHA-256 (hoặc so sánh trực tiếp nếu mật khẩu chưa băm)
        if (VerifyPassword(password, account.PasswordHash))
        {
            if (!account.PasswordHash.StartsWith("pbkdf2$", StringComparison.Ordinal))
            {
                account.PasswordHash = HashPassword(password);
                account.UpdatedAt = DateTime.UtcNow;
                context.SaveChanges();
            }
            return account;
        }

        return null;
    }

    /// <summary>
    /// Đăng ký tài khoản mới kèm kiểm tra trùng username và email
    /// </summary>
    public (bool Success, string Message, Account? Account) Register(
        string username,
        string password,
        string fullName,
        string? email,
        string? phoneNumber,
        int roleId = 4)
    {
        if (string.IsNullOrWhiteSpace(username))
            return (false, "Tên đăng nhập không được để trống", null);

        if (string.IsNullOrWhiteSpace(password) || password.Length < 10)
            return (false, "Mật khẩu phải chứa ít nhất 10 ký tự", null);

        if (string.IsNullOrWhiteSpace(fullName))
            return (false, "Họ tên không được để trống", null);

        // Kiểm tra trùng username
        bool usernameExists = context.Accounts.Any(a => a.Username.ToLower() == username.Trim().ToLower());
        if (usernameExists)
        {
            return (false, "Tên đăng nhập đã được sử dụng trong hệ thống", null);
        }

        // Kiểm tra trùng email (nếu có cung cấp email)
        if (!string.IsNullOrWhiteSpace(email))
        {
            bool emailExists = context.Accounts.Any(a => a.Email != null && a.Email.ToLower() == email.Trim().ToLower());
            if (emailExists)
            {
                return (false, "Email đã được sử dụng trong hệ thống", null);
            }
        }

        // Self-registration can only create a customer account; role changes are admin actions.
        roleId = 8;

        var newAccount = new Account
        {
            RoleId = roleId,
            Username = username.Trim(),
            PasswordHash = HashPassword(password),
            FullName = fullName.Trim(),
            Email = string.IsNullOrWhiteSpace(email) ? null : email.Trim(),
            PhoneNumber = string.IsNullOrWhiteSpace(phoneNumber) ? null : phoneNumber.Trim(),
            Avatar = "default_avatar.png",
            IsActive = true,
            IsEmailVerified = false,
            OAuthProvider = "Local",
            CreatedAt = DateTime.Now
        };

        context.Accounts.Add(newAccount);
        context.SaveChanges();

        return (true, "Đăng ký tài khoản thành công", newAccount);
    }

    /// <summary>
    /// Đổi mật khẩu tài khoản
    /// </summary>
    public (bool Success, string Message) ChangePassword(int accountId, string oldPassword, string newPassword)
    {
        var account = context.Accounts.Find(accountId);
        if (account == null)
        {
            return (false, "Không tìm thấy tài khoản");
        }

        if (!VerifyPassword(oldPassword, account.PasswordHash))
        {
            return (false, "Mật khẩu cũ không chính xác");
        }

        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 10)
        {
            return (false, "Mật khẩu mới phải chứa ít nhất 10 ký tự");
        }

        account.PasswordHash = HashPassword(newPassword);
        account.UpdatedAt = DateTime.Now;
        context.SaveChanges();

        return (true, "Đổi mật khẩu thành công");
    }

    /// <summary>
    /// Lấy danh sách thành viên/nhân viên kèm thông tin vai trò
    /// </summary>
    public List<AccountMemberDto> GetMembers()
    {
        var query = from a in context.Accounts
                    join r in context.Roles on a.RoleId equals r.RoleId into roleGroup
                    from r in roleGroup.DefaultIfEmpty()
                    orderby a.AccountId
                    select new AccountMemberDto
                    {
                        AccountId = a.AccountId,
                        RoleId = a.RoleId,
                        RoleName = r != null ? r.RoleName : "Chưa phân quyền",
                        RoleCode = r != null ? r.RoleCode : "UNKNOWN",
                        Username = a.Username,
                        FullName = a.FullName,
                        Email = a.Email,
                        PhoneNumber = a.PhoneNumber,
                        Avatar = a.Avatar,
                        IsActive = a.IsActive,
                        CreatedAt = a.CreatedAt
                    };

        return query.ToList();
    }

    /// <summary>
    /// Lấy thông tin tài khoản theo ID
    /// </summary>
    public Account? GetById(int accountId)
    {
        return context.Accounts.Find(accountId);
    }

    /// <summary>
    /// Cập nhật vai trò (Role) cho tài khoản
    /// </summary>
    public (bool Success, string Message) UpdateRole(int accountId, int newRoleId)
    {
        var account = context.Accounts.Find(accountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");

        var role = context.Roles.Find(newRoleId);
        if (role == null) return (false, "Vai trò không hợp lệ");

        account.RoleId = newRoleId;
        account.UpdatedAt = DateTime.Now;
        context.SaveChanges();

        return (true, $"Đã cập nhật vai trò thành công sang '{role.RoleName}'");
    }

    /// <summary>
    /// Lấy danh sách toàn bộ vai trò trong hệ thống
    /// </summary>
    public List<Role> GetRoles()
    {
        return context.Roles.OrderBy(r => r.RoleId).ToList();
    }

    /// <summary>
    /// Lấy Role theo RoleId
    /// </summary>
    public Role? GetRoleById(int roleId)
    {
        return context.Roles.Find(roleId);
    }
}

public class AccountMemberDto
{
    public int AccountId { get; set; }
    public int RoleId { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string RoleCode { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Avatar { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
