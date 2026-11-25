using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using WebApi.Services;

namespace WebApi.Models;

public class AccountRepository : BaseRepository
{
    private static readonly HashSet<string> AllowedOAuthProviders = new(StringComparer.OrdinalIgnoreCase)
    {
        "Google", "Facebook", "Zalo"
    };

    public AccountRepository(RestaurantPosContext context) : base(context) { }

    public async Task<(bool Success, string Message, Account? Account, string? EmailOtp)> RegisterAsync(RegisterDto dto)
    {
        string username = dto.Username.Trim();
        if (await context.Accounts.AnyAsync(a => a.Username.ToLower() == username.ToLower()))
        {
            return (false, "Tên đăng nhập đã tồn tại trong hệ thống", null, null);
        }

        string? email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();
        if (email != null)
        {
            if (await context.Accounts.AnyAsync(a => a.Email != null && a.Email.ToLower() == email.ToLower()))
            {
                return (false, "Email đã được sử dụng trong hệ thống", null, null);
            }
        }

        // Public registration strictly assigns MEMBER role (Anti-Privilege Escalation)
        var memberRole = await context.Roles.FirstOrDefaultAsync(r => r.RoleCode == "MEMBER");
        if (memberRole == null)
        {
            return (false, "Hệ thống chưa cấu hình vai trò MEMBER", null, null);
        }

        string? emailOtp = null;
        string? hashedOtp = null;
        DateTime? expiry = null;
        if (email != null)
        {
            emailOtp = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
            hashedOtp = PasswordHasher.ComputeSha256($"verify:{email.ToLowerInvariant()}:{emailOtp}");
            expiry = DateTime.Now.AddMinutes(15);
        }

        var account = new Account
        {
            Username = username,
            PasswordHash = PasswordHasher.HashPassword(dto.Password),
            FullName = dto.FullName.Trim(),
            Email = email,
            PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
            RoleId = memberRole.RoleId,
            IsActive = true,
            IsEmailVerified = false,
            EmailVerificationToken = hashedOtp,
            ResetPasswordExpiry = expiry,
            OAuthProvider = "Local",
            LoyaltyPoints = 0,
            CreatedAt = DateTime.Now
        };

        context.Accounts.Add(account);
        await context.SaveChangesAsync();

        return (true, "Đăng ký tài khoản thành công", account, emailOtp);
    }

    public async Task<(bool Success, string Message, Account? Account, Role? Role)> LoginAsync(LoginDto dto)
    {
        string username = dto.Username.Trim();
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Username.ToLower() == username.ToLower());

        if (account == null)
        {
            return (false, "Tên đăng nhập hoặc mật khẩu không chính xác", null, null);
        }

        if (!account.IsActive)
        {
            return (false, "Tài khoản của bạn đã bị khóa hoặc ngừng hoạt động", null, null);
        }

        if (!PasswordHasher.VerifyPassword(dto.Password, account.PasswordHash))
        {
            return (false, "Tên đăng nhập hoặc mật khẩu không chính xác", null, null);
        }

        // Transparently upgrade legacy SHA-256 / salt:sha256 hashes to PBKDF2-SHA256
        if (PasswordHasher.NeedsRehash(account.PasswordHash))
        {
            account.PasswordHash = PasswordHasher.HashPassword(dto.Password);
            account.UpdatedAt = DateTime.Now;
            await context.SaveChangesAsync();
        }

