using System.Security.Cryptography;
using System.Text;

namespace WebApi.Services;

public static class PasswordHasher
{
    private const int Pbkdf2Iterations = 100_000;
    private const int SaltSize = 16;
    private const int HashSize = 32;

    /// <summary>
    /// Hashes a password using PBKDF2-HMAC-SHA256 (100,000 iterations, 16-byte random salt).
    /// Format: "pbkdf2${saltHex}${hashHex}"
    /// </summary>
    public static string HashPassword(string password)
    {
        byte[] saltBytes = RandomNumberGenerator.GetBytes(SaltSize);
        byte[] hashBytes = Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password),
            saltBytes,
            Pbkdf2Iterations,
            HashAlgorithmName.SHA256,
            HashSize);
        return $"pbkdf2${Convert.ToHexString(saltBytes).ToLowerInvariant()}${Convert.ToHexString(hashBytes).ToLowerInvariant()}";
    }

    public static bool NeedsRehash(string storedHash)
    {
        return string.IsNullOrWhiteSpace(storedHash) || !storedHash.StartsWith("pbkdf2$", StringComparison.Ordinal);
    }

    /// <summary>
    /// Verifies password against PBKDF2, legacy "{salt}:{sha256}", or legacy plain SHA-256 hashes using constant-time comparison.
    /// </summary>
    public static bool VerifyPassword(string password, string storedHash)
    {
        if (string.IsNullOrWhiteSpace(storedHash) || string.IsNullOrEmpty(password))
            return false;

        if (storedHash.StartsWith("pbkdf2$", StringComparison.Ordinal))
        {
            var parts = storedHash.Split('$');
            if (parts.Length != 3) return false;
            try
            {
                byte[] saltBytes = Convert.FromHexString(parts[1]);
                byte[] expectedBytes = Convert.FromHexString(parts[2]);
                byte[] actualBytes = Rfc2898DeriveBytes.Pbkdf2(
                    Encoding.UTF8.GetBytes(password),
                    saltBytes,
                    Pbkdf2Iterations,
                    HashAlgorithmName.SHA256,
                    expectedBytes.Length);
                return CryptographicOperations.FixedTimeEquals(actualBytes, expectedBytes);
            }
            catch
            {
                return false;
            }
        }

        if (storedHash.Contains(':'))
        {
            var parts = storedHash.Split(':');
            if (parts.Length != 2) return false;
            byte[] computed = SHA256.HashData(Encoding.UTF8.GetBytes(parts[0] + password));
            try
            {
                byte[] expected = Convert.FromHexString(parts[1]);
                return expected.Length == computed.Length && CryptographicOperations.FixedTimeEquals(computed, expected);
            }
            catch
            {
                return false;
            }
        }

        // Legacy seeded plain SHA-256
        {
            byte[] computed = SHA256.HashData(Encoding.UTF8.GetBytes(password));
            try
            {
                byte[] expected = Convert.FromHexString(storedHash);
                return expected.Length == computed.Length && CryptographicOperations.FixedTimeEquals(computed, expected);
            }
            catch
            {
                return false;
            }
        }
    }

    public static string ComputeSha256(string input)
    {
        byte[] bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
