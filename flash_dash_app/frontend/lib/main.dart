import 'package:flutter/material.dart';
import 'features/upload/screens/upload_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
void main() {
  runApp(const FlashDashApp());
}

class FlashDashApp extends StatelessWidget {
  const FlashDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash-Dash BI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        // 1. PALETA DE CORES CORPORATIVA E MODERNA
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
          // ignore: deprecated_member_use
          background: const Color(0xFFF8FAFC),
        ),

        // 2. APP BAR (Barra Superior) MINIMALISTA
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF64748B)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),

        // 3. CARTÕES COM SOMBRAS SUAVES (CORRIGIDO PARA CardThemeData)
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          margin: const EdgeInsets.all(8),
        ),

        // 4. BOTÕES MODERNOS
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 5. CAMPOS DE TEXTO (Inputs) LIMPOS
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),

      home: const LoginScreen(),
    );
  }
}
