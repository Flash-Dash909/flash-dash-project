import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/api_config.dart';
import '../../../core/calculated_metric.dart';
import '../../../core/download_service.dart';
import '../../../core/presentation_fullscreen.dart';
import '../../../core/visual_config.dart';
import '../../../core/widgets/app_logo.dart';
import '../dashboard_manager.dart';
import '../widgets/chart_renderer.dart';
import '../widgets/power_bi_format_panel.dart';
import 'dashboard_data_screen.dart';
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
  final Map<String, Set<String>> _selecoesVisuais = {};
  bool _isChatLoading = false;
  bool _modoApresentacao = false;
  bool _snapAtivo = false;
  bool _arrastandoVisual = false;
  final GlobalKey _dashboardBoundaryKey = GlobalKey();
  final TransformationController _canvasController = TransformationController();
  Size? _lastCanvasViewport;

  Future<Uint8List> _capturarDashboard() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _dashboardBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Dashboard ainda nao esta pronto.');
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('Nao foi possivel gerar a imagem.');
    return data.buffer.asUint8List();
  }

  Future<void> _exportarDashboardImagem(String formato) async {
    try {
      final png = await _capturarDashboard();
      if (formato == 'png') {
        await DownloadService.save(
          bytes: png,
          name: 'flash_dash_dashboard',
          extension: 'png',
          mimeType: 'image/png',
        );
      } else {
        final document = pw.Document();
        document.addPage(
          pw.Page(
            pageFormat: const PdfPageFormat(_dashboardWidth, _dashboardHeight),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        );
        await DownloadService.save(
          bytes: await document.save(),
          name: 'flash_dash_dashboard',
          extension: 'pdf',
          mimeType: 'application/pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao exportar: $e')));
      }
    }
  }

  Future<void> _exportarDadosDashboard(String formato) async {
    final dashboardId = DashboardManager.dashboardAtualId;
    if (dashboardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salve o dashboard antes de exportar os dados.'),
        ),
      );
      return;
    }
    final query = <String, String>{'formato': formato};
    final usuarioId = DashboardManager.usuarioAtualId;
    if (usuarioId != null) query['usuario_id'] = usuarioId;
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/dashboards/$dashboardId/exportar',
      ).replace(queryParameters: query),
      headers: DashboardManager.authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Nao foi possivel exportar os dados.');
    }
    final ext = formato == 'json' ? 'json' : 'xlsx';
    await DownloadService.save(
      bytes: Uint8List.fromList(response.bodyBytes),
      name: 'flash_dash_dashboard',
      extension: ext,
      mimeType: ext == 'json'
          ? 'application/json'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // ==========================================
  // Snap magnetico da grade.
  // ==========================================
  double _snap(double value) {
    const double gridSize = 20.0;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  void _limitarGeometriaDoVisual(
    ChartConfig config, {
    bool aplicarSnap = false,
  }) {
    final minWidth = ((config.configExtra['minWidth'] ?? 200) as num)
        .toDouble()
        .clamp(80.0, _dashboardWidth);
    final minHeight = ((config.configExtra['minHeight'] ?? 200) as num)
        .toDouble()
        .clamp(80.0, _dashboardHeight);
    var width = config.tamanho.width;
    var height = config.tamanho.height;
    var x = config.posicao.dx;
    var y = config.posicao.dy;

    if (aplicarSnap && _snapAtivo) {
      width = _snap(width);
      height = _snap(height);
      x = _snap(x);
      y = _snap(y);
    }

    width = width.clamp(minWidth, _dashboardWidth);
    height = height.clamp(minHeight, _dashboardHeight);
    x = x.clamp(0.0, math.max(0.0, _dashboardWidth - width));
    y = y.clamp(0.0, math.max(0.0, _dashboardHeight - height));
    config.tamanho = Size(width, height);
    config.posicao = Offset(x, y);
  }

  List<String> _fonteIdsAtuais() {
    final data = DashboardManager.dadosFonteAtual;
    if (data == null) return const [];
    final ids = <String>{};
    ids.addAll(DashboardManager.fonteIdsDashboard);
    final source = data['fonte'];
    if (source is Map && source['id'] != null) {
      ids.add(source['id'].toString());
    }
    final summaryRaw = data['dados_planilha']?['summary'] ?? data['summary'];
    if (summaryRaw is Map && summaryRaw['fontes_origem'] is List) {
      ids.addAll(
        (summaryRaw['fontes_origem'] as List)
            .where((item) => item != null)
            .map((item) => item.toString()),
      );
    }
    return ids.toList();
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
      setState(() {
        DashboardManager.graficosAtivos.remove(config);
        _selecoesVisuais.remove(config.id);
      });
    }
  }

  @override
  void dispose() {
    if (_modoApresentacao) {
      unawaited(PresentationFullscreen.exit());
    }
    _canvasController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _definirModoApresentacao(bool ativo) async {
    try {
      if (ativo) {
        await PresentationFullscreen.enter();
      } else {
        await PresentationFullscreen.exit();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ativo
                  ? 'O navegador bloqueou a tela cheia. Tente novamente.'
                  : 'Nao foi possivel sair da tela cheia: $error',
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() => _modoApresentacao = ativo);
  }

  Future<void> _abrirDadosDashboard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DashboardDataScreen()),
    );
    if (mounted) setState(() {});
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
                  final configJson = <Map<String, dynamic>>[
                    {
                      "id": "__dashboard_meta__",
                      "tipo": "__dashboard_meta__",
                      "paginas_dashboard": DashboardManager.paginasDashboard,
                      "pagina_atual": DashboardManager.paginaAtual,
                    },
                    ...DashboardManager.graficosAtivos.map(
                      (g) => <String, dynamic>{
                        "id": g.id,
                        "tipo": g.tipo,
                        "titulo": g.titulo,
                        "dimensao": g.dimensao,
                        "metrica": g.metrica,
                        "pagina": g.pagina,
                        "dados": g.dados
                            .map(
                              (d) => {
                                "label": d["label"],
                                if (d.containsKey("secondaryLabel"))
                                  "secondaryLabel": d["secondaryLabel"],
                                "value": d["value"],
                                if (d.containsKey("value2"))
                                  "value2": d["value2"],
                                if (d["seriesValues"] is Map)
                                  "seriesValues": Map<String, dynamic>.from(
                                    d["seriesValues"] as Map,
                                  ),
                                "color": d["color"] is Color
                                    ? (d["color"] as Color)
                                          .toARGB32()
                                          .toString()
                                    : d["color"].toString(),
                              },
                            )
                            .toList(),
                        "posicao_x": g.posicao.dx,
                        "posicao_y": g.posicao.dy,
                        "largura": g.tamanho.width,
                        "altura": g.tamanho.height,
                        "cor_fundo": g.corFundo.toARGB32().toString(),
                        "mostrar_legenda": g.mostrarLegenda,
                        "posicao_legenda": g.posicaoLegenda,
                        "config_extra": g.configExtra,
                        "font_size_titulo": g.fontSizeTitulo,
                        "alinhamento_titulo": g.alinhamentoTitulo,
                        "cor_texto_titulo": g.corTextoTitulo
                            .toARGB32()
                            .toString(),
                        "raio_borda": g.raioBorda,
                        "mostrar_sombra": g.mostrarSombra,
                        "mostrar_eixos": g.mostrarEixos,
                        "mostrar_valores": g.mostrarValores,
                        "mostrar_rotulos": g.mostrarRotulos,
                      },
                    ),
                  ];

                  try {
                    var response = await http.post(
                      Uri.parse('${ApiConfig.baseUrl}/salvar-dashboard'),
                      headers: {
                        "Content-Type": "application/json",
                        ...DashboardManager.authHeaders,
                      },
                      body: json.encode({
                        "dashboard_id": DashboardManager.dashboardAtualId,
                        "titulo": nomeController.text,
                        "graficos_config": configJson,
                        "metricas_calculadas": DashboardManager
                            .metricasCalculadas
                            .values
                            .map((metric) => metric.toJson())
                            .toList(),
                        "fonte_ids": _fonteIdsAtuais(),
                        "usuario_id": DashboardManager.usuarioAtualId,
                      }),
                    );

                    if (response.statusCode == 200) {
                      final body = json.decode(utf8.decode(response.bodyBytes));
                      final savedDashboard = body is Map
                          ? body['dashboard']
                          : null;
                      if (savedDashboard is Map &&
                          savedDashboard['id'] != null) {
                        DashboardManager.dashboardAtualId = savedDashboard['id']
                            .toString();
                      }
                      if (!mounted || !dialogContext.mounted) return;
                      DashboardManager.graficosAtivos.clear();
                      DashboardManager.metricasCalculadas.clear();
                      DashboardManager.limparFontesDashboard();
                      DashboardManager.resetarPaginas();
                      Navigator.pop(dialogContext);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    } else {
                      final body = json.decode(utf8.decode(response.bodyBytes));
                      final message = body is Map
                          ? (body['detail'] ?? body['message'])?.toString()
                          : null;
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            message ?? 'Nao foi possivel salvar o dashboard.',
                          ),
                        ),
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
      DashboardManager.metricasCalculadas.clear();
      DashboardManager.limparFontesDashboard();
      DashboardManager.resetarPaginas();
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
        Uri.parse("${ApiConfig.baseUrl}/dashboards/$dashboardId"),
        headers: DashboardManager.authHeaders,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        DashboardManager.graficosAtivos.clear();
        DashboardManager.metricasCalculadas.clear();
        DashboardManager.limparFontesDashboard();
        DashboardManager.resetarPaginas();
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
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
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
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: isUser
                                    ? null
                                    : Border.all(color: scheme.outlineVariant),
                              ),
                              child: Text(
                                _mensagensChat[index]['texto']!,
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : scheme.onSurface,
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
      var uri = Uri.parse('${ApiConfig.baseUrl}/chat-ia');
      var response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              ...DashboardManager.authHeaders,
            },
            body: json.encode({
              "mensagem": pergunta,
              "contexto_dashboard": contextoDashboard,
            }),
          )
          .timeout(const Duration(seconds: 50));

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        setModalState(() {
          _mensagensChat.add({'remetente': 'ia', 'texto': data['resposta']});
          _isChatLoading = false;
        });
      } else {
        throw Exception("Erro servidor: ${response.statusCode}");
      }
    } on TimeoutException {
      setModalState(() {
        _mensagensChat.add({
          'remetente': 'ia',
          'texto':
              'A IA demorou mais que o esperado. Tente novamente em alguns segundos.',
        });
        _isChatLoading = false;
      });
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
    if (DashboardManager.graficosAtivos.isNotEmpty &&
        identical(DashboardManager.graficosAtivos.last, config)) {
      return;
    }
    setState(() {
      DashboardManager.graficosAtivos.remove(config);
      DashboardManager.graficosAtivos.add(config);
    });
  }

  void _iniciarArrasteVisual(ChartConfig config) {
    _trazerParaFrente(config);
    if (!_arrastandoVisual) setState(() => _arrastandoVisual = true);
  }

  void _moverVisual(ChartConfig config, DragUpdateDetails details) {
    final delta = _deltaNoCanvas(details);
    setState(() => config.posicao += delta);
  }

  Offset _deltaNoCanvas(DragUpdateDetails details) {
    final escala = _canvasController.value.getMaxScaleOnAxis();
    final fator = escala <= 0 ? 1.0 : escala;
    return details.delta / fator;
  }

  void _finalizarArrasteVisual(ChartConfig config) {
    setState(() {
      _arrastandoVisual = false;
      _limitarGeometriaDoVisual(config, aplicarSnap: true);
    });
  }

  void _abrirVisualEmFoco(ChartConfig config) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        return Dialog(
          insetPadding: EdgeInsets.all(size.width < 700 ? 12 : 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1100,
              maxHeight: size.height * 0.9,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          config.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar modo de foco',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_fullscreen_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: _buildConteudoComLegenda(config),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copiarCsvDoVisual(ChartConfig config) async {
    final buffer = StringBuffer()
      ..writeln(
        '${config.dimensao},${config.metrica}${config.configExtra['metricaSecundaria'] != null ? ',${config.configExtra['metricaSecundaria']}' : ''}',
      );
    for (final item in _configVisual(config).dados) {
      final label = item['label'].toString().replaceAll('"', '""');
      buffer.write('"$label",${item['value']}');
      if (item.containsKey('value2')) buffer.write(',${item['value2']}');
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados CSV copiados para a area de transferencia.'),
      ),
    );
  }

  void _alternarOrdenacaoVisual(ChartConfig config) {
    setState(() {
      final current =
          config.configExtra['categorySort']?.toString() ?? 'valueDesc';
      config.configExtra['categorySort'] = switch (current) {
        'valueDesc' => 'valueAsc',
        'valueAsc' => 'categoryAsc',
        'categoryAsc' => 'categoryDesc',
        _ => 'valueDesc',
      };
      final data = config.dados;
      final mode = config.configExtra['categorySort'];
      data.sort((a, b) {
        if (mode == 'categoryAsc' || mode == 'categoryDesc') {
          final comparison = a['label'].toString().compareTo(
            b['label'].toString(),
          );
          return mode == 'categoryDesc' ? -comparison : comparison;
        }
        final aValue = ((a['value'] ?? 0) as num).toDouble();
        final bValue = ((b['value'] ?? 0) as num).toDouble();
        return mode == 'valueAsc'
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    });
  }

  void _mudarPagina(int pagina) {
    final limite = DashboardManager.paginasDashboard.length - 1;
    final destino = pagina.clamp(0, limite).toInt();
    if (destino == DashboardManager.paginaAtual) return;
    setState(() {
      DashboardManager.paginaAtual = destino;
      _selecoesVisuais.clear();
    });
  }

  void _adicionarPagina() {
    setState(() {
      DashboardManager.paginasDashboard.add(
        'Pagina ${DashboardManager.paginasDashboard.length + 1}',
      );
      DashboardManager.paginaAtual =
          DashboardManager.paginasDashboard.length - 1;
      _selecoesVisuais.clear();
    });
  }

  Future<void> _renomearPaginaAtual() async {
    final controller = TextEditingController(
      text: DashboardManager.nomePaginaAtual,
    );
    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear pagina'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nome da pagina'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || nome == null || nome.isEmpty) return;
    setState(() {
      DashboardManager.paginasDashboard[DashboardManager.paginaAtual] = nome;
    });
  }

  Future<void> _excluirPaginaAtual() async {
    if (DashboardManager.paginasDashboard.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O dashboard precisa ter uma pagina.')),
      );
      return;
    }
    final pagina = DashboardManager.paginaAtual;
    final quantidade = DashboardManager.graficosAtivos
        .where((grafico) => grafico.pagina == pagina)
        .length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pagina'),
        content: Text(
          quantidade == 0
              ? 'Deseja excluir esta pagina?'
              : 'Esta pagina possui $quantidade visual(is). Deseja exclui-la por completo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    setState(() {
      final removidos = DashboardManager.graficosAtivos
          .where((grafico) => grafico.pagina == pagina)
          .map((grafico) => grafico.id)
          .toSet();
      DashboardManager.graficosAtivos.removeWhere(
        (grafico) => grafico.pagina == pagina,
      );
      for (final grafico in DashboardManager.graficosAtivos) {
        if (grafico.pagina > pagina) grafico.pagina -= 1;
      }
      for (final id in removidos) {
        _selecoesVisuais.remove(id);
      }
      DashboardManager.paginasDashboard.removeAt(pagina);
      DashboardManager.paginaAtual = pagina
          .clamp(0, DashboardManager.paginasDashboard.length - 1)
          .toInt();
    });
  }

  Widget _buildNavegacaoPaginas() {
    final paginas = DashboardManager.paginasDashboard;
    final atual = DashboardManager.paginaAtual;
    final theme = Theme.of(context);
    final compacto = MediaQuery.sizeOf(context).width < 600;
    final foreground = _modoApresentacao
        ? Colors.white
        : theme.colorScheme.onSurface;
    final background = _modoApresentacao
        ? Colors.black.withValues(alpha: 0.72)
        : theme.colorScheme.surface.withValues(alpha: 0.94);

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: background,
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Pagina anterior',
                onPressed: atual > 0 ? () => _mudarPagina(atual - 1) : null,
                color: foreground,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              PopupMenuButton<int>(
                tooltip: 'Ir para pagina',
                onSelected: _mudarPagina,
                itemBuilder: (context) => [
                  for (var index = 0; index < paginas.length; index++)
                    PopupMenuItem(
                      value: index,
                      child: Row(
                        children: [
                          if (index == atual)
                            const Icon(Icons.check_rounded, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Flexible(child: Text(paginas[index])),
                        ],
                      ),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compacto
                        ? math.max(80, MediaQuery.sizeOf(context).width - 200)
                        : 220,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${paginas[atual]}  ${atual + 1}/${paginas.length}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Proxima pagina',
                onPressed: atual < paginas.length - 1
                    ? () => _mudarPagina(atual + 1)
                    : null,
                color: foreground,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (!_modoApresentacao) ...[
                if (!compacto) ...[
                  const SizedBox(width: 2),
                  Container(
                    width: 1,
                    height: 24,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  IconButton(
                    tooltip: 'Adicionar pagina',
                    onPressed: _adicionarPagina,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
                PopupMenuButton<String>(
                  tooltip: 'Opcoes da pagina',
                  onSelected: (value) {
                    if (value == 'adicionar') _adicionarPagina();
                    if (value == 'renomear') _renomearPaginaAtual();
                    if (value == 'excluir') _excluirPaginaAtual();
                  },
                  itemBuilder: (context) => [
                    if (compacto)
                      const PopupMenuItem(
                        value: 'adicionar',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.add_rounded),
                          title: Text('Adicionar pagina'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'renomear',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Renomear pagina'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'excluir',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                        title: Text('Excluir pagina'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _modoApresentacao
          ? null
          : AppBar(
              title: Text(
                isDesktop ? 'Area de Trabalho' : 'Dashboard',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              elevation: 1,
              shadowColor: Colors.black12,
              actions: [
                if (isDesktop)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: AppLogo(size: 30, opacity: 0.72),
                  ),
                IconButton(
                  icon: const Icon(Icons.dataset_linked_outlined),
                  onPressed: _abrirDadosDashboard,
                  tooltip: 'Dados e fontes do dashboard',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.save_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  onPressed: _salvarDashboard,
                  tooltip: "Salvar",
                ),
                if (isDesktop) ...[
                  IconButton(
                    icon: const Icon(Icons.slideshow_rounded),
                    onPressed: () => _definirModoApresentacao(true),
                    tooltip: "Modo apresentacao",
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.grid_4x4_rounded,
                      color: _snapAtivo ? const Color(0xFF2563EB) : null,
                    ),
                    onPressed: () => setState(() => _snapAtivo = !_snapAtivo),
                    tooltip: _snapAtivo
                        ? "Desativar encaixe na grade"
                        : "Ativar encaixe na grade",
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                    onPressed: _abrirChatIA,
                    tooltip: "Chat com a IA",
                  ),
                ],
                PopupMenuButton<String>(
                  tooltip: "Mais opcoes",
                  onSelected: (value) {
                    if (value == 'apresentar') {
                      _definirModoApresentacao(true);
                    }
                    if (value == 'snap') {
                      setState(() => _snapAtivo = !_snapAtivo);
                    }
                    if (value == 'ia') _abrirChatIA();
                    if (value == 'excluir') _excluirDashboardAtual();
                    if (value == 'atualizar') setState(() {});
                    if (value == 'png' || value == 'pdf') {
                      _exportarDashboardImagem(value);
                    }
                    if (value == 'xlsx' || value == 'json') {
                      final messenger = ScaffoldMessenger.of(context);
                      _exportarDadosDashboard(value).catchError((e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Falha ao exportar: $e')),
                          );
                        }
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isDesktop) ...[
                      const PopupMenuItem(
                        value: 'apresentar',
                        child: ListTile(
                          leading: Icon(Icons.slideshow_rounded),
                          title: Text('Modo apresentacao'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'ia',
                        child: ListTile(
                          leading: Icon(Icons.auto_awesome),
                          title: Text('Chat com a IA'),
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'atualizar',
                      child: Text('Atualizar layout'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'snap',
                      checked: _snapAtivo,
                      child: const Text('Encaixe na grade'),
                    ),
                    const PopupMenuItem(
                      value: 'png',
                      child: Text('Exportar PNG'),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Text('Exportar PDF'),
                    ),
                    const PopupMenuItem(
                      value: 'xlsx',
                      child: Text('Exportar dados Excel'),
                    ),
                    const PopupMenuItem(
                      value: 'json',
                      child: Text('Exportar configuracao JSON'),
                    ),
                    const PopupMenuDivider(),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildNavegacaoPaginas(),
            ),
          ),
          if (_modoApresentacao)
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: FilledButton.tonalIcon(
                  onPressed: () => _definirModoApresentacao(false),
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

        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastCanvasViewport != viewport &&
            viewport.width.isFinite &&
            viewport.height.isFinite) {
          _lastCanvasViewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final scale = math
                .min(
                  (viewport.width - 20) / _dashboardWidth,
                  (viewport.height - 20) / _dashboardHeight,
                )
                .clamp(0.2, 1.0)
                .toDouble();
            _canvasController.value = Matrix4.diagonal3Values(scale, scale, 1);
          });
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: _modoApresentacao
              ? Colors.black
              : Theme.of(context).scaffoldBackgroundColor,
          child: InteractiveViewer(
            transformationController: _canvasController,
            panEnabled: !_arrastandoVisual,
            boundaryMargin: const EdgeInsets.all(240),
            minScale: 0.2,
            maxScale: 3.0,
            constrained: false,
            child: SizedBox(
              width: areaWidth,
              height: areaHeight,
              child: Center(
                child: RepaintBoundary(
                  key: _dashboardBoundaryKey,
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
                        children: DashboardManager.graficosAtivos
                            .where(
                              (config) =>
                                  config.pagina == DashboardManager.paginaAtual,
                            )
                            .map((config) {
                              return Positioned(
                                key: ValueKey(config.id),
                                left: config.posicao.dx,
                                top: config.posicao.dy,
                                child: _buildResizableDraggableChart(config),
                              );
                            })
                            .toList(),
                      ),
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
    _limitarGeometriaDoVisual(config);
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
        config.configExtra['secondaryScaleMode']?.toString() ?? 'automatico';
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
    var tempPowerBiConfig = PowerBiVisualConfig.merge(
      config.tipo,
      config.configExtra,
    );

    void sincronizarPowerBi(Map<String, dynamic> value) {
      tempPowerBiConfig = Map<String, dynamic>.from(value);
      double number(String key, double fallback) {
        final raw = value[key];
        return raw is num ? raw.toDouble() : fallback;
      }

      bool flag(String key, bool fallback) {
        final raw = value[key];
        return raw is bool ? raw : fallback;
      }

      Color color(String key, Color fallback) =>
          _corConfig(value[key], fallback);

      tempBarOpacity = number('barOpacity', tempBarOpacity);
      tempBarGap = number('barGap', tempBarGap);
      tempBarBorderWidth = number('barBorderWidth', tempBarBorderWidth);
      tempMarkerSize = number('markerSize', tempMarkerSize);
      tempMostrarPontos = flag('markerVisible', tempMostrarPontos);
      tempEspessuraLinha = number('lineWidth', tempEspessuraLinha);
      tempSliceOpacity = number('sliceOpacity', tempSliceOpacity);
      tempRaioFuro = number('raioFuro', tempRaioFuro);
      tempGaugeMin = number('gaugeMin', tempGaugeMin);
      tempGaugeMax = number('gaugeMax', tempGaugeMax);
      tempGaugeMeta = number('gaugeMeta', tempGaugeMeta);
      tempGaugeRanges = flag('gaugeMostrarFaixas', tempGaugeRanges);
      tempKpiShowMeta = flag('kpiShowMeta', tempKpiShowMeta);
      tempKpiMeta = number('kpiMeta', tempKpiMeta);
      tempKpiShowTrend = flag('kpiShowTrend', tempKpiShowTrend);
      tempKpiPrevious = number('kpiPrevious', tempKpiPrevious);
      tempKpiFontSize = number('kpiFontSize', tempKpiFontSize);
      tempHeaderTabela = color('headerColor', tempHeaderTabela);
      tempRowColorA = color('rowColorA', tempRowColorA);
      tempRowColorB = color('rowColorB', tempRowColorB);
      tempGridColor = color('gridColor', tempGridColor);
      tempRowHeight = number('rowHeight', tempRowHeight);
      tempSegmentacaoMultipla = flag(
        'segmentacaoMultipla',
        tempSegmentacaoMultipla,
      );
      tempSlicerStyle = value['slicerStyle']?.toString() ?? tempSlicerStyle;
      tempSlicerSearch = flag('slicerSearch', tempSlicerSearch);
      tempTreemapSpacing = number('treemapSpacing', tempTreemapSpacing);
      tempTooltipAtivo = flag('tooltipEnabled', tempTooltipAtivo);
      tempInteracaoFiltrar = flag('interactionFilter', tempInteracaoFiltrar);
      tempInteracaoDestacar = flag(
        'interactionHighlight',
        tempInteracaoDestacar,
      );
      tempDrillthrough = flag('interactionDrillthrough', tempDrillthrough);
      tempAnimationEntrada =
          value['animationIn']?.toString() ?? tempAnimationEntrada;
      tempAnimationUpdate =
          value['animationUpdate']?.toString() ?? tempAnimationUpdate;
    }

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

    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
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
                            value: config.tamanho.width.clamp(
                              tempMinWidth.clamp(80, _dashboardWidth),
                              _dashboardWidth,
                            ),
                            min: tempMinWidth.clamp(80, _dashboardWidth),
                            max: _dashboardWidth,
                            onChanged: (v) => setModalState(() {
                              config.tamanho = Size(v, config.tamanho.height);
                              _limitarGeometriaDoVisual(config);
                            }),
                          ),
                          Text(
                            "Altura: ${config.tamanho.height.toStringAsFixed(0)}",
                          ),
                          Slider(
                            value: config.tamanho.height.clamp(
                              tempMinHeight.clamp(80, _dashboardHeight),
                              _dashboardHeight,
                            ),
                            min: tempMinHeight.clamp(80, _dashboardHeight),
                            max: _dashboardHeight,
                            onChanged: (v) => setModalState(() {
                              config.tamanho = Size(config.tamanho.width, v);
                              _limitarGeometriaDoVisual(config);
                            }),
                          ),
                          Text("X: ${config.posicao.dx.toStringAsFixed(0)}"),
                          Slider(
                            value: config.posicao.dx.clamp(
                              0,
                              math.max(
                                0,
                                _dashboardWidth - config.tamanho.width,
                              ),
                            ),
                            min: 0,
                            max: math.max(
                              0,
                              _dashboardWidth - config.tamanho.width,
                            ),
                            onChanged: (v) => setModalState(
                              () =>
                                  config.posicao = Offset(v, config.posicao.dy),
                            ),
                          ),
                          Text("Y: ${config.posicao.dy.toStringAsFixed(0)}"),
                          Slider(
                            value: config.posicao.dy.clamp(
                              0,
                              math.max(
                                0,
                                _dashboardHeight - config.tamanho.height,
                              ),
                            ),
                            min: 0,
                            max: math.max(
                              0,
                              _dashboardHeight - config.tamanho.height,
                            ),
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
                                    (_dashboardWidth - config.tamanho.width) /
                                        2,
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
                                    (_dashboardHeight - config.tamanho.height) /
                                        2,
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
                                initialValue: tempMetricColorMode,
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
                                initialValue: tempSecondaryScaleMode,
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
                              initialValue: tempBarColorMode,
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
                              initialValue: tempSlicerStyle,
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
                          const Divider(height: 32),
                          const Text(
                            "Configuracao detalhada Power BI",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PowerBiFormatPanel(
                            visualType: config.tipo,
                            value: tempPowerBiConfig,
                            onChanged: (value) =>
                                setModalState(() => sincronizarPowerBi(value)),
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
                            config.configExtra.addAll(tempPowerBiConfig);
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
                                tempSubtituloColor.toARGB32().toString();
                            config.configExtra['descriptionText'] =
                                descricaoController.text;
                            config.configExtra['backgroundOpacity'] =
                                tempBgOpacity;
                            config.configExtra['borderVisible'] =
                                tempBorderVisible;
                            config.configExtra['borderColor'] = tempBorderColor
                                .toARGB32()
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
                                .toARGB32()
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
                                tempCorPrincipal.toARGB32().toString();
                            config.configExtra['corMetricaPrincipal'] =
                                tempCorMetricaPrincipal.toARGB32().toString();
                            config.configExtra['corMetricaSecundaria'] =
                                tempCorMetricaSecundaria.toARGB32().toString();
                            config.configExtra['metricColorMode'] =
                                tempMetricColorMode;
                            config.configExtra['secondaryScaleMode'] =
                                tempSecondaryScaleMode;
                            config.configExtra['barColor'] =
                                tempCorMetricaPrincipal.toARGB32().toString();
                            config.configExtra['stackColor'] =
                                tempCorMetricaSecundaria.toARGB32().toString();
                            config.configExtra['markerColor'] =
                                tempCorMetricaPrincipal.toARGB32().toString();
                            config.configExtra['headerColor'] = tempHeaderTabela
                                .toARGB32()
                                .toString();
                            config.configExtra['totalColor'] = tempTotalTabela
                                .toARGB32()
                                .toString();
                            config.configExtra['rowColorA'] = tempRowColorA
                                .toARGB32()
                                .toString();
                            config.configExtra['rowColorB'] = tempRowColorB
                                .toARGB32()
                                .toString();
                            config.configExtra['gridColor'] = tempGridColor
                                .toARGB32()
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

  List<dynamic> _dadosBrutosDoGrafico(ChartConfig config) {
    final fonteId = config.configExtra['fonteId']?.toString();
    final data =
        DashboardManager.fonteDashboardPorId(fonteId) ??
        DashboardManager.dadosFonteAtual;
    return data?['dados_limpos'] ??
        data?['dados_brutos'] ??
        data?['dados_planilha']?['dados_limpos'] ??
        data?['dados_planilha']?['dados_brutos'] ??
        const [];
  }

  String _chaveFiltro(dynamic valor) =>
      valor?.toString().trim().toLowerCase() ?? '';

  List<Map<String, dynamic>> _filtrarAgregadosSemFonte(ChartConfig config) {
    var dados = List<Map<String, dynamic>>.from(config.dados);
    final filtroDireto = _filtrosSegmentacao[config.dimensao];
    if (filtroDireto != null && filtroDireto.isNotEmpty) {
      final chaves = filtroDireto.map(_chaveFiltro).toSet();
      dados = dados
          .where((item) => chaves.contains(_chaveFiltro(item['label'])))
          .toList();
    }
    for (final selection in _selecoesVisuais.entries) {
      if (selection.key == config.id || selection.value.isEmpty) continue;
      ChartConfig? source;
      for (final chart in DashboardManager.graficosAtivos) {
        if (chart.id == selection.key) {
          source = chart;
          break;
        }
      }
      if (source == null || source.dimensao != config.dimensao) continue;
      final chaves = selection.value.map(_chaveFiltro).toSet();
      dados = dados
          .where((item) => chaves.contains(_chaveFiltro(item['label'])))
          .toList();
    }
    return dados;
  }

  List<Map<String, dynamic>> _calcularDadosFiltrados(ChartConfig config) {
    final dadosBrutos = _dadosBrutosDoGrafico(config);
    if (dadosBrutos.isEmpty) {
      return _filtrarAgregadosSemFonte(config);
    }
    if (_filtrosSegmentacao.isEmpty && _selecoesVisuais.isEmpty) {
      return config.dados;
    }

    final linhasFiltradas = dadosBrutos.where((linha) {
      if (linha is! Map) return false;
      for (final filtro in _filtrosSegmentacao.entries) {
        if (filtro.value.isEmpty) continue;
        if (!linha.containsKey(filtro.key)) continue;
        final valor = _chaveFiltro(linha[filtro.key]);
        if (!filtro.value.map(_chaveFiltro).contains(valor)) return false;
      }
      for (final selection in _selecoesVisuais.entries) {
        if (selection.key == config.id || selection.value.isEmpty) continue;
        ChartConfig? source;
        for (final chart in DashboardManager.graficosAtivos) {
          if (chart.id == selection.key) {
            source = chart;
            break;
          }
        }
        if (source == null) continue;
        if (!linha.containsKey(source.dimensao)) continue;
        final value = _chaveFiltro(linha[source.dimensao]);
        if (!selection.value.map(_chaveFiltro).contains(value)) return false;
      }
      return true;
    });

    final agrupamento = <String, List<double>>{};
    final labelsPrimarios = <String, String>{};
    final labelsSecundarios = <String, String>{};
    final metricasCalculadas = <String, CalculatedMetric>{
      ...DashboardManager.metricasCalculadas,
    };
    final rawCalculated = config.configExtra['calculatedMetrics'];
    if (rawCalculated is List) {
      for (final item in rawCalculated) {
        final metric = CalculatedMetric.fromJson(item);
        if (metric != null) metricasCalculadas[metric.name] = metric;
      }
    }
    final metricasAdicionais = <String>[
      if (config.configExtra['metricasAdicionais'] is List)
        ...(config.configExtra['metricasAdicionais'] as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty && item != config.metrica)
      else if ((config.configExtra['metricaSecundaria']?.toString() ?? '')
          .isNotEmpty)
        config.configExtra['metricaSecundaria'].toString(),
    ];
    final agrupamentosAdicionais = <String, Map<String, List<double>>>{
      for (final nome in metricasAdicionais) nome: <String, List<double>>{},
    };
    final dimensaoSecundaria = config.configExtra['dimensaoSecundaria']
        ?.toString();
    for (final linha in linhasFiltradas) {
      if (linha is! Map) continue;
      final labelPrimario =
          linha[config.dimensao]?.toString().trim().isNotEmpty == true
          ? linha[config.dimensao].toString()
          : 'Desconhecido';
      final labelSecundario = dimensaoSecundaria != null
          ? (linha[dimensaoSecundaria]?.toString().trim().isNotEmpty == true
                ? linha[dimensaoSecundaria].toString()
                : 'Sem detalhe')
          : '';
      final chave = dimensaoSecundaria == null
          ? labelPrimario
          : '$labelPrimario\u001F$labelSecundario';
      labelsPrimarios[chave] = labelPrimario;
      labelsSecundarios[chave] = labelSecundario;
      final valor = resolveMetricValue(
        linha,
        config.metrica,
        metricasCalculadas,
      );
      agrupamento.putIfAbsent(chave, () => []).add(valor);
      for (final nome in metricasAdicionais) {
        final valorAdicional = resolveMetricValue(
          linha,
          nome,
          metricasCalculadas,
        );
        agrupamentosAdicionais[nome]!
            .putIfAbsent(chave, () => [])
            .add(valorAdicional);
      }
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

    double agregar(List<double> valores) {
      if (valores.isEmpty) return 0;
      final soma = valores.fold<double>(0, (total, valor) => total + valor);
      return switch (agregacao) {
        'Media' => soma / valores.length,
        'Contagem' => valores.length.toDouble(),
        'Maximo' => valores.reduce((a, b) => a > b ? a : b),
        'Minimo' => valores.reduce((a, b) => a < b ? a : b),
        _ => soma,
      };
    }

    final dados = agrupamento.entries.map((entry) {
      final valor = agregar(entry.value);
      final seriesValues = <String, double>{
        for (final nome in metricasAdicionais)
          nome: agregar(
            agrupamentosAdicionais[nome]?[entry.key] ?? const <double>[],
          ),
      };
      final index = agrupamento.keys.toList().indexOf(entry.key);
      return {
        'label': labelsPrimarios[entry.key] ?? entry.key,
        if ((labelsSecundarios[entry.key] ?? '').isNotEmpty)
          'secondaryLabel': labelsSecundarios[entry.key],
        'value': valor,
        if (metricasAdicionais.isNotEmpty)
          'value2': seriesValues[metricasAdicionais.first] ?? 0.0,
        if (metricasAdicionais.isNotEmpty) 'seriesValues': seriesValues,
        'color': paleta[index % paleta.length],
      };
    }).toList();

    final sortMode =
        config.configExtra['categorySort']?.toString() ??
        (ordenarDesc ? 'valueDesc' : 'valueAsc');
    dados.sort((a, b) {
      if (sortMode == 'categoryAsc' || sortMode == 'categoryDesc') {
        final comparison = a['label'].toString().compareTo(
          b['label'].toString(),
        );
        return sortMode == 'categoryDesc' ? -comparison : comparison;
      }
      final valorA = (a['value'] as num).toDouble();
      final valorB = (b['value'] as num).toDouble();
      return sortMode == 'valueAsc'
          ? valorA.compareTo(valorB)
          : valorB.compareTo(valorA);
    });

    return dados.take(limite <= 0 ? dados.length : limite).toList();
  }

  ChartConfig _configVisual(ChartConfig config) {
    final tipo = config.tipo.toLowerCase();
    if (tipo.contains('segment')) return config;
    final dados = _calcularDadosFiltrados(config);
    final extraConfig = Map<String, dynamic>.from(config.configExtra);
    extraConfig.putIfAbsent(
      'calculatedMetrics',
      () => DashboardManager.metricasCalculadas.values
          .map((metric) => metric.toJson())
          .toList(),
    );
    return ChartConfig(
      id: config.id,
      tipo: config.tipo,
      titulo: config.titulo,
      dimensao: config.dimensao,
      metrica: config.metrica,
      dados: dados,
      posicao: config.posicao,
      tamanho: config.tamanho,
      pagina: config.pagina,
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
      configExtra: extraConfig,
    );
  }

  bool _tipoUsaLegenda(String tipo) {
    final t = tipo.toLowerCase();
    return !(t.contains('cartao') ||
        t.contains('kpi') ||
        t.contains('tabela') ||
        t.contains('segment') ||
        t.contains('gauge') ||
        t.contains('treemap') ||
        t.contains('influenciador') ||
        t.contains('narrativa'));
  }

  Widget _buildConteudoComLegenda(ChartConfig config) {
    final visualConfig = _configVisual(config);
    final tipo = config.tipo.toLowerCase();
    Widget chartWidget = ChartRenderer(
      config: visualConfig,
      filtrosSelecionados: _filtrosSegmentacao[config.dimensao],
      selecaoVisual: _selecoesVisuais[config.id],
      onSegmentacaoChanged: tipo.contains('segment')
          ? (selecionados) => setState(() {
              if (selecionados.isEmpty) {
                _filtrosSegmentacao.remove(config.dimensao);
              } else {
                _filtrosSegmentacao[config.dimensao] = selecionados;
              }
            })
          : null,
      onSelecaoVisualChanged:
          !tipo.contains('segment') &&
              (config.configExtra['interactionFilter'] as bool? ?? true)
          ? (selecionados) => setState(() {
              if (selecionados.isEmpty) {
                _selecoesVisuais.remove(config.id);
              } else {
                _selecoesVisuais[config.id] = selecionados;
              }
            })
          : null,
    );

    if (!_tipoUsaLegenda(config.tipo) ||
        !visualConfig.mostrarLegenda ||
        visualConfig.dados.isEmpty) {
      return chartWidget;
    }

    final metricasAdicionais = <String>[
      if (config.configExtra['metricasAdicionais'] is List)
        ...(config.configExtra['metricasAdicionais'] as List)
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty && item != config.metrica)
      else if ((config.configExtra['metricaSecundaria']?.toString() ?? '')
          .isNotEmpty)
        config.configExtra['metricaSecundaria'].toString(),
    ];
    if (metricasAdicionais.isEmpty &&
        visualConfig.dados.any((item) => item.containsKey('value2'))) {
      metricasAdicionais.add('Segunda metrica');
    }
    final usaSeriesDeMetricas =
        metricasAdicionais.isNotEmpty &&
        (tipo.contains('barra') ||
            tipo.contains('coluna') ||
            tipo.contains('linha') ||
            tipo.contains('area') ||
            tipo.contains('combo') ||
            tipo.contains('radar') ||
            tipo.contains('ribbon'));
    final coresSeries = <dynamic>[
      config.configExtra['corMetricaPrincipal'],
      config.configExtra['corMetricaSecundaria'],
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
      const Color(0xFF64748B),
    ];
    final nomesSeries = <String>[config.metrica, ...metricasAdicionais];
    final itensLegenda = usaSeriesDeMetricas
        ? List<Map<String, dynamic>>.generate(nomesSeries.length, (index) {
            final nome = nomesSeries[index];
            final metricColors = config.configExtra['metricColors'];
            return {
              'label': nome,
              'color': metricColors is Map && metricColors[nome] != null
                  ? metricColors[nome]
                  : coresSeries[index % coresSeries.length],
              'value': visualConfig.dados.fold<double>(0, (sum, item) {
                if (index == 0) {
                  return sum + ((item['value'] ?? 0) as num).toDouble();
                }
                final seriesValues = item['seriesValues'];
                final value = seriesValues is Map
                    ? seriesValues[nome]
                    : index == 1
                    ? item['value2']
                    : null;
                return sum + (value is num ? value.toDouble() : 0.0);
              }),
            };
          })
        : visualConfig.dados;
    final showLegendValues =
        config.configExtra['legendShowValues'] as bool? ?? false;

    Widget legenda = Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      direction:
          (config.posicaoLegenda == 'left' || config.posicaoLegenda == 'right')
          ? Axis.vertical
          : Axis.horizontal,
      children: itensLegenda
          .map(
            (d) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ((config.configExtra['legendMarkerSize'] ?? 9) as num)
                      .toDouble(),
                  height: ((config.configExtra['legendMarkerSize'] ?? 9) as num)
                      .toDouble(),
                  color: _converterCor(d['color']),
                  margin: const EdgeInsets.only(right: 4),
                ),
                Text(
                  () {
                    final rawLabel = d['label'].toString();
                    final label = rawLabel.length > 12
                        ? '${rawLabel.substring(0, 12)}...'
                        : rawLabel;
                    final rawValue = d['value'];
                    if (!showLegendValues || rawValue is! num) return label;
                    return '$label  ${formatarValorVisual(config, rawValue.toDouble())}';
                  }(),
                  style: TextStyle(
                    fontSize:
                        ((config.configExtra['legendFontSize'] ?? 10) as num)
                            .toDouble(),
                    color: _corConfig(
                      config.configExtra['legendColor'],
                      const Color(0xFF475569),
                    ),
                  ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((config.configExtra['legendTitle']?.toString() ?? '')
                .isNotEmpty)
              Text(
                config.configExtra['legendTitle'].toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            legenda,
          ],
        ),
      ),
    );

    if (config.posicaoLegenda == 'top') {
      return Column(
        children: [
          safeLegenda,
          const SizedBox(height: 8),
          Expanded(child: chartWidget),
        ],
      );
    }
    if (config.posicaoLegenda == 'bottom') {
      return Column(
        children: [
          Expanded(child: chartWidget),
          const SizedBox(height: 8),
          safeLegenda,
        ],
      );
    }
    if (config.posicaoLegenda == 'left') {
      return Row(
        children: [
          safeLegenda,
          const SizedBox(width: 8),
          Expanded(child: chartWidget),
        ],
      );
    }
    if (config.posicaoLegenda == 'right') {
      return Row(
        children: [
          Expanded(child: chartWidget),
          const SizedBox(width: 8),
          safeLegenda,
        ],
      );
    }

    return chartWidget;
  }

  Widget _buildResizableDraggableChart(ChartConfig config) {
    TextAlign alignTitulo = TextAlign.left;
    if (config.alinhamentoTitulo == 'center') alignTitulo = TextAlign.center;
    if (config.alinhamentoTitulo == 'right') alignTitulo = TextAlign.right;

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
                                onPanStart: (_) =>
                                    _iniciarArrasteVisual(config),
                                onPanUpdate: (details) =>
                                    _moverVisual(config, details),
                                onPanEnd: (_) =>
                                    _finalizarArrasteVisual(config),
                                onPanCancel: () =>
                                    _finalizarArrasteVisual(config),
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
                                  onPanStart: (_) =>
                                      _iniciarArrasteVisual(config),
                                  onPanUpdate: (details) =>
                                      _moverVisual(config, details),
                                  onPanEnd: (_) =>
                                      _finalizarArrasteVisual(config),
                                  onPanCancel: () =>
                                      _finalizarArrasteVisual(config),
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
                              if (!_modoApresentacao)
                                PopupMenuButton<String>(
                                  tooltip: 'Opcoes do visual',
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    size: 19,
                                  ),
                                  onSelected: (action) {
                                    if (action == 'focus') {
                                      _abrirVisualEmFoco(config);
                                    } else if (action == 'sort') {
                                      _alternarOrdenacaoVisual(config);
                                    } else if (action == 'csv') {
                                      _copiarCsvDoVisual(config);
                                    } else if (action == 'edit') {
                                      _abrirConfiguracoesBottomSheet(config);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'focus',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.open_in_full_rounded,
                                        ),
                                        title: Text('Modo de foco'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'sort',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.sort_rounded),
                                        title: Text('Alterar ordenacao'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'csv',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.download_rounded),
                                        title: Text('Copiar CSV'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.tune_rounded),
                                        title: Text('Formatar visual'),
                                      ),
                                    ),
                                  ],
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
                    onPanStart: (_) => _iniciarArrasteVisual(config),
                    onPanUpdate: (details) => setState(() {
                      final delta = _deltaNoCanvas(details);
                      double novaLargura = config.tamanho.width + delta.dx;
                      if (novaLargura >= minWidth) {
                        config.tamanho = Size(
                          novaLargura,
                          config.tamanho.height,
                        );
                      }
                    }),
                    onPanEnd: (_) => _finalizarArrasteVisual(config),
                    onPanCancel: () => _finalizarArrasteVisual(config),
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
                    onPanStart: (_) => _iniciarArrasteVisual(config),
                    onPanUpdate: (details) => setState(() {
                      final delta = _deltaNoCanvas(details);
                      double novaLargura = config.tamanho.width - delta.dx;
                      if (novaLargura >= minWidth) {
                        config.posicao = Offset(
                          config.posicao.dx + delta.dx,
                          config.posicao.dy,
                        );
                        config.tamanho = Size(
                          novaLargura,
                          config.tamanho.height,
                        );
                      }
                    }),
                    onPanEnd: (_) => _finalizarArrasteVisual(config),
                    onPanCancel: () => _finalizarArrasteVisual(config),
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
                    onPanStart: (_) => _iniciarArrasteVisual(config),
                    onPanUpdate: (details) => setState(() {
                      final delta = _deltaNoCanvas(details);
                      double novaAltura = config.tamanho.height + delta.dy;
                      if (novaAltura >= minHeight) {
                        config.tamanho = Size(config.tamanho.width, novaAltura);
                      }
                    }),
                    onPanEnd: (_) => _finalizarArrasteVisual(config),
                    onPanCancel: () => _finalizarArrasteVisual(config),
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
                    onPanStart: (_) => _iniciarArrasteVisual(config),
                    onPanUpdate: (details) => setState(() {
                      final delta = _deltaNoCanvas(details);
                      double novaAltura = config.tamanho.height - delta.dy;
                      if (novaAltura >= minHeight) {
                        config.posicao = Offset(
                          config.posicao.dx,
                          config.posicao.dy + delta.dy,
                        );
                        config.tamanho = Size(config.tamanho.width, novaAltura);
                      }
                    }),
                    onPanEnd: (_) => _finalizarArrasteVisual(config),
                    onPanCancel: () => _finalizarArrasteVisual(config),
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
                    onPanStart: (_) => _iniciarArrasteVisual(config),
                    onPanUpdate: (details) => setState(() {
                      final delta = _deltaNoCanvas(details);
                      double novaLargura = config.tamanho.width + delta.dx;
                      double novaAltura = config.tamanho.height + delta.dy;
                      config.tamanho = Size(
                        novaLargura > minWidth ? novaLargura : minWidth,
                        novaAltura > minHeight ? novaAltura : minHeight,
                      );
                    }),
                    onPanEnd: (_) => _finalizarArrasteVisual(config),
                    onPanCancel: () => _finalizarArrasteVisual(config),
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
      if (corOrigem.startsWith('#')) {
        return Color(int.parse(corOrigem.replaceFirst('#', '0xFF')));
      }
      int? valorNumerico = int.tryParse(corOrigem);
      if (valorNumerico != null) return Color(valorNumerico);
    }
    if (corOrigem is int) return Color(corOrigem);
    return Colors.blueAccent;
  }
}
