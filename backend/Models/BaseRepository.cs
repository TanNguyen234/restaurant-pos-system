namespace WebApi.Models;

public abstract class BaseRepository
{
    protected RestaurantPosContext context;
    protected RestaurantPosContext Context => context;

    public BaseRepository(RestaurantPosContext context)
    {
        this.context = context;
    }
}
