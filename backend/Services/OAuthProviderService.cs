using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using WebApi.Models;

namespace WebApi.Services;

public record OAuthProviderStatusDto(
    string Provider,
    string DisplayName,
    bool Configured,
    IReadOnlyList<string> RequiredEnvKeys,
    IReadOnlyList<string> MissingEnvKeys,
    string CallbackUrl);

public record OAuthAuthorizationResult(
    bool Success,
    string? AuthUrl,
    string? ErrorMessage,
    IReadOnlyList<string> MissingKeys,
    string CallbackUrl);

public record OAuthCallbackResult(
    bool Success,
    string? ErrorMessage,
    OAuthLoginDto? Profile,
    string? ClientRedirect,
    string? PollKey);

public record OAuthPollStatus(
    bool Ready,
    string? Ticket,
    string? Error);

internal record OAuthPendingState(
    string Provider,
    string CodeVerifier,
    string? ClientRedirect,
    string? PollKey,
    DateTimeOffset ExpiresAt);

internal record OAuthTicketEntry(
    object Payload,
    DateTimeOffset ExpiresAt);

internal record OAuthPollEntry(
    bool Ready,
    string? Ticket,
    string? Error,
    DateTimeOffset ExpiresAt);

public class OAuthProviderService
{
    private static readonly TimeSpan StateTtl = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan TicketTtl = TimeSpan.FromSeconds(60);

    private readonly IConfiguration _config;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<OAuthProviderService> _logger;

    private readonly ConcurrentDictionary<string, OAuthPendingState> _pendingStates = new();
    private readonly ConcurrentDictionary<string, OAuthTicketEntry> _tickets = new();
    private readonly ConcurrentDictionary<string, OAuthPollEntry> _polls = new();

    public OAuthProviderService(
        IConfiguration config,
        IHttpClientFactory httpClientFactory,
        ILogger<OAuthProviderService> logger)
    {
        _config = config;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public string GetCallbackBaseUrl()
    {
        var raw = ReadSetting("OAuth:CallbackBaseUrl", "OAUTH_CALLBACK_BASE_URL");
        if (string.IsNullOrWhiteSpace(raw))
        {
            return "http://localhost:5138";
        }
        return raw.Trim().TrimEnd('/');
    }

    public string GetCallbackUrl(string provider)
    {
        var normalized = provider.Trim().ToLowerInvariant();
        return $"{GetCallbackBaseUrl()}/api/auth/oauth/{normalized}/callback";
    }

    public IReadOnlyList<OAuthProviderStatusDto> GetConfiguredProviders()
    {
        return
        [
            BuildProviderStatus("google", "Google"),
            BuildProviderStatus("facebook", "Facebook"),
            BuildProviderStatus("zalo", "Zalo")
        ];
    }

    public (bool IsValid, string? ValidatedRedirect) ValidateClientRedirect(string? clientRedirect)
    {
        if (string.IsNullOrWhiteSpace(clientRedirect))
        {
            return (true, null);
        }

        var trimmed = clientRedirect.Trim();
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri))
        {
            return (false, null);
        }

