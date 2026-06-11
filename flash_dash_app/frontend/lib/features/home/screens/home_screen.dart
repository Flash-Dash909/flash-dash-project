import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_theme_controller.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/screens/login_screen.dart';
import '../../upload/screens/upload_screen.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../dashboard/screens/dashboard_canvas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceSelecionado = 0;
  final _perfilFormKey = GlobalKey<FormState>();
  final _nomePerfilController = TextEditingController();
  final _idadePerfilController = TextEditingController();
  final _telefonePerfilController = TextEditingController();
  final _cargoPerfilController = TextEditingController();
  final _empresaPerfilController = TextEditingController();
  final _bioPerfilController = TextEditingController();

  bool _perfilCarregando = false;
  bool _perfilSalvando = false;
  bool _perfilEditando = false;
  String? _fotoPerfil;

  String get _baseUrl => 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
    _preencherPerfilLocal();
    _buscarPerfil();
  }

  @override
  void dispose() {
    _nomePerfilController.dispose();
    _idadePerfilController.dispose();
    _telefonePerfilController.dispose();
    _cargoPerfilController.dispose();
    _empresaPerfilController.dispose();
    _bioPerfilController.dispose();
    super.dispose();
  }

  void _preencherPerfilLocal() {
    _nomePerfilController.text = DashboardManager.usuarioAtualNome ?? '';
    _idadePerfilController.text =
        DashboardManager.usuarioAtualIdade?.toString() ?? '';
    _telefonePerfilController.text =
        DashboardManager.usuarioAtualTelefone ?? '';
    _cargoPerfilController.text = DashboardManager.usuarioAtualCargo ?? '';
    _empresaPerfilController.text = DashboardManager.usuarioAtualEmpresa ?? '';
    _bioPerfilController.text = DashboardManager.usuarioAtualBio ?? '';
    _fotoPerfil = DashboardManager.usuarioAtualFoto;
  }

  void _aplicarUsuario(Map<String, dynamic> usuario) {
    DashboardManager.usuarioAtualId = usuario['id']?.toString();
    DashboardManager.usuarioAtualNome = usuario['nome']?.toString();
    DashboardManager.usuarioAtualEmail = usuario['email']?.toString();
    DashboardManager.usuarioAtualIdade = usuario['idade'] is int
        ? usuario['idade'] as int
        : int.tryParse(usuario['idade']?.toString() ?? '');
    DashboardManager.usuarioAtualTelefone = usuario['telefone']?.toString();
    DashboardManager.usuarioAtualCargo = usuario['cargo']?.toString();
    DashboardManager.usuarioAtualEmpresa = usuario['empresa']?.toString();
    DashboardManager.usuarioAtualBio = usuario['bio']?.toString();
    DashboardManager.usuarioAtualFoto = usuario['foto_url']?.toString();
    _preencherPerfilLocal();
  }

  Future<void> _buscarPerfil() async {
    final usuarioId = DashboardManager.usuarioAtualId;
    if (usuarioId == null || usuarioId.isEmpty) return;

    setState(() => _perfilCarregando = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/perfil/$usuarioId'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final usuario = data['usuario'];
        if (usuario is Map<String, dynamic>) {
          setState(() => _aplicarUsuario(usuario));
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar perfil: $e');
    } finally {
      if (mounted) setState(() => _perfilCarregando = false);
    }
  }

  Future<void> _selecionarFotoPerfil() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    final extensao = result.files.single.extension?.toLowerCase();
    final mimeType = extensao == 'png'
        ? 'image/png'
        : extensao == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    setState(() {
      _fotoPerfil = 'data:$mimeType;base64,${base64Encode(bytes)}';
      _perfilEditando = true;
    });
  }

  Future<void> _salvarPerfil() async {
    if (!_perfilFormKey.currentState!.validate()) return;

    final usuarioId = DashboardManager.usuarioAtualId;
    if (usuarioId == null || usuarioId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario nao encontrado para salvar.')),
      );
      return;
    }

    setState(() => _perfilSalvando = true);
    try {
      final idadeTexto = _idadePerfilController.text.trim();
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/perfil/$usuarioId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nome': _nomePerfilController.text.trim(),
          'idade': idadeTexto.isEmpty ? null : int.tryParse(idadeTexto),
          'telefone': _telefonePerfilController.text.trim(),
          'cargo': _cargoPerfilController.text.trim(),
          'empresa': _empresaPerfilController.text.trim(),
          'bio': _bioPerfilController.text.trim(),
          'foto_url': _fotoPerfil,
        }),
      );

      if (!mounted) return;
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final usuario = data['usuario'];
        if (usuario is Map<String, dynamic>) {
          setState(() {
            _aplicarUsuario(usuario);
            _perfilEditando = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Erro ao salvar perfil.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar perfil: $e')));
    } finally {
      if (mounted) setState(() => _perfilSalvando = false);
    }
  }

  void _logout() {
    DashboardManager.graficosAtivos.clear();
    DashboardManager.dashboardsSalvos.clear();
    DashboardManager.fontesSalvas.clear();
    DashboardManager.dadosFonteAtual = null;
    DashboardManager.dashboardAtualId = null;
    DashboardManager.usuarioAtualId = null;
    DashboardManager.usuarioAtualNome = null;
    DashboardManager.usuarioAtualEmail = null;
    DashboardManager.usuarioAtualIdade = null;
    DashboardManager.usuarioAtualTelefone = null;
    DashboardManager.usuarioAtualCargo = null;
    DashboardManager.usuarioAtualEmpresa = null;
    DashboardManager.usuarioAtualBio = null;
    DashboardManager.usuarioAtualFoto = null;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ==========================================
  // BUSCA OS DASHBOARDS DO BACKEND (SUPABASE)
  // ==========================================
  Future<List<dynamic>> _buscarDashboards() async {
    try {
      final usuarioId = DashboardManager.usuarioAtualId;
      final url = usuarioId == null
          ? 'http://127.0.0.1:8000/listar-dashboards'
          : 'http://127.0.0.1:8000/listar-dashboards?usuario_id=$usuarioId';
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint("Erro ao buscar dashboards: $e");
    }
    return [];
  }

  // BUSCA OS LOGS DO BACKEND
  Future<List<dynamic>> _buscarLogsETL() async {
    try {
      var response = await http.get(
        Uri.parse('http://127.0.0.1:8000/listar-logs-etl'),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint("Erro ao buscar logs ETL: $e");
    }
    return [];
  }

  void _iniciarNovoDashboard() {
    DashboardManager.graficosAtivos.clear();
    DashboardManager.dashboardAtualId = null;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadScreen()),
    );
  }

  Widget _buildFotoPerfil(double radius) {
    final foto = _fotoPerfil;
    ImageProvider? imageProvider;

    if (foto != null && foto.isNotEmpty) {
      if (foto.startsWith('data:image')) {
        try {
          imageProvider = MemoryImage(base64Decode(foto.split(',').last));
        } catch (_) {
          imageProvider = null;
        }
      } else {
        imageProvider = NetworkImage(foto);
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEFF6FF),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(Icons.person, color: const Color(0xFF2563EB), size: radius)
          : null,
    );
  }

  // ==========================================
  // MENU LATERAL (SIDEBAR) RESPONSIVO
  // ==========================================
  Widget _buildSidebar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [Expanded(child: AppLogo(size: 42, showText: true))],
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(Icons.dashboard_rounded, "Dashboards", 0),
          _buildMenuItem(Icons.receipt_long_rounded, "Logs ETL", 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              "SISTEMA",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.54),
              ),
            ),
          ),
          _buildMenuItem(Icons.settings_suggest_rounded, "Configuracoes", 2),
          _buildMenuItem(Icons.person_outline_rounded, "Perfil", 3),
          const Spacer(),
          _buildMenuItem(Icons.logout_rounded, "Sair", -1),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildFotoPerfil(20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DashboardManager.usuarioAtualNome ?? "Flash Dash",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DashboardManager.usuarioAtualCargo ?? "Workspace BI",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index) {
    bool isSelected = _indiceSelecionado == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final idleColor = colorScheme.onSurface.withValues(alpha: 0.64);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF2563EB) : idleColor,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF2563EB) : idleColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () {
          if (index == -1) {
            _logout();
            return;
          }
          setState(() => _indiceSelecionado = index);
          if (MediaQuery.of(context).size.width < 800) {
            Navigator.pop(context);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==========================================
  // CONSTRUÃ‡ÃƒO DA TELA PRINCIPAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 800;
    double paddingGlobal = isDesktop ? 40.0 : 16.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: !isDesktop
          ? AppBar(title: const AppLogo(size: 34, showText: true))
          : null,
      drawer: !isDesktop ? Drawer(child: _buildSidebar()) : null,

      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),

          Expanded(
            child: _indiceSelecionado == 0
                ? _buildTelaDashboards(isDesktop, paddingGlobal)
                : _indiceSelecionado == 1
                ? _buildTelaLogsETL(isDesktop, paddingGlobal)
                : _indiceSelecionado == 2
                ? _buildTelaConfiguracoes(isDesktop, paddingGlobal)
                : _buildTelaPerfil(isDesktop, paddingGlobal),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 0: TELA DOS DASHBOARDS (COM PRÃ‰-VISUALIZAÃ‡ÃƒO)
  // ==========================================
  Widget _buildTelaDashboards(bool isDesktop, double paddingGlobal) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    int crossAxisCount = isDesktop
        ? 3
        : (MediaQuery.of(context).size.width >= 600 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: paddingGlobal,
            vertical: isDesktop ? 24 : 16,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Meus Dashboards",
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _iniciarNovoDashboard,
                icon: const Icon(Icons.add),
                label: Text(isDesktop ? "Novo Dashboard" : "Novo"),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _buscarDashboards(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final dashboards = snapshot.data ?? [];

              if (dashboards.isEmpty) {
                return Center(
                  child: Text(
                    "Nenhum dashboard salvo na nuvem ainda.\nClique em Novo Dashboard para comeÃ§ar!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.all(paddingGlobal),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: isDesktop
                      ? 1.2
                      : 1.5, // Ajustado para dar mais espaÃ§o Ã  capa
                ),
                itemCount: dashboards.length,
                itemBuilder: (context, index) {
                  return _buildDashboardCard(dashboards[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // CARD DO DASHBOARD (A MÃGICA DA PRÃ‰-VISUALIZAÃ‡ÃƒO ACONTECE AQUI!)
  // ==========================================
  Color _corDoBanco(dynamic valor, [Color fallback = Colors.white]) {
    if (valor == null) return fallback;
    if (valor is int) return Color(valor);
    if (valor is String) {
      if (valor.startsWith('#')) {
        return Color(int.parse(valor.replaceFirst('#', '0xFF')));
      }
      final parsed = int.tryParse(valor);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  Rect _limitesDashboard(List<dynamic> graficos) {
    if (graficos.isEmpty) return const Rect.fromLTWH(0, 0, 1200, 800);

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = 0;
    double maxY = 0;

    for (final grafico in graficos) {
      final x = ((grafico['posicao_x'] ?? 0) as num).toDouble();
      final y = ((grafico['posicao_y'] ?? 0) as num).toDouble();
      final largura = ((grafico['largura'] ?? 350) as num).toDouble();
      final altura = ((grafico['altura'] ?? 280) as num).toDouble();

      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x + largura);
      maxY = math.max(maxY, y + altura);
    }

    const margem = 80.0;
    return Rect.fromLTRB(
      minX - margem,
      minY - margem,
      maxX + margem,
      maxY + margem,
    );
  }

  Future<void> _excluirDashboard(Map<String, dynamic> dash) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Excluir dashboard"),
        content: Text("Deseja excluir '${dash['titulo'] ?? 'Sem titulo'}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmado != true || dash['id'] == null) return;

    try {
      final response = await http.delete(
        Uri.parse("http://127.0.0.1:8000/dashboards/${dash['id']}"),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Dashboard excluido.")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nao foi possivel excluir o dashboard."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
    }
  }

  Widget _buildDashboardCard(Map<String, dynamic> dash) {
    String dataFormatada = "Atualizado recentemente";
    if (dash['created_at'] != null) {
      try {
        DateTime dt = DateTime.parse(dash['created_at']).toLocal();
        dataFormatada =
            "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (e) {}
    }

    List<dynamic> configDoBanco = dash['graficos_config'] ?? [];

    return Card(
      clipBehavior:
          Clip.antiAlias, // Impede que a capa vaze pelas bordas arredondadas
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          DashboardManager.graficosAtivos.clear();
          DashboardManager.dashboardAtualId = dash['id']?.toString();
          for (var item in configDoBanco) {
            DashboardManager.graficosAtivos.add(
              ChartConfig(
                id:
                    item['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                tipo: item['tipo'],
                titulo: item['titulo'],
                dimensao: item['dimensao'] ?? '',
                metrica: item['metrica'] ?? '',
                dados: List<Map<String, dynamic>>.from(item['dados']),
                posicao: Offset(
                  (item['posicao_x'] ?? 50).toDouble(),
                  (item['posicao_y'] ?? 50).toDouble(),
                ),
                tamanho: Size(
                  (item['largura'] ?? 350).toDouble(),
                  (item['altura'] ?? 280).toDouble(),
                ),
                corFundo: item['cor_fundo'] != null
                    ? Color(int.parse(item['cor_fundo']))
                    : Colors.white,
                mostrarLegenda: item['mostrar_legenda'] ?? true,
                posicaoLegenda: item['posicao_legenda'] ?? 'bottom',
                configExtra: item['config_extra'] != null
                    ? Map<String, dynamic>.from(item['config_extra'])
                    : {},
                fontSizeTitulo: (item['font_size_titulo'] ?? 14.0).toDouble(),
                alinhamentoTitulo: item['alinhamento_titulo'] ?? 'left',
                corTextoTitulo: item['cor_texto_titulo'] != null
                    ? Color(int.parse(item['cor_texto_titulo']))
                    : const Color(0xFF0F172A),
                raioBorda: (item['raio_borda'] ?? 12.0).toDouble(),
                mostrarSombra: item['mostrar_sombra'] ?? true,
                mostrarEixos: item['mostrar_eixos'] ?? true,
                mostrarValores: item['mostrar_valores'] ?? true,
                mostrarRotulos: item['mostrar_rotulos'] ?? true,
              ),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardCanvasScreen(),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. ÃREA DA CAPA (PRÃ‰-VISUALIZAÃ‡ÃƒO WIREFRAME)
            // ==========================================
            Expanded(
              child: Container(
                color: const Color(
                  0xFFF1F5F9,
                ), // Fundo acinzentado simulando o Canvas
                padding: EdgeInsets.zero,
                child: configDoBanco.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.dashboard_customize_rounded,
                          color: Colors.blueGrey.shade200,
                          size: 48,
                        ),
                      )
                    : CustomPaint(
                        painter: _DashboardPreviewPainter(
                          graficos: configDoBanco,
                          limites: _limitesDashboard(configDoBanco),
                          resolverCor: _corDoBanco,
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
            // ==========================================
            // 2. RODAPÃ‰ (TÃTULO E DATA)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dash['titulo'] ?? 'Sem Título',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: "Excluir dashboard",
                        onPressed: () => _excluirDashboard(dash),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.blueGrey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dataFormatada,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ABA 1: TELA DAS FONTES DE DADOS
  // ==========================================
  // ignore: unused_element
  Widget _buildTelaFontesDeDados(bool isDesktop, double paddingGlobal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: paddingGlobal,
            vertical: isDesktop ? 24 : 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Fontes de Dados",
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _iniciarNovoDashboard,
                icon: const Icon(Icons.link),
                label: Text(isDesktop ? "Conectar Nova Fonte" : "Conectar"),
              ),
            ],
          ),
        ),
        Expanded(
          child: DashboardManager.fontesSalvas.isEmpty
              ? Center(
                  child: Text(
                    "Nenhuma planilha importada ainda nesta sessÃ£o.",
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(paddingGlobal),
                  itemCount: DashboardManager.fontesSalvas.length,
                  itemBuilder: (context, index) {
                    final fonte = DashboardManager.fontesSalvas[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.table_view_rounded,
                            color: Colors.green.shade600,
                          ),
                        ),
                        title: Text(
                          fonte['nome']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.blueGrey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fonte['data']!,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.folder_open,
                                size: 14,
                                color: Colors.blueGrey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fonte['tamanho']!,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            fonte['status']!,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 2: TELA DE LOGS DE AUDITORIA (ETL)
  // ==========================================
  Widget _buildTelaLogsETL(bool isDesktop, double paddingGlobal) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    IconData getIconParaFase(String? fase) {
      if (fase == null) return Icons.info_outline;
      if (fase.contains('ExtraÃ§Ã£o')) return Icons.cloud_download_rounded;
      if (fase.contains('Limpeza')) return Icons.cleaning_services_rounded;
      if (fase.contains('Filtragem')) return Icons.filter_alt_rounded;
      if (fase.contains('PadronizaÃ§Ã£o')) return Icons.spellcheck_rounded;
      if (fase.contains('Modelagem')) return Icons.account_tree_rounded;
      if (fase.contains('Carga') || fase.contains('Load'))
        return Icons.check_circle_rounded;
      return Icons.info_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: paddingGlobal,
            vertical: isDesktop ? 24 : 16,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                "Auditoria de Dados (ETL)",
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _buscarLogsETL(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final fontes = snapshot.data ?? [];

              if (fontes.isEmpty) {
                return Center(
                  child: Text(
                    "Nenhum log de ETL encontrado.\nFaÃ§a o upload de uma planilha para gerar auditorias.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(paddingGlobal),
                itemCount: fontes.length,
                itemBuilder: (context, index) {
                  final fonte = fontes[index];
                  final List<dynamic> logs = fonte['etl_logs'] ?? [];

                  String dataFormatada = "";
                  if (fonte['created_at'] != null) {
                    try {
                      DateTime dt = DateTime.parse(
                        fonte['created_at'],
                      ).toLocal();
                      dataFormatada =
                          "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} Ã s ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                    } catch (e) {}
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    elevation: 0,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.indigo.shade600,
                          ),
                        ),
                        title: Text(
                          fonte['nome_arquivo'] ?? 'Arquivo Desconhecido',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "Processado em: $dataFormatada",
                          style: TextStyle(
                            color: Colors.blueGrey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        children: [
                          Container(
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.all(24),
                            child: logs.isEmpty
                                ? const Text(
                                    "Sem logs detalhados para este arquivo.",
                                  )
                                : Column(
                                    children: logs.map((log) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              getIconParaFase(log['fase']),
                                              color: const Color(0xFF2563EB),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    log['fase'] ?? 'Etapa',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    log['descricao'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors
                                                          .blueGrey
                                                          .shade700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTelaConfiguracoes(bool isDesktop, double paddingGlobal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCabecalhoSecao(
          titulo: 'Configuracoes',
          subtitulo: 'Preferencias gerais do workspace',
          paddingGlobal: paddingGlobal,
          isDesktop: isDesktop,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(paddingGlobal),
            children: [
              _buildPainel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workspace',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {},
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Salvar dashboards na nuvem'),
                      subtitle: const Text(
                        'Mantem seus dashboards vinculados ao usuario atual.',
                      ),
                    ),
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {},
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar pre-visualizacao na home'),
                      subtitle: const Text(
                        'Usa a composicao real dos graficos como capa.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Tema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: AppThemeController.themeMode,
                      builder: (context, themeMode, _) {
                        return SegmentedButton<ThemeMode>(
                          selected: {themeMode},
                          onSelectionChanged: (selection) {
                            AppThemeController.themeMode.value =
                                selection.first;
                          },
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('Sistema'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Claro'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Escuro'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelaPerfil(bool isDesktop, double paddingGlobal) {
    final larguraCampo = isDesktop ? 320.0 : double.infinity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCabecalhoSecao(
          titulo: 'Perfil',
          subtitulo: 'Dados pessoais e identidade do workspace',
          paddingGlobal: paddingGlobal,
          isDesktop: isDesktop,
          acao: _perfilEditando
              ? Row(
                  children: [
                    TextButton(
                      onPressed: _perfilSalvando
                          ? null
                          : () {
                              setState(() {
                                _perfilEditando = false;
                                _preencherPerfilLocal();
                              });
                            },
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _perfilSalvando ? null : _salvarPerfil,
                      icon: _perfilSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Salvar'),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  onPressed: () => setState(() => _perfilEditando = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar perfil'),
                ),
        ),
        Expanded(
          child: _perfilCarregando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.all(paddingGlobal),
                  child: Form(
                    key: _perfilFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPainel(
                          child: Flex(
                            direction: isDesktop
                                ? Axis.horizontal
                                : Axis.vertical,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  _buildFotoPerfil(isDesktop ? 58 : 48),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _selecionarFotoPerfil,
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: const Text('Alterar foto'),
                                  ),
                                ],
                              ),
                              SizedBox(width: isDesktop ? 36 : 0, height: 24),
                              Expanded(
                                flex: isDesktop ? 1 : 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 18,
                                      runSpacing: 18,
                                      children: [
                                        _buildCampoPerfil(
                                          controller: _nomePerfilController,
                                          label: 'Nome',
                                          icon: Icons.badge_outlined,
                                          largura: larguraCampo,
                                          obrigatorio: true,
                                        ),
                                        _buildCampoPerfil(
                                          initialValue:
                                              DashboardManager
                                                  .usuarioAtualEmail ??
                                              '',
                                          label: 'E-mail',
                                          icon: Icons.email_outlined,
                                          largura: larguraCampo,
                                          editavel: false,
                                        ),
                                        _buildCampoPerfil(
                                          controller: _idadePerfilController,
                                          label: 'Idade',
                                          icon: Icons.cake_outlined,
                                          largura: larguraCampo,
                                          teclado: TextInputType.number,
                                          validaNumero: true,
                                        ),
                                        _buildCampoPerfil(
                                          controller: _telefonePerfilController,
                                          label: 'Telefone',
                                          icon: Icons.phone_outlined,
                                          largura: larguraCampo,
                                        ),
                                        _buildCampoPerfil(
                                          controller: _cargoPerfilController,
                                          label: 'Cargo',
                                          icon: Icons.work_outline,
                                          largura: larguraCampo,
                                        ),
                                        _buildCampoPerfil(
                                          controller: _empresaPerfilController,
                                          label: 'Empresa',
                                          icon: Icons.business_outlined,
                                          largura: larguraCampo,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _buildCampoPerfil(
                                      controller: _bioPerfilController,
                                      label: 'Bio',
                                      icon: Icons.notes_outlined,
                                      largura: isDesktop
                                          ? 658
                                          : double.infinity,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildResumoPerfil(
                              icone: Icons.dashboard_customize_outlined,
                              titulo: 'Dashboards',
                              valor:
                                  '${DashboardManager.dashboardsSalvos.length}',
                            ),
                            _buildResumoPerfil(
                              icone: Icons.table_chart_outlined,
                              titulo: 'Fontes na sessao',
                              valor: '${DashboardManager.fontesSalvas.length}',
                            ),
                            _buildResumoPerfil(
                              icone: Icons.verified_user_outlined,
                              titulo: 'Conta',
                              valor: DashboardManager.usuarioAtualId == null
                                  ? 'Local'
                                  : 'Conectada',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCabecalhoSecao({
    required String titulo,
    required String subtitulo,
    required double paddingGlobal,
    required bool isDesktop,
    Widget? acao,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: paddingGlobal,
        vertical: isDesktop ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
          if (acao != null) acao,
        ],
      ),
    );
  }

  Widget _buildPainel({required Widget child}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCampoPerfil({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    required double largura,
    bool editavel = true,
    bool obrigatorio = false,
    bool validaNumero = false,
    int maxLines = 1,
    TextInputType? teclado,
  }) {
    return SizedBox(
      width: largura,
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: editavel && _perfilEditando,
        maxLines: maxLines,
        keyboardType: teclado,
        validator: (value) {
          final texto = value?.trim() ?? '';
          if (obrigatorio && texto.length < 2)
            return 'Informe ao menos 2 letras';
          if (validaNumero && texto.isNotEmpty) {
            final idade = int.tryParse(texto);
            if (idade == null || idade < 0 || idade > 130) {
              return 'Informe uma idade valida';
            }
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: _perfilEditando && editavel
              ? Colors.white
              : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildResumoPerfil({
    required IconData icone,
    required String titulo,
    required String valor,
  }) {
    return SizedBox(
      width: 220,
      child: _buildPainel(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPreviewPainter extends CustomPainter {
  final List<dynamic> graficos;
  final Rect limites;
  final Color Function(dynamic valor, [Color fallback]) resolverCor;

  _DashboardPreviewPainter({
    required this.graficos,
    required this.limites,
    required this.resolverCor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Offset.zero & size, background);

    final scale = math.min(
      size.width / limites.width,
      size.height / limites.height,
    );
    final offset = Offset(
      (size.width - limites.width * scale) / 2 - limites.left * scale,
      (size.height - limites.height * scale) / 2 - limites.top * scale,
    );

    for (final grafico in graficos) {
      final x =
          ((grafico['posicao_x'] ?? 0) as num).toDouble() * scale + offset.dx;
      final y =
          ((grafico['posicao_y'] ?? 0) as num).toDouble() * scale + offset.dy;
      final largura = ((grafico['largura'] ?? 350) as num).toDouble() * scale;
      final altura = ((grafico['altura'] ?? 280) as num).toDouble() * scale;
      final rect = Rect.fromLTWH(x, y, largura, altura);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

      final cardPaint = Paint()
        ..color = resolverCor(grafico['cor_fundo'], Colors.white);
      final borderPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRRect(rrect, cardPaint);
      canvas.drawRRect(rrect, borderPaint);

      final headerHeight = math.max(10.0, altura * 0.16);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top + headerHeight, rect.width, 1),
        Paint()..color = const Color(0xFFE2E8F0),
      );

      final chartRect = Rect.fromLTWH(
        rect.left + largura * 0.08,
        rect.top + headerHeight + altura * 0.08,
        largura * 0.84,
        altura * 0.68,
      );

      final dados = List<dynamic>.from(grafico['dados'] ?? []);
      final tipo = (grafico['tipo'] ?? '').toString().toLowerCase();
      if (tipo.contains('pizza') ||
          tipo.contains('rosca') ||
          tipo.contains('pie')) {
        _desenharPizza(canvas, chartRect, dados);
      } else {
        _desenharBarras(canvas, chartRect, dados);
      }
    }
  }

  void _desenharBarras(Canvas canvas, Rect rect, List<dynamic> dados) {
    final valores = dados
        .map((item) => ((item['value'] ?? 0) as num).toDouble())
        .where((valor) => valor > 0)
        .toList();
    if (valores.isEmpty) return;

    final maxValor = valores.reduce(math.max);
    final quantidade = math.min(dados.length, 8);
    final gap = rect.width * 0.04;
    final barWidth = (rect.width - gap * (quantidade - 1)) / quantidade;

    for (int i = 0; i < quantidade; i++) {
      final item = dados[i];
      final valor = ((item['value'] ?? 0) as num).toDouble();
      final altura = maxValor == 0 ? 0.0 : (valor / maxValor) * rect.height;
      final left = rect.left + i * (barWidth + gap);
      final barRect = Rect.fromLTWH(
        left,
        rect.bottom - altura,
        barWidth,
        altura,
      );
      final color = resolverCor(item['color'], const Color(0xFF3B82F6));

      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
        Paint()..color = color,
      );
    }
  }

  void _desenharPizza(Canvas canvas, Rect rect, List<dynamic> dados) {
    final valores = dados
        .map((item) => ((item['value'] ?? 0) as num).toDouble())
        .where((valor) => valor > 0)
        .toList();
    if (valores.isEmpty) return;

    final total = valores.fold<double>(0, (soma, valor) => soma + valor);
    final tamanho = math.min(rect.width, rect.height);
    final pieRect = Rect.fromCenter(
      center: rect.center,
      width: tamanho,
      height: tamanho,
    );

    double inicio = -math.pi / 2;
    for (final item in dados.take(8)) {
      final valor = ((item['value'] ?? 0) as num).toDouble();
      if (valor <= 0) continue;

      final sweep = (valor / total) * math.pi * 2;
      canvas.drawArc(
        pieRect,
        inicio,
        sweep,
        true,
        Paint()..color = resolverCor(item['color'], const Color(0xFF3B82F6)),
      );
      inicio += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardPreviewPainter oldDelegate) {
    return oldDelegate.graficos != graficos || oldDelegate.limites != limites;
  }
}
