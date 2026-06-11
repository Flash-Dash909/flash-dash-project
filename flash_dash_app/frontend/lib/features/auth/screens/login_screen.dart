import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/widgets/app_logo.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true;

  String get _baseUrl {
    if (!kIsWeb) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        (!_isLoginMode && _nameController.text.trim().isEmpty)) {
      _mostrarSnackBar('Preencha todos os campos.', Colors.orange);
      return;
    }

    if (!_isLoginMode &&
        _passwordController.text != _confirmPasswordController.text) {
      _mostrarSnackBar('As senhas nao coincidem.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final endpoint = _isLoginMode ? '/auth/login' : '/auth/cadastro';
    final body = _isLoginMode
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
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (_isLoginMode) {
          DashboardManager.usuarioAtualId =
              data['usuario_id']?.toString() ??
              data['usuario']?['id']?.toString();
          DashboardManager.usuarioAtualNome =
              data['usuario_nome']?.toString() ??
              data['usuario']?['nome']?.toString();
          DashboardManager.usuarioAtualEmail = data['usuario']?['email']
              ?.toString();
          DashboardManager.usuarioAtualIdade = data['usuario']?['idade'] is int
              ? data['usuario']['idade'] as int
              : int.tryParse(data['usuario']?['idade']?.toString() ?? '');
          DashboardManager.usuarioAtualTelefone = data['usuario']?['telefone']
              ?.toString();
          DashboardManager.usuarioAtualCargo = data['usuario']?['cargo']
              ?.toString();
          DashboardManager.usuarioAtualEmpresa = data['usuario']?['empresa']
              ?.toString();
          DashboardManager.usuarioAtualBio = data['usuario']?['bio']
              ?.toString();
          DashboardManager.usuarioAtualFoto = data['usuario']?['foto_url']
              ?.toString();

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          _mostrarSnackBar(
            'Conta criada com sucesso. Faca login.',
            Colors.green,
          );
          setState(() {
            _isLoginMode = true;
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
        }
      } else {
        _mostrarSnackBar(
          data['detail'] ?? 'Erro na operacao.',
          Colors.redAccent,
        );
      }
    } catch (e) {
      _mostrarSnackBar('Erro ao conectar com o servidor: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF3F3F46)),
      filled: true,
      fillColor: const Color(0xFFF1F5FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
                  const ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.83,
                      child: AppLogo(size: 325),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLoginMode
                        ? 'Faça login para acessar seus dashboards'
                        : 'Crie sua conta no Flash Dash',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 64),
                  if (!_isLoginMode) ...[
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        'Nome completo',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      'E-mail',
                      Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _inputDecoration('Senha', Icons.lock_outline),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: _inputDecoration(
                        'Confirmar senha',
                        Icons.check_circle_outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 42),
                  SizedBox(
                    height: 62,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLoginMode ? 'ENTRAR' : 'CADASTRAR',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          },
                    child: Text(
                      _isLoginMode
                          ? 'Não tem uma conta? Cadastre-se'
                          : 'Já tem uma conta? Faça login',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
