using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AccountController : BaseController
{
    /// <summary>
    /// GET /api/account/members
    /// Returns member and staff list. Restricted to ADMIN and MANAGER roles.
    /// Returns 401 Unauthorized if unauthenticated, 403 Forbidden if unauthorized role.
    /// </summary>
    [HttpGet("members")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetMembers([FromQuery] int? roleId = null)
    {
        var members = await Provider.Account.GetMembersAsync(roleId);
        return Ok(members);
    }

    /// <summary>
    /// PUT /api/account/{id}/role
    /// Updates member/staff role. Restricted to ADMIN and MANAGER roles.
    /// </summary>
    [HttpPut("{id:int}/role")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> UpdateRole(int id, [FromBody] UpdateRoleRequest request)
    {
        if (request == null || request.RoleId <= 0)
        {
            return BadRequest(new { success = false, message = "Vui lòng chọn vai trò hợp lệ" });
        }

        var result = await Provider.Account.UpdateRoleAsync(id, request.RoleId);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message });
    }

    /// <summary>
    /// GET /api/account/profile
    /// Returns profile of the currently authenticated account.
    /// </summary>
    [HttpGet("profile")]
    [Authorize]
    public async Task<IActionResult> GetProfile()
    {
        var username = User.Identity?.Name;
        if (string.IsNullOrEmpty(username))
        {
            return Unauthorized(new
            {
                statusCode = 401,
                success = false,
                message = "Không xác định được danh tính người dùng"
            });
        }

        var account = await Provider.Account.GetByUsernameAsync(username);
        if (account == null)
        {
            return NotFound(new
            {
                statusCode = 404,
                success = false,
                message = "Không tìm thấy thông tin tài khoản"
            });
        }

        var role = await Provider.Account.GetRoleByIdAsync(account.RoleId);

        return Ok(new AccountDto
        {
            AccountId = account.AccountId,
            RoleId = account.RoleId,
            RoleCode = role?.RoleCode ?? "MEMBER",
            RoleName = role?.RoleName ?? "Thành viên",
            Username = account.Username,
            FullName = account.FullName,
            Email = account.Email,
            PhoneNumber = account.PhoneNumber,
            Avatar = account.Avatar,
            IsActive = account.IsActive,
            IsEmailVerified = account.IsEmailVerified,
            OAuthProvider = account.OAuthProvider,
            CreatedAt = account.CreatedAt,
            UpdatedAt = account.UpdatedAt
        });
    }

    /// <summary>
    /// GET /api/account/roles
    /// Returns list of all system roles. Restricted to ADMIN and MANAGER.
    /// </summary>
    [HttpGet("roles")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetRoles()
    {
        var roles = await Provider.Account.GetRolesAsync();
        return Ok(roles);
    }
}
