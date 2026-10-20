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
        using var sha256 = SHA256.Create();
        var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    /// <summary>
    /// Xác thực đăng nhập tài khoản
    /// </summary>
    public Account? Login(string username, string password)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return null;

        string hash = HashPassword(password);
        var account = context.Accounts
            .FirstOrDefault(a => a.Username.ToLower() == username.Trim().ToLower() && a.IsActive);

        if (account == null) return null;

        // Kiểm tra khớp mật khẩu băm SHA-256 (hoặc so sánh trực tiếp nếu mật khẩu chưa băm)
        if (account.PasswordHash == hash || account.PasswordHash == password)
        {
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

        if (string.IsNullOrWhiteSpace(password) || password.Length < 4)
            return (false, "Mật khẩu phải chứa ít nhất 4 ký tự", null);

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

        // Kiểm tra role tồn tại
        var role = context.Roles.Find(roleId);
        if (role == null)
        {
            roleId = 4; // Mặc định Waiter / Member
        }

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

        string oldHash = HashPassword(oldPassword);
        if (account.PasswordHash != oldHash && account.PasswordHash != oldPassword)
        {
            return (false, "Mật khẩu cũ không chính xác");
        }

        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 4)
        {
            return (false, "Mật khẩu mới phải chứa ít nhất 4 ký tự");
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