        if (!uri.Scheme.Equals("http", StringComparison.OrdinalIgnoreCase) &&
            !uri.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase))
        {
            return (false, null);
        }

        if (uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
            uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase))
        {
            return (true, trimmed);
        }

        var allowedOriginsRaw = ReadSetting("ALLOWED_ORIGINS");
        if (!string.IsNullOrWhiteSpace(allowedOriginsRaw))
        {
            var origins = allowedOriginsRaw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var targetAuthority = uri.GetLeftPart(UriPartial.Authority);
            foreach (var origin in origins)
            {
                if (Uri.TryCreate(origin, UriKind.Absolute, out var originUri) &&
                    string.Equals(originUri.GetLeftPart(UriPartial.Authority), targetAuthority, StringComparison.OrdinalIgnoreCase))
                {
                    return (true, trimmed);
                }
            }
        }

        return (false, null);
    }

    public OAuthAuthorizationResult CreateAuthorizationUrl(string provider, string? clientRedirect, string? pollKey)
    {
        CleanupExpiredEntries();

        var normalized = provider?.Trim().ToLowerInvariant() ?? string.Empty;
        if (normalized is not ("google" or "facebook" or "zalo"))
        {
            return new OAuthAuthorizationResult(
                false,
                null,
                $"Nhà cung cấp OAuth '{provider}' không được hỗ trợ (chỉ hỗ trợ google, facebook, zalo).",
                Array.Empty<string>(),
                string.Empty);
        }

        var (clientId, clientSecret, missingKeys, displayName) = ResolveCredentials(normalized);
        var callbackUrl = GetCallbackUrl(normalized);

        if (missingKeys.Count > 0 || string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
        {
            return new OAuthAuthorizationResult(
                false,
                null,
                $"OAuth {displayName} chưa được cấu hình. Vui lòng thiết lập {string.Join(", ", missingKeys)} trong file .env hoặc biến môi trường.",
                missingKeys,
                callbackUrl);
        }

        var state = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
        var codeVerifier = Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        var codeChallenge = Base64UrlEncode(SHA256.HashData(Encoding.ASCII.GetBytes(codeVerifier)));

        _pendingStates[state] = new OAuthPendingState(
            normalized,
            codeVerifier,
            string.IsNullOrWhiteSpace(clientRedirect) ? null : clientRedirect.Trim(),
            string.IsNullOrWhiteSpace(pollKey) ? null : pollKey.Trim(),
            DateTimeOffset.UtcNow.Add(StateTtl));

        string authUrl = normalized switch
        {
            "google" =>
                "https://accounts.google.com/o/oauth2/v2/auth" +
                $"?client_id={Uri.EscapeDataString(clientId)}" +
                $"&redirect_uri={Uri.EscapeDataString(callbackUrl)}" +
                "&response_type=code" +
                $"&scope={Uri.EscapeDataString("openid email profile")}" +
                $"&state={Uri.EscapeDataString(state)}" +
                $"&code_challenge={Uri.EscapeDataString(codeChallenge)}" +
                "&code_challenge_method=S256" +
                "&prompt=select_account",

            "facebook" =>
                "https://www.facebook.com/v20.0/dialog/oauth" +
                $"?client_id={Uri.EscapeDataString(clientId)}" +
                $"&redirect_uri={Uri.EscapeDataString(callbackUrl)}" +
                "&response_type=code" +
                // Mac dinh chi xin public_profile (luon duoc cap). Quyen "email" phai duoc them trong
                // App Dashboard -> Use cases -> Permissions, neu khong Facebook bao "Invalid Scopes: email".
                // Khi da bat quyen email, dat FACEBOOK_SCOPES=public_profile,email trong .env.
                $"&scope={Uri.EscapeDataString(ReadSetting("OAuth:Facebook:Scopes", "FACEBOOK_SCOPES") ?? "public_profile")}" +
                $"&state={Uri.EscapeDataString(state)}",

            "zalo" =>
                "https://oauth.zaloapp.com/v4/permission" +
                $"?app_id={Uri.EscapeDataString(clientId)}" +
                $"&redirect_uri={Uri.EscapeDataString(callbackUrl)}" +
                $"&code_challenge={Uri.EscapeDataString(codeChallenge)}" +
                $"&state={Uri.EscapeDataString(state)}",

            _ => throw new InvalidOperationException($"Unsupported provider: {normalized}")
        };

        return new OAuthAuthorizationResult(true, authUrl, null, Array.Empty<string>(), callbackUrl);
    }

    public async Task<OAuthCallbackResult> HandleCallbackAsync(string provider, string? code, string? state, string? error)
    {
        CleanupExpiredEntries();

        var normalized = provider?.Trim().ToLowerInvariant() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(state) || !_pendingStates.TryRemove(state.Trim(), out var pending))
        {
            return new OAuthCallbackResult(
                false,
                "Phiên xác thực OAuth (state) không hợp lệ, đã được sử dụng hoặc đã hết hạn.",
                null,
                null,
                null);
        }

        if (pending.ExpiresAt < DateTimeOffset.UtcNow)
        {
            return new OAuthCallbackResult(
                false,
                "Phiên xác thực OAuth đã hết hạn (quá 10 phút). Vui lòng thử đăng nhập lại.",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }

        if (!string.Equals(pending.Provider, normalized, StringComparison.OrdinalIgnoreCase))
        {
            return new OAuthCallbackResult(
                false,
                "Nhà cung cấp OAuth trong callback không khớp với phiên khởi tạo.",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }

        if (!string.IsNullOrWhiteSpace(error))
        {
            return new OAuthCallbackResult(
                false,
                $"Nhà cung cấp {normalized} từ chối hoặc hủy xác thực: {error}",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }

        if (string.IsNullOrWhiteSpace(code))
        {
            return new OAuthCallbackResult(
                false,
                "Thiếu mã ủy quyền (code) từ nhà cung cấp OAuth.",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }

        var (clientId, clientSecret, missingKeys, displayName) = ResolveCredentials(normalized);
        if (missingKeys.Count > 0 || string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
        {
            return new OAuthCallbackResult(
                false,
                $"OAuth {displayName} chưa được cấu hình đầy đủ ({string.Join(", ", missingKeys)}).",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }

        var callbackUrl = GetCallbackUrl(normalized);

        try
        {
            var profile = normalized switch
            {
                "google" => await ExchangeGoogleAsync(code.Trim(), clientId, clientSecret, callbackUrl, pending.CodeVerifier),
                "facebook" => await ExchangeFacebookAsync(code.Trim(), clientId, clientSecret, callbackUrl),
                "zalo" => await ExchangeZaloAsync(code.Trim(), clientId, clientSecret, pending.CodeVerifier),
                _ => throw new InvalidOperationException($"Unsupported provider: {normalized}")
            };

            return new OAuthCallbackResult(true, null, profile, pending.ClientRedirect, pending.PollKey);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "OAuth token/userinfo exchange failed for provider {Provider}", normalized);
            return new OAuthCallbackResult(
                false,
                $"Không thể trao đổi mã xác thực với {displayName}. Vui lòng kiểm tra cấu hình OAuth và thử lại.",
                null,
                pending.ClientRedirect,
                pending.PollKey);
        }
    }

    public string StoreAuthTicket(object authPayload, string? pollKey)
    {
        CleanupExpiredEntries();

        var ticket = Convert.ToHexString(RandomNumberGenerator.GetBytes(24)).ToLowerInvariant();
        var expiresAt = DateTimeOffset.UtcNow.Add(TicketTtl);
        _tickets[ticket] = new OAuthTicketEntry(authPayload, expiresAt);

        if (!string.IsNullOrWhiteSpace(pollKey))
        {
            _polls[pollKey.Trim()] = new OAuthPollEntry(true, ticket, null, expiresAt);
        }

        return ticket;
    }

    public void StorePollError(string? pollKey, string error)
    {
        if (string.IsNullOrWhiteSpace(pollKey))
        {
            return;
        }

        CleanupExpiredEntries();
        _polls[pollKey.Trim()] = new OAuthPollEntry(false, null, error, DateTimeOffset.UtcNow.Add(TicketTtl));
    }

    public object? ConsumeTicket(string ticket)
    {
        CleanupExpiredEntries();

        if (string.IsNullOrWhiteSpace(ticket))
        {
            return null;
        }

        if (_tickets.TryRemove(ticket.Trim(), out var entry) && entry.ExpiresAt >= DateTimeOffset.UtcNow)
        {
            return entry.Payload;
        }

        return null;
    }

    public OAuthPollStatus PollTicket(string pollKey)
    {
        CleanupExpiredEntries();

        if (string.IsNullOrWhiteSpace(pollKey))
        {
            return new OAuthPollStatus(false, null, null);
        }

        if (_polls.TryGetValue(pollKey.Trim(), out var entry) && entry.ExpiresAt >= DateTimeOffset.UtcNow)
        {
            return new OAuthPollStatus(entry.Ready, entry.Ticket, entry.Error);
        }

        return new OAuthPollStatus(false, null, null);
    }

    private async Task<OAuthLoginDto> ExchangeGoogleAsync(
        string code,
        string clientId,
        string clientSecret,
        string redirectUri,
        string codeVerifier)
    {
        var http = _httpClientFactory.CreateClient();

        using var tokenForm = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["code"] = code,
            ["client_id"] = clientId,
            ["client_secret"] = clientSecret,
            ["redirect_uri"] = redirectUri,
            ["grant_type"] = "authorization_code",
            ["code_verifier"] = codeVerifier
        });

        using var tokenRes = await http.PostAsync("https://oauth2.googleapis.com/token", tokenForm);
        var tokenBody = await tokenRes.Content.ReadAsStringAsync();
        if (!tokenRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Google token endpoint returned {(int)tokenRes.StatusCode}");
        }

        using var tokenDoc = JsonDocument.Parse(tokenBody);
        var accessToken = GetString(tokenDoc.RootElement, "access_token");
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            throw new InvalidOperationException("Google token response missing access_token");
        }

        using var userReq = new HttpRequestMessage(HttpMethod.Get, "https://openidconnect.googleapis.com/v1/userinfo");
        userReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var userRes = await http.SendAsync(userReq);
        var userBody = await userRes.Content.ReadAsStringAsync();
        if (!userRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Google userinfo endpoint returned {(int)userRes.StatusCode}");
        }

        using var userDoc = JsonDocument.Parse(userBody);
        var root = userDoc.RootElement;
        var sub = GetString(root, "sub");
        if (string.IsNullOrWhiteSpace(sub))
        {
            throw new InvalidOperationException("Google userinfo missing sub");
        }

        var email = GetString(root, "email");
        if (string.IsNullOrWhiteSpace(email))
        {
            email = $"google_{sub}@google.oauth.local";
        }

        var name = GetString(root, "name");
        var picture = GetString(root, "picture");

        return new OAuthLoginDto
        {
            Provider = "Google",
            ProviderId = sub,
            Email = email,
            FullName = string.IsNullOrWhiteSpace(name) ? email : name,
            Avatar = picture
        };
    }

    private async Task<OAuthLoginDto> ExchangeFacebookAsync(
        string code,
        string appId,
        string appSecret,
        string redirectUri)
    {
        var http = _httpClientFactory.CreateClient();

        var tokenUrl =
            "https://graph.facebook.com/v20.0/oauth/access_token" +
            $"?client_id={Uri.EscapeDataString(appId)}" +
            $"&redirect_uri={Uri.EscapeDataString(redirectUri)}" +
            $"&client_secret={Uri.EscapeDataString(appSecret)}" +
            $"&code={Uri.EscapeDataString(code)}";

        using var tokenRes = await http.GetAsync(tokenUrl);
        var tokenBody = await tokenRes.Content.ReadAsStringAsync();
        if (!tokenRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Facebook token endpoint returned {(int)tokenRes.StatusCode}");
        }

        using var tokenDoc = JsonDocument.Parse(tokenBody);
        var accessToken = GetString(tokenDoc.RootElement, "access_token");
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            throw new InvalidOperationException("Facebook token response missing access_token");
        }

        var meUrl =
            "https://graph.facebook.com/v20.0/me" +
            $"?fields={Uri.EscapeDataString("id,name,email,picture.type(large)")}" +
            $"&access_token={Uri.EscapeDataString(accessToken)}";

        using var meRes = await http.GetAsync(meUrl);
        var meBody = await meRes.Content.ReadAsStringAsync();
        if (!meRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Facebook me endpoint returned {(int)meRes.StatusCode}");
        }

        using var meDoc = JsonDocument.Parse(meBody);
        var root = meDoc.RootElement;
        var id = GetString(root, "id");
        if (string.IsNullOrWhiteSpace(id))
        {
            throw new InvalidOperationException("Facebook me response missing id");
        }

        var email = GetString(root, "email");
        if (string.IsNullOrWhiteSpace(email))
        {
            email = $"{id}@facebook.oauth.local";
        }

        var name = GetString(root, "name");
        string? avatar = null;
        if (root.TryGetProperty("picture", out var picObj) &&
            picObj.ValueKind == JsonValueKind.Object &&
            picObj.TryGetProperty("data", out var dataObj) &&
            dataObj.ValueKind == JsonValueKind.Object)
        {
            avatar = GetString(dataObj, "url");
        }

        return new OAuthLoginDto
        {
            Provider = "Facebook",
            ProviderId = id,
            Email = email,
            FullName = string.IsNullOrWhiteSpace(name) ? $"Facebook User {id}" : name,
            Avatar = avatar
        };
    }

    private async Task<OAuthLoginDto> ExchangeZaloAsync(
        string code,
        string appId,
        string appSecret,
        string codeVerifier)
    {
        var http = _httpClientFactory.CreateClient();

        using var tokenReq = new HttpRequestMessage(HttpMethod.Post, "https://oauth.zaloapp.com/v4/access_token");
        tokenReq.Headers.TryAddWithoutValidation("secret_key", appSecret);
        tokenReq.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["code"] = code,
            ["app_id"] = appId,
            ["grant_type"] = "authorization_code",
            ["code_verifier"] = codeVerifier
        });

        using var tokenRes = await http.SendAsync(tokenReq);
        var tokenBody = await tokenRes.Content.ReadAsStringAsync();
        if (!tokenRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Zalo token endpoint returned {(int)tokenRes.StatusCode}");
        }

        using var tokenDoc = JsonDocument.Parse(tokenBody);
        var accessToken = GetString(tokenDoc.RootElement, "access_token");
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            throw new InvalidOperationException("Zalo token response missing access_token");
        }

        using var meReq = new HttpRequestMessage(HttpMethod.Get, "https://graph.zalo.me/v2.0/me?fields=id,name,picture");
        meReq.Headers.TryAddWithoutValidation("access_token", accessToken);

        using var meRes = await http.SendAsync(meReq);
        var meBody = await meRes.Content.ReadAsStringAsync();
        if (!meRes.IsSuccessStatusCode)
        {
            throw new InvalidOperationException($"Zalo me endpoint returned {(int)meRes.StatusCode}");
        }

        using var meDoc = JsonDocument.Parse(meBody);
        var root = meDoc.RootElement;
        var id = GetString(root, "id");
        if (string.IsNullOrWhiteSpace(id))
        {
            throw new InvalidOperationException("Zalo me response missing id");
        }

        var name = GetString(root, "name");
        var email = GetString(root, "email");
        if (string.IsNullOrWhiteSpace(email))
        {
            email = $"zalo_{id}@zalo.oauth.local";
        }

        string? avatar = null;
        if (root.TryGetProperty("picture", out var picEl))
        {
            if (picEl.ValueKind == JsonValueKind.String)
            {
                avatar = picEl.GetString();
            }
            else if (picEl.ValueKind == JsonValueKind.Object &&
                     picEl.TryGetProperty("data", out var dataEl) &&
                     dataEl.ValueKind == JsonValueKind.Object)
            {
                avatar = GetString(dataEl, "url");
            }
        }

        return new OAuthLoginDto
        {
            Provider = "Zalo",
            ProviderId = id,
            Email = email,
            FullName = string.IsNullOrWhiteSpace(name) ? $"Zalo User {id}" : name,
            Avatar = avatar
        };
    }

    private OAuthProviderStatusDto BuildProviderStatus(string provider, string displayName)
    {
        var (_, _, missingKeys, _) = ResolveCredentials(provider);
        var requiredKeys = GetRequiredEnvKeys(provider);
        return new OAuthProviderStatusDto(
            provider,
            displayName,
            missingKeys.Count == 0,
            requiredKeys,
            missingKeys,
            GetCallbackUrl(provider));
    }

    private (string? ClientId, string? ClientSecret, IReadOnlyList<string> MissingKeys, string DisplayName) ResolveCredentials(string provider)
    {
        return provider switch
        {
            "google" => ResolvePair(
                ReadSetting("OAuth:Google:ClientId", "GOOGLE_CLIENT_ID"),
                ReadSetting("OAuth:Google:ClientSecret", "GOOGLE_CLIENT_SECRET"),
                "GOOGLE_CLIENT_ID",
                "GOOGLE_CLIENT_SECRET",
                "Google"),
            "facebook" => ResolvePair(
                ReadSetting("OAuth:Facebook:AppId", "FACEBOOK_APP_ID"),
                ReadSetting("OAuth:Facebook:AppSecret", "FACEBOOK_APP_SECRET"),
                "FACEBOOK_APP_ID",
                "FACEBOOK_APP_SECRET",
                "Facebook"),
            "zalo" => ResolvePair(
                ReadSetting("OAuth:Zalo:AppId", "ZALO_APP_ID"),
                ReadSetting("OAuth:Zalo:AppSecret", "ZALO_APP_SECRET"),
                "ZALO_APP_ID",
                "ZALO_APP_SECRET",
                "Zalo"),
            _ => (null, null, Array.Empty<string>(), provider)
        };
    }

    private static IReadOnlyList<string> GetRequiredEnvKeys(string provider) => provider switch
    {
        "google" => ["GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_SECRET"],
        "facebook" => ["FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET"],
        "zalo" => ["ZALO_APP_ID", "ZALO_APP_SECRET"],
        _ => Array.Empty<string>()
    };

    private static (string? Id, string? Secret, IReadOnlyList<string> MissingKeys, string DisplayName) ResolvePair(
        string? rawId,
        string? rawSecret,
        string idKey,
        string secretKey,
        string displayName)
    {
        var missing = new List<string>();
        var id = IsRealCredential(rawId) ? rawId!.Trim() : null;
        var secret = IsRealCredential(rawSecret) ? rawSecret!.Trim() : null;
        if (id == null) missing.Add(idKey);
        if (secret == null) missing.Add(secretKey);
        return (id, secret, missing, displayName);
    }

    private string? ReadSetting(params string[] keys)
    {
        foreach (var key in keys)
        {
            var fromConfig = _config[key];
            if (!string.IsNullOrWhiteSpace(fromConfig))
            {
                return fromConfig.Trim();
            }

            var fromEnv = Environment.GetEnvironmentVariable(key);
            if (!string.IsNullOrWhiteSpace(fromEnv))
            {
                return fromEnv.Trim();
            }
        }

        return null;
    }

    private static bool IsRealCredential(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return false;
        var v = value.Trim();
        if (v.StartsWith("your_", StringComparison.OrdinalIgnoreCase) ||
            v.StartsWith("placeholder", StringComparison.OrdinalIgnoreCase) ||
            v.StartsWith("changeme", StringComparison.OrdinalIgnoreCase) ||
            v.StartsWith("replace_", StringComparison.OrdinalIgnoreCase) ||
            (v.StartsWith('<') && v.EndsWith('>')))
        {
            return false;
        }
        return true;
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static string? GetString(JsonElement element, string propertyName)
    {
        if (element.ValueKind == JsonValueKind.Object &&
            element.TryGetProperty(propertyName, out var prop) &&
            prop.ValueKind == JsonValueKind.String)
        {
            return prop.GetString();
        }
        return null;
    }

    private void CleanupExpiredEntries()
    {
        var now = DateTimeOffset.UtcNow;

        foreach (var kv in _pendingStates)
        {
            if (kv.Value.ExpiresAt < now)
            {
                _pendingStates.TryRemove(kv.Key, out _);
            }
        }

        foreach (var kv in _tickets)
        {
            if (kv.Value.ExpiresAt < now)
            {
                _tickets.TryRemove(kv.Key, out _);
            }
        }

        foreach (var kv in _polls)
        {
            if (kv.Value.ExpiresAt < now)
            {
                _polls.TryRemove(kv.Key, out _);
            }
        }
    }
}
