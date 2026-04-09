import 'package:flutter/material.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/projetos/screens/projetos_screen.dart';

void main() {
  runApp(const FlashDashApp());
}

class FlashDashApp extends StatelessWidget {
  const FlashDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Dash',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      home: const ProjetosScreen(),
    );
  }
}