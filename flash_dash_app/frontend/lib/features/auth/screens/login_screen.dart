import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/api_config.dart';
import '../../../core/widgets/app_logo.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../home/screens/home_screen.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '191150128104-28vgeh8p0pm3heti252b7e9t17c16km6.apps.googleusercontent.com',
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _googleClientId : null,
    serverClientId: kIsWeb ? null : _googleClientId,
  );
  StreamSubscription<GoogleSignInAccount?>? _googleUserSubscription;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();

    _googleUserSubscription = _googleSignIn.onCurrentUserChanged.listen((
      GoogleSignInAccount? account,
    ) {
      if (account != null) {
        _processarLoginGoogle(account);
      }
    });
    _googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    _googleUserSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _acionarLoginGoogle() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null && mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Erro ao abrir Google Sign-In: $e', Colors.redAccent);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processarLoginGoogle(GoogleSignInAccount googleUser) async {
    if (!mounted) return;
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
        DashboardManager.tokenAutenticacao = data['token']?.toString();
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
          DashboardManager.tokenAutenticacao = data['token']?.toString();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final double logoSize = screenHeight < 700 ? 220 : 325;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (!_isLoginMode) ...[
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: scheme.onSurface),
                      decoration: _inputDecoration(
                        'Nome completo',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: _emailController,
                    style: TextStyle(color: scheme.onSurface),
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
                    style: TextStyle(color: scheme.onSurface),
                    obscureText: true,
                    decoration: _inputDecoration('Senha', Icons.lock_outline),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 18),
                    TextField(
                      controller: _confirmPasswordController,
                      style: TextStyle(color: scheme.onSurface),
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

                  buildGoogleSignInButton(
                    isLoading: _isLoading,
                    onPressed: _acionarLoginGoogle,
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
