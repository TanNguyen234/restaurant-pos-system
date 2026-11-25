using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace WebApi.Models;

public class EmptyToNullStringConverter : JsonConverter<string?>
{
    public override string? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.Null) return null;
        var val = reader.GetString()?.Trim();
        return string.IsNullOrEmpty(val) ? null : val;
    }

    public override void Write(Utf8JsonWriter writer, string? value, JsonSerializerOptions options)
    {
        if (value == null) writer.WriteNullValue();
        else writer.WriteStringValue(value);
    }
}

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

    [JsonConverter(typeof(EmptyToNullStringConverter))]
    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    public string? Email { get; set; }

    [JsonConverter(typeof(EmptyToNullStringConverter))]
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
    public int? AccountId { get; set; }
    public string? Username { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại")]
    public string OldPassword { get; set; } = null!;

    [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
    [MinLength(6, ErrorMessage = "Mật khẩu mới tối thiểu 6 ký tự")]
    public string NewPassword { get; set; } = null!;
}

public class UpdateProfileDto
{
    [Required(ErrorMessage = "Họ tên không được để trống")]
    [StringLength(128, ErrorMessage = "Họ tên tối đa 128 ký tự")]
    public string FullName { get; set; } = null!;

    [JsonConverter(typeof(EmptyToNullStringConverter))]
    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    public string? Email { get; set; }

    [JsonConverter(typeof(EmptyToNullStringConverter))]
    [Phone(ErrorMessage = "Số điện thoại không hợp lệ")]
    public string? PhoneNumber { get; set; }
}

public class UpdateRoleRequest
{
    public int RoleId { get; set; }
}

public class UpdateAccountStatusRequest
{
    public bool IsActive { get; set; }
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
    public int LoyaltyPoints { get; set; }
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

public class RequestOtpDto
{
    public string? Email { get; set; }
    public string? Username { get; set; }
}

public class VerifyEmailDto
{
    [Required]
    public string Identity { get; set; } = null!;

    [Required]
    public string Otp { get; set; } = null!;
}

public class ResetPasswordOtpDto
{
    [Required]
    public string Identity { get; set; } = null!;

    [Required]
    public string Otp { get; set; } = null!;

    [Required]
    [MinLength(6, ErrorMessage = "Mật khẩu mới tối thiểu 6 ký tự")]
    public string NewPassword { get; set; } = null!;
}

public class OAuthLoginDto
{
    [Required]
    public string Provider { get; set; } = null!; // 'Google' | 'Facebook' | 'Zalo'

    public string? Token { get; set; }

    public string? ProviderId { get; set; }

    [Required]
    [EmailAddress(ErrorMessage = "Email mạng xã hội không hợp lệ")]
    public string Email { get; set; } = null!;

    [Required]
    public string FullName { get; set; } = null!;

    public string? Avatar { get; set; }
}
