import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../../../core/widgets/app_logo.dart';
import '../dashboard_manager.dart';
import '../widgets/chart_renderer.dart';
import '../../home/screens/home_screen.dart';
import '../../resultado/screens/selecao_grafico_screen.dart';
import '../../upload/screens/upload_screen.dart';

class DashboardCanvasScreen extends StatefulWidget {
  const DashboardCanvasScreen({super.key});

  @override
  State<DashboardCanvasScreen> createState() => _DashboardCanvasScreenState();
}

class _DashboardCanvasScreenState extends State<DashboardCanvasScreen> {
  static const double _dashboardWidth = 1280;
  static const double _dashboardHeight = 720;
  final List<Map<String, String>> _mensagensChat = [];
  final TextEditingController _chatController = TextEditingController();
  final Map<String, Set<String>> _filtrosSegmentacao = {};
  bool _isChatLoading = false;
  bool _modoApresentacao = false;

  // ==========================================
  // Snap magnetico da grade.
  // ==========================================
  double _snap(double value) {
    const double gridSize = 20.0;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  // ==========================================
  // MENU DE CONTEXTO (LONG PRESS)
  // ==========================================
  void _mostrarMenuContexto(
    BuildContext context,
    ChartConfig config,
    Offset tapPosition,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final String? acao = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        const PopupMenuItem(
          value: 'editar',
          child: Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 12),
              Text('Editar Visual'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'excluir',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text('Excluir', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'cancelar',
          child: Row(
            children: [
              Icon(Icons.close, color: Colors.grey, size: 20),
              SizedBox(width: 12),
              Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );

    if (acao == 'editar') {
      _abrirConfiguracoesBottomSheet(config);
    } else if (acao == 'excluir') {
      setState(() => DashboardManager.graficosAtivos.remove(config));
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _salvarDashboard() async {
    TextEditingController nomeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Salvar Dashboard na Nuvem"),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: TextField(
            controller: nomeController,
            decoration: const InputDecoration(
              hintText: "Nome do Dashboard",
              filled: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeController.text.isNotEmpty) {
                  var configJson = DashboardManager.graficosAtivos
                      .map(
                        (g) => {
                          "id": g.id,
                          "tipo": g.tipo,
                          "titulo": g.titulo,
                          "dimensao": g.dimensao,
                          "metrica": g.metrica,
                          "dados": g.dados
                              .map(
                                (d) => {
                                  "label": d["label"],
                                  "value": d["value"],
                                  "color": d["color"] is Color
                                      ? (d["color"] as Color).value.toString()
                                      : d["color"].toString(),
                                },
                              )
                              .toList(),
                          "posicao_x": g.posicao.dx,
                          "posicao_y": g.posicao.dy,
                          "largura": g.tamanho.width,
                          "altura": g.tamanho.height,
                          "cor_fundo": g.corFundo.value.toString(),
                          "mostrar_legenda": g.mostrarLegenda,
                          "posicao_legenda": g.posicaoLegenda,
                          "config_extra": g.configExtra,
                          "font_size_titulo": g.fontSizeTitulo,
                          "alinhamento_titulo": g.alinhamentoTitulo,
                          "cor_texto_titulo": g.corTextoTitulo.value.toString(),
                          "raio_borda": g.raioBorda,
                          "mostrar_sombra": g.mostrarSombra,
                          "mostrar_eixos": g.mostrarEixos,
                          "mostrar_valores": g.mostrarValores,
                          "mostrar_rotulos": g.mostrarRotulos,
                        },
                      )
                      .toList();

                  try {
                    var response = await http.post(
                      Uri.parse('http://127.0.0.1:8000/salvar-dashboard'),
                      headers: {"Content-Type": "application/json"},
                      body: json.encode({
                        "titulo": nomeController.text,
                        "graficos_config": configJson,
                        "usuario_id": DashboardManager.usuarioAtualId,
                      }),
                    );

                    if (response.statusCode == 200) {
                      DashboardManager.graficosAtivos.clear();
                      Navigator.pop(dialogContext);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erro ao salvar: $e")),
                    );
                  }
                }
              },
              child: const Text("Confirmar e Salvar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _excluirDashboardAtual() async {
    final dashboardId = DashboardManager.dashboardAtualId;
    if (dashboardId == null) {
      DashboardManager.graficosAtivos.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Excluir dashboard"),
        content: const Text("Deseja excluir este dashboard por completo?"),
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

    if (confirmado != true) return;

    try {
      final response = await http.delete(
        Uri.parse("http://127.0.0.1:8000/dashboards/$dashboardId"),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        DashboardManager.graficosAtivos.clear();
        DashboardManager.dashboardAtualId = null;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
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

  void _abrirChatIA() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text(
                          "Analista IA",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _mensagensChat.length,
                        itemBuilder: (context, index) {
                          bool isUser =
                              _mensagensChat[index]['remetente'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blueAccent
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: isUser
                                    ? null
                                    : Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                _mensagensChat[index]['texto']!,
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isChatLoading)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Pergunte sobre os graficos...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _enviarMensagem(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () => _enviarMensagem(setModalState),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enviarMensagem(StateSetter setModalState) async {
    String pergunta = _chatController.text.trim();
    if (pergunta.isEmpty) return;

    setModalState(() {
      _mensagensChat.add({'remetente': 'user', 'texto': pergunta});
      _chatController.clear();
      _isChatLoading = true;
    });

    List<Map<String, dynamic>> contextoDashboard = DashboardManager
        .graficosAtivos
        .map((g) {
          var dadosLimposParaIA = g.dados
              .map((d) => {"label": d['label'], "value": d['value']})
              .toList();
          return {"titulo_grafico": g.titulo, "dados": dadosLimposParaIA};
        })
        .toList();

    try {
      var uri = Uri.parse('http://127.0.0.1:8000/chat-ia');
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "mensagem": pergunta,
          "contexto_dashboard": contextoDashboard,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        setModalState(() {
          _mensagensChat.add({'remetente': 'ia', 'texto': data['resposta']});
          _isChatLoading = false;
        });
      } else {
        throw Exception("Erro servidor: ${response.statusCode}");
      }
    } catch (e) {
      setModalState(() {
        _mensagensChat.add({
          'remetente': 'ia',
          'texto': 'Erro de conexao com a IA.',
        });
        _isChatLoading = false;
      });
    }
  }

  // ==========================================
  // Z-INDEX: TRAZER CARD PARA FRENTE
  // ==========================================
  void _trazerParaFrente(ChartConfig config) {
    setState(() {
      DashboardManager.graficosAtivos.remove(config);
      DashboardManager.graficosAtivos.add(config);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: _modoApresentacao
          ? null
          : AppBar(
              title: Text(
                isDesktop ? 'Area de Trabalho' : 'Dashboard',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 1,
              shadowColor: Colors.black12,
              actions: [
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: AppLogo(size: 30, opacity: 0.72),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.save_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  onPressed: _salvarDashboard,
                  tooltip: "Salvar",
                ),
                IconButton(
                  icon: const Icon(Icons.slideshow_rounded),
                  onPressed: () => setState(() => _modoApresentacao = true),
                  tooltip: "Modo apresentacao",
                ),
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                  onPressed: _abrirChatIA,
                  tooltip: "Chat com a IA",
                ),
                PopupMenuButton<String>(
                  tooltip: "Mais opcoes",
                  onSelected: (value) {
                    if (value == 'excluir') _excluirDashboardAtual();
                    if (value == 'atualizar') setState(() {});
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'atualizar',
                      child: Text('Atualizar layout'),
                    ),
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir dashboard'),
                    ),
                  ],
                ),
              ],
            ),
      body: Stack(
        children: [
          _buildCanvas(),
          if (_modoApresentacao)
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _modoApresentacao = false),
                  icon: const Icon(Icons.close_fullscreen_rounded),
                  label: const Text('Sair'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _modoApresentacao
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tooltip: "Adicionar Grafico",
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                final dadosFonte = DashboardManager.dadosFonteAtual;
                if (dadosFonte == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadScreen(),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SelecaoGraficoScreen(data: dadosFonte),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth > _dashboardWidth
            ? constraints.maxWidth
            : _dashboardWidth;
        final areaHeight = constraints.maxHeight > _dashboardHeight
            ? constraints.maxHeight
            : _dashboardHeight;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: _modoApresentacao ? Colors.black : const Color(0xFFF8FAFC),
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(240),
            minScale: 0.35,
            maxScale: 3.0,
            constrained: false,
            child: SizedBox(
              width: areaWidth,
              height: areaHeight,
              child: Center(
                child: Container(
                  width: _dashboardWidth,
                  height: _dashboardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: _modoApresentacao
                        ? null
                        : Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: _modoApresentacao
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                  ),
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: DashboardManager.graficosAtivos.map((config) {
                        return Positioned(
                          left: config.posicao.dx,
                          top: config.posicao.dy,
                          child: _buildResizableDraggableChart(config),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // Menu de edicao.
  // ==========================================
  void _abrirConfiguracoesBottomSheet(ChartConfig config) {
    final tituloController = TextEditingController(text: config.titulo);
    final subtituloController = TextEditingController(
      text: config.configExtra['subtitleText']?.toString() ?? '',
    );
    final descricaoController = TextEditingController(
      text: config.configExtra['descriptionText']?.toString() ?? '',
    );
    var tempMostrarLegenda = config.mostrarLegenda;
    var tempMostrarValores = config.mostrarValores;
    var tempMostrarRotulos = config.mostrarRotulos;
    var tempMostrarEixos = config.mostrarEixos;
    var tempMostrarTitulo = config.configExtra['showTitle'] as bool? ?? true;
    var tempTituloNegrito = config.configExtra['titleBold'] as bool? ?? true;
    var tempTituloItalico = config.configExtra['titleItalic'] as bool? ?? false;
    var tempTituloSublinhado =
        config.configExtra['titleUnderline'] as bool? ?? false;
    var tempMostrarSubtitulo =
        config.configExtra['showSubtitle'] as bool? ?? false;
    var tempSubtituloSize = ((config.configExtra['subtitleSize'] ?? 12) as num)
        .toDouble();
    var tempSubtituloColor = _corConfig(
      config.configExtra['subtitleColor'],
      const Color(0xFF64748B),
    );
    var tempCorFundo = config.corFundo;
    var tempBgOpacity =
        ((config.configExtra['backgroundOpacity'] ?? 1.0) as num).toDouble();
    var tempCorTexto = config.corTextoTitulo;
    var tempFontSize = config.fontSizeTitulo;
    var tempAlinhamento = config.alinhamentoTitulo;
    var tempPosicaoLegenda = config.posicaoLegenda;
    var tempContentPadding =
        ((config.configExtra['contentPadding'] ?? 8) as num).toDouble();
    var tempPlotPadding = ((config.configExtra['plotPadding'] ?? 6) as num)
        .toDouble();
    var tempBorderWidth = ((config.configExtra['borderWidth'] ?? 1) as num)
        .toDouble();
    var tempBorderVisible =
        config.configExtra['borderVisible'] as bool? ?? true;
    var tempBorderColor = _corConfig(
      config.configExtra['borderColor'],
      const Color(0xFFE2E8F0),
    );
    var tempShadowOpacity =
        ((config.configExtra['shadowOpacity'] ?? 0.12) as num).toDouble();
    var tempShadowBlur = ((config.configExtra['shadowBlur'] ?? 10) as num)
        .toDouble();
    var tempMinWidth = ((config.configExtra['minWidth'] ?? 200) as num)
        .toDouble();
    var tempMinHeight = ((config.configExtra['minHeight'] ?? 200) as num)
        .toDouble();
    var tempAnimationEntrada =
        config.configExtra['animationIn']?.toString() ?? 'instantanea';
    var tempAnimationUpdate =
        config.configExtra['animationUpdate']?.toString() ?? 'suave';
    var tempTooltipAtivo =
        config.configExtra['tooltipEnabled'] as bool? ?? true;
    var tempInteracaoFiltrar =
        config.configExtra['interactionFilter'] as bool? ?? true;
    var tempInteracaoDestacar =
        config.configExtra['interactionHighlight'] as bool? ?? true;
    var tempDrillthrough =
        config.configExtra['interactionDrillthrough'] as bool? ?? false;
    var tempNavegacao =
        config.configExtra['interactionNavigation'] as bool? ?? false;
    var tempExportPng = config.configExtra['exportPng'] as bool? ?? true;
    var tempExportPdf = config.configExtra['exportPdf'] as bool? ?? false;
    var tempExportCsv = config.configExtra['exportCsv'] as bool? ?? true;
    var tempExportExcel = config.configExtra['exportExcel'] as bool? ?? false;
    var tempThemePreset =
        config.configExtra['themePreset']?.toString() ?? 'manual';
    var tempRaioFuro = (config.configExtra['raioFuro'] ?? 0.0).toDouble();
    var tempMostrarPorcentagem =
        config.configExtra['mostrarPorcentagem'] ?? false;
    var tempMostrarPontos = config.configExtra['mostrarPontos'] ?? true;
    var tempEspessuraLinha = (config.configExtra['espessuraLinha'] ?? 3.0)
        .toDouble();
    var tempGaugeMin = (config.configExtra['gaugeMin'] ?? 0.0).toDouble();
    var tempGaugeMax = (config.configExtra['gaugeMax'] ?? 100.0).toDouble();
    var tempGaugeMeta = (config.configExtra['gaugeMeta'] ?? 80.0).toDouble();
    var tempKpiPrefixo = (config.configExtra['prefixo'] ?? '').toString();
    var tempKpiSufixo = (config.configExtra['sufixo'] ?? '').toString();
    var tempKpiDecimais = ((config.configExtra['decimais'] ?? 0) as num)
        .round();
    var tempKpiFontSize = (config.configExtra['kpiFontSize'] ?? 44.0)
        .toDouble();
    var tempCorPrincipal = _corConfig(
      config.configExtra['corPrincipal'],
      const Color(0xFF2563EB),
    );
    var tempCorMetricaPrincipal = _corConfig(
      config.configExtra['corMetricaPrincipal'] ??
          config.configExtra['barColor'] ??
          config.configExtra['lineColor'] ??
          config.configExtra['corPrincipal'],
      const Color(0xFF2563EB),
    );
    var tempCorMetricaSecundaria = _corConfig(
      config.configExtra['corMetricaSecundaria'] ??
          config.configExtra['stackColor'],
      const Color(0xFFF59E0B),
    );
    var tempMetricColorMode =
        config.configExtra['metricColorMode']?.toString() ?? 'categoria';
    var tempSecondaryScaleMode =
        config.configExtra['secondaryScaleMode']?.toString() ?? 'mesma';
    var tempHeaderTabela = _corConfig(
      config.configExtra['headerColor'],
      const Color(0xFF1D4ED8),
    );
    var tempTotalTabela = _corConfig(
      config.configExtra['totalColor'],
      const Color(0xFFFDE047),
    );
    var tempRowColorA = _corConfig(
      config.configExtra['rowColorA'],
      Colors.white,
    );
    var tempRowColorB = _corConfig(
      config.configExtra['rowColorB'],
      const Color(0xFFF1F5F9),
    );
    var tempGridColor = _corConfig(
      config.configExtra['gridColor'],
      const Color(0xFFE2E8F0),
    );
    var tempRowHeight = ((config.configExtra['rowHeight'] ?? 34) as num)
        .toDouble();
    var tempChipRadius = (config.configExtra['chipRadius'] ?? 8.0).toDouble();
    var tempSegmentacaoMultipla =
        config.configExtra['segmentacaoMultipla'] as bool? ?? true;
    var tempSlicerStyle =
        config.configExtra['slicerStyle']?.toString() ?? 'botoes';
    var tempSlicerSearch = config.configExtra['slicerSearch'] as bool? ?? false;
    var tempGaugeRanges =
        config.configExtra['gaugeMostrarFaixas'] as bool? ?? false;
    var tempTreemapSpacing =
        ((config.configExtra['treemapSpacing'] ?? 0) as num).toDouble();
    var tempBarGap = ((config.configExtra['barGap'] ?? 0.04) as num).toDouble();
    var tempBarOpacity = ((config.configExtra['barOpacity'] ?? 1.0) as num)
        .toDouble();
    var tempBarBorderWidth =
        ((config.configExtra['barBorderWidth'] ?? 0) as num).toDouble();
    var tempBarColorMode =
        config.configExtra['barColorMode']?.toString() ?? 'categoria';
    var tempLineColor = _corConfig(
      config.configExtra['lineColor'],
      const Color(0xFF2563EB),
    );
    var tempMarkerSize = ((config.configExtra['markerSize'] ?? 4) as num)
        .toDouble();
    var tempSliceOpacity = ((config.configExtra['sliceOpacity'] ?? 1.0) as num)
        .toDouble();
    var tempKpiShowMeta = config.configExtra['kpiShowMeta'] as bool? ?? false;
    var tempKpiMeta = ((config.configExtra['kpiMeta'] ?? 0) as num).toDouble();
    var tempKpiShowTrend = config.configExtra['kpiShowTrend'] as bool? ?? false;
    var tempKpiPrevious = ((config.configExtra['kpiPrevious'] ?? 0) as num)
        .toDouble();
    final usaLegenda = _tipoUsaLegenda(config.tipo);
    final tipoLower = config.tipo.toLowerCase();
    final usaMetricaSecundaria =
        tipoLower.contains('empilh') ||
        tipoLower.contains('100%') ||
        tipoLower.contains('combo') ||
        config.dados.any((item) => item.containsKey('value2'));
    final usaEixos =
        tipoLower.contains('barra') ||
        tipoLower.contains('coluna') ||
        tipoLower.contains('linha') ||
        tipoLower.contains('area') ||
        tipoLower.contains('dispers');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.88,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Formatar visual",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Dados",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text("Dimensao: ${config.dimensao}"),
                          Text("Metrica: ${config.metrica}"),
                          const Divider(height: 32),
                          const Text(
                            "Aparencia",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Exibir titulo"),
                            value: tempMostrarTitulo,
                            onChanged: (v) =>
                                setModalState(() => tempMostrarTitulo = v),
                          ),
                          TextField(
                            controller: tituloController,
                            decoration: const InputDecoration(
                              labelText: "Titulo do grafico",
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text("Negrito"),
                                selected: tempTituloNegrito,
                                onSelected: (v) =>
                                    setModalState(() => tempTituloNegrito = v),
                              ),
                              FilterChip(
                                label: const Text("Italico"),
                                selected: tempTituloItalico,
                                onSelected: (v) =>
                                    setModalState(() => tempTituloItalico = v),
                              ),
                              FilterChip(
                                label: const Text("Sublinhado"),
                                selected: tempTituloSublinhado,
                                onSelected: (v) => setModalState(
                                  () => tempTituloSublinhado = v,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text("Tamanho do titulo: ${tempFontSize.round()}"),
                          Slider(
                            value: tempFontSize,
                            min: 10,
                            max: 28,
                            onChanged: (v) =>
                                setModalState(() => tempFontSize = v),
                          ),
                          Row(
                            children: [
                              const Text("Alinhamento: "),
                              ToggleButtons(
                                borderRadius: BorderRadius.circular(8),
                                isSelected: [
                                  tempAlinhamento == 'left',
                                  tempAlinhamento == 'center',
                                  tempAlinhamento == 'right',
                                ],
                                onPressed: (index) => setModalState(
                                  () => tempAlinhamento = [
                                    'left',
                                    'center',
                                    'right',
                                  ][index],
                                ),
                                children: const [
                                  Icon(Icons.format_align_left),
                                  Icon(Icons.format_align_center),
                                  Icon(Icons.format_align_right),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Cor do titulo",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            children:
                                [
                                      const Color(0xFF0F172A),
                                      const Color(0xFF2563EB),
                                      const Color(0xFFEF4444),
                                      Colors.white,
                                    ]
                                    .map(
                                      (cor) => _botaoCor(
                                        tempCorTexto,
                                        cor,
                                        setModalState,
                                        (c) => tempCorTexto = c,
                                      ),
                                    )
                                    .toList(),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Exibir subtitulo"),
                            value: tempMostrarSubtitulo,
                            onChanged: (v) =>
                                setModalState(() => tempMostrarSubtitulo = v),
                          ),
                          TextField(
                            controller: subtituloController,
                            decoration: const InputDecoration(
                              labelText: "Texto do subtitulo",
                            ),
                          ),
                          Text(
                            "Tamanho do subtitulo: ${tempSubtituloSize.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: tempSubtituloSize,
                            min: 9,
                            max: 22,
                            onChanged: (v) =>
                                setModalState(() => tempSubtituloSize = v),
                          ),
                          const Text("Cor do subtitulo"),
                          Wrap(
                            spacing: 12,
                            children:
                                [
                                      const Color(0xFF64748B),
                                      const Color(0xFF2563EB),
                                      const Color(0xFF0F172A),
                                      const Color(0xFFEF4444),
                                    ]
                                    .map(
                                      (cor) => _botaoCor(
                                        tempSubtituloColor,
                                        cor,
                                        setModalState,
                                        (c) => tempSubtituloColor = c,
                                      ),
                                    )
                                    .toList(),
                          ),
                          TextField(
                            controller: descricaoController,
                            decoration: const InputDecoration(
                              labelText: "Descricao / tooltip",
                            ),
                          ),
                          const Divider(height: 32),
                          const Text(
                            "Container",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children:
                                [
                                      Colors.white,
                                      const Color(0xFFF8FAFC),
                                      const Color(0xFFEFF6FF),
                                      const Color(0xFFFFFBEB),
                                      const Color(0xFF1E293B),
                                      Colors.black,
                                    ]
                                    .map(
                                      (cor) => _botaoCor(
                                        tempCorFundo,
                                        cor,
                                        setModalState,
                                        (c) => tempCorFundo = c,
                                      ),
                                    )
                                    .toList(),
                          ),
                          Text(
                            "Transparencia do fundo: ${(1 - tempBgOpacity).toStringAsFixed(2)}",
                          ),
                          Slider(
                            value: tempBgOpacity,
                            min: 0,
                            max: 1,
                            onChanged: (v) =>
                                setModalState(() => tempBgOpacity = v),
                          ),
                          Text(
                            "Largura: ${config.tamanho.width.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: config.tamanho.width,
                            min: tempMinWidth,
                            max: 1200,
                            onChanged: (v) => setModalState(
                              () => config.tamanho = Size(
                                v,
                                config.tamanho.height,
                              ),
                            ),
                          ),
                          Text(
                            "Altura: ${config.tamanho.height.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: config.tamanho.height,
                            min: tempMinHeight,
                            max: 900,
                            onChanged: (v) => setModalState(
                              () => config.tamanho = Size(
                                config.tamanho.width,
                                v,
                              ),
                            ),
                          ),
                          Text("X: ${config.posicao.dx.toStringAsFixed(0)}"),
                          Slider(
                            value: config.posicao.dx.clamp(0, 10000),
                            min: 0,
                            max: 10000,
                            onChanged: (v) => setModalState(
                              () =>
                                  config.posicao = Offset(v, config.posicao.dy),
                            ),
                          ),
                          Text("Y: ${config.posicao.dy.toStringAsFixed(0)}"),
                          Slider(
                            value: config.posicao.dy.clamp(0, 10000),
                            min: 0,
                            max: 10000,
                            onChanged: (v) => setModalState(
                              () =>
                                  config.posicao = Offset(config.posicao.dx, v),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => setModalState(() {
                                  config.posicao = Offset(
                                    MediaQuery.of(context).size.width / 2 -
                                        config.tamanho.width / 2,
                                    config.posicao.dy,
                                  );
                                }),
                                icon: const Icon(Icons.align_horizontal_center),
                                label: const Text("Centralizar H"),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => setModalState(() {
                                  config.posicao = Offset(
                                    config.posicao.dx,
                                    MediaQuery.of(context).size.height / 2 -
                                        config.tamanho.height / 2,
                                  );
                                }),
                                icon: const Icon(Icons.align_vertical_center),
                                label: const Text("Centralizar V"),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Exibir borda"),
                            value: tempBorderVisible,
                            onChanged: (v) =>
                                setModalState(() => tempBorderVisible = v),
                          ),
                          const Text("Cor da borda"),
                          Wrap(
                            spacing: 12,
                            children:
                                [
                                      const Color(0xFFE2E8F0),
                                      const Color(0xFF2563EB),
                                      const Color(0xFF0F172A),
                                      const Color(0xFFEF4444),
                                    ]
                                    .map(
                                      (cor) => _botaoCor(
                                        tempBorderColor,
                                        cor,
                                        setModalState,
                                        (c) => tempBorderColor = c,
                                      ),
                                    )
                                    .toList(),
                          ),
                          Text(
                            "Espacamento interno: ${tempContentPadding.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: tempContentPadding,
                            min: 0,
                            max: 32,
                            onChanged: (v) =>
                                setModalState(() => tempContentPadding = v),
                          ),
                          Text(
                            "Margem interna do grafico: ${tempPlotPadding.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: tempPlotPadding,
                            min: 0,
                            max: 28,
                            onChanged: (v) =>
                                setModalState(() => tempPlotPadding = v),
                          ),
                          Text(
                            "Borda do cartao: ${tempBorderWidth.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: tempBorderWidth,
                            min: 0,
                            max: 8,
                            divisions: 8,
                            onChanged: (v) =>
                                setModalState(() => tempBorderWidth = v),
                          ),
                          Text(
                            "Opacidade da sombra: ${tempShadowOpacity.toStringAsFixed(2)}",
                          ),
                          Slider(
                            value: tempShadowOpacity,
                            min: 0,
                            max: 1,
                            onChanged: (v) =>
                                setModalState(() => tempShadowOpacity = v),
                          ),
                          Text(
                            "Desfoque da sombra: ${tempShadowBlur.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: tempShadowBlur,
                            min: 0,
                            max: 40,
                            onChanged: (v) =>
                                setModalState(() => tempShadowBlur = v),
                          ),
                          const Divider(height: 32),
                          const Text(
                            "Legenda, rotulos e eixos",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (usaLegenda)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar legenda"),
                              value: tempMostrarLegenda,
                              onChanged: (v) =>
                                  setModalState(() => tempMostrarLegenda = v),
                            ),
                          if (usaLegenda && tempMostrarLegenda)
                            Wrap(
                              spacing: 8,
                              children: ['top', 'bottom', 'left', 'right']
                                  .map(
                                    (pos) => ChoiceChip(
                                      label: Text(pos.toUpperCase()),
                                      selected: tempPosicaoLegenda == pos,
                                      onSelected: (_) => setModalState(
                                        () => tempPosicaoLegenda = pos,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (!tipoLower.contains('segment'))
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar valores"),
                              value: tempMostrarValores,
                              onChanged: (v) =>
                                  setModalState(() => tempMostrarValores = v),
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Mostrar rotulos"),
                            value: tempMostrarRotulos,
                            onChanged: (v) =>
                                setModalState(() => tempMostrarRotulos = v),
                          ),
                          if (usaEixos)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar eixos e grade"),
                              value: tempMostrarEixos,
                              onChanged: (v) =>
                                  setModalState(() => tempMostrarEixos = v),
                            ),
                          if (!tipoLower.contains('tabela') &&
                              !tipoLower.contains('matriz') &&
                              !tipoLower.contains('segment')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Cores das metricas",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            if (!usaMetricaSecundaria)
                              DropdownButtonFormField<String>(
                                value: tempMetricColorMode,
                                decoration: const InputDecoration(
                                  labelText: "Aplicar cores",
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'categoria',
                                    child: Text("Por categoria"),
                                  ),
                                  DropdownMenuItem(
                                    value: 'metrica',
                                    child: Text("Por metrica"),
                                  ),
                                ],
                                onChanged: (v) => setModalState(
                                  () => tempMetricColorMode = v ?? 'categoria',
                                ),
                              ),
                            const SizedBox(height: 8),
                            const Text("Metrica principal"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFF2563EB),
                                        const Color(0xFF10B981),
                                        const Color(0xFFF59E0B),
                                        const Color(0xFFEF4444),
                                        const Color(0xFF8B5CF6),
                                        const Color(0xFF14B8A6),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempCorMetricaPrincipal,
                                          cor,
                                          setModalState,
                                          (c) {
                                            tempCorMetricaPrincipal = c;
                                            tempCorPrincipal = c;
                                            tempLineColor = c;
                                          },
                                        ),
                                      )
                                      .toList(),
                            ),
                            if (usaMetricaSecundaria) ...[
                              const SizedBox(height: 12),
                              const Text("Metrica secundaria"),
                              Wrap(
                                spacing: 12,
                                children:
                                    [
                                          const Color(0xFFF59E0B),
                                          const Color(0xFFEF4444),
                                          const Color(0xFF10B981),
                                          const Color(0xFF8B5CF6),
                                          const Color(0xFF14B8A6),
                                          const Color(0xFF64748B),
                                        ]
                                        .map(
                                          (cor) => _botaoCor(
                                            tempCorMetricaSecundaria,
                                            cor,
                                            setModalState,
                                            (c) => tempCorMetricaSecundaria = c,
                                          ),
                                        )
                                        .toList(),
                              ),
                              DropdownButtonFormField<String>(
                                value: tempSecondaryScaleMode,
                                decoration: const InputDecoration(
                                  labelText: "Escala da segunda metrica",
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'mesma',
                                    child: Text("Mesma escala"),
                                  ),
                                  DropdownMenuItem(
                                    value: 'independente',
                                    child: Text("Independente"),
                                  ),
                                ],
                                onChanged: (v) => setModalState(
                                  () => tempSecondaryScaleMode = v ?? 'mesma',
                                ),
                              ),
                            ],
                          ],
                          if (config.tipo.contains('Linha') ||
                              config.tipo.contains('Area') ||
                              config.tipo.contains('Área')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Linha e area",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar marcadores"),
                              value: tempMostrarPontos,
                              onChanged: (v) =>
                                  setModalState(() => tempMostrarPontos = v),
                            ),
                            Text(
                              "Espessura da linha: ${tempEspessuraLinha.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempEspessuraLinha,
                              min: 1,
                              max: 8,
                              onChanged: (v) =>
                                  setModalState(() => tempEspessuraLinha = v),
                            ),
                            const Text("Cor da linha"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFF2563EB),
                                        const Color(0xFF10B981),
                                        const Color(0xFFEF4444),
                                        const Color(0xFF8B5CF6),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempLineColor,
                                          cor,
                                          setModalState,
                                          (c) => tempLineColor = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            Text(
                              "Tamanho dos marcadores: ${tempMarkerSize.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempMarkerSize,
                              min: 2,
                              max: 12,
                              onChanged: (v) =>
                                  setModalState(() => tempMarkerSize = v),
                            ),
                          ],
                          if (config.tipo.contains('Pizza') ||
                              config.tipo.contains('Rosca')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Pizza e rosca",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar porcentagem"),
                              value: tempMostrarPorcentagem,
                              onChanged: (v) => setModalState(
                                () => tempMostrarPorcentagem = v,
                              ),
                            ),
                            Text(
                              "Abertura central: ${tempRaioFuro.toStringAsFixed(2)}",
                            ),
                            Slider(
                              value: tempRaioFuro,
                              min: 0,
                              max: 0.82,
                              onChanged: (v) =>
                                  setModalState(() => tempRaioFuro = v),
                            ),
                            Text(
                              "Transparencia das fatias: ${(1 - tempSliceOpacity).toStringAsFixed(2)}",
                            ),
                            Slider(
                              value: tempSliceOpacity,
                              min: 0.1,
                              max: 1,
                              onChanged: (v) =>
                                  setModalState(() => tempSliceOpacity = v),
                            ),
                          ],
                          if (tipoLower.contains('barra') ||
                              tipoLower.contains('coluna')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Barras e colunas",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              value: tempBarColorMode,
                              decoration: const InputDecoration(
                                labelText: "Cores",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'categoria',
                                  child: Text("Por categoria"),
                                ),
                                DropdownMenuItem(
                                  value: 'unica',
                                  child: Text("Cor unica"),
                                ),
                              ],
                              onChanged: (v) => setModalState(
                                () => tempBarColorMode = v ?? 'categoria',
                              ),
                            ),
                            Text(
                              "Transparencia: ${(1 - tempBarOpacity).toStringAsFixed(2)}",
                            ),
                            Slider(
                              value: tempBarOpacity,
                              min: 0.1,
                              max: 1,
                              onChanged: (v) =>
                                  setModalState(() => tempBarOpacity = v),
                            ),
                            Text(
                              "Espacamento: ${tempBarGap.toStringAsFixed(2)}",
                            ),
                            Slider(
                              value: tempBarGap,
                              min: 0,
                              max: 0.18,
                              onChanged: (v) =>
                                  setModalState(() => tempBarGap = v),
                            ),
                            Text(
                              "Borda da barra: ${tempBarBorderWidth.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempBarBorderWidth,
                              min: 0,
                              max: 6,
                              onChanged: (v) =>
                                  setModalState(() => tempBarBorderWidth = v),
                            ),
                          ],
                          if (config.tipo.contains('Gauge')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Gauge",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            Text(
                              "Valor minimo: ${tempGaugeMin.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempGaugeMin,
                              min: 0,
                              max: 100000,
                              onChanged: (v) =>
                                  setModalState(() => tempGaugeMin = v),
                            ),
                            Text(
                              "Valor maximo: ${tempGaugeMax.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempGaugeMax,
                              min: 1,
                              max: 1000000,
                              onChanged: (v) =>
                                  setModalState(() => tempGaugeMax = v),
                            ),
                            Text("Meta: ${tempGaugeMeta.toStringAsFixed(0)}"),
                            Slider(
                              value: tempGaugeMeta,
                              min: 0,
                              max: 1000000,
                              onChanged: (v) =>
                                  setModalState(() => tempGaugeMeta = v),
                            ),
                            const Text(
                              "Cor principal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFF2563EB),
                                        const Color(0xFF10B981),
                                        const Color(0xFFF59E0B),
                                        const Color(0xFFEF4444),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempCorPrincipal,
                                          cor,
                                          setModalState,
                                          (c) => tempCorPrincipal = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Mostrar faixas boa/media/ruim",
                              ),
                              value: tempGaugeRanges,
                              onChanged: (v) =>
                                  setModalState(() => tempGaugeRanges = v),
                            ),
                          ],
                          if (config.tipo.contains('KPI') ||
                              config.tipo.contains('Cartao') ||
                              config.tipo.contains('Cartão')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Cartao KPI",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Prefixo",
                              ),
                              controller: TextEditingController(
                                text: tempKpiPrefixo,
                              ),
                              onChanged: (v) => tempKpiPrefixo = v,
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Sufixo",
                              ),
                              controller: TextEditingController(
                                text: tempKpiSufixo,
                              ),
                              onChanged: (v) => tempKpiSufixo = v,
                            ),
                            Text(
                              "Tamanho do numero: ${tempKpiFontSize.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempKpiFontSize,
                              min: 24,
                              max: 72,
                              onChanged: (v) =>
                                  setModalState(() => tempKpiFontSize = v),
                            ),
                            Text("Casas decimais: $tempKpiDecimais"),
                            Slider(
                              value: tempKpiDecimais.toDouble(),
                              min: 0,
                              max: 3,
                              divisions: 3,
                              onChanged: (v) => setModalState(
                                () => tempKpiDecimais = v.round(),
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar meta"),
                              value: tempKpiShowMeta,
                              onChanged: (v) =>
                                  setModalState(() => tempKpiShowMeta = v),
                            ),
                            Text("Meta: ${tempKpiMeta.toStringAsFixed(0)}"),
                            Slider(
                              value: tempKpiMeta,
                              min: 0,
                              max: 10000000,
                              onChanged: (v) =>
                                  setModalState(() => tempKpiMeta = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar tendencia"),
                              value: tempKpiShowTrend,
                              onChanged: (v) =>
                                  setModalState(() => tempKpiShowTrend = v),
                            ),
                            Text(
                              "Valor anterior: ${tempKpiPrevious.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempKpiPrevious,
                              min: 0,
                              max: 10000000,
                              onChanged: (v) =>
                                  setModalState(() => tempKpiPrevious = v),
                            ),
                          ],
                          if (config.tipo.contains('Tabela')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Tabela",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text("Cor do cabecalho"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFF1D4ED8),
                                        const Color(0xFF1E1B4B),
                                        const Color(0xFF0F5592),
                                        const Color(0xFF111827),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempHeaderTabela,
                                          cor,
                                          setModalState,
                                          (c) => tempHeaderTabela = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text("Cor da linha total"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFFFDE047),
                                        const Color(0xFFBBF7D0),
                                        const Color(0xFFFFEDD5),
                                        const Color(0xFFE0E7FF),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempTotalTabela,
                                          cor,
                                          setModalState,
                                          (c) => tempTotalTabela = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text("Cor das linhas alternadas"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        Colors.white,
                                        const Color(0xFFF1F5F9),
                                        const Color(0xFFEFF6FF),
                                        const Color(0xFFFFFBEB),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempRowColorA,
                                          cor,
                                          setModalState,
                                          (c) => tempRowColorA = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFFF8FAFC),
                                        const Color(0xFFE2E8F0),
                                        const Color(0xFFDBEAFE),
                                        const Color(0xFFDCFCE7),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempRowColorB,
                                          cor,
                                          setModalState,
                                          (c) => tempRowColorB = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text("Cor das grades"),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFFE2E8F0),
                                        const Color(0xFF94A3B8),
                                        const Color(0xFF60A5FA),
                                        const Color(0xFFCBD5E1),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempGridColor,
                                          cor,
                                          setModalState,
                                          (c) => tempGridColor = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            Text(
                              "Altura das linhas: ${tempRowHeight.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempRowHeight,
                              min: 24,
                              max: 56,
                              onChanged: (v) =>
                                  setModalState(() => tempRowHeight = v),
                            ),
                          ],
                          if (config.tipo.contains('Segment')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Segmentacao",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            Text(
                              "Raio dos botoes: ${tempChipRadius.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempChipRadius,
                              min: 0,
                              max: 28,
                              onChanged: (v) =>
                                  setModalState(() => tempChipRadius = v),
                            ),
                            const Text(
                              "Cor dos botoes",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children:
                                  [
                                        const Color(0xFF0F5592),
                                        const Color(0xFF2563EB),
                                        const Color(0xFF1D4ED8),
                                        const Color(0xFF0F172A),
                                      ]
                                      .map(
                                        (cor) => _botaoCor(
                                          tempCorPrincipal,
                                          cor,
                                          setModalState,
                                          (c) => tempCorPrincipal = c,
                                        ),
                                      )
                                      .toList(),
                            ),
                            DropdownButtonFormField<String>(
                              value: tempSlicerStyle,
                              decoration: const InputDecoration(
                                labelText: "Estilo",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'botoes',
                                  child: Text("Botoes"),
                                ),
                                DropdownMenuItem(
                                  value: 'lista',
                                  child: Text("Lista"),
                                ),
                                DropdownMenuItem(
                                  value: 'tags',
                                  child: Text("Tags"),
                                ),
                                DropdownMenuItem(
                                  value: 'dropdown',
                                  child: Text("Dropdown"),
                                ),
                              ],
                              onChanged: (v) => setModalState(
                                () => tempSlicerStyle = v ?? 'botoes',
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar busca"),
                              value: tempSlicerSearch,
                              onChanged: (v) =>
                                  setModalState(() => tempSlicerSearch = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Permitir selecao multipla"),
                              value: tempSegmentacaoMultipla,
                              onChanged: (v) => setModalState(
                                () => tempSegmentacaoMultipla = v,
                              ),
                            ),
                          ],
                          if (config.tipo.contains('Treemap')) ...[
                            const Divider(height: 32),
                            const Text(
                              "Treemap",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            Text(
                              "Espacamento entre blocos: ${tempTreemapSpacing.toStringAsFixed(0)}",
                            ),
                            Slider(
                              value: tempTreemapSpacing,
                              min: 0,
                              max: 10,
                              onChanged: (v) =>
                                  setModalState(() => tempTreemapSpacing = v),
                            ),
                          ],
                          const Divider(height: 32),
                          const Text(
                            "Interacoes, animacoes e exportacao",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Tooltip ativo"),
                            value: tempTooltipAtivo,
                            onChanged: (v) =>
                                setModalState(() => tempTooltipAtivo = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Filtrar outros visuais"),
                            value: tempInteracaoFiltrar,
                            onChanged: (v) =>
                                setModalState(() => tempInteracaoFiltrar = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Destacar selecao"),
                            value: tempInteracaoDestacar,
                            onChanged: (v) =>
                                setModalState(() => tempInteracaoDestacar = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Drill-through"),
                            value: tempDrillthrough,
                            onChanged: (v) =>
                                setModalState(() => tempDrillthrough = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Navegacao"),
                            value: tempNavegacao,
                            onChanged: (v) =>
                                setModalState(() => tempNavegacao = v),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilterChip(
                                label: const Text("PNG"),
                                selected: tempExportPng,
                                onSelected: (v) =>
                                    setModalState(() => tempExportPng = v),
                              ),
                              FilterChip(
                                label: const Text("PDF"),
                                selected: tempExportPdf,
                                onSelected: (v) =>
                                    setModalState(() => tempExportPdf = v),
                              ),
                              FilterChip(
                                label: const Text("CSV"),
                                selected: tempExportCsv,
                                onSelected: (v) =>
                                    setModalState(() => tempExportCsv = v),
                              ),
                              FilterChip(
                                label: const Text("Excel"),
                                selected: tempExportExcel,
                                onSelected: (v) =>
                                    setModalState(() => tempExportExcel = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            config.titulo = tituloController.text;
                            config.mostrarLegenda = tempMostrarLegenda;
                            config.mostrarValores = tempMostrarValores;
                            config.mostrarRotulos = tempMostrarRotulos;
                            config.mostrarEixos = tempMostrarEixos;
                            config.corFundo = tempCorFundo;
                            config.corTextoTitulo = tempCorTexto;
                            config.fontSizeTitulo = tempFontSize;
                            config.alinhamentoTitulo = tempAlinhamento;
                            config.posicaoLegenda = tempPosicaoLegenda;
                            config.configExtra['showTitle'] = tempMostrarTitulo;
                            config.configExtra['titleBold'] = tempTituloNegrito;
                            config.configExtra['titleItalic'] =
                                tempTituloItalico;
                            config.configExtra['titleUnderline'] =
                                tempTituloSublinhado;
                            config.configExtra['showSubtitle'] =
                                tempMostrarSubtitulo;
                            config.configExtra['subtitleText'] =
                                subtituloController.text;
                            config.configExtra['subtitleSize'] =
                                tempSubtituloSize;
                            config.configExtra['subtitleColor'] =
                                tempSubtituloColor.value.toString();
                            config.configExtra['descriptionText'] =
                                descricaoController.text;
                            config.configExtra['backgroundOpacity'] =
                                tempBgOpacity;
                            config.configExtra['borderVisible'] =
                                tempBorderVisible;
                            config.configExtra['borderColor'] = tempBorderColor
                                .value
                                .toString();
                            config.configExtra['shadowOpacity'] =
                                tempShadowOpacity;
                            config.configExtra['shadowBlur'] = tempShadowBlur;
                            config.configExtra['minWidth'] = tempMinWidth;
                            config.configExtra['minHeight'] = tempMinHeight;
                            config.configExtra['contentPadding'] =
                                tempContentPadding;
                            config.configExtra['plotPadding'] = tempPlotPadding;
                            config.configExtra['borderWidth'] = tempBorderWidth;
                            config.configExtra['raioFuro'] = tempRaioFuro;
                            config.configExtra['mostrarPorcentagem'] =
                                tempMostrarPorcentagem;
                            config.configExtra['mostrarPontos'] =
                                tempMostrarPontos;
                            config.configExtra['espessuraLinha'] =
                                tempEspessuraLinha;
                            config.configExtra['lineColor'] = tempLineColor
                                .value
                                .toString();
                            config.configExtra['markerSize'] = tempMarkerSize;
                            config.configExtra['barGap'] = tempBarGap;
                            config.configExtra['barOpacity'] = tempBarOpacity;
                            config.configExtra['barBorderWidth'] =
                                tempBarBorderWidth;
                            config.configExtra['barColorMode'] =
                                tempBarColorMode;
                            config.configExtra['sliceOpacity'] =
                                tempSliceOpacity;
                            config.configExtra['gaugeMin'] = tempGaugeMin;
                            config.configExtra['gaugeMax'] = tempGaugeMax;
                            config.configExtra['gaugeMeta'] = tempGaugeMeta;
                            config.configExtra['gaugeMostrarFaixas'] =
                                tempGaugeRanges;
                            config.configExtra['prefixo'] = tempKpiPrefixo;
                            config.configExtra['sufixo'] = tempKpiSufixo;
                            config.configExtra['decimais'] = tempKpiDecimais;
                            config.configExtra['kpiFontSize'] = tempKpiFontSize;
                            config.configExtra['kpiShowMeta'] = tempKpiShowMeta;
                            config.configExtra['kpiMeta'] = tempKpiMeta;
                            config.configExtra['kpiShowTrend'] =
                                tempKpiShowTrend;
                            config.configExtra['kpiPrevious'] = tempKpiPrevious;
                            config.configExtra['corPrincipal'] =
                                tempCorPrincipal.value.toString();
                            config.configExtra['corMetricaPrincipal'] =
                                tempCorMetricaPrincipal.value.toString();
                            config.configExtra['corMetricaSecundaria'] =
                                tempCorMetricaSecundaria.value.toString();
                            config.configExtra['metricColorMode'] =
                                tempMetricColorMode;
                            config.configExtra['secondaryScaleMode'] =
                                tempSecondaryScaleMode;
                            config.configExtra['barColor'] =
                                tempCorMetricaPrincipal.value.toString();
                            config.configExtra['stackColor'] =
                                tempCorMetricaSecundaria.value.toString();
                            config.configExtra['markerColor'] =
                                tempCorMetricaPrincipal.value.toString();
                            config.configExtra['headerColor'] = tempHeaderTabela
                                .value
                                .toString();
                            config.configExtra['totalColor'] = tempTotalTabela
                                .value
                                .toString();
                            config.configExtra['rowColorA'] = tempRowColorA
                                .value
                                .toString();
                            config.configExtra['rowColorB'] = tempRowColorB
                                .value
                                .toString();
                            config.configExtra['gridColor'] = tempGridColor
                                .value
                                .toString();
                            config.configExtra['rowHeight'] = tempRowHeight;
                            config.configExtra['chipRadius'] = tempChipRadius;
                            config.configExtra['segmentacaoMultipla'] =
                                tempSegmentacaoMultipla;
                            config.configExtra['slicerStyle'] = tempSlicerStyle;
                            config.configExtra['slicerSearch'] =
                                tempSlicerSearch;
                            config.configExtra['treemapSpacing'] =
                                tempTreemapSpacing;
                            config.configExtra['tooltipEnabled'] =
                                tempTooltipAtivo;
                            config.configExtra['interactionFilter'] =
                                tempInteracaoFiltrar;
                            config.configExtra['interactionHighlight'] =
                                tempInteracaoDestacar;
                            config.configExtra['interactionDrillthrough'] =
                                tempDrillthrough;
                            config.configExtra['interactionNavigation'] =
                                tempNavegacao;
                            config.configExtra['animationIn'] =
                                tempAnimationEntrada;
                            config.configExtra['animationUpdate'] =
                                tempAnimationUpdate;
                            config.configExtra['exportPng'] = tempExportPng;
                            config.configExtra['exportPdf'] = tempExportPdf;
                            config.configExtra['exportCsv'] = tempExportCsv;
                            config.configExtra['exportExcel'] = tempExportExcel;
                            config.configExtra['themePreset'] = tempThemePreset;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Aplicar configuracoes"),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      tituloController.dispose();
      subtituloController.dispose();
      descricaoController.dispose();
    });
  }

  Widget _botaoCor(
    Color corAtual,
    Color novaCor,
    StateSetter setModalState,
    Function(Color) onSelect,
  ) {
    return GestureDetector(
      onTap: () => setModalState(() => onSelect(novaCor)),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: novaCor,
          shape: BoxShape.circle,
          border: Border.all(
            color: corAtual == novaCor
                ? const Color(0xFF2563EB)
                : Colors.grey.shade300,
            width: corAtual == novaCor ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Color _corConfig(dynamic value, Color fallback) {
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return Color(parsed);
      if (value.startsWith('#')) {
        return Color(int.parse(value.replaceFirst('#', '0xFF')));
      }
    }
    return fallback;
  }

  List<dynamic> get _dadosBrutosAtuais =>
      DashboardManager.dadosFonteAtual?['dados_brutos'] ??
      DashboardManager.dadosFonteAtual?['dados_planilha']?['dados_brutos'] ??
      [];

  List<Map<String, dynamic>> _calcularDadosFiltrados(ChartConfig config) {
    final dadosBrutos = _dadosBrutosAtuais;
    if (dadosBrutos.isEmpty || _filtrosSegmentacao.isEmpty) {
      return config.dados;
    }

    final linhasFiltradas = dadosBrutos.where((linha) {
      if (linha is! Map) return false;
      for (final filtro in _filtrosSegmentacao.entries) {
        if (filtro.value.isEmpty) continue;
        final valor = linha[filtro.key]?.toString() ?? '';
        if (!filtro.value.contains(valor)) return false;
      }
      return true;
    });

    final agrupamento = <String, List<double>>{};
    for (final linha in linhasFiltradas) {
      if (linha is! Map) continue;
      final chave = linha[config.dimensao]?.toString().trim().isNotEmpty == true
          ? linha[config.dimensao].toString()
          : 'Desconhecido';
      final raw = linha[config.metrica];
      final valor = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '.')) ?? 0.0;
      agrupamento.putIfAbsent(chave, () => []).add(valor);
    }

    final paleta = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFF64748B),
    ];

    final agregacao = config.configExtra['agregacao']?.toString() ?? 'Soma';
    final ordenarDesc = config.configExtra['ordenarDesc'] as bool? ?? true;
    final limite =
        ((config.configExtra['limiteItens'] ?? config.dados.length) as num)
            .round();

    final dados = agrupamento.entries.map((entry) {
      final valores = entry.value;
      final soma = valores.fold<double>(0, (total, valor) => total + valor);
      final valor = switch (agregacao) {
        'Media' => soma / valores.length,
        'Contagem' => valores.length.toDouble(),
        'Maximo' => valores.reduce((a, b) => a > b ? a : b),
        'Minimo' => valores.reduce((a, b) => a < b ? a : b),
        _ => soma,
      };
      final index = agrupamento.keys.toList().indexOf(entry.key);
      return {
        'label': entry.key,
        'value': valor,
        'color': paleta[index % paleta.length],
      };
    }).toList();

    dados.sort((a, b) {
      final valorA = (a['value'] as num).toDouble();
      final valorB = (b['value'] as num).toDouble();
      return ordenarDesc ? valorB.compareTo(valorA) : valorA.compareTo(valorB);
    });

    return dados.take(limite <= 0 ? dados.length : limite).toList();
  }

  ChartConfig _configVisual(ChartConfig config) {
    final tipo = config.tipo.toLowerCase();
    if (tipo.contains('segment')) return config;
    final dados = _calcularDadosFiltrados(config);
    return ChartConfig(
      id: config.id,
      tipo: config.tipo,
      titulo: config.titulo,
      dimensao: config.dimensao,
      metrica: config.metrica,
      dados: dados,
      posicao: config.posicao,
      tamanho: config.tamanho,
      corFundo: config.corFundo,
      fontSizeTitulo: config.fontSizeTitulo,
      alinhamentoTitulo: config.alinhamentoTitulo,
      corTextoTitulo: config.corTextoTitulo,
      raioBorda: config.raioBorda,
      mostrarSombra: config.mostrarSombra,
      mostrarEixos: config.mostrarEixos,
      mostrarLegenda: config.mostrarLegenda,
      posicaoLegenda: config.posicaoLegenda,
      mostrarValores: config.mostrarValores,
      mostrarRotulos: config.mostrarRotulos,
      configExtra: Map<String, dynamic>.from(config.configExtra),
    );
  }

  bool _tipoUsaLegenda(String tipo) {
    final t = tipo.toLowerCase();
    return !(t.contains('cartao') ||
        t.contains('kpi') ||
        t.contains('tabela') ||
        t.contains('segment') ||
        t.contains('gauge') ||
        t.contains('treemap'));
  }

  Widget _buildConteudoComLegenda(ChartConfig config) {
    final visualConfig = _configVisual(config);
    final tipo = config.tipo.toLowerCase();
    Widget chartWidget = ChartRenderer(
      config: visualConfig,
      filtrosSelecionados: _filtrosSegmentacao[config.dimensao],
      onSegmentacaoChanged: tipo.contains('segment')
          ? (selecionados) => setState(() {
              if (selecionados.isEmpty) {
                _filtrosSegmentacao.remove(config.dimensao);
              } else {
                _filtrosSegmentacao[config.dimensao] = selecionados;
              }
            })
          : null,
    );

    if (!_tipoUsaLegenda(config.tipo) ||
        !visualConfig.mostrarLegenda ||
        visualConfig.dados.isEmpty) {
      return chartWidget;
    }

    Widget legenda = Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      direction:
          (config.posicaoLegenda == 'left' || config.posicaoLegenda == 'right')
          ? Axis.vertical
          : Axis.horizontal,
      children: visualConfig.dados
          .map(
            (d) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  color: _converterCor(d['color']),
                  margin: const EdgeInsets.only(right: 4),
                ),
                Text(
                  d['label'].toString().length > 12
                      ? '${d['label'].toString().substring(0, 12)}...'
                      : d['label'].toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          )
          .toList(),
    );

    Widget safeLegenda = Container(
      constraints: BoxConstraints(
        maxHeight:
            (config.posicaoLegenda == 'top' ||
                config.posicaoLegenda == 'bottom')
            ? 60
            : double.infinity,
        maxWidth:
            (config.posicaoLegenda == 'left' ||
                config.posicaoLegenda == 'right')
            ? 100
            : double.infinity,
      ),
      child: SingleChildScrollView(
        scrollDirection:
            (config.posicaoLegenda == 'left' ||
                config.posicaoLegenda == 'right')
            ? Axis.vertical
            : Axis.horizontal,
        child: legenda,
      ),
    );

    if (config.posicaoLegenda == 'top')
      return Column(
        children: [
          safeLegenda,
          const SizedBox(height: 8),
          Expanded(child: chartWidget),
        ],
      );
    if (config.posicaoLegenda == 'bottom')
      return Column(
        children: [
          Expanded(child: chartWidget),
          const SizedBox(height: 8),
          safeLegenda,
        ],
      );
    if (config.posicaoLegenda == 'left')
      return Row(
        children: [
          safeLegenda,
          const SizedBox(width: 8),
          Expanded(child: chartWidget),
        ],
      );
    if (config.posicaoLegenda == 'right')
      return Row(
        children: [
          Expanded(child: chartWidget),
          const SizedBox(width: 8),
          safeLegenda,
        ],
      );

    return chartWidget;
  }

  Widget _buildResizableDraggableChart(ChartConfig config) {
    TextAlign alignTitulo = TextAlign.left;
    if (config.alinhamentoTitulo == 'center') alignTitulo = TextAlign.center;
    if (config.alinhamentoTitulo == 'right') alignTitulo = TextAlign.right;

    // 1. APAGUE a variÃ¡vel "Offset posicaoToque = Offset.zero;" que ficava aqui
    const double espessuraBorda = 12.0;
    final minWidth = ((config.configExtra['minWidth'] ?? 200) as num)
        .toDouble();
    final minHeight = ((config.configExtra['minHeight'] ?? 200) as num)
        .toDouble();
    final contentPadding = ((config.configExtra['contentPadding'] ?? 8) as num)
        .toDouble();
    final borderWidth = ((config.configExtra['borderWidth'] ?? 1) as num)
        .toDouble();
    final showTitle = config.configExtra['showTitle'] as bool? ?? true;
    final showSubtitle = config.configExtra['showSubtitle'] as bool? ?? false;
    final subtitleText = config.configExtra['subtitleText']?.toString() ?? '';
    final subtitleColor = _corConfig(
      config.configExtra['subtitleColor'],
      const Color(0xFF64748B),
    );
    final subtitleSize = ((config.configExtra['subtitleSize'] ?? 12) as num)
        .toDouble();
    final borderVisible = config.configExtra['borderVisible'] as bool? ?? true;
    final borderColor = _corConfig(
      config.configExtra['borderColor'],
      Colors.blueGrey.shade100,
    );
    final bgOpacity = ((config.configExtra['backgroundOpacity'] ?? 1) as num)
        .toDouble();
    final shadowOpacity = ((config.configExtra['shadowOpacity'] ?? 0.12) as num)
        .toDouble();
    final showHeader = showTitle || (showSubtitle && subtitleText.isNotEmpty);

    return SizedBox(
      width: config.tamanho.width,
      height: config.tamanho.height,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // 2. Mude o onTapDown apenas para trazer para frente
                onTapDown: _modoApresentacao
                    ? null
                    : (_) {
                        _trazerParaFrente(config);
                      },
                // 3. Use o onLongPressStart (ele captura os detalhes da posiÃ§Ã£o do clique longo)
                onLongPressStart: _modoApresentacao
                    ? null
                    : (details) {
                        _mostrarMenuContexto(
                          context,
                          config,
                          details.globalPosition,
                        );
                      },
                child: Card(
                  color: config.corFundo.withValues(alpha: bgOpacity),
                  elevation: config.mostrarSombra ? 2 : 0,
                  shadowColor: Colors.black.withValues(alpha: shadowOpacity),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      config.raioBorda,
                    ), // Bordas mais modernas
                    side: BorderSide(
                      color: borderVisible ? borderColor : Colors.transparent,
                      width: borderVisible ? borderWidth : 0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CABEÃ‡ALHO DISCRETO
                      if (showHeader)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: config.corFundo, // Fundo igual ao card
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.blueGrey.shade50,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onPanStart: (_) => _trazerParaFrente(
                                  config,
                                ), // <--- TrÃ¡s para frente ao comeÃ§ar arrastar
                                onPanUpdate: (details) => setState(
                                  () => config.posicao += details.delta,
                                ),
                                onPanEnd: (_) => setState(
                                  () => config.posicao = Offset(
                                    _snap(config.posicao.dx),
                                    _snap(config.posicao.dy),
                                  ),
                                ),
                                // Ãcone de arraste super discreto e com cor suave
                                child: const MouseRegion(
                                  cursor: SystemMouseCursors.move,
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 16,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onPanStart: (_) => _trazerParaFrente(config),
                                  onPanUpdate: (details) => setState(
                                    () => config.posicao += details.delta,
                                  ),
                                  onPanEnd: (_) => setState(
                                    () => config.posicao = Offset(
                                      _snap(config.posicao.dx),
                                      _snap(config.posicao.dy),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showTitle)
                                        Text(
                                          config.titulo,
                                          textAlign: alignTitulo,
                                          style: TextStyle(
                                            fontWeight:
                                                (config.configExtra['titleBold']
                                                        as bool? ??
                                                    true)
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            fontStyle:
                                                (config.configExtra['titleItalic']
                                                        as bool? ??
                                                    false)
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            decoration:
                                                (config.configExtra['titleUnderline']
                                                        as bool? ??
                                                    false)
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                            fontSize: config.fontSizeTitulo,
                                            color: config.corTextoTitulo,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (showSubtitle &&
                                          subtitleText.isNotEmpty)
                                        Text(
                                          subtitleText,
                                          textAlign: alignTitulo,
                                          style: TextStyle(
                                            fontSize: subtitleSize,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(contentPadding),
                          child: _buildConteudoComLegenda(config),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CONTROLES DE REDIMENSIONAMENTO INVISÃVEIS (Bordas)
            // Leste
            if (!_modoApresentacao)
              Align(
                alignment: Alignment.centerRight,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onPanStart: (_) => _trazerParaFrente(config),
                    onPanUpdate: (details) => setState(() {
                      double novaLargura =
                          config.tamanho.width + details.delta.dx;
                      if (novaLargura >= minWidth)
                        config.tamanho = Size(
                          novaLargura,
                          config.tamanho.height,
                        );
                    }),
                    onPanEnd: (_) => setState(
                      () => config.tamanho = Size(
                        _snap(config.tamanho.width),
                        config.tamanho.height,
                      ),
                    ),
                    child: Container(
                      width: espessuraBorda,
                      height: double.infinity,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // Oeste
            if (!_modoApresentacao)
              Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onPanStart: (_) => _trazerParaFrente(config),
                    onPanUpdate: (details) => setState(() {
                      double novaLargura =
                          config.tamanho.width - details.delta.dx;
                      if (novaLargura >= minWidth) {
                        config.posicao = Offset(
                          config.posicao.dx + details.delta.dx,
                          config.posicao.dy,
                        );
                        config.tamanho = Size(
                          novaLargura,
                          config.tamanho.height,
                        );
                      }
                    }),
                    onPanEnd: (_) => setState(() {
                      config.posicao = Offset(
                        _snap(config.posicao.dx),
                        config.posicao.dy,
                      );
                      config.tamanho = Size(
                        _snap(config.tamanho.width),
                        config.tamanho.height,
                      );
                    }),
                    child: Container(
                      width: espessuraBorda,
                      height: double.infinity,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // Sul
            if (!_modoApresentacao)
              Align(
                alignment: Alignment.bottomCenter,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    onPanStart: (_) => _trazerParaFrente(config),
                    onPanUpdate: (details) => setState(() {
                      double novaAltura =
                          config.tamanho.height + details.delta.dy;
                      if (novaAltura >= minHeight)
                        config.tamanho = Size(config.tamanho.width, novaAltura);
                    }),
                    onPanEnd: (_) => setState(
                      () => config.tamanho = Size(
                        config.tamanho.width,
                        _snap(config.tamanho.height),
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: espessuraBorda,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // Norte
            if (!_modoApresentacao)
              Align(
                alignment: Alignment.topCenter,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: GestureDetector(
                    onPanStart: (_) => _trazerParaFrente(config),
                    onPanUpdate: (details) => setState(() {
                      double novaAltura =
                          config.tamanho.height - details.delta.dy;
                      if (novaAltura >= minHeight) {
                        config.posicao = Offset(
                          config.posicao.dx,
                          config.posicao.dy + details.delta.dy,
                        );
                        config.tamanho = Size(config.tamanho.width, novaAltura);
                      }
                    }),
                    onPanEnd: (_) => setState(() {
                      config.posicao = Offset(
                        config.posicao.dx,
                        _snap(config.posicao.dy),
                      );
                      config.tamanho = Size(
                        config.tamanho.width,
                        _snap(config.tamanho.height),
                      );
                    }),
                    child: Container(
                      width: double.infinity,
                      height: espessuraBorda,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

            // Sudeste (Canto inferior direito com indicativo visual)
            if (!_modoApresentacao)
              Align(
                alignment: Alignment.bottomRight,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: GestureDetector(
                    onPanStart: (_) => _trazerParaFrente(config),
                    onPanUpdate: (details) => setState(() {
                      double novaLargura =
                          config.tamanho.width + details.delta.dx;
                      double novaAltura =
                          config.tamanho.height + details.delta.dy;
                      config.tamanho = Size(
                        novaLargura > minWidth ? novaLargura : minWidth,
                        novaAltura > minHeight ? novaAltura : minHeight,
                      );
                    }),
                    onPanEnd: (_) => setState(() {
                      config.tamanho = Size(
                        _snap(config.tamanho.width),
                        _snap(config.tamanho.height),
                      );
                    }),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      // Detalhe visual elegante indicando que ali redimensiona
                      child: const Center(
                        child: Icon(
                          Icons.signal_cellular_4_bar_rounded,
                          size: 14,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _converterCor(dynamic corOrigem) {
    if (corOrigem is Color) return corOrigem;
    if (corOrigem is String) {
      if (corOrigem.startsWith('#'))
        return Color(int.parse(corOrigem.replaceFirst('#', '0xFF')));
      int? valorNumerico = int.tryParse(corOrigem);
      if (valorNumerico != null) return Color(valorNumerico);
    }
    if (corOrigem is int) return Color(corOrigem);
    return Colors.blueAccent;
  }
}
