namespace WebApi.Models;

public class SiteProvider : BaseProvider
{
    public SiteProvider(IHttpContextAccessor accessor) : base(accessor) { }

    CategoryRepository? category;
    public CategoryRepository Category => category ??= new CategoryRepository(Context);

    TableRepository? table;
    public TableRepository Table => table ??= new TableRepository(Context);
}
