using System.ComponentModel.DataAnnotations;

namespace WebApi.Models;

public class RegisterDto
{
    [Required(ErrorMessage = "Tên đăng nhập không được để trống")]
    [StringLength(64, MinimumLength = 3, ErrorMessage = "Tên đăng nhập từ 3 đến 64 ký tự")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Mật khẩu không được để trống")]
    [MinLength(6, ErrorMessage = "Mật khẩu tối thiểu 6 ký tự")]
    public string Password { get; set; } = null!;

    [Required(ErrorMessage = "Họ tên không được để trống")]
    [StringLength(128, ErrorMessage = "Họ tên tối đa 128 ký tự")]
    public string FullName { get; set; } = null!;

    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    public string? Email { get; set; }

    [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
    public string? PhoneNumber { get; set; }

    public int? RoleId { get; set; }

    public string? RoleCode { get; set; }
}

public class LoginDto
{
    [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
    public string Username { get; set; } = null!;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
    public string Password { get; set; } = null!;
}

public class ChangePasswordDto
{
    public string? Username { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại")]
    public string OldPassword { get; set; } = null!;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
    [MinLength(6, ErrorMessage = "Mật khẩu mới tối thiểu 6 ký tự")]
    public string NewPassword { get; set; } = null!;
}

public class LoginResponseDto
{
    public string Token { get; set; } = null!;
    public int AccountId { get; set; }
    public string Username { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string Role { get; set; } = null!;
    public string RoleName { get; set; } = null!;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Avatar { get; set; }
}

public class AccountDto
{
    public int AccountId { get; set; }
    public int RoleId { get; set; }
    public string RoleCode { get; set; } = null!;
    public string RoleName { get; set; } = null!;
    public string Username { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public string? Email { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Avatar { get; set; }
    public bool IsActive { get; set; }
    public bool IsEmailVerified { get; set; }
    public string? OAuthProvider { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class RoleDto
{
    public int RoleId { get; set; }
    public string RoleName { get; set; } = null!;
    public string RoleCode { get; set; } = null!;
    public string? Description { get; set; }
}