        var role = await context.Roles.FindAsync(account.RoleId);
        return (true, "Đăng nhập thành công", account, role);
    }

    public async Task<(bool Success, string Message)> ChangePasswordAsync(int accountId, string oldPassword, string newPassword)
    {
        var account = await context.Accounts.FindAsync(accountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");
        if (!account.IsActive) return (false, "Tài khoản đã bị khóa");

        if (!PasswordHasher.VerifyPassword(oldPassword, account.PasswordHash))
        {
            return (false, "Mật khẩu hiện tại không chính xác");
        }

        account.PasswordHash = PasswordHasher.HashPassword(newPassword);
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();
        return (true, "Đổi mật khẩu thành công");
    }

    public async Task<(bool Success, string Message)> UpdateProfileAsync(int accountId, UpdateProfileDto dto)
    {
        var account = await context.Accounts.FindAsync(accountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");

        string? newEmail = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();
        if (newEmail != null && !string.Equals(newEmail, account.Email, StringComparison.OrdinalIgnoreCase))
        {
            bool exists = await context.Accounts.AnyAsync(a =>
                a.AccountId != accountId && a.Email != null && a.Email.ToLower() == newEmail.ToLower());
            if (exists) return (false, "Email này đã được sử dụng bởi tài khoản khác");

            account.Email = newEmail;
            account.IsEmailVerified = false;
        }
        else if (newEmail == null)
        {
            account.Email = null;
            account.IsEmailVerified = false;
        }

        account.FullName = dto.FullName.Trim();
        account.PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim();
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, "Cập nhật hồ sơ cá nhân thành công");
    }

    public async Task<(bool Success, string Message)> UpdateRoleAsync(
        int targetAccountId,
        int newRoleId,
        int actorAccountId,
        string actorRoleCode)
    {
        if (targetAccountId == actorAccountId)
        {
            return (false, "Không thể tự thay đổi vai trò của chính mình");
        }

        var account = await context.Accounts.FindAsync(targetAccountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");

        var currentTargetRole = await context.Roles.FindAsync(account.RoleId);
        var newRole = await context.Roles.FindAsync(newRoleId);
        if (newRole == null) return (false, "Vai trò không hợp lệ");

        bool isActorAdmin = string.Equals(actorRoleCode, "ADMIN", StringComparison.OrdinalIgnoreCase);
        if (!isActorAdmin)
        {
            if (string.Equals(newRole.RoleCode, "ADMIN", StringComparison.OrdinalIgnoreCase))
            {
                return (false, "Chỉ Quản trị viên (ADMIN) mới có quyền cấp vai trò ADMIN");
            }
            if (currentTargetRole != null && string.Equals(currentTargetRole.RoleCode, "ADMIN", StringComparison.OrdinalIgnoreCase))
            {
                return (false, "Không có quyền thay đổi vai trò của Quản trị viên");
            }
        }

        account.RoleId = newRoleId;
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, $"Đã cập nhật vai trò thành công sang '{newRole.RoleName}'");
    }

    public async Task<(bool Success, string Message)> UpdateStatusAsync(int targetAccountId, bool isActive, int actorAccountId)
    {
        if (targetAccountId == actorAccountId && !isActive)
        {
            return (false, "Không thể tự khóa tài khoản đang đăng nhập");
        }

        var account = await context.Accounts.FindAsync(targetAccountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");

        account.IsActive = isActive;
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, isActive ? $"Đã mở khóa tài khoản '{account.Username}'" : $"Đã khóa tài khoản '{account.Username}'");
    }

    public async Task<List<AccountDto>> GetMembersAsync(int? roleId = null)
    {
        var query = from a in context.Accounts
                    join r in context.Roles on a.RoleId equals r.RoleId into roleGroup
                    from r in roleGroup.DefaultIfEmpty()
                    select new AccountDto
                    {
                        AccountId = a.AccountId,
                        RoleId = a.RoleId,
                        RoleCode = r != null ? r.RoleCode : "UNKNOWN",
                        RoleName = r != null ? r.RoleName : "Không xác định",
                        Username = a.Username,
                        FullName = a.FullName,
                        Email = a.Email,
                        PhoneNumber = a.PhoneNumber,
                        Avatar = a.Avatar,
                        IsActive = a.IsActive,
                        IsEmailVerified = a.IsEmailVerified,
                        OAuthProvider = a.OAuthProvider,
                        LoyaltyPoints = a.LoyaltyPoints,
                        CreatedAt = a.CreatedAt,
                        UpdatedAt = a.UpdatedAt
                    };

        if (roleId.HasValue && roleId.Value > 0)
        {
            query = query.Where(a => a.RoleId == roleId.Value);
        }

        return await query.OrderBy(a => a.AccountId).ToListAsync();
    }

    public async Task<Account?> GetByIdAsync(int accountId) => await context.Accounts.FindAsync(accountId);

    public async Task<Account?> GetByUsernameAsync(string username) =>
        await context.Accounts.FirstOrDefaultAsync(a => a.Username.ToLower() == username.ToLower());

    public async Task<Account?> GetByEmailAsync(string email) =>
        await context.Accounts.FirstOrDefaultAsync(a => a.Email != null && a.Email.ToLower() == email.ToLower());

    public async Task<Account?> FindByIdentityAsync(string identity)
    {
        var norm = identity.Trim().ToLower();
        return await context.Accounts.FirstOrDefaultAsync(a =>
            (a.Email != null && a.Email.ToLower() == norm) ||
            a.Username.ToLower() == norm);
    }

    public async Task<Role?> GetRoleByIdAsync(int roleId) => await context.Roles.FindAsync(roleId);

    public async Task<List<RoleDto>> GetRolesAsync()
    {
        return await context.Roles
            .OrderBy(r => r.RoleId)
            .Select(r => new RoleDto
            {
                RoleId = r.RoleId,
                RoleName = r.RoleName,
                RoleCode = r.RoleCode,
                Description = r.Description
            })
            .ToListAsync();
    }

    public async Task<(bool Success, string Message, Account? Account, string? Otp)> IssueEmailVerificationOtpAsync(string identity)
    {
        var account = await FindByIdentityAsync(identity);
        if (account == null) return (false, "Không tìm thấy tài khoản phù hợp", null, null);
        if (!account.IsActive) return (false, "Tài khoản đã bị khóa", null, null);
        if (string.IsNullOrWhiteSpace(account.Email)) return (false, "Tài khoản chưa đăng ký địa chỉ email", null, null);
        if (account.IsEmailVerified) return (false, "Email tài khoản này đã được xác thực trước đó", null, null);

        string otp = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        account.EmailVerificationToken = PasswordHasher.ComputeSha256($"verify:{account.Email.ToLowerInvariant()}:{otp}");
        account.ResetPasswordExpiry = DateTime.Now.AddMinutes(15);
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, "Đã khởi tạo mã xác thực Email", account, otp);
    }

    public async Task<(bool Success, string Message)> VerifyEmailOtpAsync(string identity, string otp)
    {
        var account = await FindByIdentityAsync(identity);
        if (account == null || string.IsNullOrWhiteSpace(account.Email))
        {
            return (false, "Không tìm thấy tài khoản hoặc email cần xác thực");
        }

        if (account.IsEmailVerified)
        {
            return (true, "Email đã được xác thực");
        }

        if (string.IsNullOrWhiteSpace(account.EmailVerificationToken) ||
            !account.ResetPasswordExpiry.HasValue ||
            account.ResetPasswordExpiry.Value < DateTime.Now)
        {
            return (false, "Mã xác thực email đã hết hạn hoặc chưa được yêu cầu");
        }

        string expected = PasswordHasher.ComputeSha256($"verify:{account.Email.ToLowerInvariant()}:{otp.Trim()}");
        if (!string.Equals(expected, account.EmailVerificationToken, StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Mã xác thực OTP không chính xác");
        }

        account.IsEmailVerified = true;
        account.EmailVerificationToken = null;
        account.ResetPasswordExpiry = null;
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, "Xác thực Email thành công!");
    }

    public async Task<(bool Success, string Message, Account? Account, string? Otp)> IssuePasswordResetOtpAsync(string identity)
    {
        var account = await FindByIdentityAsync(identity);
        if (account == null) return (false, "Không tìm thấy tài khoản phù hợp với thông tin đã cung cấp", null, null);
        if (!account.IsActive) return (false, "Tài khoản hiện đang bị khóa, không thể đặt lại mật khẩu", null, null);
        if (string.IsNullOrWhiteSpace(account.Email)) return (false, "Tài khoản chưa liên kết email để nhận mã khôi phục", null, null);

        string otp = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
        account.ResetPasswordToken = PasswordHasher.ComputeSha256($"reset:{account.AccountId}:{otp}");
        account.ResetPasswordExpiry = DateTime.Now.AddMinutes(5);
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, "Đã khởi tạo mã OTP khôi phục mật khẩu", account, otp);
    }

    public async Task<(bool Success, string Message)> ResetPasswordWithOtpAsync(string identity, string otp, string newPassword)
    {
        var account = await FindByIdentityAsync(identity);
        if (account == null) return (false, "Tài khoản không tồn tại");
        if (!account.IsActive) return (false, "Tài khoản hiện đang bị khóa");

        if (string.IsNullOrWhiteSpace(account.ResetPasswordToken) ||
            !account.ResetPasswordExpiry.HasValue ||
            account.ResetPasswordExpiry.Value < DateTime.Now)
        {
            return (false, "Mã OTP không chính xác hoặc đã hết thời gian hiệu lực (5 phút)!");
        }

        string expectedHash = PasswordHasher.ComputeSha256($"reset:{account.AccountId}:{otp.Trim()}");
        if (!string.Equals(expectedHash, account.ResetPasswordToken, StringComparison.OrdinalIgnoreCase))
        {
            return (false, "Mã OTP không chính xác hoặc đã hết thời gian hiệu lực (5 phút)!");
        }

        account.PasswordHash = PasswordHasher.HashPassword(newPassword);
        account.ResetPasswordToken = null;
        account.ResetPasswordExpiry = null;
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, "Đặt lại mật khẩu mới thành công! Bạn có thể đăng nhập ngay bằng mật khẩu mới.");
    }

    public async Task<(bool Success, string Message, Account? Account, Role? Role)> OAuthLoginAsync(OAuthLoginDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Provider) || !AllowedOAuthProviders.Contains(dto.Provider.Trim()))
        {
            return (false, "Nhà cung cấp OAuth không được hỗ trợ (Chỉ hỗ trợ Google, Facebook, Zalo)", null, null);
        }

        if (string.IsNullOrWhiteSpace(dto.Email))
        {
            return (false, "Email đăng nhập mạng xã hội không hợp lệ", null, null);
        }

        string provider = AllowedOAuthProviders.First(p => p.Equals(dto.Provider.Trim(), StringComparison.OrdinalIgnoreCase));
        string email = dto.Email.Trim().ToLowerInvariant();
        var existing = await context.Accounts
            .FirstOrDefaultAsync(a => a.Email != null && a.Email.ToLower() == email);

        if (existing != null)
        {
            if (!existing.IsActive)
            {
                return (false, "Tài khoản này đã bị khóa hoặc ngừng hoạt động", null, null);
            }

            var existingRole = await context.Roles.FindAsync(existing.RoleId);
            string roleCode = existingRole?.RoleCode ?? "MEMBER";

            // SECURITY FIX: Never allow OAuth Sandbox flow to hijack staff/admin accounts!
            if (roleCode is not ("MEMBER" or "VIP_MEMBER"))
            {
                return (false, "Tài khoản nhân sự/quản trị nội bộ không được phép đăng nhập qua OAuth khách hàng. Vui lòng dùng mật khẩu hệ thống.", null, null);
            }

            existing.FullName = string.IsNullOrWhiteSpace(dto.FullName) ? existing.FullName : dto.FullName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.Avatar)) existing.Avatar = dto.Avatar.Trim();
            existing.OAuthProvider = provider;
            if (!string.IsNullOrWhiteSpace(dto.ProviderId)) existing.OAuthProviderId = dto.ProviderId.Trim();
            existing.IsEmailVerified = true;
            existing.UpdatedAt = DateTime.Now;
            await context.SaveChangesAsync();
            return (true, $"Đăng nhập bằng {provider} thành công", existing, existingRole);
        }

        var memberRole = await context.Roles.FirstOrDefaultAsync(r => r.RoleCode == "MEMBER");
        if (memberRole == null)
        {
            return (false, "Hệ thống chưa cấu hình vai trò MEMBER", null, null);
        }

        string baseUsername = email.Split('@')[0];
        if (string.IsNullOrWhiteSpace(baseUsername)) baseUsername = "member";
        string username = baseUsername;
        int counter = 1;
        while (await context.Accounts.AnyAsync(a => a.Username.ToLower() == username.ToLower()))
        {
            username = $"{baseUsername}_{counter++}";
        }

        var newAccount = new Account
        {
            Username = username,
            PasswordHash = PasswordHasher.HashPassword(Guid.NewGuid().ToString("N")),
            FullName = string.IsNullOrWhiteSpace(dto.FullName) ? username : dto.FullName.Trim(),
            Email = email,
            RoleId = memberRole.RoleId,
            IsActive = true,
            IsEmailVerified = true,
            OAuthProvider = provider,
            OAuthProviderId = string.IsNullOrWhiteSpace(dto.ProviderId) ? $"{provider.ToLower()}_{Guid.NewGuid():N}" : dto.ProviderId.Trim(),
            Avatar = dto.Avatar?.Trim(),
            LoyaltyPoints = 100, // Welcome bonus points for verified member
            CreatedAt = DateTime.Now
        };

        context.Accounts.Add(newAccount);
        await context.SaveChangesAsync();

        return (true, $"Đăng ký và đăng nhập thành công với tài khoản {provider}", newAccount, memberRole);
    }
}
