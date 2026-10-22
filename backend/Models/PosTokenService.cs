using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace WebApi.Models;

/// <summary>
/// Short-lived, password-versioned HMAC tokens. POS_SIGNING_KEY must be
/// supplied from the environment, never included in source control.
/// </summary>
public sealed class PosTokenService
{
    private readonly byte[] _key;

    public PosTokenService(IConfiguration config)
    {
        var key = config["POS_SIGNING_KEY"];
        if (string.IsNullOrWhiteSpace(key) || Encoding.UTF8.GetByteCount(key) < 32)
            throw new InvalidOperationException("POS_SIGNING_KEY must be configured with at least 32 UTF-8 bytes.");
        _key = Encoding.UTF8.GetBytes(key);
    }

    private byte[] Sign(string payload)
    {
        using var hmac = new HMACSHA256(_key);
        return hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
    }

    public string Issue(Account account)
    {
        var deadline = DateTimeOffset.UtcNow.AddHours(8).ToUnixTimeSeconds();
        var payload = $"{account.AccountId}.{deadline}";
        var mac = Convert.ToHexString(Sign($"{payload}:{account.PasswordHash}"));
        return $"{payload}.{mac}";
    }

    public Account? Validate(string? bearerToken, RestaurantPosContext db)
    {
        if (string.IsNullOrWhiteSpace(bearerToken)) return null;
        var components = bearerToken.Split('.');
        if (components.Length != 3 ||
            !int.TryParse(components[0], NumberStyles.None, CultureInfo.InvariantCulture, out var id) ||
            !long.TryParse(components[1], NumberStyles.None, CultureInfo.InvariantCulture, out var expiry) ||
            id <= 0 || expiry <= DateTimeOffset.UtcNow.ToUnixTimeSeconds())
            return null;

        byte[] supplied;
        try { supplied = Convert.FromHexString(components[2]); }
        catch (FormatException) { return null; }
        var account = db.Accounts.Find(id);
        if (account == null || !account.IsActive) return null;
        var mac = Sign($"{components[0]}.{components[1]}:{account.PasswordHash}");
        return supplied.Length == mac.Length && CryptographicOperations.FixedTimeEquals(supplied, mac)
            ? account : null;
    }
}
