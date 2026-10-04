import 'package:flutter/material.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../utils/database_helper.dart';

class CategoryPage extends StatefulWidget {
  final String title;

  const CategoryPage({super.key, required this.title});

  @override
  State<StatefulWidget> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Category> categories = [];
  bool isLoading = true;
  int cartCount = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initData();
    _loadCartCount();
  }

  void _initData() async {
    var data = await CategoryRepository.getCategories();
    if (!mounted) return;
    setState(() {
      if (data != null) {
        categories = data;
      }
      isLoading = false;
    });
  }

  void _loadCartCount() async {
    int count = await _dbHelper.getCartItemCount();
    if (!mounted) return;
    setState(() {
      cartCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  // Mở màn hình giỏ hàng
                },
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.coffee, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        "Chưa có danh mục hoặc chưa kết nối Web API",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => isLoading = true);
                          _initData();
                        },
                        child: const Text("Tải lại"),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    Category item = categories[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.brown.shade100,
                          child: const Icon(Icons.local_cafe, color: Colors.brown),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item.description),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Xem sản phẩm theo danh mục
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
