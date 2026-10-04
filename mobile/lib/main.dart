import 'package:flutter/material.dart';
import 'views/category_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RestaurantPosApp());
}

class RestaurantPosApp extends StatelessWidget {
  const RestaurantPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant & Cafe POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const CategoryPage(title: 'Restaurant & Coffee POS'),
    );
  }
}
