import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;

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

  // Instância do GoogleSignIn movida para o nível da classe (sem escopos extras para não quebrar o idToken)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '191150128104-28vgeh8p0pm3heti252b7e9t17c16km6.apps.googleusercontent.com',
  );

  String get _baseUrl {
    if (!kIsWeb) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  @override
  void initState() {
    super.initState();

    // Escuta as mudanças de estado. Quando o botão oficial web ou o popup mobile finalizam, cai aqui.
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null) {
        _processarLoginGoogle(account);
      }
    });

    // Opcional: Tenta logar automaticamente caso o usuário já tenha logado antes e a sessão esteja ativa
    _googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Função exclusiva para Mobile: O botão customizado aciona essa função, que abre o popup
  Future<void> _acionarLoginGoogleMobile() async {
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isLoading = false); // Usuário cancelou
      }
      // Se não for null, o listener no initState vai capturar e chamar _processarLoginGoogle automaticamente
    } catch (e) {
      _mostrarSnackBar('Erro ao abrir Google Sign-In: $e', Colors.redAccent);
      setState(() => _isLoading = false);
    }
  }

  // Função que realmente extrai o token e envia para o backend (usada tanto no Web quanto no Mobile)
  Future<void> _processarLoginGoogle(GoogleSignInAccount googleUser) async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        _mostrarSnackBar(
          'Não foi possível obter o token do Google.',
          Colors.redAccent,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Envia o idToken para o seu backend FastAPI
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': idToken}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
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
        DashboardManager.usuarioAtualBio = data['usuario']?['bio']?.toString();
        DashboardManager.usuarioAtualFoto = data['usuario']?['foto_url']
            ?.toString();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        _mostrarSnackBar(
          data['detail'] ?? 'Erro na autenticação com o Google.',
          Colors.redAccent,
        );
      }
    } catch (e) {
      _mostrarSnackBar('Erro ao conectar com o Google: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      _mostrarSnackBar('As senhas não coincidem.', Colors.orange);
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
            'Conta criada com sucesso. Faça login.',
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
          data['detail'] ?? 'Erro na operação.',
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
    final screenHeight = MediaQuery.of(context).size.height;
    final double logoSize = screenHeight < 700 ? 220 : 325;

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
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.83,
                      child: AppLogo(size: logoSize),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _isLoginMode
                          ? 'Faça login para acessar seus dashboards'
                          : 'Crie sua conta no Flash Dash',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
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
                  const SizedBox(height: 16),

                  // Renderização condicional do botão do Google (Oficial na Web, Customizado no Mobile)
                  if (kIsWeb)
                    SizedBox(
                      height:
                          44, // O renderButton tem uma altura padrão injetada pelo Google
                      child:
                          (GoogleSignInPlatform.instance
                                  as web.GoogleSignInPlugin)
                              .renderButton(),
                    )
                  else
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _acionarLoginGoogleMobile,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 32,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          'Continuar com o Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
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
