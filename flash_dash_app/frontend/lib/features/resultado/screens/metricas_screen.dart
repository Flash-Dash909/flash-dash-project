import 'package:flutter/material.dart';

import '../../../core/calculated_metric.dart';
import '../../../core/visual_config.dart';
import '../../../core/widgets/app_logo.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../dashboard/screens/dashboard_canvas_screen.dart';
import '../../dashboard/widgets/chart_renderer.dart';
import '../../dashboard/widgets/power_bi_format_panel.dart';

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
  String? _dimensaoSecundariaSelecionada;
  String? _metricaSelecionada;
  String? _metricaSecundariaSelecionada;
  final Map<String, CalculatedMetric> _metricasCalculadas = {};
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
  Color _corMetricaPrincipal = const Color(0xFF2563EB);
  Color _corMetricaSecundaria = const Color(0xFFF59E0B);
  String _modoCorMetrica = 'categoria';
  String _escalaMetricaSecundaria = 'mesma';
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
  late Map<String, dynamic> _powerBiConfig;

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
  bool get _usaMetricaSecundaria =>
      widget.tipoGrafico.contains('Empilhada') ||
      widget.tipoGrafico.contains('Empilhadas') ||
      widget.tipoGrafico.contains('100%') ||
      widget.tipoGrafico.contains('Combo') ||
      widget.tipoGrafico.contains('Barra') ||
      widget.tipoGrafico.contains('Coluna') ||
      widget.tipoGrafico.contains('Linha') ||
      widget.tipoGrafico.contains('Area') ||
      widget.tipoGrafico.contains('Dispers') ||
      widget.tipoGrafico.contains('Radar') ||
      widget.tipoGrafico.contains('Ribbon');

  bool get _isGauge => widget.tipoGrafico.contains('Gauge');
  bool get _isKpi =>
      widget.tipoGrafico.contains('KPI') ||
      widget.tipoGrafico.contains('Cartao') ||
      widget.tipoGrafico.contains('Progress') ||
      widget.tipoGrafico.contains('Bullet');
  bool get _isTabela =>
      widget.tipoGrafico.contains('Tabela') ||
      widget.tipoGrafico.contains('Matriz');
  bool get _isSegmentacao => widget.tipoGrafico.contains('Segment');
  bool get _isTreemap => widget.tipoGrafico.contains('Treemap');
  bool get _usaDimensaoSecundaria =>
      widget.tipoGrafico.contains('Matriz') ||
      widget.tipoGrafico.contains('Treemap') ||
      widget.tipoGrafico.contains('Sankey') ||
      widget.tipoGrafico.contains('Network') ||
      widget.tipoGrafico.contains('Decomposition') ||
      widget.tipoGrafico.contains('Sunburst');
  bool get _isSemLegenda =>
      _isKpi ||
      _isTabela ||
      _isSegmentacao ||
      _isGauge ||
      _isTreemap ||
      widget.tipoGrafico.contains('Funnel') ||
      widget.tipoGrafico.contains('Waterfall') ||
      widget.tipoGrafico.contains('Histograma') ||
      widget.tipoGrafico.contains('Heatmap') ||
      widget.tipoGrafico.contains('Mapa') ||
      widget.tipoGrafico.contains('Sankey') ||
      widget.tipoGrafico.contains('Gantt') ||
      widget.tipoGrafico.contains('Timeline') ||
      widget.tipoGrafico.contains('Network') ||
      widget.tipoGrafico.contains('Decomposition') ||
      widget.tipoGrafico.contains('Sunburst') ||
      widget.tipoGrafico.contains('Influenciadores') ||
      widget.tipoGrafico.contains('Narrativa');
  bool get _usaLegenda => !_isSemLegenda;
  bool get _usaEixos =>
      widget.tipoGrafico.contains('Barra') ||
      widget.tipoGrafico.contains('Coluna') ||
      _isLinhaOuArea ||
      widget.tipoGrafico.contains('Dispers') ||
      widget.tipoGrafico.contains('Histograma') ||
      widget.tipoGrafico.contains('Waterfall') ||
      widget.tipoGrafico.contains('Combo');

  @override
  void initState() {
    super.initState();
    _raioFuro = widget.tipoGrafico.contains('Rosca') ? 0.58 : 0.0;
    _powerBiConfig = PowerBiVisualConfig.defaultsFor(widget.tipoGrafico);
    _metricasCalculadas.addAll(DashboardManager.metricasCalculadas);
  }

  void _sincronizarPowerBiConfig(Map<String, dynamic> value) {
    _powerBiConfig = Map<String, dynamic>.from(value);
    double number(String key, double fallback) {
      final raw = value[key];
      return raw is num ? raw.toDouble() : fallback;
    }

    bool flag(String key, bool fallback) {
      final raw = value[key];
      return raw is bool ? raw : fallback;
    }

    Color color(String key, Color fallback) {
      final raw = value[key];
      if (raw is Color) return raw;
      if (raw is int) return Color(raw);
      if (raw is String) {
        final parsed = raw.startsWith('#')
            ? int.tryParse(raw.replaceFirst('#', '0xFF'))
            : int.tryParse(raw);
        if (parsed != null) return Color(parsed);
      }
      return fallback;
    }

    _barOpacity = number('barOpacity', _barOpacity);
    _barGap = number('barGap', _barGap);
    _barBorderWidth = number('barBorderWidth', _barBorderWidth);
    _markerSize = number('markerSize', _markerSize);
    _mostrarPontos = flag('markerVisible', _mostrarPontos);
    _espessuraLinha = number('lineWidth', _espessuraLinha);
    _sliceOpacity = number('sliceOpacity', _sliceOpacity);
    _raioFuro = number('raioFuro', _raioFuro);
    _gaugeMin = number('gaugeMin', _gaugeMin);
    _gaugeMax = number('gaugeMax', _gaugeMax);
    _gaugeMeta = number('gaugeMeta', _gaugeMeta);
    _gaugeRanges = flag('gaugeMostrarFaixas', _gaugeRanges);
    _kpiShowMeta = flag('kpiShowMeta', _kpiShowMeta);
    _kpiMeta = number('kpiMeta', _kpiMeta);
    _kpiShowTrend = flag('kpiShowTrend', _kpiShowTrend);
    _kpiPrevious = number('kpiPrevious', _kpiPrevious);
    _kpiFontSize = number('kpiFontSize', _kpiFontSize);
    _headerTabela = color('headerColor', _headerTabela);
    _rowTabelaA = color('rowColorA', _rowTabelaA);
    _rowTabelaB = color('rowColorB', _rowTabelaB);
    _gridTabela = color('gridColor', _gridTabela);
    _rowHeight = number('rowHeight', _rowHeight);
    _segmentacaoMultipla = flag('segmentacaoMultipla', _segmentacaoMultipla);
    _slicerStyle = value['slicerStyle']?.toString() ?? _slicerStyle;
    _slicerSearch = flag('slicerSearch', _slicerSearch);
    _treemapSpacing = number('treemapSpacing', _treemapSpacing);
    _tooltipEnabled = flag('tooltipEnabled', _tooltipEnabled);
    _interactionFilter = flag('interactionFilter', _interactionFilter);
    _interactionHighlight = flag('interactionHighlight', _interactionHighlight);
    _interactionDrillthrough = flag(
      'interactionDrillthrough',
      _interactionDrillthrough,
    );
  }

  List<Map<String, dynamic>> _calcularDadosDinamicos(
    String dimensao,
    String metrica, [
    String? metricaSecundaria,
    String? dimensaoSecundaria,
  ]) {
    final dadosBrutos = _dadosBrutos;
    if (dadosBrutos.isEmpty) {
      return List<Map<String, dynamic>>.from(
        widget.data['chart_data'] ??
            widget.data['dados_planilha']?['chart_data'] ??
            [],
      );
    }

    final agrupamento = <String, List<double>>{};
    final agrupamentoSecundario = <String, List<double>>{};
    final labelsPrimarios = <String, String>{};
    final labelsSecundarios = <String, String>{};
    for (final linha in dadosBrutos) {
      final labelPrimario =
          linha[dimensao]?.toString().trim().isNotEmpty == true
          ? linha[dimensao].toString()
          : "Desconhecido";
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
      final valor = linha is Map
          ? resolveMetricValue(linha, metrica, _metricasCalculadas)
          : 0.0;
      agrupamento.putIfAbsent(chave, () => []).add(valor);
      if (metricaSecundaria != null && metricaSecundaria.isNotEmpty) {
        final valor2 = linha is Map
            ? resolveMetricValue(linha, metricaSecundaria, _metricasCalculadas)
            : 0.0;
        agrupamentoSecundario.putIfAbsent(chave, () => []).add(valor2);
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
      final valores2 = agrupamentoSecundario[entry.key] ?? const <double>[];
      final soma2 = valores2.fold<double>(0, (total, valor) => total + valor);
      final valor2 = valores2.isEmpty
          ? 0.0
          : switch (_agregacao) {
              'Media' => soma2 / valores2.length,
              'Contagem' => valores2.length.toDouble(),
              'Maximo' => valores2.reduce((a, b) => a > b ? a : b),
              'Minimo' => valores2.reduce((a, b) => a < b ? a : b),
              _ => soma2,
            };
      final index = agrupamento.keys.toList().indexOf(entry.key);
      return {
        "label": labelsPrimarios[entry.key] ?? entry.key,
        if ((labelsSecundarios[entry.key] ?? '').isNotEmpty)
          "secondaryLabel": labelsSecundarios[entry.key],
        "value": valor,
        if (metricaSecundaria != null) "value2": valor2,
        "color": paleta[index % paleta.length],
      };
    }).toList();

    final sortMode =
        _powerBiConfig['categorySort']?.toString() ??
        (_ordenarDesc ? 'valueDesc' : 'valueAsc');
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
    return dados.take(_limiteItens).toList();
  }

  ChartConfig _criarConfigPreview(
    String dim,
    String met, [
    String? met2,
    String? dim2,
  ]) {
    final titulo = _tituloPersonalizado.isEmpty
        ? met2 == null
              ? "$met por $dim"
              : "$met e $met2 por $dim"
        : _tituloPersonalizado;
    return ChartConfig(
      id: 'preview',
      tipo: widget.tipoGrafico,
      titulo: titulo,
      dimensao: dim,
      metrica: met,
      dados: _calcularDadosDinamicos(dim, met, met2, dim2),
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
        ..._powerBiConfig,
        'agregacao': _agregacao,
        'calculatedMetrics': _metricasCalculadas.values
            .map((metric) => metric.toJson())
            .toList(),
        if (met2 != null) 'metricaSecundaria': met2,
        if (dim2 != null) 'dimensaoSecundaria': dim2,
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
        'corMetricaPrincipal': _corMetricaPrincipal.value.toString(),
        'corMetricaSecundaria': _corMetricaSecundaria.value.toString(),
        'metricColorMode': _modoCorMetrica,
        'secondaryScaleMode': _escalaMetricaSecundaria,
        'barColor': _corMetricaPrincipal.value.toString(),
        'stackColor': _corMetricaSecundaria.value.toString(),
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
        'lineColor': _corMetricaPrincipal.value.toString(),
        'markerColor': _corMetricaPrincipal.value.toString(),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCompact = MediaQuery.of(context).size.width < 600;
            return SizedBox(
              height:
                  MediaQuery.of(context).size.height *
                  (isCompact ? 0.94 : 0.88),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 24,
                      18,
                      12,
                      8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Formatar visual",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                      padding: EdgeInsets.all(isCompact ? 12 : 24),
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
                          if (!_isTabela && !_isSegmentacao)
                            _secao("Cores das metricas", [
                              if (!_isKpi &&
                                  !_isGauge &&
                                  !_usaMetricaSecundaria)
                                _dropdown(
                                  "Aplicar cores",
                                  _modoCorMetrica,
                                  ['categoria', 'metrica'],
                                  (v) =>
                                      setModalState(() => _modoCorMetrica = v),
                                ),
                              _cores(
                                "Metrica principal",
                                _corMetricaPrincipal,
                                [
                                  const Color(0xFF2563EB),
                                  const Color(0xFF10B981),
                                  const Color(0xFFF59E0B),
                                  const Color(0xFFEF4444),
                                  const Color(0xFF8B5CF6),
                                  const Color(0xFF14B8A6),
                                ],
                                (c) => setModalState(() {
                                  _corMetricaPrincipal = c;
                                  _corPrincipal = c;
                                }),
                              ),
                              if (_usaMetricaSecundaria)
                                _cores(
                                  "Metrica secundaria",
                                  _corMetricaSecundaria,
                                  [
                                    const Color(0xFFF59E0B),
                                    const Color(0xFFEF4444),
                                    const Color(0xFF10B981),
                                    const Color(0xFF8B5CF6),
                                    const Color(0xFF14B8A6),
                                    const Color(0xFF64748B),
                                  ],
                                  (c) => setModalState(
                                    () => _corMetricaSecundaria = c,
                                  ),
                                ),
                              if (_usaMetricaSecundaria)
                                _dropdown(
                                  "Escala da segunda metrica",
                                  _escalaMetricaSecundaria,
                                  ['mesma', 'independente'],
                                  (v) => setModalState(
                                    () => _escalaMetricaSecundaria = v,
                                  ),
                                ),
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
                          _secao("Configuracao detalhada Power BI", [
                            PowerBiFormatPanel(
                              visualType: widget.tipoGrafico,
                              value: _powerBiConfig,
                              onChanged: (value) => setModalState(
                                () => _sincronizarPowerBiConfig(value),
                              ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
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
    final labelWidget = Text(
      "$label: ${value.toStringAsFixed(max <= 1 ? 2 : 0)}",
    );
    final slider = Slider(
      value: value,
      min: min,
      max: max,
      onChanged: onChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, slider],
          );
        }

        return Row(
          children: [
            SizedBox(width: 170, child: labelWidget),
            Expanded(child: slider),
          ],
        );
      },
    );
  }

  Widget _segmented(
    String label,
    String value,
    Map<String, IconData> options,
    ValueChanged<String> onChanged,
  ) {
    final buttons = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ToggleButtons(
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label), const SizedBox(height: 8), buttons],
          );
        }

        return Row(
          children: [
            SizedBox(width: 120, child: Text(label)),
            Expanded(child: buttons),
          ],
        );
      },
    );
  }

  Widget _cores(
    String label,
    Color ativa,
    List<Color> cores,
    ValueChanged<Color> onChanged,
  ) {
    final swatches = Wrap(
      spacing: 10,
      runSpacing: 10,
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label), const SizedBox(height: 8), swatches],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label)),
            Expanded(child: swatches),
          ],
        );
      },
    );
  }

  Future<void> _abrirCriadorDeMetrica(List<String> metricasBase) async {
    final nomeController = TextEditingController();
    final formulaController = TextEditingController();

    void inserir(String texto) {
      final atual = formulaController.text;
      final selection = formulaController.selection;
      final inicio = selection.isValid ? selection.start : atual.length;
      final fim = selection.isValid ? selection.end : atual.length;
      formulaController.text = atual.replaceRange(inicio, fim, texto);
      final cursor = inicio + texto.length;
      formulaController.selection = TextSelection.collapsed(offset: cursor);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final isCompact = MediaQuery.of(context).size.width < 640;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calculate_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Criar metrica calculada",
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                        padding: EdgeInsets.all(isCompact ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: nomeController,
                              decoration: const InputDecoration(
                                labelText: "Nome da metrica",
                                hintText: "Ex: Ticket medio",
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: formulaController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: "Formula",
                                hintText: "[Faturamento] / 2",
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Metricas detectadas",
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: metricasBase.map((metrica) {
                                return ActionChip(
                                  avatar: const Icon(
                                    Icons.data_array_rounded,
                                    size: 16,
                                  ),
                                  label: Text(metrica),
                                  onPressed: () => setModalState(
                                    () => inserir("[$metrica]"),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    '+',
                                    '-',
                                    '*',
                                    '/',
                                    '(',
                                    ')',
                                    '0',
                                    '1',
                                    '2',
                                    '3',
                                    '4',
                                    '5',
                                    '6',
                                    '7',
                                    '8',
                                    '9',
                                    '.',
                                  ].map((key) {
                                    return SizedBox(
                                      width: 52,
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            setModalState(() => inserir(key)),
                                        child: Text(key),
                                      ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => setModalState(() {
                                    final text = formulaController.text;
                                    if (text.isNotEmpty) {
                                      formulaController.text = text.substring(
                                        0,
                                        text.length - 1,
                                      );
                                      formulaController
                                          .selection = TextSelection.collapsed(
                                        offset: formulaController.text.length,
                                      );
                                    }
                                  }),
                                  icon: const Icon(Icons.backspace_outlined),
                                  label: const Text("Apagar"),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setModalState(
                                    () => formulaController.clear(),
                                  ),
                                  icon: const Icon(Icons.cleaning_services),
                                  label: const Text("Limpar"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Exemplo: toque em Faturamento, depois /, depois 2. A metrica criada aparece na lista de metricas dos graficos.",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text("Salvar metrica"),
                          onPressed: () {
                            final nome = nomeController.text.trim();
                            final formula = formulaController.text.trim();
                            if (nome.isEmpty || formula.isEmpty) return;
                            setState(() {
                              _metricasCalculadas[nome] = CalculatedMetric(
                                name: nome,
                                formula: formula,
                              );
                              DashboardManager.metricasCalculadas =
                                  Map<String, CalculatedMetric>.from(
                                    _metricasCalculadas,
                                  );
                              _metricaSelecionada = nome;
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    nomeController.dispose();
    formulaController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimensoes = List<dynamic>.from(_summary['dimensoes'] ?? []);
    final metricasBase = List<dynamic>.from(
      _summary['metricas'] ?? [],
    ).map((m) => m.toString()).toList();
    final metricas = [...metricasBase, ..._metricasCalculadas.keys];

    final dim =
        _dimensaoSelecionada ??
        (dimensoes.isNotEmpty ? dimensoes[0].toString() : "Categoria");
    final dimensoesSecundarias = dimensoes
        .map((item) => item.toString())
        .where((item) => item != dim)
        .toList();
    final dim2 = _usaDimensaoSecundaria && dimensoesSecundarias.isNotEmpty
        ? (_dimensaoSecundariaSelecionada != null &&
                  dimensoesSecundarias.contains(_dimensaoSecundariaSelecionada)
              ? _dimensaoSecundariaSelecionada
              : dimensoesSecundarias.first)
        : null;
    final met =
        _metricaSelecionada ??
        (metricas.isNotEmpty ? metricas[0].toString() : "Valor");
    final metricaSecundariaPadrao = metricas
        .map((m) => m.toString())
        .where((m) => m != met)
        .cast<String>()
        .toList();
    final met2 = _usaMetricaSecundaria && metricaSecundariaPadrao.isNotEmpty
        ? (_metricaSecundariaSelecionada != null &&
                  metricaSecundariaPadrao.contains(
                    _metricaSecundariaSelecionada,
                  )
              ? _metricaSecundariaSelecionada
              : metricaSecundariaPadrao.first)
        : null;

    if (!_tituloEditadoManualmente) {
      _tituloPersonalizado = met2 == null
          ? "$met por $dim"
          : "$met e $met2 por $dim";
    }

    final configPreview = _criarConfigPreview(dim, met, met2, dim2);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final horizontalPadding = isDesktop ? 24.0 : 14.0;
    final cardPadding = isDesktop ? 24.0 : 16.0;
    final previewHeight = isDesktop ? 310.0 : 260.0;
    final alignPreview = _alinhamentoTitulo == 'center'
        ? TextAlign.center
        : (_alinhamentoTitulo == 'right' ? TextAlign.right : TextAlign.left);

    final previewCard = Container(
      constraints: BoxConstraints(minHeight: isDesktop ? 460 : 390),
      decoration: BoxDecoration(
        color: _corFundo,
        borderRadius: BorderRadius.circular(_raioBorda),
        border: Border.all(color: const Color(0xFFE2E8F0), width: _borderWidth),
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
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: isDesktop ? 420 : double.infinity,
                  child: Text(
                    configPreview.titulo,
                    textAlign: alignPreview,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _fontSizeTitulo,
                      color: _corTextoTitulo,
                    ),
                    maxLines: 2,
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
            height: previewHeight,
            child: Padding(
              padding: EdgeInsets.all(_contentPadding),
              child: ChartRenderer(config: configPreview),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            child: ElevatedButton.icon(
              onPressed: () {
                DashboardManager.graficosAtivos.add(
                  configPreview
                    ..id = DateTime.now().millisecondsSinceEpoch.toString(),
                );
                DashboardManager.dadosFonteAtual = widget.data;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardCanvasScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text("Adicionar ao Dashboard"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Criar ${widget.tipoGrafico}'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogo(size: 32, opacity: 0.82),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Flex(
          direction: isDesktop ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isDesktop ? 390 : double.infinity,
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
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
                  Text(
                    "Dados do grafico",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
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
                  if (_usaDimensaoSecundaria &&
                      dimensoesSecundarias.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: dim2,
                      decoration: const InputDecoration(
                        labelText: "Segunda dimensao",
                        helperText:
                            "Cria hierarquia, destino ou detalhamento do visual.",
                      ),
                      items: dimensoesSecundarias
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _dimensaoSecundariaSelecionada = value,
                      ),
                    ),
                  ],
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _abrirCriadorDeMetrica(metricasBase),
                    icon: const Icon(Icons.calculate_rounded),
                    label: const Text("Criar metrica calculada"),
                  ),
                  if (_metricasCalculadas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _metricasCalculadas.values.map((metric) {
                        return InputChip(
                          avatar: const Icon(Icons.functions, size: 16),
                          label: Text(metric.name),
                          selected: _metricaSelecionada == metric.name,
                          onPressed: () =>
                              setState(() => _metricaSelecionada = metric.name),
                          onDeleted: () => setState(() {
                            _metricasCalculadas.remove(metric.name);
                            DashboardManager.metricasCalculadas =
                                Map<String, CalculatedMetric>.from(
                                  _metricasCalculadas,
                                );
                            if (_metricaSelecionada == metric.name) {
                              _metricaSelecionada = null;
                            }
                            if (_metricaSecundariaSelecionada == metric.name) {
                              _metricaSecundariaSelecionada = null;
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_usaMetricaSecundaria &&
                      metricaSecundariaPadrao.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: met2,
                      decoration: const InputDecoration(
                        labelText: "Segunda metrica",
                        helperText:
                            "Usada para empilhar, comparar ou desenhar a linha.",
                      ),
                      items: metricaSecundariaPadrao
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _metricaSecundariaSelecionada = val),
                    ),
                  ],
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
            if (isDesktop) Expanded(child: previewCard) else previewCard,
          ],
        ),
      ),
    );
  }
}
