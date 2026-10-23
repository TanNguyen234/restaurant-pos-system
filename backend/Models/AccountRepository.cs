using Microsoft.EntityFrameworkCore;
using WebApi.Services;

namespace WebApi.Models;

public class AccountRepository : BaseRepository
{
    public AccountRepository(RestaurantPosContext context) : base(context) { }

    /// <summary>
    /// Registers a new account with SHA-256 + salt password hashing.
    /// Checks for unique username and unique email.
    /// </summary>
    public async Task<(bool Success, string Message, Account? Account)> RegisterAsync(RegisterDto dto)
    {
        string username = dto.Username.Trim();
        if (await context.Accounts.AnyAsync(a => a.Username.ToLower() == username.ToLower()))
        {
            return (false, "Tên đăng nhập đã tồn tại trong hệ thống", null);
        }

        if (!string.IsNullOrWhiteSpace(dto.Email))
        {
            string email = dto.Email.Trim();
            if (await context.Accounts.AnyAsync(a => a.Email != null && a.Email.ToLower() == email.ToLower()))
            {
                return (false, "Email đã được sử dụng trong hệ thống", null);
            }
        }

        // SECURITY FIX (Anti-Privilege Escalation):
        // Public registration must ALWAYS be assigned strictly to the MEMBER role.
        // Client-supplied RoleId or RoleCode in public registration is ignored to prevent unauthorized privilege escalation.
        var memberRole = await context.Roles
            .FirstOrDefaultAsync(r => r.RoleCode == "MEMBER")
            ?? await context.Roles.FirstOrDefaultAsync(r => r.RoleCode == "CUSTOMER");
        int resolvedRoleId = memberRole?.RoleId ?? 8;

        var account = new Account
        {
            Username = username,
            PasswordHash = PasswordHasher.HashPassword(dto.Password),
            FullName = dto.FullName.Trim(),
            Email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim(),
            PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
            RoleId = resolvedRoleId,
            IsActive = true,
            IsEmailVerified = false,
            OAuthProvider = "Local",
            CreatedAt = DateTime.Now
        };

        context.Accounts.Add(account);
        await context.SaveChangesAsync();

        return (true, "Đăng ký tài khoản thành công", account);
    }

    /// <summary>
    /// Validates login credentials and returns account with role information.
    /// </summary>
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

        bool isPasswordValid = PasswordHasher.VerifyPassword(dto.Password, account.PasswordHash);
        if (!isPasswordValid)
        {
            return (false, "Tên đăng nhập hoặc mật khẩu không chính xác", null, null);
        }

        var role = await context.Roles.FindAsync(account.RoleId);

        return (true, "Đăng nhập thành công", account, role);
    }

    /// <summary>
    /// Changes password after verifying existing password.
    /// Saves newly salted and hashed password to database.
    /// </summary>
    public async Task<(bool Success, string Message)> ChangePasswordAsync(string username, string oldPassword, string newPassword)
    {
        var account = await context.Accounts
            .FirstOrDefaultAsync(a => a.Username.ToLower() == username.ToLower());

        if (account == null)
        {
            return (false, "Không tìm thấy tài khoản");
        }

        if (!PasswordHasher.VerifyPassword(oldPassword, account.PasswordHash))
        {
            return (false, "Mật khẩu hiện tại không chính xác");
        }

        account.PasswordHash = PasswordHasher.HashPassword(newPassword);
        account.UpdatedAt = DateTime.Now;

        await context.SaveChangesAsync();
        return (true, "Đổi mật khẩu thành công");
    }

    /// <summary>
    /// Changes password by AccountId after verifying existing password.
    /// </summary>
    public async Task<(bool Success, string Message)> ChangePasswordAsync(int accountId, string oldPassword, string newPassword)
    {
        var account = await context.Accounts.FindAsync(accountId);
        if (account == null)
        {
            return (false, "Không tìm thấy tài khoản");
        }

        if (!PasswordHasher.VerifyPassword(oldPassword, account.PasswordHash))
        {
            return (false, "Mật khẩu hiện tại không chính xác");
        }

        account.PasswordHash = PasswordHasher.HashPassword(newPassword);
        account.UpdatedAt = DateTime.Now;

        await context.SaveChangesAsync();
        return (true, "Đổi mật khẩu thành công");
    }

    /// <summary>
    /// Updates account role. Restricted to administrative workflows.
    /// </summary>
    public async Task<(bool Success, string Message)> UpdateRoleAsync(int accountId, int newRoleId)
    {
        var account = await context.Accounts.FindAsync(accountId);
        if (account == null) return (false, "Không tìm thấy tài khoản");

        var role = await context.Roles.FindAsync(newRoleId);
        if (role == null) return (false, "Vai trò không hợp lệ");

        account.RoleId = newRoleId;
        account.UpdatedAt = DateTime.Now;
        await context.SaveChangesAsync();

        return (true, $"Đã cập nhật vai trò thành công sang '{role.RoleName}'");
    }

    /// <summary>
    /// Retrieves members with joined role details, optionally filtered by RoleId.
    /// Excludes password hash and sensitive tokens.
    /// </summary>
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
                        CreatedAt = a.CreatedAt,
                        UpdatedAt = a.UpdatedAt
                    };

        if (roleId.HasValue && roleId.Value > 0)
        {
            query = query.Where(a => a.RoleId == roleId.Value);
        }

        return await query.OrderBy(a => a.AccountId).ToListAsync();
    }

    public async Task<Account?> GetByIdAsync(int accountId)
    {
        return await context.Accounts.FindAsync(accountId);
    }

    public async Task<Account?> GetByUsernameAsync(string username)
    {
        return await context.Accounts
            .FirstOrDefaultAsync(a => a.Username.ToLower() == username.ToLower());
    }

    public async Task<Role?> GetRoleByIdAsync(int roleId)
    {
        return await context.Roles.FindAsync(roleId);
    }

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
}
