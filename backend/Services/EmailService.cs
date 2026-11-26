using System.Net;
using System.Net.Mail;

namespace WebApi.Services;

public class EmailService
{
    private readonly IConfiguration _config;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration config, ILogger<EmailService> logger)
    {
        _config = config;
        _logger = logger;
    }

    public bool IsEnabled
    {
        get
        {
            var flag = _config["ACCOUNT_EMAIL_ENABLED"] ?? _config["Smtp:Enabled"] ?? "false";
            return flag.Equals("true", StringComparison.OrdinalIgnoreCase) || flag == "1";
        }
    }

    public async Task<(bool Sent, string Message)> SendOtpEmailAsync(string toEmail, string subject, string fullName, string otp, string purpose, int expiryMinutes = 5)
    {
        if (string.IsNullOrWhiteSpace(toEmail))
        {
            return (false, "Tài khoản chưa có địa chỉ email");
        }

        if (!IsEnabled)
        {
            return (false, "Chế độ gửi email SMTP đang tắt (ACCOUNT_EMAIL_ENABLED=false)");
        }

        string? host = _config["Smtp:Host"] ?? _config["SMTP_HOST"] ?? _config["MAIL_HOST"];
        string? portStr = _config["Smtp:Port"] ?? _config["SMTP_PORT"] ?? _config["MAIL_PORT"];
        string? username = _config["Smtp:Username"] ?? _config["EMAIL_USER"] ?? _config["MAIL_USERNAME"];
        string? password = _config["Smtp:Password"] ?? _config["EMAIL_PASS"];
        string? fromEmail = _config["Smtp:FromEmail"] ?? _config["EMAIL_FROM"] ?? username;
        bool enableSsl = !string.Equals(_config["Smtp:EnableSsl"] ?? _config["SMTP_ENABLE_SSL"] ?? "true", "false", StringComparison.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(fromEmail))
        {
            return (false, "Thiếu cấu hình SMTP (SMTP_HOST / EMAIL_USER / EMAIL_PASS) trong .env");
        }

        int port = int.TryParse(portStr, out var parsedPort) ? parsedPort : 587;

        try
        {
            using var client = new SmtpClient(host.Trim(), port)
            {
                Credentials = new NetworkCredential(username.Trim(), password.Trim()),
                EnableSsl = enableSsl,
                Timeout = 10000
            };

            string body = $"""
                <div style="font-family:Segoe UI,Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e2e8f0;border-radius:12px;">
                  <h2 style="color:#0f172a;margin-top:0;">Bistro POS — {WebUtility.HtmlEncode(purpose)}</h2>
                  <p>Xin chào <strong>{WebUtility.HtmlEncode(fullName)}</strong>,</p>
                  <p>Mã xác thực OTP 6 chữ số của bạn là:</p>
                  <div style="font-size:28px;font-weight:700;letter-spacing:6px;background:#f1f5f9;color:#0f172a;padding:14px 20px;border-radius:8px;text-align:center;margin:16px 0;">
                    {WebUtility.HtmlEncode(otp)}
                  </div>
                  <p style="color:#475569;font-size:13px;">Mã có hiệu lực trong vòng {expiryMinutes} phút. Tuyệt đối không chia sẻ mã này cho người khác.</p>
                </div>
                """;

            using var mail = new MailMessage
            {
                From = new MailAddress(fromEmail.Trim(), "Restaurant & Cafe POS"),
                Subject = subject,
                Body = body,
                IsBodyHtml = true
            };
            mail.To.Add(toEmail.Trim());

            await client.SendMailAsync(mail);
            return (true, $"Đã gửi mã xác thực OTP đến email {MaskEmail(toEmail)}");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "SMTP send failed for {Email}", MaskEmail(toEmail));
            return (false, "Không thể kết nối máy chủ gửi email lúc này. Vui lòng kiểm tra cấu hình SMTP.");
        }
    }

    public static string MaskEmail(string email)
    {
        var parts = email.Trim().Split('@');
        if (parts.Length != 2 || parts[0].Length == 0) return "***";
        string local = parts[0];
        string masked = local.Length <= 2 ? local[0] + "***" : local[..2] + new string('*', Math.Min(local.Length - 2, 5));
        return $"{masked}@{parts[1]}";
    }
}
