/// Danh mục đồ uống phục vụ tại Quầy Bar (và hiện tùy chọn Đường/Đá khi đặt món):
/// 1: Cà phê truyền thống, 2: Espresso, 3: Trà trái cây, 4: Trà sữa,
/// 5: Đá xay & Sinh tố, 9: Nước ép tươi, 10: Mocktail & Soda.
const Set<int> drinkCategoryIds = <int>{1, 2, 3, 4, 5, 9, 10};

bool isDrinkCategory(int categoryId) => drinkCategoryIds.contains(categoryId);
