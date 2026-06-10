import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../home/screens/home_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController(); // Novo campo
  final TextEditingController _emailController = TextEditingController(); // Alterado para Email
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoginMode = true; 

  Future<void> _submitForm() async {
    // Validação simples
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || 
        (!_isLoginMode && _nameController.text.isEmpty)) {
      _mostrarSnackBar('Preencha todos os campos!', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String baseUrl = 'http://localhost:8000';
    if (!kIsWeb) {
      baseUrl = 'http://10.0.2.2:8000';
    }

    final endpoint = _isLoginMode ? '/auth/login' : '/auth/cadastro';
    final url = Uri.parse('$baseUrl$endpoint');

    // Monta o corpo da requisição dependendo se é login ou cadastro
    final Map<String, dynamic> requestBody = _isLoginMode 
        ? {
            'email': _emailController.text.trim(),
            'senha': _passwordController.text,
          }
        : {
            'nome': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'senha': _passwordController.text,
          };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (_isLoginMode) {
          print("ID do usuário logado: ${responseData['usuario_id']}");
          if (mounted) {
            // PASSANDO O NOME PARA A HOME SCREEN AQUI:
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  usuarioNome: responseData['usuario_nome'] ?? 'Usuário',
                  usuarioId: responseData['usuario_id'],
                ),
              ),
            );
          }
        } else {
          // Cadastro sucesso!
          _mostrarSnackBar(responseData['mensagem'], Colors.green);
          setState(() {
            _isLoginMode = true;
            _passwordController.clear(); 
          });
        }
      } else {
        _mostrarSnackBar(responseData['detail'] ?? 'Erro na operação.', Colors.redAccent);
      }
    } catch (e) {
      _mostrarSnackBar('Erro ao conectar com o servidor: $e', Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.insights,
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
              Text(
                _isLoginMode 
                    ? 'Faça login para acessar seus dashboards'
                    : 'Crie sua conta no Flash Dash',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 48),

              // Campo de Nome (Apenas aparece se for Cadastro)
              if (!_isLoginMode) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
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

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLoginMode ? 'ENTRAR' : 'CADASTRAR'),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: Text(
                  _isLoginMode 
                      ? 'Não tem uma conta? Cadastre-se'
                      : 'Já tem uma conta? Faça login',
                  style: const TextStyle(color: Color(0xFF2563EB)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}