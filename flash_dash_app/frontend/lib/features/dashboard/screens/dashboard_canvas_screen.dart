import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../dashboard_manager.dart';
import '../../home/screens/home_screen.dart';

class DashboardCanvasScreen extends StatefulWidget {
  const DashboardCanvasScreen({super.key});

  @override
  State<DashboardCanvasScreen> createState() => _DashboardCanvasScreenState();
}

class _DashboardCanvasScreenState extends State<DashboardCanvasScreen> {
  final List<Map<String, String>> _mensagensChat = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;

  // ==========================================
  // FORMATADOR DE NÚMEROS (UX/Data Viz)
  // ==========================================
  String _formatarNumero(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}k';
    // Remove o ".0" se for número inteiro
    return valor == valor.toInt() ? valor.toInt().toString() : valor.toStringAsFixed(1);
  }

  // ==========================================
  // FUNÇÃO MAGNÉTICA (SNAP TO GRID)
  // ==========================================
  double _snap(double value) {
    const double gridSize = 20.0;
    return (value / gridSize).roundToDouble() * gridSize;
  }

  

  // ==========================================
  // MENU DE CONTEXTO (LONG PRESS)
  // ==========================================
  void _mostrarMenuContexto(BuildContext context, ChartConfig config, Offset tapPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final String? acao = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40), 
        Offset.zero & overlay.size,       
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.tune, color: Color(0xFF2563EB), size: 20), SizedBox(width: 12), Text('Editar Visual')])),
        const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text('Excluir', style: TextStyle(color: Colors.redAccent))])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'cancelar', child: Row(children: [Icon(Icons.close, color: Colors.grey, size: 20), SizedBox(width: 12), Text('Cancelar', style: TextStyle(color: Colors.grey))])),
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  Future<void> _salvarDashboard() async {
    TextEditingController nomeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Salvar Dashboard na Nuvem"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: TextField(controller: nomeController, decoration: const InputDecoration(hintText: "Nome do Dashboard", filled: true)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                if (nomeController.text.isNotEmpty) {
                  var configJson = DashboardManager.graficosAtivos.map((g) => {
                    "id": g.id,
                    "tipo": g.tipo,
                    "titulo": g.titulo,
                    "dimensao": g.dimensao,
                    "metrica": g.metrica,
                    "dados": g.dados.map((d) => {
                      "label": d["label"],
                      "value": d["value"],
                      "color": d["color"] is Color ? (d["color"] as Color).value.toString() : d["color"].toString()
                    }).toList(),
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
                  }).toList();

                  try {
                    var response = await http.post(
                      Uri.parse('http://127.0.0.1:8000/salvar-dashboard'),
                      headers: {"Content-Type": "application/json"},
                      body: json.encode({"titulo": nomeController.text, "graficos_config": configJson}),
                    );

                    if (response.statusCode == 200) {
                      DashboardManager.graficosAtivos.clear();
                      Navigator.pop(dialogContext); 
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
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

  void _abrirChatIA() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text("Analista IA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _mensagensChat.length,
                        itemBuilder: (context, index) {
                          bool isUser = _mensagensChat[index]['remetente'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blueAccent : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: isUser ? null : Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(_mensagensChat[index]['texto']!, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isChatLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Pergunte sobre os gráficos...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _enviarMensagem(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: () => _enviarMensagem(setModalState)),
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          }
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

    List<Map<String, dynamic>> contextoDashboard = DashboardManager.graficosAtivos.map((g) {
      var dadosLimposParaIA = g.dados.map((d) => {"label": d['label'], "value": d['value']}).toList();
      return {"titulo_grafico": g.titulo, "dados": dadosLimposParaIA};
    }).toList();

    try {
      var uri = Uri.parse('http://127.0.0.1:8000/chat-ia');
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"mensagem": pergunta, "contexto_dashboard": contextoDashboard}),
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
        _mensagensChat.add({'remetente': 'ia', 'texto': '⚠️ Erro de conexão com a IA.'});
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
      appBar: AppBar(
        title: Text(isDesktop ? 'Área de Trabalho' : 'Dashboard', style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: isDesktop 
              ? ElevatedButton.icon(onPressed: _salvarDashboard, icon: const Icon(Icons.save_rounded, size: 18), label: const Text("Salvar Dashboard"))
              : IconButton(icon: const Icon(Icons.save_rounded, color: Color(0xFF2563EB)), onPressed: _salvarDashboard, tooltip: "Salvar"),
          ),
          IconButton(icon: const Icon(Icons.auto_awesome, color: Colors.amber), onPressed: _abrirChatIA, tooltip: "Chat com a IA"),
          if (isDesktop) IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {}), tooltip: "Atualizar layout")
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8FAFC), // Fundo cinza-claro muito sutil (Slate 50)
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(double.infinity), // Permite arrastar para o infinito
          minScale: 0.1, // Zoom out profundo
          maxScale: 3.0, // Zoom in detalhado
          constrained: false, // Libera o tamanho interno para ser maior que a tela
          child: SizedBox(
            width: 10000, // Espaço "ilimitado" de 10k x 10k
            height: 10000,
            child: Stack(
              clipBehavior: Clip.none,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Mais orgânico
        tooltip: "Adicionar Gráfico",
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.pop(context), 
      ),
    );
  }

  // ==========================================
  // MENU DE EDIÇÃO (BOTTOM SHEET MODERNO)
  // ==========================================
  void _abrirConfiguracoesBottomSheet(ChartConfig config) {
    TextEditingController tituloController = TextEditingController(text: config.titulo);
    
    // Variáveis temporárias para o modal
    bool tempMostrarLegenda = config.mostrarLegenda;
    bool tempMostrarValores = config.mostrarValores;
    bool tempMostrarRotulos = config.mostrarRotulos;
    Color tempCorFundo = config.corFundo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Formatar Visual", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: tituloController, 
                      decoration: const InputDecoration(labelText: "Título do Gráfico", border: OutlineInputBorder())
                    ),
                    const SizedBox(height: 24),
                    
                    const Text("Configurações de Exibição", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text("Mostrar Legenda"),
                      value: tempMostrarLegenda,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => tempMostrarLegenda = val),
                    ),
                    SwitchListTile(
                      title: const Text("Mostrar Números (Valores)"),
                      value: tempMostrarValores,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => tempMostrarValores = val),
                    ),
                    SwitchListTile(
                      title: const Text("Mostrar Nomes (Rótulos)"),
                      value: tempMostrarRotulos,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => tempMostrarRotulos = val),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text("Cor de Fundo:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Claros / Neutros
                        Colors.white,
                        const Color(0xFFF8FAFC), // Slate 50
                        const Color(0xFFF1F5F9), // Slate 100
                        const Color(0xFFE2E8F0), // Slate 200
                        // Escuros
                        const Color(0xFF1E293B), // Slate 800
                        const Color(0xFF0F172A), // Slate 900
                        Colors.black,
                        // Tons Frios (Azul/Verde)
                        const Color(0xFFEFF6FF), // Blue 50
                        const Color(0xFF1E3A8A), // Blue 900
                        const Color(0xFFECFDF5), // Emerald 50
                        const Color(0xFF064E3B), // Emerald 900
                        // Tons Quentes (Amarelo/Vermelho/Roxo)
                        const Color(0xFFFFFBEB), // Amber 50
                        const Color(0xFFFEF2F2), // Red 50
                        const Color(0xFF7F1D1D), // Red 900
                        const Color(0xFFFAF5FF), // Purple 50
                        const Color(0xFF3B0764), // Purple 900
                      ].map((cor) => _botaoCor(tempCorFundo, cor, setModalState, (c) => tempCorFundo = c)).toList(),
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () {
                          // Aplica as alterações no gráfico e atualiza a tela
                          setState(() {
                            config.titulo = tituloController.text;
                            config.mostrarLegenda = tempMostrarLegenda;
                            config.mostrarValores = tempMostrarValores;
                            config.mostrarRotulos = tempMostrarRotulos;
                            config.corFundo = tempCorFundo;
                            // Se o fundo for escuro, o título fica branco automaticamente
                            config.corTextoTitulo = tempCorFundo == const Color(0xFF1E293B) ? Colors.white : const Color(0xFF0F172A);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("Aplicar Configurações", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _botaoCor(Color corAtual, Color novaCor, StateSetter setModalState, Function(Color) onSelect) {
    return GestureDetector(
      onTap: () => setModalState(() => onSelect(novaCor)),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: novaCor, 
          shape: BoxShape.circle, 
          border: Border.all(color: corAtual == novaCor ? const Color(0xFF2563EB) : Colors.grey.shade300, width: corAtual == novaCor ? 3 : 1)
        ),
      ),
    );
  }

  Widget _buildConteudoComLegenda(ChartConfig config) {
    Widget chartWidget = Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _renderGraficoMini(config, constraints);
        },
      ),
    );

    if (!config.mostrarLegenda || config.dados.isEmpty) return chartWidget;

    Widget legenda = Wrap(
      spacing: 8, runSpacing: 4,
      alignment: WrapAlignment.center,
      direction: (config.posicaoLegenda == 'left' || config.posicaoLegenda == 'right') ? Axis.vertical : Axis.horizontal,
      children: config.dados.map((d) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: _converterCor(d['color']), margin: const EdgeInsets.only(right: 4)),
          Text(
            d['label'].toString().length > 12 ? '${d['label'].toString().substring(0,12)}...' : d['label'].toString(),
            style: const TextStyle(fontSize: 10)
          ),
        ],
      )).toList(),
    );

    Widget safeLegenda = Container(
      constraints: BoxConstraints(
        maxHeight: (config.posicaoLegenda == 'top' || config.posicaoLegenda == 'bottom') ? 60 : double.infinity,
        maxWidth: (config.posicaoLegenda == 'left' || config.posicaoLegenda == 'right') ? 100 : double.infinity,
      ),
      child: SingleChildScrollView(
        scrollDirection: (config.posicaoLegenda == 'left' || config.posicaoLegenda == 'right') ? Axis.vertical : Axis.horizontal,
        child: legenda,
      ),
    );

    if (config.posicaoLegenda == 'top') return Column(children: [safeLegenda, const SizedBox(height: 8), chartWidget]);
    if (config.posicaoLegenda == 'bottom') return Column(children: [chartWidget, const SizedBox(height: 8), safeLegenda]);
    if (config.posicaoLegenda == 'left') return Row(children: [safeLegenda, const SizedBox(width: 8), chartWidget]);
    if (config.posicaoLegenda == 'right') return Row(children: [chartWidget, const SizedBox(width: 8), safeLegenda]);

    return chartWidget;
  }

  Widget _buildResizableDraggableChart(ChartConfig config) {
    TextAlign alignTitulo = TextAlign.left;
    if (config.alinhamentoTitulo == 'center') alignTitulo = TextAlign.center;
    if (config.alinhamentoTitulo == 'right') alignTitulo = TextAlign.right;

    // 1. APAGUE a variável "Offset posicaoToque = Offset.zero;" que ficava aqui
    const double minSize = 200.0; 
    const double espessuraBorda = 12.0; 

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
                onTapDown: (_) {
                  _trazerParaFrente(config);
                },
                // 3. Use o onLongPressStart (ele captura os detalhes da posição do clique longo)
                onLongPressStart: (details) {
                  _mostrarMenuContexto(context, config, details.globalPosition);
                },
                child: Card(
                  color: config.corFundo,
                  elevation: 2, // Sombra suave para destacar do fundo cinza
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Bordas mais modernas
                    side: BorderSide(color: Colors.blueGrey.shade100, width: 1)
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CABEÇALHO DISCRETO
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: config.corFundo, // Fundo igual ao card
                          border: Border(bottom: BorderSide(color: Colors.blueGrey.shade50, width: 1))
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onPanStart: (_) => _trazerParaFrente(config), // <--- Trás para frente ao começar arrastar
                              onPanUpdate: (details) => setState(() => config.posicao += details.delta),
                              onPanEnd: (_) => setState(() => config.posicao = Offset(_snap(config.posicao.dx), _snap(config.posicao.dy))),
                              // Ícone de arraste super discreto e com cor suave
                              child: const MouseRegion(
                                cursor: SystemMouseCursors.move, 
                                child: Icon(Icons.drag_indicator, size: 16, color: Color(0xFFCBD5E1))
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onPanStart: (_) => _trazerParaFrente(config),
                                onPanUpdate: (details) => setState(() => config.posicao += details.delta),
                                onPanEnd: (_) => setState(() => config.posicao = Offset(_snap(config.posicao.dx), _snap(config.posicao.dy))),
                                child: Text(
                                  config.titulo, 
                                  textAlign: alignTitulo, 
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: config.fontSizeTitulo, color: config.corTextoTitulo), 
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildConteudoComLegenda(config),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CONTROLES DE REDIMENSIONAMENTO INVISÍVEIS (Bordas)
            // Leste
            Align(
              alignment: Alignment.centerRight,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onPanStart: (_) => _trazerParaFrente(config),
                  onPanUpdate: (details) => setState(() {
                    double novaLargura = config.tamanho.width + details.delta.dx;
                    if (novaLargura >= minSize) config.tamanho = Size(novaLargura, config.tamanho.height);
                  }),
                  onPanEnd: (_) => setState(() => config.tamanho = Size(_snap(config.tamanho.width), config.tamanho.height)),
                  child: Container(width: espessuraBorda, height: double.infinity, color: Colors.transparent),
                ),
              ),
            ),
            
            // Oeste
            Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onPanStart: (_) => _trazerParaFrente(config),
                  onPanUpdate: (details) => setState(() {
                    double novaLargura = config.tamanho.width - details.delta.dx;
                    if (novaLargura >= minSize) {
                      config.posicao = Offset(config.posicao.dx + details.delta.dx, config.posicao.dy);
                      config.tamanho = Size(novaLargura, config.tamanho.height);
                    }
                  }),
                  onPanEnd: (_) => setState(() {
                    config.posicao = Offset(_snap(config.posicao.dx), config.posicao.dy);
                    config.tamanho = Size(_snap(config.tamanho.width), config.tamanho.height);
                  }),
                  child: Container(width: espessuraBorda, height: double.infinity, color: Colors.transparent),
                ),
              ),
            ),

            // Sul
            Align(
              alignment: Alignment.bottomCenter,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  onPanStart: (_) => _trazerParaFrente(config),
                  onPanUpdate: (details) => setState(() {
                    double novaAltura = config.tamanho.height + details.delta.dy;
                    if (novaAltura >= minSize) config.tamanho = Size(config.tamanho.width, novaAltura);
                  }),
                  onPanEnd: (_) => setState(() => config.tamanho = Size(config.tamanho.width, _snap(config.tamanho.height))),
                  child: Container(width: double.infinity, height: espessuraBorda, color: Colors.transparent),
                ),
              ),
            ),

            // Norte
            Align(
              alignment: Alignment.topCenter,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  onPanStart: (_) => _trazerParaFrente(config),
                  onPanUpdate: (details) => setState(() {
                    double novaAltura = config.tamanho.height - details.delta.dy;
                    if (novaAltura >= minSize) {
                      config.posicao = Offset(config.posicao.dx, config.posicao.dy + details.delta.dy);
                      config.tamanho = Size(config.tamanho.width, novaAltura);
                    }
                  }),
                  onPanEnd: (_) => setState(() {
                    config.posicao = Offset(config.posicao.dx, _snap(config.posicao.dy));
                    config.tamanho = Size(config.tamanho.width, _snap(config.tamanho.height));
                  }),
                  child: Container(width: double.infinity, height: espessuraBorda, color: Colors.transparent),
                ),
              ),
            ),

            // Sudeste (Canto inferior direito com indicativo visual)
            Align(
              alignment: Alignment.bottomRight,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  onPanStart: (_) => _trazerParaFrente(config),
                  onPanUpdate: (details) => setState(() {
                    double novaLargura = config.tamanho.width + details.delta.dx;
                    double novaAltura = config.tamanho.height + details.delta.dy;
                    config.tamanho = Size(novaLargura > minSize ? novaLargura : minSize, novaAltura > minSize ? novaAltura : minSize);
                  }),
                  onPanEnd: (_) => setState(() {
                    config.tamanho = Size(_snap(config.tamanho.width), _snap(config.tamanho.height));
                  }),
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    // Detalhe visual elegante indicando que ali redimensiona
                    child: const Center(
                      child: Icon(Icons.signal_cellular_4_bar_rounded, size: 14, color: Color(0xFFE2E8F0)),
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
      if (corOrigem.startsWith('#')) return Color(int.parse(corOrigem.replaceFirst('#', '0xFF')));
      int? valorNumerico = int.tryParse(corOrigem);
      if (valorNumerico != null) return Color(valorNumerico);
    }
    if (corOrigem is int) return Color(corOrigem);
    return Colors.blueAccent; 
  }

  Widget _renderGraficoMini(ChartConfig config, BoxConstraints constraints) {
    if (config.dados.isEmpty) return const Center(child: Text("Sem dados"));
    bool isPizzaOuRosca = config.tipo.contains('Pizza') || config.tipo.contains('Rosca');

    if (isPizzaOuRosca) {
      double menorLado = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
      double multiplicadorFuro = config.configExtra['raioFuro'] ?? 0.0;
      bool mostrarPorcentagem = config.configExtra['mostrarPorcentagem'] ?? false;
      double espessuraFatia = config.configExtra['espessuraFatia'] ?? 1.0;
      double raioExterno = (menorLado * 0.35) * espessuraFatia; 
      
      bool forcarOcultarTexto = menorLado < 130; 
      double fontSizeDinamico = menorLado < 200 ? 9 : 11;
      double total = config.dados.fold(0.0, (sum, item) => sum + (item['value'] as num).toDouble());

      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: raioExterno * multiplicadorFuro,
          sections: config.dados.map((d) {
            double valorRaw = (d['value'] as num).toDouble();
            
            // USO DO NOVO FORMATADOR (1.5k, 2M)
            String textoExibicao = mostrarPorcentagem && total > 0
                ? '${((valorRaw / total) * 100).toStringAsFixed(1)}%'
                : _formatarNumero(valorRaw); 

            String tituloFinal = '';
            if (config.mostrarRotulos && config.mostrarValores) {
              tituloFinal = '${d['label']}\n$textoExibicao';
            } else if (config.mostrarRotulos) {
              tituloFinal = d['label'].toString();
            } else if (config.mostrarValores) {
              tituloFinal = textoExibicao;
            }

            return PieChartSectionData(
              value: valorRaw, 
              color: _converterCor(d['color']), 
              radius: raioExterno * (1 - multiplicadorFuro),
              showTitle: forcarOcultarTexto ? false : (config.mostrarRotulos || config.mostrarValores), 
              title: tituloFinal, 
              titleStyle: TextStyle(fontSize: fontSizeDinamico, fontWeight: FontWeight.bold, color: (config.corFundo == const Color(0xFF1E293B)) ? Colors.white : Colors.white),
            );
          }).toList(),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: config.dados.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: config.dados.asMap().entries.map((e) => BarChartGroupData(
          x: e.key, 
          barRods: [
            BarChartRodData(
              toY: (e.value['value'] as num).toDouble(),
              color: _converterCor(e.value['color']),    
              width: constraints.maxWidth / (config.dados.length * 2.5), 
              borderRadius: BorderRadius.circular(4)
            )
          ]
        )).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: config.mostrarValores, 
            reservedSize: 45, // Aumentei um pouco o espaço para caber o "M"
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4.0),
              // USO DO NOVO FORMATADOR NO EIXO Y
              child: Text(_formatarNumero(value), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right),
            )
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: config.mostrarRotulos, 
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < config.dados.length) {
                String label = config.dados[value.toInt()]['label'].toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0), // Respiro entre a barra e o texto
                  child: Text(
                    label.length > 7 ? '${label.substring(0, 7)}.' : label, 
                    style: const TextStyle(fontSize: 9), 
                    overflow: TextOverflow.ellipsis
                  ),
                );
              }
              return const Text('');
          })),
        ),
        gridData: FlGridData(show: config.mostrarEixos, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}