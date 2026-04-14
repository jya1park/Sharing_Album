import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const BodeumiApp());
}

class BodeumiApp extends StatelessWidget {
  const BodeumiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '보드미',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
