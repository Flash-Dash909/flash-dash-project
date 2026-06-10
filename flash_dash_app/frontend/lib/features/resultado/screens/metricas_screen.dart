import 'package:flutter/material.dart';

import '../../dashboard/dashboard_manager.dart';
import '../../dashboard/screens/dashboard_canvas_screen.dart';
import '../../dashboard/widgets/chart_renderer.dart';

class MetricasScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String tipoGrafico;

  const MetricasScreen({
    super.key,
    required this.data,
    required this.tipoGrafico,
  });

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  String? _dimensaoSelecionada;
  String? _metricaSelecionada;
  String _agregacao = 'Soma';
  int _limiteItens = 8;
  bool _ordenarDesc = true;

  String _tituloPersonalizado = "";
  bool _tituloEditadoManualmente = false;
  Color _corFundo = Colors.white;
  Color _corTextoTitulo = const Color(0xFF0F172A);
  double _fontSizeTitulo = 14.0;
  String _alinhamentoTitulo = 'left';
  double _raioBorda = 12.0;
  bool _mostrarSombra = true;
  bool _mostrarEixos = true;
  bool _mostrarLegenda = true;
  String _posicaoLegenda = 'bottom';
  bool _mostrarValores = true;
  bool _mostrarRotulos = true;
  bool _mostrarPontos = true;
  double _espessuraLinha = 3.0;
  double _raioFuro = 0.0;
  bool _mostrarPorcentagem = false;

  List<dynamic> get _dadosBrutos =>
      widget.data['dados_brutos'] ??
      widget.data['dados_planilha']?['dados_brutos'] ??
      [];

  Map<String, dynamic> get _summary => Map<String, dynamic>.from(
    widget.data['summary'] ?? widget.data['dados_planilha']?['summary'] ?? {},
  );

  bool get _isPizzaOuRosca =>
      widget.tipoGrafico.contains('Pizza') ||
      widget.tipoGrafico.contains('Rosca');
  bool get _isLinhaOuArea =>
      widget.tipoGrafico.contains('Linha') ||
      widget.tipoGrafico.contains('Área');

  @override
  void initState() {
    super.initState();
    _raioFuro = widget.tipoGrafico.contains('Rosca') ? 0.58 : 0.0;
  }

  List<Map<String, dynamic>> _calcularDadosDinamicos(
    String dimensao,
    String metrica,
  ) {
    final dadosBrutos = _dadosBrutos;
    if (dadosBrutos.isEmpty) {
      return List<Map<String, dynamic>>.from(
        widget.data['chart_data'] ??
            widget.data['dados_planilha']?['chart_data'] ??
            [],
      );
    }

    final agrupamento = <String, List<double>>{};
    for (final linha in dadosBrutos) {
      final chave = linha[dimensao]?.toString().trim().isNotEmpty == true
          ? linha[dimensao].toString()
          : "Desconhecido";
      final raw = linha[metrica];
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

    final dados = agrupamento.entries.map((entry) {
      final valores = entry.value;
      final soma = valores.fold<double>(0, (total, valor) => total + valor);
      final valor = switch (_agregacao) {
        'Média' => soma / valores.length,
        'Contagem' => valores.length.toDouble(),
        'Máximo' => valores.reduce((a, b) => a > b ? a : b),
        'Mínimo' => valores.reduce((a, b) => a < b ? a : b),
        _ => soma,
      };
      final index = agrupamento.keys.toList().indexOf(entry.key);
      return {
        "label": entry.key,
        "value": valor,
        "color": paleta[index % paleta.length],
      };
    }).toList();

    dados.sort((a, b) {
      final valorA = (a['value'] as num).toDouble();
      final valorB = (b['value'] as num).toDouble();
      return _ordenarDesc ? valorB.compareTo(valorA) : valorA.compareTo(valorB);
    });
    return dados.take(_limiteItens).toList();
  }

  ChartConfig _criarConfigPreview(String dim, String met) {
    final titulo = _tituloPersonalizado.isEmpty
        ? "$met por $dim"
        : _tituloPersonalizado;
    return ChartConfig(
      id: 'preview',
      tipo: widget.tipoGrafico,
      titulo: titulo,
      dimensao: dim,
      metrica: met,
      dados: _calcularDadosDinamicos(dim, met),
      posicao: const Offset(50, 50),
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
        'agregacao': _agregacao,
        'limiteItens': _limiteItens,
        'ordenarDesc': _ordenarDesc,
        'mostrarPontos': _mostrarPontos,
        'espessuraLinha': _espessuraLinha,
        'raioFuro': _raioFuro,
        'mostrarPorcentagem': _mostrarPorcentagem,
      },
    );
  }

  void _abrirPainelDeEdicao() {
    final tituloController = TextEditingController(text: _tituloPersonalizado);

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
                        children: [
                          _secao("Dados", [
                            _dropdown(
                              "Agregação",
                              _agregacao,
                              ['Soma', 'Média', 'Contagem', 'Máximo', 'Mínimo'],
                              (v) => setModalState(() => _agregacao = v),
                            ),
                            _slider(
                              "Quantidade de categorias",
                              _limiteItens.toDouble(),
                              3,
                              20,
                              (v) =>
                                  setModalState(() => _limiteItens = v.round()),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Ordenar do maior para o menor",
                              ),
                              value: _ordenarDesc,
                              onChanged: (v) =>
                                  setModalState(() => _ordenarDesc = v),
                            ),
                          ]),
                          _secao("Título", [
                            TextField(
                              controller: tituloController,
                              decoration: const InputDecoration(
                                labelText: "Texto do título",
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                              onChanged: (v) => setModalState(() {
                                _tituloPersonalizado = v;
                                _tituloEditadoManualmente = true;
                              }),
                            ),
                            _slider(
                              "Tamanho do título",
                              _fontSizeTitulo,
                              10,
                              28,
                              (v) => setModalState(() => _fontSizeTitulo = v),
                            ),
                            _segmented(
                              "Alinhamento",
                              _alinhamentoTitulo,
                              const {
                                'left': Icons.format_align_left,
                                'center': Icons.format_align_center,
                                'right': Icons.format_align_right,
                              },
                              (v) =>
                                  setModalState(() => _alinhamentoTitulo = v),
                            ),
                            _cores(
                              "Cor do título",
                              _corTextoTitulo,
                              [
                                const Color(0xFF0F172A),
                                const Color(0xFF2563EB),
                                const Color(0xFFEF4444),
                                Colors.white,
                              ],
                              (c) => setModalState(() => _corTextoTitulo = c),
                            ),
                          ]),
                          _secao("Cartão", [
                            _cores(
                              "Fundo",
                              _corFundo,
                              [
                                Colors.white,
                                const Color(0xFFF8FAFC),
                                const Color(0xFFEFF6FF),
                                const Color(0xFFFFFBEB),
                                const Color(0xFF1E293B),
                              ],
                              (c) => setModalState(() => _corFundo = c),
                            ),
                            _slider(
                              "Raio da borda",
                              _raioBorda,
                              0,
                              32,
                              (v) => setModalState(() => _raioBorda = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Sombra"),
                              value: _mostrarSombra,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarSombra = v),
                            ),
                          ]),
                          _secao("Eixos, rótulos e legenda", [
                            if (!_isPizzaOuRosca)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar eixos e grade"),
                                value: _mostrarEixos,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarEixos = v),
                              ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar valores"),
                              value: _mostrarValores,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarValores = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar rótulos"),
                              value: _mostrarRotulos,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarRotulos = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar legenda"),
                              value: _mostrarLegenda,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarLegenda = v),
                            ),
                            if (_mostrarLegenda)
                              _dropdown(
                                "Posição da legenda",
                                _posicaoLegenda,
                                ['top', 'bottom', 'left', 'right'],
                                (v) => setModalState(() => _posicaoLegenda = v),
                              ),
                          ]),
                          if (_isLinhaOuArea)
                            _secao("Linha e área", [
                              _slider(
                                "Espessura da linha",
                                _espessuraLinha,
                                1,
                                8,
                                (v) => setModalState(() => _espessuraLinha = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar marcadores"),
                                value: _mostrarPontos,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarPontos = v),
                              ),
                            ]),
                          if (_isPizzaOuRosca)
                            _secao("Pizza e rosca", [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  "Exibir valores em porcentagem",
                                ),
                                value: _mostrarPorcentagem,
                                onChanged: (v) => setModalState(
                                  () => _mostrarPorcentagem = v,
                                ),
                              ),
                              _slider(
                                "Abertura central",
                                _raioFuro,
                                0,
                                0.82,
                                (v) => setModalState(() => _raioFuro = v),
                              ),
                            ]),
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
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: const Text("Aplicar configurações"),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => tituloController.dispose());
  }

  Widget _secao(String titulo, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text("$label: ${value.toStringAsFixed(max <= 1 ? 2 : 0)}"),
        ),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _segmented(
    String label,
    String value,
    Map<String, IconData> options,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          isSelected: options.keys.map((key) => key == value).toList(),
          onPressed: (index) => onChanged(options.keys.elementAt(index)),
          children: options.values
              .map(
                (icon) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(icon),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _cores(
    String label,
    Color ativa,
    List<Color> cores,
    ValueChanged<Color> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Wrap(
          spacing: 10,
          children: cores.map((cor) {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(cor),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ativa == cor
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFCBD5E1),
                    width: ativa == cor ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimensoes = List<dynamic>.from(_summary['dimensoes'] ?? []);
    final metricas = List<dynamic>.from(_summary['metricas'] ?? []);

    final dim =
        _dimensaoSelecionada ??
        (dimensoes.isNotEmpty ? dimensoes[0].toString() : "Categoria");
    final met =
        _metricaSelecionada ??
        (metricas.isNotEmpty ? metricas[0].toString() : "Valor");

    if (!_tituloEditadoManualmente) {
      _tituloPersonalizado = "$met por $dim";
    }

    final configPreview = _criarConfigPreview(dim, met);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final alignPreview = _alinhamentoTitulo == 'center'
        ? TextAlign.center
        : (_alinhamentoTitulo == 'right' ? TextAlign.right : TextAlign.left);

    return Scaffold(
      appBar: AppBar(title: Text('Criar ${widget.tipoGrafico}')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Flex(
          direction: isDesktop ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isDesktop ? 390 : double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Dados do gráfico",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: dimensoes.contains(dim) ? dim : null,
                    decoration: const InputDecoration(labelText: "Dimensão"),
                    items: dimensoes
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.toString(),
                            child: Text(d.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _dimensaoSelecionada = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: metricas.contains(met) ? met : null,
                    decoration: const InputDecoration(labelText: "Métrica"),
                    items: metricas
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.toString(),
                            child: Text(m.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _metricaSelecionada = val),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _abrirPainelDeEdicao,
                    icon: const Icon(Icons.brush_rounded),
                    label: const Text("Personalizar visual"),
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 32 : 0, height: isDesktop ? 0 : 24),
            Expanded(
              flex: isDesktop ? 1 : 0,
              child: Container(
                constraints: const BoxConstraints(minHeight: 460),
                decoration: BoxDecoration(
                  color: _corFundo,
                  borderRadius: BorderRadius.circular(_raioBorda),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: _mostrarSombra
                      ? const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              configPreview.titulo,
                              textAlign: alignPreview,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _fontSizeTitulo,
                                color: _corTextoTitulo,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _abrirPainelDeEdicao,
                            icon: const Icon(Icons.brush, size: 16),
                            label: const Text("Editar"),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 310,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: ChartRenderer(config: configPreview),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          DashboardManager.graficosAtivos.add(
                            configPreview
                              ..id = DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                          );
                          DashboardManager.dadosFonteAtual = widget.data;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DashboardCanvasScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text(
                          "Adicionar ao Dashboard",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
