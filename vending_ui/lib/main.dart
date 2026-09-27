import 'package:flutter/material.dart';
import 'config/app_colors.dart';
import 'screens/vending_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vending Machine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.machineBody,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.cardWhite,
        ),
      ),
      home: const VendingScreen(),
    );
  }
}