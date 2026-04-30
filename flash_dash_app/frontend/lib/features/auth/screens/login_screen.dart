import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Importante para o kIsWeb
import '../../home/screens/home_screen.dart'; // Ajuste o caminho conforme sua estrutura

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _fazerLogin() async {
    setState(() {
      _isLoading = true;
    });

    // 1. DEFINE A URL DINAMICAMENTE
    String baseUrl = 'http://localhost:8000'; // Padrão para Web e Desktop
    
    // Se NÃO for Web, assumimos que é o Emulador Android
    if (!kIsWeb) {
      baseUrl = 'http://10.0.2.2:8000';
    }

    // 2. MONTA A URL FINAL
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'usuario': _userController.text,
          'senha': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Login com sucesso!
        final data = json.decode(response.body);
        print("Token recebido: ${data['token']}");

        if (mounted) {
          // pushReplacement substitui a tela atual, impedindo que o usuário volte para o login pelo botão "voltar"
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Erro de usuário ou senha
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário ou senha incorretos.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar com o servidor: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ignore: deprecated_member_use
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo ou Título do App
              const Icon(
                Icons.insights, // Um ícone provisório para o Flash Dash
                size: 80,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 16),
              const Text(
                'Flash Dash',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faça login para acessar seus dashboards',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 48),

              // Campos de Input
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 32),

              // Botão de Login
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _fazerLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ENTRAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
