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
  bool _mostrarTitulo = true;
  bool _tituloNegrito = true;
  bool _tituloItalico = false;
  bool _tituloSublinhado = false;
  bool _mostrarSubtitulo = false;
  String _subtitulo = '';
  double _subtituloSize = 12.0;
  Color _subtituloColor = const Color(0xFF64748B);
  String _descricao = '';
  Color _corFundo = Colors.white;
  double _backgroundOpacity = 1.0;
  Color _corTextoTitulo = const Color(0xFF0F172A);
  double _fontSizeTitulo = 14.0;
  String _alinhamentoTitulo = 'left';
  double _raioBorda = 12.0;
  bool _mostrarBorda = true;
  Color _corBorda = const Color(0xFFE2E8F0);
  bool _mostrarSombra = true;
  double _shadowOpacity = 0.12;
  double _shadowBlur = 10.0;
  double _minWidth = 200.0;
  double _minHeight = 200.0;
  bool _mostrarEixos = true;
  bool _mostrarLegenda = true;
  String _posicaoLegenda = 'bottom';
  bool _mostrarValores = true;
  bool _mostrarRotulos = true;
  bool _mostrarPontos = true;
  double _espessuraLinha = 3.0;
  double _raioFuro = 0.0;
  bool _mostrarPorcentagem = false;
  double _gaugeMin = 0.0;
  double _gaugeMax = 100.0;
  double _gaugeMeta = 80.0;
  String _kpiPrefixo = '';
  String _kpiSufixo = '';
  int _kpiDecimais = 0;
  double _kpiFontSize = 44.0;
  Color _corPrincipal = const Color(0xFF2563EB);
  Color _headerTabela = const Color(0xFF1D4ED8);
  Color _totalTabela = const Color(0xFFFDE047);
  Color _rowTabelaA = Colors.white;
  Color _rowTabelaB = const Color(0xFFF1F5F9);
  Color _gridTabela = const Color(0xFFE2E8F0);
  double _chipRadius = 8.0;
  bool _segmentacaoMultipla = true;
  String _slicerStyle = 'botoes';
  bool _slicerSearch = false;
  double _contentPadding = 8.0;
  double _plotPadding = 6.0;
  double _borderWidth = 1.0;
  double _rowHeight = 34.0;
  double _barGap = 0.04;
  double _barOpacity = 1.0;
  double _barBorderWidth = 0.0;
  String _barColorMode = 'categoria';
  Color _lineColor = const Color(0xFF2563EB);
  double _markerSize = 4.0;
  double _sliceOpacity = 1.0;
  bool _gaugeRanges = false;
  bool _kpiShowMeta = false;
  double _kpiMeta = 0.0;
  bool _kpiShowTrend = false;
  double _kpiPrevious = 0.0;
  double _treemapSpacing = 0.0;
  bool _tooltipEnabled = true;
  bool _interactionFilter = true;
  bool _interactionHighlight = true;
  bool _interactionDrillthrough = false;
  bool _interactionNavigation = false;
  String _animationIn = 'instantanea';
  String _animationUpdate = 'suave';
  bool _exportPng = true;
  bool _exportPdf = false;
  bool _exportCsv = true;
  bool _exportExcel = false;
  String _themePreset = 'manual';

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
      widget.tipoGrafico.contains('Area');

  bool get _isGauge => widget.tipoGrafico.contains('Gauge');
  bool get _isKpi =>
      widget.tipoGrafico.contains('KPI') ||
      widget.tipoGrafico.contains('Cartao');
  bool get _isTabela => widget.tipoGrafico.contains('Tabela');
  bool get _isSegmentacao => widget.tipoGrafico.contains('Segment');
  bool get _isTreemap => widget.tipoGrafico.contains('Treemap');
  bool get _usaLegenda =>
      !(_isKpi || _isTabela || _isSegmentacao || _isGauge || _isTreemap);
  bool get _usaEixos =>
      widget.tipoGrafico.contains('Barra') ||
      widget.tipoGrafico.contains('Coluna') ||
      _isLinhaOuArea ||
      widget.tipoGrafico.contains('Dispers');

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
        'Media' => soma / valores.length,
        'Contagem' => valores.length.toDouble(),
        'Maximo' => valores.reduce((a, b) => a > b ? a : b),
        'Minimo' => valores.reduce((a, b) => a < b ? a : b),
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
        'showTitle': _mostrarTitulo,
        'titleBold': _tituloNegrito,
        'titleItalic': _tituloItalico,
        'titleUnderline': _tituloSublinhado,
        'showSubtitle': _mostrarSubtitulo,
        'subtitleText': _subtitulo,
        'subtitleSize': _subtituloSize,
        'subtitleColor': _subtituloColor.value.toString(),
        'descriptionText': _descricao,
        'backgroundOpacity': _backgroundOpacity,
        'borderVisible': _mostrarBorda,
        'borderColor': _corBorda.value.toString(),
        'shadowOpacity': _shadowOpacity,
        'shadowBlur': _shadowBlur,
        'minWidth': _minWidth,
        'minHeight': _minHeight,
        'raioFuro': _raioFuro,
        'mostrarPorcentagem': _mostrarPorcentagem,
        'gaugeMin': _gaugeMin,
        'gaugeMax': _gaugeMax,
        'gaugeMeta': _gaugeMeta,
        'prefixo': _kpiPrefixo,
        'sufixo': _kpiSufixo,
        'decimais': _kpiDecimais,
        'kpiFontSize': _kpiFontSize,
        'corPrincipal': _corPrincipal.value.toString(),
        'corMeta': const Color(0xFFEF4444).value.toString(),
        'headerColor': _headerTabela.value.toString(),
        'totalColor': _totalTabela.value.toString(),
        'rowColorA': _rowTabelaA.value.toString(),
        'rowColorB': _rowTabelaB.value.toString(),
        'gridColor': _gridTabela.value.toString(),
        'rowHeight': _rowHeight,
        'chipRadius': _chipRadius,
        'segmentacaoMultipla': _segmentacaoMultipla,
        'slicerStyle': _slicerStyle,
        'slicerSearch': _slicerSearch,
        'contentPadding': _contentPadding,
        'plotPadding': _plotPadding,
        'borderWidth': _borderWidth,
        'barGap': _barGap,
        'barOpacity': _barOpacity,
        'barBorderWidth': _barBorderWidth,
        'barColorMode': _barColorMode,
        'lineColor': _lineColor.value.toString(),
        'markerSize': _markerSize,
        'sliceOpacity': _sliceOpacity,
        'gaugeMostrarFaixas': _gaugeRanges,
        'kpiShowMeta': _kpiShowMeta,
        'kpiMeta': _kpiMeta,
        'kpiShowTrend': _kpiShowTrend,
        'kpiPrevious': _kpiPrevious,
        'treemapSpacing': _treemapSpacing,
        'tooltipEnabled': _tooltipEnabled,
        'interactionFilter': _interactionFilter,
        'interactionHighlight': _interactionHighlight,
        'interactionDrillthrough': _interactionDrillthrough,
        'interactionNavigation': _interactionNavigation,
        'animationIn': _animationIn,
        'animationUpdate': _animationUpdate,
        'exportPng': _exportPng,
        'exportPdf': _exportPdf,
        'exportCsv': _exportCsv,
        'exportExcel': _exportExcel,
        'themePreset': _themePreset,
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
                              "Agregacao",
                              _agregacao,
                              ['Soma', 'Media', 'Contagem', 'Maximo', 'Minimo'],
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
                          _secao("Aparencia", [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Exibir titulo"),
                              value: _mostrarTitulo,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarTitulo = v),
                            ),
                            TextField(
                              controller: tituloController,
                              decoration: const InputDecoration(
                                labelText: "Texto do titulo",
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                              onChanged: (v) => setModalState(() {
                                _tituloPersonalizado = v;
                                _tituloEditadoManualmente = true;
                              }),
                            ),
                            _slider(
                              "Tamanho do titulo",
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
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text("Negrito"),
                                  selected: _tituloNegrito,
                                  onSelected: (v) =>
                                      setModalState(() => _tituloNegrito = v),
                                ),
                                FilterChip(
                                  label: const Text("Italico"),
                                  selected: _tituloItalico,
                                  onSelected: (v) =>
                                      setModalState(() => _tituloItalico = v),
                                ),
                                FilterChip(
                                  label: const Text("Sublinhado"),
                                  selected: _tituloSublinhado,
                                  onSelected: (v) => setModalState(
                                    () => _tituloSublinhado = v,
                                  ),
                                ),
                              ],
                            ),
                            _cores(
                              "Cor do titulo",
                              _corTextoTitulo,
                              [
                                const Color(0xFF0F172A),
                                const Color(0xFF2563EB),
                                const Color(0xFFEF4444),
                                Colors.white,
                              ],
                              (c) => setModalState(() => _corTextoTitulo = c),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Exibir subtitulo"),
                              value: _mostrarSubtitulo,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarSubtitulo = v),
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Texto do subtitulo",
                              ),
                              onChanged: (v) =>
                                  setModalState(() => _subtitulo = v),
                            ),
                            _slider(
                              "Tamanho do subtitulo",
                              _subtituloSize,
                              9,
                              22,
                              (v) => setModalState(() => _subtituloSize = v),
                            ),
                            _cores(
                              "Cor do subtitulo",
                              _subtituloColor,
                              [
                                const Color(0xFF64748B),
                                const Color(0xFF2563EB),
                                const Color(0xFF0F172A),
                                const Color(0xFFEF4444),
                              ],
                              (c) => setModalState(() => _subtituloColor = c),
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "Descricao / tooltip",
                              ),
                              onChanged: (v) =>
                                  setModalState(() => _descricao = v),
                            ),
                          ]),
                          _secao("Avancado", [
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
                              "Transparencia do fundo",
                              1 - _backgroundOpacity,
                              0,
                              1,
                              (v) => setModalState(
                                () => _backgroundOpacity = 1 - v,
                              ),
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
                              title: const Text("Exibir borda"),
                              value: _mostrarBorda,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarBorda = v),
                            ),
                            _cores(
                              "Cor da borda",
                              _corBorda,
                              [
                                const Color(0xFFE2E8F0),
                                const Color(0xFF2563EB),
                                const Color(0xFF0F172A),
                                const Color(0xFFEF4444),
                              ],
                              (c) => setModalState(() => _corBorda = c),
                            ),
                            _slider(
                              "Borda do cartao",
                              _borderWidth,
                              0,
                              8,
                              (v) => setModalState(() => _borderWidth = v),
                            ),
                            _slider(
                              "Espacamento interno",
                              _contentPadding,
                              0,
                              32,
                              (v) => setModalState(() => _contentPadding = v),
                            ),
                            _slider(
                              "Margem interna do grafico",
                              _plotPadding,
                              0,
                              28,
                              (v) => setModalState(() => _plotPadding = v),
                            ),
                            _slider(
                              "Largura minima",
                              _minWidth,
                              120,
                              500,
                              (v) => setModalState(() => _minWidth = v),
                            ),
                            _slider(
                              "Altura minima",
                              _minHeight,
                              120,
                              500,
                              (v) => setModalState(() => _minHeight = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Sombra"),
                              value: _mostrarSombra,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarSombra = v),
                            ),
                            _slider(
                              "Opacidade da sombra",
                              _shadowOpacity,
                              0,
                              1,
                              (v) => setModalState(() => _shadowOpacity = v),
                            ),
                            _slider(
                              "Desfoque da sombra",
                              _shadowBlur,
                              0,
                              40,
                              (v) => setModalState(() => _shadowBlur = v),
                            ),
                          ]),
                          if (_usaLegenda)
                            _secao("Legenda", [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar legenda"),
                                value: _mostrarLegenda,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarLegenda = v),
                              ),
                              if (_mostrarLegenda)
                                _dropdown(
                                  "Posicao da legenda",
                                  _posicaoLegenda,
                                  ['top', 'bottom', 'left', 'right'],
                                  (v) =>
                                      setModalState(() => _posicaoLegenda = v),
                                ),
                            ]),
                          _secao("Rotulos", [
                            if (!_isSegmentacao)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar valores"),
                                value: _mostrarValores,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarValores = v),
                              ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Mostrar rotulos"),
                              value: _mostrarRotulos,
                              onChanged: (v) =>
                                  setModalState(() => _mostrarRotulos = v),
                            ),
                          ]),
                          if (_usaEixos)
                            _secao("Eixos", [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar eixos e grade"),
                                value: _mostrarEixos,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarEixos = v),
                              ),
                              _dropdown("Escala", 'linear', [
                                'linear',
                                'log',
                              ], (_) {}),
                            ]),
                          if (_isLinhaOuArea)
                            _secao("Linha e area", [
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
                          if (widget.tipoGrafico.contains('Barra') ||
                              widget.tipoGrafico.contains('Coluna'))
                            _secao("Barras e colunas", [
                              _dropdown(
                                "Cores",
                                _barColorMode,
                                ['categoria', 'unica'],
                                (v) => setModalState(() => _barColorMode = v),
                              ),
                              _slider(
                                "Transparencia",
                                1 - _barOpacity,
                                0,
                                0.9,
                                (v) => setModalState(() => _barOpacity = 1 - v),
                              ),
                              _slider(
                                "Espacamento",
                                _barGap,
                                0,
                                0.18,
                                (v) => setModalState(() => _barGap = v),
                              ),
                              _slider(
                                "Espessura da borda",
                                _barBorderWidth,
                                0,
                                6,
                                (v) => setModalState(() => _barBorderWidth = v),
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
                              _slider(
                                "Transparencia das fatias",
                                1 - _sliceOpacity,
                                0,
                                0.9,
                                (v) =>
                                    setModalState(() => _sliceOpacity = 1 - v),
                              ),
                            ]),
                          if (_isKpi)
                            _secao("Cartao KPI", [
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: "Prefixo",
                                  hintText: r"R$",
                                ),
                                onChanged: (v) =>
                                    setModalState(() => _kpiPrefixo = v),
                              ),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: "Sufixo",
                                  hintText: " Mil",
                                ),
                                onChanged: (v) =>
                                    setModalState(() => _kpiSufixo = v),
                              ),
                              _slider(
                                "Casas decimais",
                                _kpiDecimais.toDouble(),
                                0,
                                3,
                                (v) => setModalState(
                                  () => _kpiDecimais = v.round(),
                                ),
                              ),
                              _slider(
                                "Tamanho do numero",
                                _kpiFontSize,
                                24,
                                72,
                                (v) => setModalState(() => _kpiFontSize = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar meta"),
                                value: _kpiShowMeta,
                                onChanged: (v) =>
                                    setModalState(() => _kpiShowMeta = v),
                              ),
                              _slider(
                                "Meta",
                                _kpiMeta,
                                0,
                                10000000,
                                (v) => setModalState(() => _kpiMeta = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar tendencia"),
                                value: _kpiShowTrend,
                                onChanged: (v) =>
                                    setModalState(() => _kpiShowTrend = v),
                              ),
                              _slider(
                                "Valor anterior",
                                _kpiPrevious,
                                0,
                                10000000,
                                (v) => setModalState(() => _kpiPrevious = v),
                              ),
                            ]),
                          if (_isGauge)
                            _secao("Gauge", [
                              _slider(
                                "Valor minimo",
                                _gaugeMin,
                                0,
                                100000,
                                (v) => setModalState(() => _gaugeMin = v),
                              ),
                              _slider(
                                "Valor maximo",
                                _gaugeMax,
                                1,
                                1000000,
                                (v) => setModalState(() => _gaugeMax = v),
                              ),
                              _slider(
                                "Meta",
                                _gaugeMeta,
                                0,
                                1000000,
                                (v) => setModalState(() => _gaugeMeta = v),
                              ),
                              _cores(
                                "Cor principal",
                                _corPrincipal,
                                [
                                  const Color(0xFF2563EB),
                                  const Color(0xFF10B981),
                                  const Color(0xFFF59E0B),
                                  const Color(0xFFEF4444),
                                ],
                                (c) => setModalState(() => _corPrincipal = c),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar faixas"),
                                value: _gaugeRanges,
                                onChanged: (v) =>
                                    setModalState(() => _gaugeRanges = v),
                              ),
                            ]),
                          if (_isTabela)
                            _secao("Tabela", [
                              _cores(
                                "Cabecalho",
                                _headerTabela,
                                [
                                  const Color(0xFF1D4ED8),
                                  const Color(0xFF1E1B4B),
                                  const Color(0xFF0F5592),
                                  const Color(0xFF111827),
                                ],
                                (c) => setModalState(() => _headerTabela = c),
                              ),
                              _cores(
                                "Linha total",
                                _totalTabela,
                                [
                                  const Color(0xFFFDE047),
                                  const Color(0xFFBBF7D0),
                                  const Color(0xFFFFEDD5),
                                  const Color(0xFFE0E7FF),
                                ],
                                (c) => setModalState(() => _totalTabela = c),
                              ),
                              _cores(
                                "Linhas alternadas A",
                                _rowTabelaA,
                                [
                                  Colors.white,
                                  const Color(0xFFF1F5F9),
                                  const Color(0xFFEFF6FF),
                                  const Color(0xFFFFFBEB),
                                ],
                                (c) => setModalState(() => _rowTabelaA = c),
                              ),
                              _cores(
                                "Linhas alternadas B",
                                _rowTabelaB,
                                [
                                  const Color(0xFFF8FAFC),
                                  const Color(0xFFE2E8F0),
                                  const Color(0xFFDBEAFE),
                                  const Color(0xFFDCFCE7),
                                ],
                                (c) => setModalState(() => _rowTabelaB = c),
                              ),
                              _cores(
                                "Grades",
                                _gridTabela,
                                [
                                  const Color(0xFFE2E8F0),
                                  const Color(0xFF94A3B8),
                                  const Color(0xFF60A5FA),
                                  const Color(0xFFCBD5E1),
                                ],
                                (c) => setModalState(() => _gridTabela = c),
                              ),
                              _slider(
                                "Altura das linhas",
                                _rowHeight,
                                24,
                                56,
                                (v) => setModalState(() => _rowHeight = v),
                              ),
                            ]),
                          if (_isSegmentacao)
                            _secao("Segmentacao", [
                              _slider(
                                "Raio dos botoes",
                                _chipRadius,
                                0,
                                28,
                                (v) => setModalState(() => _chipRadius = v),
                              ),
                              _cores(
                                "Cor dos botoes",
                                _corPrincipal,
                                [
                                  const Color(0xFF0F5592),
                                  const Color(0xFF2563EB),
                                  const Color(0xFF1D4ED8),
                                  const Color(0xFF0F172A),
                                ],
                                (c) => setModalState(() => _corPrincipal = c),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Permitir selecao multipla"),
                                value: _segmentacaoMultipla,
                                onChanged: (v) => setModalState(
                                  () => _segmentacaoMultipla = v,
                                ),
                              ),
                              _dropdown(
                                "Estilo",
                                _slicerStyle,
                                ['botoes', 'lista', 'tags', 'dropdown'],
                                (v) => setModalState(() => _slicerStyle = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar busca"),
                                value: _slicerSearch,
                                onChanged: (v) =>
                                    setModalState(() => _slicerSearch = v),
                              ),
                            ]),
                          if (_isTreemap)
                            _secao("Treemap", [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text("Mostrar nomes nos blocos"),
                                value: _mostrarRotulos,
                                onChanged: (v) =>
                                    setModalState(() => _mostrarRotulos = v),
                              ),
                              _slider(
                                "Espacamento entre blocos",
                                _treemapSpacing,
                                0,
                                10,
                                (v) => setModalState(() => _treemapSpacing = v),
                              ),
                            ]),
                          _secao("Interacoes", [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Tooltip ativo"),
                              value: _tooltipEnabled,
                              onChanged: (v) =>
                                  setModalState(() => _tooltipEnabled = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Filtrar outros visuais"),
                              value: _interactionFilter,
                              onChanged: (v) =>
                                  setModalState(() => _interactionFilter = v),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Destacar selecao"),
                              value: _interactionHighlight,
                              onChanged: (v) => setModalState(
                                () => _interactionHighlight = v,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Drill-through"),
                              value: _interactionDrillthrough,
                              onChanged: (v) => setModalState(
                                () => _interactionDrillthrough = v,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Navegacao"),
                              value: _interactionNavigation,
                              onChanged: (v) => setModalState(
                                () => _interactionNavigation = v,
                              ),
                            ),
                          ]),
                          _secao("Animacoes", [
                            _dropdown(
                              "Entrada",
                              _animationIn,
                              ['instantanea', 'fade', 'zoom', 'slide'],
                              (v) => setModalState(() => _animationIn = v),
                            ),
                            _dropdown(
                              "Atualizacao",
                              _animationUpdate,
                              ['suave', 'instantanea'],
                              (v) => setModalState(() => _animationUpdate = v),
                            ),
                          ]),
                          _secao("Exportacao e temas", [
                            Wrap(
                              spacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text("PNG"),
                                  selected: _exportPng,
                                  onSelected: (v) =>
                                      setModalState(() => _exportPng = v),
                                ),
                                FilterChip(
                                  label: const Text("PDF"),
                                  selected: _exportPdf,
                                  onSelected: (v) =>
                                      setModalState(() => _exportPdf = v),
                                ),
                                FilterChip(
                                  label: const Text("CSV"),
                                  selected: _exportCsv,
                                  onSelected: (v) =>
                                      setModalState(() => _exportCsv = v),
                                ),
                                FilterChip(
                                  label: const Text("Excel"),
                                  selected: _exportExcel,
                                  onSelected: (v) =>
                                      setModalState(() => _exportExcel = v),
                                ),
                              ],
                            ),
                            _dropdown(
                              "Preset",
                              _themePreset,
                              [
                                'manual',
                                'executivo',
                                'comercial',
                                'financeiro',
                                'marketing',
                              ],
                              (v) => setModalState(() => _themePreset = v),
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
                    "Dados do grafico",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: dimensoes.contains(dim) ? dim : null,
                    decoration: const InputDecoration(labelText: "Dimensao"),
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
                    decoration: const InputDecoration(labelText: "Metrica"),
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
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: _borderWidth,
                  ),
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
                        padding: EdgeInsets.all(_contentPadding),
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
