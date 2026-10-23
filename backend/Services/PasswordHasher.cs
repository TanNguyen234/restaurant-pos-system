using System.Security.Cryptography;
using System.Text;

namespace WebApi.Services;

public static class PasswordHasher
{
    /// <summary>
    /// Hashes a password using a 16-byte cryptographically secure random salt and SHA-256.
    /// Returns format: "{salt}:{hash}" (97 characters), safely fitting in VARCHAR(256).
    /// </summary>
    public static string HashPassword(string password)
    {
        byte[] saltBytes = RandomNumberGenerator.GetBytes(16);
        string salt = Convert.ToHexString(saltBytes).ToLowerInvariant();
        string hash = ComputeSha256(salt + password);
        return $"{salt}:{hash}";
    }

    /// <summary>
    /// Verifies password against stored hash.
    /// Supports both salted format ("{salt}:{hash}") and legacy/seeded format (plain SHA-256).
    /// </summary>
    public static bool VerifyPassword(string password, string storedHash)
    {
        if (string.IsNullOrWhiteSpace(storedHash) || string.IsNullOrEmpty(password))
            return false;

        if (storedHash.Contains(':'))
        {
            var parts = storedHash.Split(':');
            if (parts.Length != 2) return false;
            string salt = parts[0];
            string hash = parts[1];
            string computed = ComputeSha256(salt + password);
            return string.Equals(computed, hash, StringComparison.OrdinalIgnoreCase);
        }
        else
        {
            // Plain SHA-256 (matches database seeds)
            string computed = ComputeSha256(password);
            return string.Equals(computed, storedHash, StringComparison.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// Computes lowercase hex SHA-256 hash of input string.
    /// </summary>
    public static string ComputeSha256(string input)
    {
        byte[] bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
