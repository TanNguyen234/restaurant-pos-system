namespace WebApi.Models;

public class CategoryRepository : BaseRepository
{
    public CategoryRepository(RestaurantPosContext context) : base(context) { }

    public IEnumerable<Category> GetCategories()
    {
        return context.Categories.Where(c => c.IsActive).OrderBy(c => c.SortOrder).ToList();
    }

    public Category? GetById(short id)
    {
        return context.Categories.Find(id);
    }

    public int Add(Category obj)
    {
        context.Categories.Add(obj);
        return context.SaveChanges();
    }

    public int Update(Category obj)
    {
        context.Categories.Update(obj);
        return context.SaveChanges();
    }

    public int Delete(short id)
    {
        var item = context.Categories.Find(id);
        if (item != null)
        {
            context.Categories.Remove(item);
            return context.SaveChanges();
        }
        return 0;
    }

    public bool HasProducts(short id)
    {
        return context.Products.Any(p => p.CategoryId == id);
    }
}
