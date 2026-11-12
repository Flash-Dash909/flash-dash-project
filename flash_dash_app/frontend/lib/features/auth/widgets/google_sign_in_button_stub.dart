import 'package:flutter/material.dart';

Widget buildGoogleSignInButton({
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: 54,
    child: OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
      ),
      icon: const Icon(Icons.g_mobiledata, size: 32, color: Color(0xFF2563EB)),
      label: const Text(
        'Continuar com o Google',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    ),
  );
}
