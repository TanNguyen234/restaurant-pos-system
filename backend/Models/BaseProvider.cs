namespace WebApi.Models;

public abstract class BaseProvider
{
    RestaurantPosContext? context;
    IHttpContextAccessor accessor;

    public BaseProvider(IHttpContextAccessor accessor)
    {
        this.accessor = accessor;
    }

    protected RestaurantPosContext Context => context ??= accessor.HttpContext!.RequestServices.GetRequiredService<RestaurantPosContext>();
}
