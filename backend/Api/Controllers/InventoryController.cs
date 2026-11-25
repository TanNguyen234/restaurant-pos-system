using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Models;
using WebApi.Services;

namespace WebApi.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : BaseController
{
    private readonly PosRealtimeNotifier _realtime;

    public InventoryController(PosRealtimeNotifier realtime)
    {
        _realtime = realtime;
    }

    private int? GetCallerAccountId()
    {
        var claim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("accountId");
        return int.TryParse(claim, out int id) && id > 0 ? id : null;
    }

    [HttpGet("ingredients")]
    [Authorize(Roles = "ADMIN,MANAGER,HEAD_CHEF,BARISTA_LEAD,KITCHEN")]
    public async Task<IActionResult> GetIngredients([FromQuery] string? search = null, [FromQuery] bool lowStockOnly = false)
    {
        var list = await Provider.Inventory.GetIngredientsAsync(search, lowStockOnly);
        int lowCount = list.Count(i => i.CurrentStock <= i.MinThreshold);
        return Ok(new
        {
            statusCode = 200,
            success = true,
            total = list.Count,
            lowStockCount = lowCount,
            data = list
        });
    }

    [HttpPost("ingredients")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> CreateIngredient([FromBody] IngredientInputDto dto)
    {
        var res = await Provider.Inventory.CreateIngredientAsync(dto, GetCallerAccountId());
        if (!res.Success) return BadRequest(new { statusCode = 400, success = false, message = res.Message });
        await _realtime.NotifyInventoryAlertAsync(new { action = "Created", ingredient = res.Data });
        return Ok(new { statusCode = 200, success = true, message = res.Message, data = res.Data });
    }

    [HttpPut("ingredients/{id:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> UpdateIngredient(int id, [FromBody] IngredientInputDto dto)
    {
        var res = await Provider.Inventory.UpdateIngredientAsync(id, dto);
        if (!res.Success) return BadRequest(new { statusCode = 400, success = false, message = res.Message });
        await _realtime.NotifyInventoryAlertAsync(new { action = "Updated", ingredient = res.Data });
        return Ok(new { statusCode = 200, success = true, message = res.Message, data = res.Data });
    }

    [HttpPost("ingredients/{id:int}/adjust")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> AdjustStock(int id, [FromBody] AdjustStockDto dto)
    {
        var res = await Provider.Inventory.AdjustStockAsync(id, dto, GetCallerAccountId());
        if (!res.Success) return BadRequest(new { statusCode = 400, success = false, message = res.Message });
        await _realtime.NotifyInventoryAlertAsync(new { action = "Adjusted", ingredient = res.Data });
        return Ok(new { statusCode = 200, success = true, message = res.Message, data = res.Data });
    }

    [HttpGet("recipes/{productId:int}")]
    [Authorize(Roles = "ADMIN,MANAGER,HEAD_CHEF,BARISTA_LEAD,KITCHEN")]
    public async Task<IActionResult> GetRecipes(int productId)
    {
        var data = await Provider.Inventory.GetRecipesByProductAsync(productId);
        return Ok(new { statusCode = 200, success = true, data });
    }

    [HttpPut("recipes/{productId:int}")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> SaveRecipes(int productId, [FromBody] List<RecipeItemInputDto> items)
    {
        var res = await Provider.Inventory.SaveRecipesForProductAsync(productId, items ?? new());
        if (!res.Success) return BadRequest(new { statusCode = 400, success = false, message = res.Message });
        return Ok(new { statusCode = 200, success = true, message = res.Message, data = res.Data });
    }

    [HttpGet("transactions")]
    [Authorize(Roles = "ADMIN,MANAGER")]
    public async Task<IActionResult> GetTransactions([FromQuery] int? ingredientId = null, [FromQuery] int limit = 100)
    {
        var data = await Provider.Inventory.GetTransactionsAsync(ingredientId, limit);
        return Ok(new { statusCode = 200, success = true, data });
    }
}
