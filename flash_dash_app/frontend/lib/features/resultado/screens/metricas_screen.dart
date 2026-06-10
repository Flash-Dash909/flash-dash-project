import 'package:flutter/material.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../dashboard/screens/dashboard_canvas_screen.dart';

class MetricasScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String tipoGrafico;
  final String usuarioNome;

  const MetricasScreen({super.key, required this.data, required this.tipoGrafico, required this.usuarioNome});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  String? _dimensaoSelecionada;
  String? _metricaSelecionada;

  // Variáveis de Estado Reais (Controlam a Pré-visualização e o Salvamento)
  String _tituloPersonalizado = "";
  bool _tituloEditadoManualmente = false;
  Color _corFundo = Colors.white;
  double _fontSizeTitulo = 14.0;
  String _alinhamentoTitulo = 'left';
  Color _corTextoTitulo = const Color(0xFF0F172A);
  double _raioBorda = 12.0;
  bool _mostrarSombra = true;
  bool _mostrarEixos = true;
  bool _mostrarLegenda = true;
  String _posicaoLegenda = 'bottom';
  bool _mostrarValores = true; 
  bool _mostrarRotulos = true;
  
  double? _raioFuro; 
  bool _mostrarPorcentagem = false;

  // Lógica de Agrupamento Dinâmico (Group By)
  List<Map<String, dynamic>> _calcularDadosDinamicos(String dimensao, String metrica) {
    List<dynamic> dadosBrutos = widget.data['dados_brutos'] ?? widget.data['dados_planilha']?['dados_brutos'] ?? [];
    if (dadosBrutos.isEmpty) return List<Map<String, dynamic>>.from(widget.data['chart_data'] ?? widget.data['dados_planilha']?['chart_data'] ?? []);

    Map<String, double> agrupamento = {};
    for (var linha in dadosBrutos) {
      String chave = linha[dimensao]?.toString() ?? "Desconhecido";
      double valor = 0.0;
      if (linha[metrica] is num) valor = (linha[metrica] as num).toDouble();
      else if (linha[metrica] is String) valor = double.tryParse(linha[metrica].toString()) ?? 0.0;
      agrupamento[chave] = (agrupamento[chave] ?? 0.0) + valor;
    }

    List<Map<String, dynamic>> novoChartData = [];
    List<Color> paleta = [
      const Color(0xFF2563EB), const Color(0xFF10B981), const Color(0xFFF59E0B),
      const Color(0xFFEF4444), const Color(0xFF8B5CF6), const Color(0xFF14B8A6)
    ];
    int indexCor = 0;
    agrupamento.forEach((key, value) {
      novoChartData.add({"label": key, "value": value, "color": paleta[indexCor % paleta.length]});
      indexCor++;
    });
    
    novoChartData.sort((a, b) => b['value'].compareTo(a['value']));
    return novoChartData.take(6).toList(); 
  }

  // Painel de Edição com Cópias Temporárias (Padrão Power BI)
  void _abrirPainelDeEdicao() {
    TextEditingController tituloController = TextEditingController(text: _tituloPersonalizado);
    
    // Criamos cópias temporárias para o Modal manipular isoladamente
    double tempFontSize = _fontSizeTitulo;
    String tempAlinhamento = _alinhamentoTitulo;
    Color tempCorTexto = _corTextoTitulo;
    Color tempCorFundo = _corFundo;
    double tempRaioBorda = _raioBorda;
    bool tempMostrarSombra = _mostrarSombra;
    bool tempMostrarEixos = _mostrarEixos;
    bool tempMostrarLegenda = _mostrarLegenda;
    String tempPosicaoLegenda = _posicaoLegenda;
    double tempRaioFuro = _raioFuro ?? (widget.tipoGrafico.contains('Rosca') ? 0.6 : 0.0);
    bool tempMostrarPorc = _mostrarPorcentagem;
    bool tempMostrarValores = _mostrarValores;
    bool tempMostrarRotulos = _mostrarRotulos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isPizzaOuRosca = widget.tipoGrafico.contains('Pizza') || widget.tipoGrafico.contains('Rosca');

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                children: [
                  const Text("Formatar Visual", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 1. CABEÇALHO ---
                          const SizedBox(height: 8),
                          const Text("1. Cabeçalho do Gráfico", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: tituloController,
                            decoration: const InputDecoration(labelText: "Texto do Título", border: OutlineInputBorder()),
                            onChanged: (val) => setModalState(() { _tituloPersonalizado = val; _tituloEditadoManualmente = true; }),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text("Alinhamento: "),
                              ToggleButtons(
                                borderRadius: BorderRadius.circular(8),
                                constraints: const BoxConstraints(minHeight: 36, minWidth: 40),
                                isSelected: [tempAlinhamento == 'left', tempAlinhamento == 'center', tempAlinhamento == 'right'],
                                onPressed: (index) => setModalState(() => tempAlinhamento = ['left', 'center', 'right'][index]),
                                children: const [Icon(Icons.format_align_left), Icon(Icons.format_align_center), Icon(Icons.format_align_right)],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text("Tamanho Fonte (${tempFontSize.round()}): "),
                              Expanded(
                                child: Slider(value: tempFontSize, min: 10, max: 24, divisions: 14,
                                  onChanged: (val) => setModalState(() => tempFontSize = val)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text("Cor do Texto: "),
                              _buildBolinha(const Color(0xFF0F172A), tempCorTexto, (c) => tempCorTexto = c, setModalState),
                              _buildBolinha(const Color(0xFF2563EB), tempCorTexto, (c) => tempCorTexto = c, setModalState),
                              _buildBolinha(const Color(0xFFEF4444), tempCorTexto, (c) => tempCorTexto = c, setModalState),
                            ],
                          ),
                          const Divider(height: 32),

                          // --- 2. CARTÃO E EFEITOS ---
                          const Text("2. Cartão e Efeitos Visuais", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text("Cor de Fundo: "),
                              _buildBolinha(Colors.white, tempCorFundo, (c) => tempCorFundo = c, setModalState),
                              _buildBolinha(const Color(0xFFF1F5F9), tempCorFundo, (c) => tempCorFundo = c, setModalState),
                              _buildBolinha(const Color(0xFFEFF6FF), tempCorFundo, (c) => tempCorFundo = c, setModalState),
                              _buildBolinha(const Color(0xFFFFFBEB), tempCorFundo, (c) => tempCorFundo = c, setModalState),
                              _buildBolinha(const Color(0xFF1E293B), tempCorFundo, (c) => tempCorFundo = c, setModalState),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text("Bordas Arredondadas (${tempRaioBorda.round()}): "),
                              Expanded(
                                child: Slider(value: tempRaioBorda, min: 0, max: 32, divisions: 8,
                                  onChanged: (val) => setModalState(() => tempRaioBorda = val)),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Sombra do Cartão"),
                              Switch(value: tempMostrarSombra, activeColor: const Color(0xFF2563EB), onChanged: (val) => setModalState(() => tempMostrarSombra = val)),
                            ],
                          ),
                          const Divider(height: 32),

                          // --- 3. EIXOS E LEGENDA ---
                          const Text("3. Rótulos e Legenda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                          
                          // NOVOS CONTROLES DE VALORES E RÓTULOS:
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Mostrar Números (Valores)"),
                              Switch(value: tempMostrarValores, activeColor: const Color(0xFF2563EB), onChanged: (val) => setModalState(() => tempMostrarValores = val)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Mostrar Nomes (Categorias)"),
                              Switch(value: tempMostrarRotulos, activeColor: const Color(0xFF2563EB), onChanged: (val) => setModalState(() => tempMostrarRotulos = val)),
                            ],
                          ),

                          if (!isPizzaOuRosca)

                          const Text("3. Eixos e Legenda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                          if (!isPizzaOuRosca)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Mostrar Eixos (X e Y)"),
                                Switch(value: tempMostrarEixos, activeColor: const Color(0xFF2563EB), onChanged: (val) => setModalState(() => tempMostrarEixos = val)),
                              ],
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Mostrar Legenda"),
                              Switch(value: tempMostrarLegenda, activeColor: const Color(0xFF2563EB), onChanged: (val) => setModalState(() => tempMostrarLegenda = val)),
                            ],
                          ),
                          if (tempMostrarLegenda)
                            Wrap(
                              spacing: 8,
                              children: ['top', 'bottom', 'left', 'right'].map((pos) {
                                return ChoiceChip(
                                  label: Text(pos.toUpperCase()), 
                                  selected: tempPosicaoLegenda == pos, 
                                  onSelected: (val) => setModalState(() => tempPosicaoLegenda = pos)
                                );
                              }).toList(),
                            ),
                          const Divider(height: 32),

                          // --- 4. ESPECÍFICO (PIZZA) ---
                          if (isPizzaOuRosca) ...[
                            const Text("4. Configurações da Pizza/Rosca", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Formato dos Dados"),
                                ToggleButtons(
                                  borderRadius: BorderRadius.circular(8),
                                  isSelected: [!tempMostrarPorc, tempMostrarPorc],
                                  onPressed: (index) => setModalState(() => tempMostrarPorc = index == 1),
                                  children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("123")), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("%"))],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text("Abertura Central (Rosca)"),
                            Slider(value: tempRaioFuro, min: 0.0, max: 0.8, activeColor: const Color(0xFF10B981), onChanged: (val) => setModalState(() => tempRaioFuro = val)),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  
                  // BOTÃO APLICAR: DEVOLVE AS ALTERAÇÕES À TELA PRINCIPAL
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        setState(() {
                          _fontSizeTitulo = tempFontSize;
                          _alinhamentoTitulo = tempAlinhamento;
                          _corTextoTitulo = tempCorTexto;
                          _corFundo = tempCorFundo;
                          _raioBorda = tempRaioBorda;
                          _mostrarSombra = tempMostrarSombra;
                          _mostrarEixos = tempMostrarEixos;
                          _mostrarLegenda = tempMostrarLegenda;
                          _posicaoLegenda = tempPosicaoLegenda;
                          _raioFuro = tempRaioFuro;
                          _mostrarPorcentagem = tempMostrarPorc;
                          _mostrarValores = tempMostrarValores;
                          _mostrarRotulos = tempMostrarRotulos;
                        }); 
                        Navigator.pop(context);
                      },
                      child: const Text("Aplicar Configurações", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildBolinha(Color cor, Color ativa, Function(Color) updateTarget, StateSetter setModalState) {
    return GestureDetector(
      onTap: () => setModalState(() => updateTarget(cor)),
      child: Container(
        margin: const EdgeInsets.only(right: 8, left: 8),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: cor, 
          shape: BoxShape.circle, 
          border: Border.all(color: ativa == cor ? const Color(0xFF2563EB) : Colors.grey.shade300, width: ativa == cor ? 3 : 1)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> dimensoes = widget.data['summary']?['dimensoes'] ?? widget.data['dados_planilha']?['summary']?['dimensoes'] ?? [];
    List<dynamic> metricas = widget.data['summary']?['metricas'] ?? widget.data['dados_planilha']?['summary']?['metricas'] ?? [];

    String dim = _dimensaoSelecionada ?? (dimensoes.isNotEmpty ? dimensoes[0].toString() : "Categoria");
    String met = _metricaSelecionada ?? (metricas.isNotEmpty ? metricas[0].toString() : "Valor");
    
    if (!_tituloEditadoManualmente) {
      _tituloPersonalizado = "$met por $dim";
    }

    List<Map<String, dynamic>> dadosPreview = _calcularDadosDinamicos(dim, met);
    bool isDesktop = MediaQuery.of(context).size.width >= 800;

    TextAlign alignPreview = _alinhamentoTitulo == 'center' 
        ? TextAlign.center 
        : (_alinhamentoTitulo == 'right' ? TextAlign.right : TextAlign.left);

    return Scaffold(
      appBar: AppBar(title: Text('Criar ${widget.tipoGrafico}')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // PAINEL DA ESQUERDA: DROP DOWNS
              Container(
                width: isDesktop ? 400 : double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.tune_rounded, size: 40, color: Color(0xFF2563EB)),
                    const SizedBox(height: 16),
                    const Text("Dados do Gráfico", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    const Text("Eixo X (Dimensão)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: dimensoes.contains(dim) ? dim : null,
                      items: dimensoes.map((d) => DropdownMenuItem(value: d.toString(), child: Text(d.toString()))).toList(),
                      onChanged: (val) => setState(() => _dimensaoSelecionada = val),
                    ),
                    const SizedBox(height: 24),
                    const Text("Eixo Y (Métrica)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: metricas.contains(met) ? met : null,
                      items: metricas.map((m) => DropdownMenuItem(value: m.toString(), child: Text(m.toString()))).toList(),
                      onChanged: (val) => setState(() => _metricaSelecionada = val),
                    ),
                  ],
                ),
              ),

              if (isDesktop) const SizedBox(width: 32) else const SizedBox(height: 24),

              // PAINEL DA DIREITA: LIVE PREVIEW TOTALMENTE DINÂMICO
              Container(
                width: isDesktop ? 500 : double.infinity,
                decoration: BoxDecoration(
                  color: _corFundo, // Fundo dinâmico
                  borderRadius: BorderRadius.circular(_raioBorda), // Bordas dinâmicas
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: _mostrarSombra 
                      ? const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))] 
                      : [], // Sombra dinâmica
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _tituloPersonalizado, 
                              textAlign: alignPreview, // Alinhamento dinâmico
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: _fontSizeTitulo, // Fonte dinâmica
                                color: _corTextoTitulo // Cor de texto dinâmica
                              ), 
                              overflow: TextOverflow.ellipsis
                            )
                          ),
                          TextButton.icon(
                            onPressed: _abrirPainelDeEdicao,
                            icon: const Icon(Icons.brush, size: 16),
                            label: const Text("Editar Visual"),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    Container(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.remove_red_eye_outlined, color: _corTextoTitulo.withOpacity(0.5), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Pré-visualização Ativa\nO cartão acima já reflete o design final.", 
                              textAlign: TextAlign.center, 
                              style: TextStyle(color: _corTextoTitulo.withOpacity(0.6))
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          DashboardManager.graficosAtivos.add(
                            ChartConfig(
                              id: DateTime.now().millisecondsSinceEpoch.toString(), 
                              tipo: widget.tipoGrafico,
                              titulo: _tituloPersonalizado,
                              dimensao: dim,
                              metrica: met,
                              dados: dadosPreview,
                              posicao: const Offset(50, 50),
                              
                              // PASSANDO AS CONFIGURAÇÕES REAIS PARA O CANVAS
                              corFundo: _corFundo,
                              fontSizeTitulo: _fontSizeTitulo,
                              alinhamentoTitulo: _alinhamentoTitulo,
                              corTextoTitulo: _corTextoTitulo,
                              raioBorda: _raioBorda,
                              mostrarSombra: _mostrarSombra,
                              mostrarEixos: _mostrarEixos,
                              mostrarLegenda: _mostrarLegenda,
                              posicaoLegenda: _posicaoLegenda,
                              mostrarValores: _mostrarValores,
                              mostrarRotulos: _mostrarRotulos,
                              
                              
                              configExtra: {
                                'raioFuro': _raioFuro ?? (widget.tipoGrafico.contains('Rosca') ? 0.6 : 0.0),
                                'mostrarPorcentagem': _mostrarPorcentagem,
                                'espessuraFatia': 1.0,
                              }
                            )
                          );
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardCanvasScreen(usuarioNome: widget.usuarioNome)));
                        },
                        icon: const Icon(Icons.check),
                        label: const Text("Adicionar ao Dashboard", style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}