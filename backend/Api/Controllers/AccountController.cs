using Microsoft.AspNetCore.Mvc;
using WebApi.Models;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AccountController : BaseController
{
    /// <summary>
    /// GET /api/account/members
    /// Lấy danh sách thành viên và nhân sự trong hệ thống kèm vai trò
    /// </summary>
    [HttpGet("members")]
    public IActionResult GetMembers()
    {
        var members = Provider.Account.GetMembers();
        return Ok(members);
    }

    /// <summary>
    /// PUT /api/account/{id}/role
    /// Cập nhật vai trò (Role) cho tài khoản (Admin)
    /// </summary>
    [HttpPut("{id:int}/role")]
    public IActionResult UpdateRole(int id, [FromBody] UpdateRoleRequest request)
    {
        if (request == null || request.RoleId <= 0)
        {
            return BadRequest(new { success = false, message = "Vui lòng chọn vai trò hợp lệ" });
        }

        var result = Provider.Account.UpdateRole(id, request.RoleId);
        if (!result.Success)
        {
            return BadRequest(new { success = false, message = result.Message });
        }

        return Ok(new { success = true, message = result.Message });
    }
}

public class UpdateRoleRequest
{
    public int RoleId { get; set; }
}
