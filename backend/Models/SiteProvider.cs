namespace WebApi.Models;

public class SiteProvider : BaseProvider
{
    public SiteProvider(IHttpContextAccessor accessor) : base(accessor) { }

    CategoryRepository? category;
    public CategoryRepository Category => category ??= new CategoryRepository(Context);

    TableRepository? table;
    public TableRepository Table => table ??= new TableRepository(Context);

    AccountRepository? account;
    public AccountRepository Account => account ??= new AccountRepository(Context);

    ProductRepository? product;
    public ProductRepository Product => product ??= new ProductRepository(Context);

    OrderRepository? order;
    public OrderRepository Order => order ??= new OrderRepository(Context);

    PaymentRepository? payment;
    public PaymentRepository Payment => payment ??= new PaymentRepository(Context);
}
