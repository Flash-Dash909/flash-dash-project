import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../dashboard_manager.dart';
import '../../home/screens/home_screen.dart';

class DashboardCanvasScreen extends StatefulWidget {
  final String usuarioNome; // <- ADICIONE ESSA VARIÁVEL
  final String usuarioId; // <- ADICIONE ESSA VARIÁVEL

  // Atualize o construtor para receber o nome
  const DashboardCanvasScreen({super.key, required this.usuarioNome, required this.usuarioId}); 

  @override
  State<DashboardCanvasScreen> createState() => _DashboardCanvasScreenState();
}

class _DashboardCanvasScreenState extends State<DashboardCanvasScreen> {
  final List<Map<String, String>> _mensagensChat = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;
  
  // Controle de Tooltip do FlChart
  int touchedIndex = -1;

  // ==========================================
  // FORMATADOR DE NÚMEROS AVANÇADO
  // ==========================================
  String _formatarNumeroAvancado(double valor, String unidade, int decimais) {
    if (unidade == 'Nenhum') return valor.toStringAsFixed(decimais);
    if (unidade == 'Milhares') return '${(valor / 1000).toStringAsFixed(decimais)} Mil';
    if (unidade == 'Milhões') return '${(valor / 1000000).toStringAsFixed(decimais)} Mi';
    if (unidade == 'Bilhões') return '${(valor / 1000000000).toStringAsFixed(decimais)} Bi';
    
    // Auto
    if (valor >= 1000000000) return '${(valor / 1000000000).toStringAsFixed(decimais)}Bi';
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(decimais)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(decimais)}k';
    return valor == valor.toInt() ? valor.toInt().toString() : valor.toStringAsFixed(decimais);
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
        const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.tune, color: Color(0xFF2563EB), size: 20), SizedBox(width: 12), Text('Formatar Visual')])),
        const PopupMenuItem(value: 'excluir', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text('Excluir Visual', style: TextStyle(color: Colors.redAccent))])),
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
                      body: json.encode({"titulo": nomeController.text, "graficos_config": configJson, "usuario_id": widget.usuarioId}),
                    );

                    if (response.statusCode == 200) {
                      DashboardManager.graficosAtivos.clear();
                      Navigator.pop(dialogContext); 
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => HomeScreen(usuarioNome: widget.usuarioNome, usuarioId: widget.usuarioId)), (route) => false);
                    } else {
                      // ISSO VAI MOSTRAR O MOTIVO EXATO DO ERRO 422 NO CONSOLE:
                      debugPrint("ERRO DO FASTAPI: ${response.body}");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Falha ao salvar. Erro: ${response.statusCode}")));
                      }
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
        color: const Color(0xFFE2E8F0), // Fundo Workspace
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(double.infinity), 
          minScale: 0.1, 
          maxScale: 3.0, 
          constrained: false, 
          child: SizedBox(
            width: 10000, 
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
        tooltip: "Adicionar Gráfico",
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.pop(context), 
      ),
    );
  }

  // ==========================================
  // HELPERS PARA CONSTRUIR O MENU DE EDIÇÃO LIMPO
  // ==========================================
  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label), value: value, activeColor: const Color(0xFF0F766E), contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) => onChanged(val!),
      ),
    );
  }

  Widget _buildTypographyControls(Map<String, dynamic> conf, String prefix, StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildDropdown("Fonte", conf['${prefix}FontFamily'], ['Roboto', 'Segoe UI', 'Arial', 'Courier'], (val) { setModalState(() => conf['${prefix}FontFamily'] = val); setState((){}); })),
            const SizedBox(width: 8),
            SizedBox(
              width: 70, 
              child: TextField(
                keyboardType: TextInputType.number, 
                decoration: InputDecoration(hintText: conf['${prefix}FontSize'].toString(), labelText: "Tam.", isDense: true, border: const OutlineInputBorder()), 
                onSubmitted: (val) { setModalState(() => conf['${prefix}FontSize'] = double.tryParse(val) ?? 11.0); setState((){}); }
              )
            ),
          ]
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [conf['${prefix}Bold'], conf['${prefix}Italic'], conf['${prefix}Underline']],
          onPressed: (i) { 
            setModalState(() { 
              if(i==0) conf['${prefix}Bold'] = !conf['${prefix}Bold']; 
              if(i==1) conf['${prefix}Italic'] = !conf['${prefix}Italic']; 
              if(i==2) conf['${prefix}Underline'] = !conf['${prefix}Underline']; 
            }); 
            setState((){}); 
          },
          children: const [Icon(Icons.format_bold), Icon(Icons.format_italic), Icon(Icons.format_underline)],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ==========================================
  // MENU DE EDIÇÃO (BOTTOM SHEET MODERNO & COMPLETO)
  // ==========================================
  void _abrirConfiguracoesBottomSheet(ChartConfig config) {
    TextEditingController tituloController = TextEditingController(text: config.titulo);
    TextEditingController textoCentroController = TextEditingController(text: config.configExtra['textoCentralCustom'] ?? '');
    String fatiaSelecionada = 'Todos';

    // 1. Inicializa DEZENAS de opções do Power BI
    Map<String, dynamic> e = config.configExtra;
    
    // Rótulos
    e['posicaoRotulo'] ??= 'fora';
    e['conteudoRotulo'] ??= 'categoria_percentual';
    e['rotuloFontFamily'] ??= 'Roboto';
    e['rotuloFontSize'] ??= 11.0;
    e['rotuloBold'] ??= true;
    e['rotuloItalic'] ??= false;
    e['rotuloUnderline'] ??= false;
    e['rotuloColor'] ??= '#0F172A';
    e['rotuloBgColor'] ??= 'transparent';
    e['rotuloUnidades'] ??= 'Auto';
    e['rotuloDecimais'] ??= 1;
    
    // Legenda
    e['legendaPosicao'] ??= 'bottom';
    e['legendaFontFamily'] ??= 'Roboto';
    e['legendaFontSize'] ??= 10.0;
    e['legendaBold'] ??= false;
    e['legendaItalic'] ??= false;
    e['legendaUnderline'] ??= false;
    e['legendaColor'] ??= '#0F172A';

    // Título
    e['tituloFontFamily'] ??= 'Roboto';
    e['tituloBold'] ??= true;
    e['tituloItalic'] ??= false;
    e['tituloUnderline'] ??= false;
    e['tituloBgColor'] ??= 'transparent';

    // Fatias e Efeitos
    e['rotacao'] ??= 0.0;
    e['espacamento'] ??= 2.0;
    e['mostrarBordaCard'] ??= true;
    e['cardBorderColor'] ??= '#E2E8F0';
    e['cardBorderWidth'] ??= 1.0;
    e['mostrarCabecalho'] ??= true;
    e['mostrarTooltip'] ??= true;
    
    // Rosca
    e['raioFuro'] ??= 0.65;
    e['mostrarTextoCentral'] ??= false;
    e['textoCentralTipo'] ??= 'Total'; // 'Total' ou 'Customizado'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isPizza = config.tipo.contains('Pizza') || config.tipo.contains('Rosca');
            bool isRosca = config.tipo.contains('Rosca');

            return Container(
              height: MediaQuery.of(context).size.height * 0.9, 
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      child: const TabBar(
                        labelColor: Color(0xFF0F766E), indicatorColor: Color(0xFF0F766E), indicatorWeight: 3, 
                        tabs: [Tab(text: "Visual"), Tab(text: "Geral")]
                      )
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // ==========================================
                          // ABA 1: VISUAL
                          // ==========================================
                          ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // 1. LEGENDA
                              ExpansionTile(
                                title: const Text("1. Legenda", style: TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  _buildToggle("Ativar Legenda", config.mostrarLegenda, (val) { setModalState(() => config.mostrarLegenda = val); setState((){}); }),
                                  if (config.mostrarLegenda) ...[
                                    _buildDropdown("Posição", e['legendaPosicao'], ['top', 'bottom', 'left', 'right'], (val) { setModalState(() => e['legendaPosicao'] = val); setState((){}); }),
                                    const Text("Texto", style: TextStyle(color: Colors.grey)),
                                    _buildTypographyControls(e, 'legenda', setModalState),
                                    _buildDropdown("Cor do Texto", e['legendaColor'], ['#0F172A', '#FFFFFF', '#64748B', '#2563EB'], (val) { setModalState(() => e['legendaColor'] = val); setState((){}); }),
                                  ]
                                ],
                              ),
                              
                              if (isPizza) ...[
                                // 2. RÓTULOS DE DETALHE
                                ExpansionTile(
                                  title: const Text("2. Rótulos de Detalhes", style: TextStyle(fontWeight: FontWeight.bold)),
                                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    _buildToggle("Ativar Rótulos", config.mostrarRotulos, (val) { setModalState(() => config.mostrarRotulos = val); setState((){}); }),
                                    if (config.mostrarRotulos) ...[
                                      _buildDropdown("Exibir", e['conteudoRotulo'], ['valor', 'percentual', 'categoria', 'categoria_percentual', 'categoria_valor'], (val) { setModalState(() => e['conteudoRotulo'] = val); setState((){}); }),
                                      _buildDropdown("Posição", e['posicaoRotulo'], ['dentro', 'fora'], (val) { setModalState(() => e['posicaoRotulo'] = val); setState((){}); }),
                                      const Divider(),
                                      const Text("Valores", style: TextStyle(fontWeight: FontWeight.bold)),
                                      _buildTypographyControls(e, 'rotulo', setModalState),
                                      Row(
                                        children: [
                                          Expanded(child: _buildDropdown("Cor Texto", e['rotuloColor'], ['#0F172A', '#FFFFFF', '#2563EB'], (val) { setModalState(() => e['rotuloColor'] = val); setState((){}); })),
                                          const SizedBox(width: 8),
                                          Expanded(child: _buildDropdown("Fundo", e['rotuloBgColor'], ['transparent', '#FFFFFF', '#0F172A', '#E2E8F0'], (val) { setModalState(() => e['rotuloBgColor'] = val); setState((){}); })),
                                        ]
                                      ),
                                      Row(
                                        children: [
                                          Expanded(child: _buildDropdown("Unidades", e['rotuloUnidades'], ['Auto', 'Nenhum', 'Milhares', 'Milhões', 'Bilhões'], (val) { setModalState(() => e['rotuloUnidades'] = val); setState((){}); })),
                                          const SizedBox(width: 8),
                                          SizedBox(width: 80, child: TextField(keyboardType: TextInputType.number, decoration: InputDecoration(hintText: e['rotuloDecimais'].toString(), labelText: "Decimais", isDense: true, border: const OutlineInputBorder()), onSubmitted: (val) { setModalState(() => e['rotuloDecimais'] = int.tryParse(val) ?? 1); setState((){}); })),
                                        ]
                                      )
                                    ]
                                  ],
                                ),

                                // 3. FATIAS E CORES
                                ExpansionTile(
                                  title: const Text("3. Fatias (Cores)", style: TextStyle(fontWeight: FontWeight.bold)),
                                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    _buildDropdown("Cor individual da Categoria", fatiaSelecionada, ['Todos', ...config.dados.map((d) => d['label'].toString())], (val) => setModalState(() => fatiaSelecionada = val)),
                                    if (fatiaSelecionada != 'Todos') ...[
                                      Wrap(
                                        spacing: 8, runSpacing: 8, 
                                        children: [
                                          const Color(0xFF2563EB), const Color(0xFF10B981), const Color(0xFFF59E0B), 
                                          const Color(0xFFEF4444), const Color(0xFF8B5CF6), const Color(0xFF0F172A), Colors.grey
                                        ].map((cor) => GestureDetector(
                                          onTap: () {
                                            setModalState(() { var item = config.dados.firstWhere((d) => d['label'] == fatiaSelecionada); item['color'] = cor.value.toString(); });
                                            setState((){});
                                          },
                                          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                                        )).toList()
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    Row(children: [const Text("Espaçamento:"), Expanded(child: Slider(value: e['espacamento'], min: 0, max: 10, activeColor: const Color(0xFF0F766E), onChanged: (val) { setModalState(() => e['espacamento'] = val); setState((){}); }))]),
                                    Row(children: [const Text("Girar Gráfico:"), Expanded(child: Slider(value: e['rotacao'], min: 0, max: 360, activeColor: const Color(0xFF0F766E), onChanged: (val) { setModalState(() => e['rotacao'] = val); setState((){}); }))]),
                                  ],
                                ),

                                // 11. ROSCA ESPECÍFICO
                                if (isRosca)
                                ExpansionTile(
                                  title: const Text("11. Gráfico de Rosca", style: TextStyle(fontWeight: FontWeight.bold)),
                                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    Row(children: [const Text("Raio Interno:"), Expanded(child: Slider(value: e['raioFuro'], min: 0.1, max: 0.9, activeColor: const Color(0xFF0F766E), onChanged: (val) { setModalState(() => e['raioFuro'] = val); setState((){}); }))]),
                                    const Divider(),
                                    _buildToggle("Texto Central", e['mostrarTextoCentral'], (val) { setModalState(() => e['mostrarTextoCentral'] = val); setState((){}); }),
                                    if (e['mostrarTextoCentral']) ...[
                                      _buildDropdown("Conteúdo", e['textoCentralTipo'], ['Total', 'Customizado'], (val) { setModalState(() => e['textoCentralTipo'] = val); setState((){}); }),
                                      if (e['textoCentralTipo'] == 'Customizado')
                                        TextField(controller: textoCentroController, decoration: const InputDecoration(labelText: "Texto Customizado", border: OutlineInputBorder(), isDense: true), onSubmitted: (val) { setModalState(() => e['textoCentralCustom'] = val); setState((){}); }),
                                    ]
                                  ],
                                ),
                              ]
                            ],
                          ),
                          
                          // ==========================================
                          // ABA 2: GERAL
                          // ==========================================
                          ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // 4. TÍTULO
                              ExpansionTile(
                                title: const Text("4. Título", style: TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  TextField(decoration: const InputDecoration(labelText: "Texto", border: OutlineInputBorder(), isDense: true), controller: tituloController, onSubmitted: (val) { config.titulo = val; setState((){}); }),
                                  const SizedBox(height: 12),
                                  _buildDropdown("Alinhamento", config.alinhamentoTitulo, ['left', 'center', 'right'], (val) { setModalState(() => config.alinhamentoTitulo = val); setState((){}); }),
                                  _buildTypographyControls(e, 'titulo', setModalState),
                                  Row(
                                    children: [
                                      Expanded(child: _buildDropdown("Cor do Texto", config.corTextoTitulo.value.toString(), [config.corTextoTitulo.value.toString(), '4294967295', '4279177002', '4280644587'], (val) { setModalState(() => config.corTextoTitulo = Color(int.parse(val))); setState((){}); })),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildDropdown("Cor de Fundo", e['tituloBgColor'], ['transparent', '#E2E8F0', '#0F172A'], (val) { setModalState(() => e['tituloBgColor'] = val); setState((){}); })),
                                    ]
                                  ),
                                ],
                              ),

                              // 5. PLANO DE FUNDO
                              ExpansionTile(
                                title: const Text("5. Plano de Fundo", style: TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  Wrap(
                                    spacing: 12, runSpacing: 12,
                                    children: [
                                      Colors.white, const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), 
                                      const Color(0xFF1E293B), const Color(0xFF0F172A), Colors.black,
                                      const Color(0xFFEFF6FF), const Color(0xFF1E3A8A), const Color(0xFFECFDF5), 
                                      const Color(0xFF064E3B), const Color(0xFFFFFBEB), const Color(0xFF7F1D1D)
                                    ].map((cor) => GestureDetector(
                                      onTap: () { 
                                        setModalState(() { 
                                          config.corFundo = cor; 
                                          config.corTextoTitulo = cor.computeLuminance() < 0.5 ? Colors.white : const Color(0xFF0F172A); 
                                        }); 
                                        setState((){}); 
                                      },
                                      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300))),
                                    )).toList(),
                                  ),
                                ],
                              ),

                              // 6. BORDA E 7. EFEITOS
                              ExpansionTile(
                                title: const Text("6. Borda e 7. Efeitos", style: TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  _buildToggle("Ativar Borda", e['mostrarBordaCard'], (val) { setModalState(() => e['mostrarBordaCard'] = val); setState((){}); }),
                                  Row(children: [const Text("Cantos Arredondados:"), Expanded(child: Slider(value: config.raioBorda, min: 0, max: 32, activeColor: const Color(0xFF0F766E), onChanged: (val) { setModalState(() => config.raioBorda = val); setState((){}); }))]),
                                  _buildToggle("Sombra (Desfoque)", config.mostrarSombra, (val) { setModalState(() => config.mostrarSombra = val); setState((){}); }),
                                ],
                              ),

                              // 8. CABEÇALHO DO VISUAL E 9. TOOLTIP
                              ExpansionTile(
                                title: const Text("8. Cabeçalho e 9. Tooltip", style: TextStyle(fontWeight: FontWeight.bold)),
                                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                  _buildToggle("Ícones de Cabeçalho", e['mostrarCabecalho'], (val) { setModalState(() => e['mostrarCabecalho'] = val); setState((){}); }),
                                  _buildToggle("Interação Tooltip", e['mostrarTooltip'], (val) { setModalState(() => e['mostrarTooltip'] = val); setState((){}); }),
                                ],
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
        );
      },
    );
  }

  // ==========================================
  // CONSTRUÇÃO DO CARTÃO DO GRÁFICO
  // ==========================================
  Widget _buildResizableDraggableChart(ChartConfig config) {
    TextAlign alignTitulo = TextAlign.left;
    if (config.alinhamentoTitulo == 'center') alignTitulo = TextAlign.center;
    if (config.alinhamentoTitulo == 'right') alignTitulo = TextAlign.right;

    const double minSize = 200.0; 
    const double espessuraBorda = 12.0; 
    Map<String, dynamic> e = config.configExtra;

    return SizedBox(
      width: config.tamanho.width,
      height: config.tamanho.height,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (_) => _trazerParaFrente(config),
                onLongPressStart: (details) => _mostrarMenuContexto(context, config, details.globalPosition),
                child: Card(
                  color: config.corFundo,
                  elevation: config.mostrarSombra ? 4 : 0, 
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(config.raioBorda), 
                    side: e['mostrarBordaCard'] == true ? BorderSide(color: _converterCor(e['cardBorderColor'] ?? '#E2E8F0'), width: e['cardBorderWidth'] ?? 1.0) : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TÍTULO E CABEÇALHO (Power BI Header)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _converterCor(e['tituloBgColor'] ?? 'transparent'), 
                          border: Border(bottom: BorderSide(color: Colors.blueGrey.shade50, width: 1))
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onPanStart: (_) => _trazerParaFrente(config), 
                              onPanUpdate: (details) => setState(() => config.posicao += details.delta),
                              onPanEnd: (_) => setState(() => config.posicao = Offset(_snap(config.posicao.dx), _snap(config.posicao.dy))),
                              child: const MouseRegion(cursor: SystemMouseCursors.move, child: Icon(Icons.drag_indicator, size: 16, color: Color(0xFFCBD5E1))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                config.titulo, 
                                textAlign: alignTitulo, 
                                style: TextStyle(
                                  fontWeight: e['tituloBold'] == true ? FontWeight.bold : FontWeight.normal,
                                  fontStyle: e['tituloItalic'] == true ? FontStyle.italic : FontStyle.normal,
                                  decoration: e['tituloUnderline'] == true ? TextDecoration.underline : TextDecoration.none,
                                  fontSize: config.fontSizeTitulo, 
                                  fontFamily: e['tituloFontFamily'] ?? 'Roboto',
                                  color: config.corTextoTitulo
                                ), 
                                maxLines: 2, overflow: TextOverflow.ellipsis
                              ),
                            ),
                            if (e['mostrarCabecalho'] == true) ...[
                              Icon(Icons.filter_alt_outlined, size: 16, color: config.corTextoTitulo.withOpacity(0.5)),
                              const SizedBox(width: 8),
                              Icon(Icons.more_horiz, size: 16, color: config.corTextoTitulo.withOpacity(0.5)),
                            ]
                          ],
                        ),
                      ),
                      
                      // ÁREA DE RENDERIZAÇÃO
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

            // CONTROLES DE REDIMENSIONAMENTO (Omitidos os códigos longos das 4 bordas para focar no chart. MAS AQUI ESTÃO ELES:)
            Align(alignment: Alignment.centerRight, child: MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: GestureDetector(onPanStart: (_) => _trazerParaFrente(config), onPanUpdate: (d) => setState(() => config.tamanho = Size((config.tamanho.width + d.delta.dx).clamp(minSize, double.infinity), config.tamanho.height)), onPanEnd: (_) => setState(() => config.tamanho = Size(_snap(config.tamanho.width), config.tamanho.height)), child: Container(width: espessuraBorda, height: double.infinity, color: Colors.transparent)))),
            Align(alignment: Alignment.centerLeft, child: MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: GestureDetector(onPanStart: (_) => _trazerParaFrente(config), onPanUpdate: (d) => setState(() { double nW = config.tamanho.width - d.delta.dx; if (nW >= minSize) { config.posicao = Offset(config.posicao.dx + d.delta.dx, config.posicao.dy); config.tamanho = Size(nW, config.tamanho.height); } }), onPanEnd: (_) => setState(() { config.posicao = Offset(_snap(config.posicao.dx), config.posicao.dy); config.tamanho = Size(_snap(config.tamanho.width), config.tamanho.height); }), child: Container(width: espessuraBorda, height: double.infinity, color: Colors.transparent)))),
            Align(alignment: Alignment.bottomCenter, child: MouseRegion(cursor: SystemMouseCursors.resizeUpDown, child: GestureDetector(onPanStart: (_) => _trazerParaFrente(config), onPanUpdate: (d) => setState(() => config.tamanho = Size(config.tamanho.width, (config.tamanho.height + d.delta.dy).clamp(minSize, double.infinity))), onPanEnd: (_) => setState(() => config.tamanho = Size(config.tamanho.width, _snap(config.tamanho.height))), child: Container(width: double.infinity, height: espessuraBorda, color: Colors.transparent)))),
            Align(alignment: Alignment.topCenter, child: MouseRegion(cursor: SystemMouseCursors.resizeUpDown, child: GestureDetector(onPanStart: (_) => _trazerParaFrente(config), onPanUpdate: (d) => setState(() { double nH = config.tamanho.height - d.delta.dy; if (nH >= minSize) { config.posicao = Offset(config.posicao.dx, config.posicao.dy + d.delta.dy); config.tamanho = Size(config.tamanho.width, nH); } }), onPanEnd: (_) => setState(() { config.posicao = Offset(config.posicao.dx, _snap(config.posicao.dy)); config.tamanho = Size(config.tamanho.width, _snap(config.tamanho.height)); }), child: Container(width: double.infinity, height: espessuraBorda, color: Colors.transparent)))),
            Align(alignment: Alignment.bottomRight, child: MouseRegion(cursor: SystemMouseCursors.resizeUpLeftDownRight, child: GestureDetector(onPanStart: (_) => _trazerParaFrente(config), onPanUpdate: (d) => setState(() => config.tamanho = Size((config.tamanho.width + d.delta.dx).clamp(minSize, double.infinity), (config.tamanho.height + d.delta.dy).clamp(minSize, double.infinity))), onPanEnd: (_) => setState(() => config.tamanho = Size(_snap(config.tamanho.width), _snap(config.tamanho.height))), child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.transparent), child: const Center(child: Icon(Icons.signal_cellular_4_bar_rounded, size: 14, color: Color(0xFFE2E8F0))))))),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudoComLegenda(ChartConfig config) {
    Widget chartWidget = Expanded(
      child: LayoutBuilder(builder: (context, constraints) => _renderGraficoMini(config, constraints)),
    );

    if (!config.mostrarLegenda || config.dados.isEmpty) return chartWidget;

    Map<String, dynamic> e = config.configExtra;
    String pos = e['legendaPosicao'] ?? 'bottom';

    Widget legenda = Wrap(
      spacing: 8, runSpacing: 4,
      alignment: WrapAlignment.center,
      direction: (pos == 'left' || pos == 'right') ? Axis.vertical : Axis.horizontal,
      children: config.dados.map((d) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, color: _converterCor(d['color']), margin: const EdgeInsets.only(right: 4)),
          Text(
            d['label'].toString().length > 12 ? '${d['label'].toString().substring(0,12)}...' : d['label'].toString(),
            style: TextStyle(
              fontSize: e['legendaFontSize'] ?? 10.0,
              fontFamily: e['legendaFontFamily'] ?? 'Roboto',
              fontWeight: e['legendaBold'] == true ? FontWeight.bold : FontWeight.normal,
              fontStyle: e['legendaItalic'] == true ? FontStyle.italic : FontStyle.normal,
              decoration: e['legendaUnderline'] == true ? TextDecoration.underline : TextDecoration.none,
              color: _converterCor(e['legendaColor'] ?? '#0F172A'),
            )
          ),
        ],
      )).toList(),
    );

    Widget safeLegenda = Container(
      constraints: BoxConstraints(
        maxHeight: (pos == 'top' || pos == 'bottom') ? 60 : double.infinity,
        maxWidth: (pos == 'left' || pos == 'right') ? 100 : double.infinity,
      ),
      child: SingleChildScrollView(scrollDirection: (pos == 'left' || pos == 'right') ? Axis.vertical : Axis.horizontal, child: legenda),
    );

    if (pos == 'top') return Column(children: [safeLegenda, const SizedBox(height: 8), chartWidget]);
    if (pos == 'bottom') return Column(children: [chartWidget, const SizedBox(height: 8), safeLegenda]);
    if (pos == 'left') return Row(children: [safeLegenda, const SizedBox(width: 8), chartWidget]);
    if (pos == 'right') return Row(children: [chartWidget, const SizedBox(width: 8), safeLegenda]);

    return chartWidget;
  }

  Color _converterCor(dynamic corOrigem) {
    if (corOrigem == 'transparent') return Colors.transparent;
    if (corOrigem is Color) return corOrigem;
    if (corOrigem is String) {
      if (corOrigem.startsWith('#')) return Color(int.parse(corOrigem.replaceFirst('#', '0xFF')));
      int? valorNumerico = int.tryParse(corOrigem);
      if (valorNumerico != null) return Color(valorNumerico);
    }
    if (corOrigem is int) return Color(corOrigem);
    return Colors.blueAccent; 
  }

  // ==========================================
  // RENDERIZAÇÃO DO FL CHART (PIZZA/ROSCA E BARRAS)
  // ==========================================
  Widget _renderGraficoMini(ChartConfig config, BoxConstraints constraints) {
    if (config.dados.isEmpty) return const Center(child: Text("Sem dados"));
    bool isPizzaOuRosca = config.tipo.contains('Pizza') || config.tipo.contains('Rosca');

    if (isPizzaOuRosca) {
      double menorLado = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
      Map<String, dynamic> e = config.configExtra;
      
      double multiplicadorFuro = e['raioFuro'] ?? 0.0;
      bool rotuloFora = e['posicaoRotulo'] == 'fora';
      double raioExterno = (menorLado * (rotuloFora ? 0.25 : 0.35)); 
      
      double total = config.dados.fold(0.0, (sum, item) => sum + (item['value'] as num).toDouble());

      Widget chart = PieChart(
        PieChartData(
          // 9. TOOLTIP INTERATIVO
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                  touchedIndex = -1; return;
                }
                if (e['mostrarTooltip'] == true) {
                  touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                }
              });
            },
          ),
          startDegreeOffset: e['rotacao'] ?? 0.0,
          sectionsSpace: e['espacamento'] ?? 2.0,
          centerSpaceRadius: raioExterno * multiplicadorFuro,
          sections: config.dados.asMap().entries.map((entry) {
            int idx = entry.key;
            var d = entry.value;
            double valorRaw = (d['value'] as num).toDouble();
            bool isTouched = idx == touchedIndex;
            
            // CONTEÚDO E FORMATAÇÃO DO RÓTULO
            String textoExibicao = '';
            String tipoConteudo = e['conteudoRotulo'] ?? 'categoria_percentual';
            String un = e['rotuloUnidades'] ?? 'Auto';
            int dec = e['rotuloDecimais'] ?? 1;
            
            if (tipoConteudo == 'valor') {
              textoExibicao = _formatarNumeroAvancado(valorRaw, un, dec);
            } else if (tipoConteudo == 'percentual') {
              textoExibicao = total > 0 ? '${((valorRaw / total) * 100).toStringAsFixed(dec)}%' : '0%';
            } else if (tipoConteudo == 'categoria') {
              textoExibicao = d['label'].toString();
            } else if (tipoConteudo == 'categoria_percentual') {
              textoExibicao = total > 0 ? '${d['label']}\n${((valorRaw / total) * 100).toStringAsFixed(dec)}%' : d['label'];
            } else if (tipoConteudo == 'categoria_valor') {
              textoExibicao = '${d['label']}\n${_formatarNumeroAvancado(valorRaw, un, dec)}';
            }

            Color corFundoTexto = _converterCor(e['rotuloBgColor'] ?? 'transparent');
            Color corTexto = _converterCor(e['rotuloColor'] ?? '#0F172A');
            if (config.corFundo != Colors.white && corTexto.computeLuminance() < 0.2) corTexto = Colors.white;

            return PieChartSectionData(
              value: valorRaw, 
              color: _converterCor(d['color']), 
              // Aumenta o raio levemente se a fatia for clicada (Efeito Tooltip)
              radius: (raioExterno * (1 - multiplicadorFuro)) + (isTouched ? 10 : 0),
              borderSide: e['mostrarBordaCard'] == true ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
              showTitle: false, 
              badgeWidget: config.mostrarRotulos ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: corFundoTexto, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  textoExibicao, 
                  softWrap: e['rotuloOverflow'] ?? true,
                  style: TextStyle(
                    color: corTexto,
                    fontSize: (e['rotuloFontSize'] ?? 11.0) + (isTouched ? 2 : 0), // Aumenta fonte ao tocar
                    fontFamily: e['rotuloFontFamily'] ?? 'Roboto',
                    fontWeight: e['rotuloBold'] == true ? FontWeight.bold : FontWeight.normal,
                    fontStyle: e['rotuloItalic'] == true ? FontStyle.italic : FontStyle.normal,
                    decoration: e['rotuloUnderline'] == true ? TextDecoration.underline : TextDecoration.none,
                  )
                ),
              ) : null,
              badgePositionPercentageOffset: rotuloFora ? 1.4 : 0.5,
            );
          }).toList(),
        ),
      );

      // 11. TEXTO CENTRAL DA ROSCA
      if (config.tipo.contains('Rosca') && e['mostrarTextoCentral'] == true) {
        String textoCentro = '';
        if (e['textoCentralTipo'] == 'Total') {
          textoCentro = _formatarNumeroAvancado(total, e['rotuloUnidades'] ?? 'Auto', e['rotuloDecimais'] ?? 1);
        } else {
          textoCentro = e['textoCentralCustom'] ?? '';
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            chart,
            Text(
              textoCentro, 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: config.corTextoTitulo),
              textAlign: TextAlign.center,
            )
          ],
        );
      }

      return chart;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: config.dados.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: config.dados.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key, 
            barRods: [
              BarChartRodData(
                toY: (e.value['value'] as num).toDouble(),
                color: _converterCor(e.value['color']),    
                width: constraints.maxWidth / (config.dados.length * 2.5), 
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: config.mostrarValores, 
            reservedSize: 45,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(
                _formatarNumeroAvancado(value, 'Auto', 0), 
                style: TextStyle(fontSize: 10, color: config.corTextoTitulo.withOpacity(0.5)), 
                textAlign: TextAlign.right
              ),
            )
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: config.mostrarRotulos, 
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < config.dados.length) {
                String label = config.dados[value.toInt()]['label'].toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label.length > 7 ? '${label.substring(0, 7)}.' : label, 
                    style: TextStyle(fontSize: 10, color: config.corTextoTitulo.withOpacity(0.5)), 
                    overflow: TextOverflow.ellipsis
                  ),
                );
              }
              return const Text('');
          })),
        ),
        gridData: FlGridData(
          show: config.mostrarEixos, 
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: config.corTextoTitulo.withOpacity(0.05), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}