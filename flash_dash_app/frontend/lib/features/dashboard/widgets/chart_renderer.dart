import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dashboard_manager.dart';

class ChartRenderer extends StatelessWidget {
  final ChartConfig config;
  final Set<String>? filtrosSelecionados;
  final ValueChanged<Set<String>>? onSegmentacaoChanged;
  final Set<String>? selecaoVisual;
  final ValueChanged<Set<String>>? onSelecaoVisualChanged;

  const ChartRenderer({
    super.key,
    required this.config,
    this.filtrosSelecionados,
    this.onSegmentacaoChanged,
    this.selecaoVisual,
    this.onSelecaoVisualChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (config.dados.isEmpty) {
      return const _SemDadosVisual();
    }
    final tipo = config.tipo.toLowerCase();
    Widget animated(Widget child) =>
        _VisualAnimation(config: config, child: child);

    if (tipo.contains('matriz')) {
      return animated(_MatrizVisual(config: config));
    }
    if (tipo.contains('tabela')) {
      return animated(_TabelaVisual(config: config));
    }
    if (tipo.contains('segment')) {
      return animated(
        _SegmentacaoVisual(
          config: config,
          selecionadosExternos: filtrosSelecionados,
          onChanged: onSegmentacaoChanged,
        ),
      );
    }
    if (tipo.contains('cartao') || tipo.contains('kpi')) {
      return animated(_CartaoKpiVisual(config: config));
    }
    if (tipo.contains('influenciador')) {
      return animated(_KeyInfluencersVisual(config: config));
    }
    if (tipo.contains('narrativa')) {
      return animated(_SmartNarrativeVisual(config: config));
    }
    if (tipo.contains('progress')) {
      return animated(_ProgressBarVisual(config: config));
    }

    return animated(
      _InteractiveChart(
        config: config,
        selectedLabels: selecaoVisual ?? const <String>{},
        onSelectionChanged: onSelecaoVisualChanged,
      ),
    );
  }
}

class _VisualAnimation extends StatelessWidget {
  final ChartConfig config;
  final Widget child;

  const _VisualAnimation({required this.config, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!(config.configExtra['animationEnabled'] as bool? ?? true)) {
      return child;
    }
    final duration = Duration(
      milliseconds: ((config.configExtra['animationDuration'] ?? 420) as num)
          .round(),
    );
    final mode = config.configExtra['animationIn']?.toString() ?? 'fade';
    final signature = Object.hashAll(
      config.dados.expand(
        (item) => [item['label'], item['value'], item['value2']],
      ),
    );
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switch (config.configExtra['animationCurve']?.toString()) {
        'linear' => Curves.linear,
        'bounce' => Curves.easeOutBack,
        _ => Curves.easeOutCubic,
      },
      transitionBuilder: (child, animation) {
        if (mode == 'zoom') {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        }
        if (mode == 'slide') {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        }
        if (mode == 'instant' || mode == 'instantanea') return child;
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(key: ValueKey(signature), child: child),
    );
  }
}

class _SemDadosVisual extends StatelessWidget {
  const _SemDadosVisual();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_chart_outlined_rounded,
            size: 34,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Sem dados para exibir',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveChart extends StatefulWidget {
  final ChartConfig config;
  final Set<String> selectedLabels;
  final ValueChanged<Set<String>>? onSelectionChanged;

  const _InteractiveChart({
    required this.config,
    required this.selectedLabels,
    this.onSelectionChanged,
  });

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  int? _hoveredIndex;
  Offset _tooltipPosition = Offset.zero;

  Rect _plotRect(Size size) {
    final tipo = widget.config.tipo.toLowerCase();
    final usaEixos =
        tipo.contains('barra') ||
        tipo.contains('coluna') ||
        tipo.contains('linha') ||
        tipo.contains('area') ||
        tipo.contains('dispers') ||
        tipo.contains('histograma') ||
        tipo.contains('waterfall') ||
        tipo.contains('combo') ||
        tipo.contains('ribbon');
    final plotPadding = ((widget.config.configExtra['plotPadding'] ?? 8) as num)
        .toDouble();
    final left = usaEixos && widget.config.mostrarEixos ? 46.0 : plotPadding;
    final bottom = usaEixos && widget.config.mostrarRotulos
        ? 38.0
        : plotPadding;
    return Rect.fromLTWH(
      left,
      plotPadding,
      math.max(1, size.width - left - plotPadding),
      math.max(1, size.height - bottom - plotPadding),
    );
  }

  int? _hitTest(Offset position, Size size) {
    final data = widget.config.dados;
    if (data.isEmpty) return null;
    final rect = _plotRect(size);
    if (!rect.inflate(10).contains(position)) return null;
    final type = widget.config.tipo.toLowerCase();

    if (type.contains('pizza') || type.contains('rosca')) {
      final delta = position - rect.center;
      final radius = delta.distance;
      final outer = math.min(rect.width, rect.height) * 0.43;
      final inner =
          outer *
          ((widget.config.configExtra['raioFuro'] ??
                      (type.contains('rosca') ? 0.58 : 0.0))
                  as num)
              .toDouble();
      if (radius > outer || radius < inner) return null;
      final total = data.fold<double>(
        0,
        (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble().abs(),
      );
      if (total <= 0) return null;
      var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
      if (angle < 0) angle += math.pi * 2;
      var cursor = 0.0;
      for (int i = 0; i < data.length; i++) {
        cursor +=
            (((data[i]['value'] ?? 0) as num).toDouble().abs() / total) *
            math.pi *
            2;
        if (angle <= cursor) return i;
      }
      return data.length - 1;
    }

    if (type.contains('barras')) {
      return (((position.dy - rect.top) / rect.height) * data.length)
          .floor()
          .clamp(0, data.length - 1);
    }
    if (type.contains('funnel') || type.contains('sankey')) {
      return (((position.dy - rect.top) / rect.height) * data.length)
          .floor()
          .clamp(0, data.length - 1);
    }
    return (((position.dx - rect.left) / rect.width) * data.length)
        .floor()
        .clamp(0, data.length - 1);
  }

  void _updateHover(PointerEvent event, Size size) {
    final index = _hitTest(event.localPosition, size);
    if (index == _hoveredIndex && event.localPosition == _tooltipPosition) {
      return;
    }
    setState(() {
      _hoveredIndex = index;
      _tooltipPosition = event.localPosition;
    });
  }

  void _select(int? index) {
    if (widget.onSelectionChanged == null) return;
    if (widget.config.configExtra['interactionFilter'] == false) return;
    if (index == null) {
      if (widget.selectedLabels.isNotEmpty) {
        widget.onSelectionChanged!(<String>{});
      }
      return;
    }
    final label = widget.config.dados[index]['label']?.toString() ?? '';
    if (label.isEmpty) return;
    final next = Set<String>.from(widget.selectedLabels);
    final multi =
        widget.config.configExtra['interactionMultiSelect'] as bool? ?? true;
    if (!multi) next.clear();
    if (next.contains(label)) {
      next.remove(label);
    } else {
      next.add(label);
    }
    widget.onSelectionChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final tooltipEnabled =
            widget.config.configExtra['tooltipEnabled'] as bool? ?? true;
        final data = _hoveredIndex == null
            ? null
            : widget.config.dados[_hoveredIndex!];
        final tooltipWidth = math.min(
          210.0,
          math.max(130.0, size.width * 0.58),
        );
        final left = (_tooltipPosition.dx + 12)
            .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
            .toDouble();
        final top = (_tooltipPosition.dy + 12)
            .clamp(4.0, math.max(4.0, size.height - 78))
            .toDouble();

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: MouseRegion(
                opaque: true,
                onHover: (event) => _updateHover(event, size),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _select(_hitTest(details.localPosition, size)),
                  child: CustomPaint(
                    painter: _ChartPainter(
                      widget.config,
                      hoveredIndex: _hoveredIndex,
                      selectedLabels: widget.selectedLabels,
                    ),
                    size: size,
                  ),
                ),
              ),
            ),
            if (tooltipEnabled && data != null)
              Positioned(
                left: left,
                top: top,
                width: tooltipWidth,
                child: IgnorePointer(
                  child: _ChartTooltip(config: widget.config, data: data),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  final ChartConfig config;
  final Map<String, dynamic> data;

  const _ChartTooltip({required this.config, required this.data});

  @override
  Widget build(BuildContext context) {
    final background = _visualColor(
      config.configExtra['tooltipBackgroundColor'],
      const Color(0xFF172033),
    );
    final foreground = _visualColor(
      config.configExtra['tooltipTextColor'],
      Colors.white,
    );
    final showCategory = config.configExtra['tooltipCategory'] as bool? ?? true;
    final showValue = config.configExtra['tooltipValue'] as bool? ?? true;
    final showValue2 =
        config.configExtra['tooltipSecondaryValue'] as bool? ?? true;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCategory)
              Text(
                data['label']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            if (showValue)
              Text(
                '${config.metrica}: ${_formatarValorVisual(config, ((data['value'] ?? 0) as num).toDouble())}',
                style: TextStyle(color: foreground, fontSize: 11),
              ),
            if (showValue2 && data.containsKey('value2'))
              Text(
                '${config.configExtra['metricaSecundaria'] ?? 'Segunda metrica'}: ${_formatarValorVisual(config, ((data['value2'] ?? 0) as num).toDouble())}',
                style: TextStyle(color: foreground, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final ChartConfig config;
  final int? hoveredIndex;
  final Set<String> selectedLabels;

  _ChartPainter(
    this.config, {
    this.hoveredIndex,
    this.selectedLabels = const <String>{},
  });

  Color _converterCor(
    dynamic corOrigem, [
    Color fallback = const Color(0xFF2563EB),
  ]) {
    if (corOrigem is Color) return corOrigem;
    if (corOrigem is String) {
      if (corOrigem.startsWith('#'))
        return Color(int.parse(corOrigem.replaceFirst('#', '0xFF')));
      final valorNumerico = int.tryParse(corOrigem);
      if (valorNumerico != null) return Color(valorNumerico);
    }
    if (corOrigem is int) return Color(corOrigem);
    return fallback;
  }

  double _numExtra(String key, double fallback) {
    final value = config.configExtra[key];
    return value is num ? value.toDouble() : fallback;
  }

  bool _boolExtra(String key, bool fallback) {
    final value = config.configExtra[key];
    return value is bool ? value : fallback;
  }

  Color _corMetricaPrincipal([Color fallback = const Color(0xFF2563EB)]) {
    return _converterCor(
      config.configExtra['corMetricaPrincipal'] ??
          config.configExtra['barColor'] ??
          config.configExtra['lineColor'] ??
          config.configExtra['corPrincipal'],
      fallback,
    );
  }

  Color _corMetricaSecundaria([Color fallback = const Color(0xFFF59E0B)]) {
    return _converterCor(
      config.configExtra['corMetricaSecundaria'] ??
          config.configExtra['stackColor'],
      fallback,
    );
  }

  bool get _usarCorPorMetrica =>
      config.configExtra['metricColorMode'] == 'metrica';

  Color _corDoItem(Color color, int index) {
    final label = index >= 0 && index < config.dados.length
        ? config.dados[index]['label']?.toString() ?? ''
        : '';
    final hasSelection = selectedLabels.isNotEmpty;
    if (hasSelection && !selectedLabels.contains(label)) {
      return color.withValues(alpha: color.a * 0.22);
    }
    if (hoveredIndex != null && hoveredIndex != index && !hasSelection) {
      return color.withValues(alpha: color.a * 0.42);
    }
    return color;
  }

  Color _conditionalColor(double value, Color fallback) {
    final mode = config.configExtra['conditionalMode']?.toString() ?? 'none';
    if (mode == 'none') return fallback;
    final min = _numExtra('conditionalMin', 0);
    final max = _numExtra('conditionalMax', 100);
    final t = ((value - min) / math.max(0.000001, max - min)).clamp(0.0, 1.0);
    final minColor = _converterCor(
      config.configExtra['conditionalMinColor'],
      const Color(0xFFEF4444),
    );
    final midColor = _converterCor(
      config.configExtra['conditionalMidColor'],
      const Color(0xFFF59E0B),
    );
    final maxColor = _converterCor(
      config.configExtra['conditionalMaxColor'],
      const Color(0xFF10B981),
    );
    if (mode == 'rules') {
      if (t < 0.34) return minColor;
      if (t < 0.67) return midColor;
      return maxColor;
    }
    return t < 0.5
        ? Color.lerp(minColor, midColor, t * 2)!
        : Color.lerp(midColor, maxColor, (t - 0.5) * 2)!;
  }

  String _formatarNumero(double valor) {
    return _formatarValorVisual(config, valor);
  }

  String _textoRotulo(Map<String, dynamic> item, double value, double total) {
    final category = item['label']?.toString() ?? '';
    final percent = total == 0 ? 0.0 : (value / total) * 100;
    final mode = config.configExtra['labelContent']?.toString() ?? 'value';
    return switch (mode) {
      'category' => category,
      'percent' => '${percent.toStringAsFixed(0)}%',
      'categoryValue' => '$category  ${_formatarNumero(value)}',
      'categoryPercent' => '$category  ${percent.toStringAsFixed(0)}%',
      'valuePercent' =>
        '${_formatarNumero(value)}  ${percent.toStringAsFixed(0)}%',
      _ => _formatarNumero(value),
    };
  }

  void _desenharTextoCentralizado(
    Canvas canvas,
    String texto,
    Offset centro,
    TextStyle style, {
    double maxWidth = 80,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: texto, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      centro - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dados = config.dados;
    final tipo = config.tipo.toLowerCase();
    final usaEixos =
        tipo.contains('barra') ||
        tipo.contains('coluna') ||
        tipo.contains('linha') ||
        tipo.contains('area') ||
        tipo.contains('dispers') ||
        tipo.contains('histograma') ||
        tipo.contains('waterfall') ||
        tipo.contains('combo') ||
        tipo.contains('ribbon') ||
        tipo.contains('anomalia');
    final plotPadding = ((config.configExtra['plotPadding'] ?? 8) as num)
        .toDouble();
    final paddingLeft = usaEixos && config.mostrarEixos ? 42.0 : plotPadding;
    final paddingBottom = usaEixos && config.mostrarRotulos
        ? 34.0
        : plotPadding;
    final chartRect = Rect.fromLTWH(
      paddingLeft,
      plotPadding,
      math.max(1, size.width - paddingLeft - plotPadding),
      math.max(1, size.height - paddingBottom - plotPadding),
    );

    final plotBackground = _converterCor(
      config.configExtra['plotBackgroundColor'],
      Colors.white,
    ).withValues(alpha: _numExtra('plotBackgroundOpacity', 0));
    if (plotBackground.a > 0) {
      canvas.drawRect(chartRect, Paint()..color = plotBackground);
    }
    if (_boolExtra('plotBorderVisible', false)) {
      canvas.drawRect(
        chartRect,
        Paint()
          ..color = _converterCor(
            config.configExtra['plotBorderColor'],
            const Color(0xFFE2E8F0),
          )
          ..strokeWidth = _numExtra('plotBorderWidth', 1)
          ..style = PaintingStyle.stroke,
      );
    }

    if (tipo.contains('pizza') || tipo.contains('rosca')) {
      _desenharPizza(canvas, chartRect, dados, tipo.contains('rosca'));
      return;
    }
    if (tipo.contains('gauge')) {
      _desenharGauge(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('treemap')) {
      _desenharTreemap(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('funnel')) {
      _desenharFunnel(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('waterfall')) {
      _desenharWaterfall(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('histograma')) {
      _desenharHistograma(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('box')) {
      _desenharBoxPlot(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('heatmap') || tipo.contains('mapa de calor')) {
      _desenharHeatmap(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('bullet')) {
      _desenharBullet(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('combo')) {
      _desenharCombo(canvas, chartRect, dados);
      _desenharAnalytics(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('ribbon')) {
      _desenharRibbon(canvas, chartRect, dados);
      _desenharAnalytics(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('anomalia')) {
      _desenharLinhaOuArea(canvas, chartRect, dados, false);
      _desenharAnomalias(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('sankey')) {
      _desenharSankey(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('gantt') || tipo.contains('timeline')) {
      _desenharGantt(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('decomposition')) {
      _desenharDecompositionTree(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('network')) {
      _desenharNetwork(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('sunburst')) {
      _desenharSunburst(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('mapa') ||
        tipo.contains('azure map') ||
        tipo.contains('shape map')) {
      _desenharMapa(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('radar')) {
      _desenharRadar(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('dispers')) {
      _desenharDispersao(canvas, chartRect, dados);
      return;
    }
    if (tipo.contains('linha') || tipo.contains('area')) {
      if (tipo.contains('area') &&
          (tipo.contains('empilh') || tipo.contains('100%')) &&
          dados.any((d) => d.containsKey('value2'))) {
        _desenharAreaEmpilhada(
          canvas,
          chartRect,
          dados,
          percentual: tipo.contains('100%'),
        );
      } else {
        _desenharLinhaOuArea(canvas, chartRect, dados, tipo.contains('area'));
      }
      _desenharAnalytics(canvas, chartRect, dados);
      return;
    }

    _desenharBarras(
      canvas,
      chartRect,
      dados,
      horizontal: tipo.contains('barras'),
    );
    _desenharAnalytics(canvas, chartRect, dados);
  }

  double _maxValor(List<Map<String, dynamic>> dados) {
    final valores = <double>[
      ...dados.map((d) => ((d['value'] ?? 0) as num).toDouble()),
      ...dados
          .where((d) => d.containsKey('value2'))
          .map((d) => ((d['value2'] ?? 0) as num).toDouble()),
    ];
    if (valores.isEmpty) return 1;
    final configured = config.configExtra['yAxisMax'];
    final maximo = configured is num
        ? configured.toDouble()
        : valores.reduce(math.max);
    return maximo <= 0 ? 1 : maximo;
  }

  double _minValor() {
    final configured = config.configExtra['yAxisMin'];
    return configured is num ? configured.toDouble() : 0.0;
  }

  double _normalizar(double value, double maxValue) {
    final minValue = _minValor();
    final scale = config.configExtra['axisScale']?.toString() ?? 'linear';
    if (scale == 'log') {
      final safeMin = math.max(0.000001, minValue <= 0 ? 0.000001 : minValue);
      final safeMax = math.max(safeMin * 1.001, maxValue);
      final safeValue = math.max(safeMin, value);
      return ((math.log(safeValue) - math.log(safeMin)) /
              (math.log(safeMax) - math.log(safeMin)))
          .clamp(0.0, 1.0);
    }
    return ((value - minValue) / math.max(0.000001, maxValue - minValue)).clamp(
      0.0,
      1.0,
    );
  }

  double _maxValorEmpilhado(List<Map<String, dynamic>> dados) {
    final valores = dados.map((d) {
      final v1 = ((d['value'] ?? 0) as num).toDouble().abs();
      final v2 = ((d['value2'] ?? 0) as num).toDouble().abs();
      return v1 + v2;
    }).toList();
    if (valores.isEmpty) return 1;
    final maximo = valores.reduce(math.max);
    return maximo <= 0 ? 1 : maximo;
  }

  void _desenharGrade(Canvas canvas, Rect rect, double maxValor) {
    if (!config.mostrarEixos) return;
    final showGrid = _boolExtra('gridVisible', true);
    final gridPaint = Paint()
      ..color = _converterCor(
        config.configExtra['gridColor'],
        const Color(0xFFE2E8F0),
      )
      ..strokeWidth = _numExtra('gridWidth', 1);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final gridCount = _numExtra('gridCount', 4).round().clamp(2, 10);
    final minValor = _minValor();
    final axisColor = _converterCor(
      config.configExtra['yAxisColor'],
      const Color(0xFF64748B),
    );
    final axisFontSize = _numExtra('yAxisFontSize', 9);

    for (int i = 0; i <= gridCount; i++) {
      final y = rect.bottom - (rect.height / gridCount) * i;
      if (showGrid) {
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      }
      textPainter.text = TextSpan(
        text: _formatarNumero(
          minValor + ((maxValor - minValor) / gridCount) * i,
        ),
        style: TextStyle(fontSize: axisFontSize, color: axisColor),
      );
      textPainter.layout(maxWidth: 42);
      textPainter.paint(canvas, Offset(1, y - textPainter.height / 2));
    }

    final xTitle = config.configExtra['xAxisTitle']?.toString() ?? '';
    if (xTitle.isNotEmpty) {
      _desenharTextoCentralizado(
        canvas,
        xTitle,
        Offset(rect.center.dx, rect.bottom + 28),
        TextStyle(
          fontSize: _numExtra('xAxisFontSize', 9) + 1,
          color: _converterCor(
            config.configExtra['xAxisColor'],
            const Color(0xFF64748B),
          ),
          fontWeight: FontWeight.w600,
        ),
        maxWidth: rect.width,
      );
    }
    final yTitle = config.configExtra['yAxisTitle']?.toString() ?? '';
    if (yTitle.isNotEmpty) {
      canvas.save();
      canvas.translate(8, rect.center.dy);
      canvas.rotate(-math.pi / 2);
      _desenharTextoCentralizado(
        canvas,
        yTitle,
        Offset.zero,
        TextStyle(
          fontSize: axisFontSize + 1,
          color: axisColor,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: rect.height,
      );
      canvas.restore();
    }
  }

  void _desenharBarras(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados, {
    required bool horizontal,
  }) {
    final tipo = config.tipo.toLowerCase();
    final empilhado = tipo.contains('empilh') || tipo.contains('100%');
    if (empilhado && dados.any((d) => d.containsKey('value2'))) {
      _desenharBarrasEmpilhadas(
        canvas,
        rect,
        dados,
        horizontal: horizontal,
        percentual: tipo.contains('100%'),
      );
      return;
    }
    if (!empilhado && dados.any((d) => d.containsKey('value2'))) {
      _desenharBarrasAgrupadas(canvas, rect, dados, horizontal: horizontal);
      return;
    }

    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    final quantidade = dados.length;
    if (quantidade == 0) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    if (horizontal) {
      final slotHeight = rect.height / quantidade;
      final gap = slotHeight * _numExtra('barGap', 0.08).clamp(0.0, 0.75);
      final barHeight = slotHeight - gap;
      for (int i = 0; i < quantidade; i++) {
        final item = dados[i];
        final valor = ((item['value'] ?? 0) as num).toDouble();
        final largura = _normalizar(valor, maxValor) * rect.width;
        final top = rect.top + i * slotHeight + gap / 2;
        final barRect = Rect.fromLTWH(rect.left, top, largura, barHeight);
        final barColorMode = config.configExtra['barColorMode'] ?? 'categoria';
        final baseColor = barColorMode == 'unica' || _usarCorPorMetrica
            ? _corMetricaPrincipal()
            : _converterCor(item['color']);
        final corBarra = _corDoItem(_conditionalColor(valor, baseColor), i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect,
            Radius.circular(_numExtra('barRadius', 4)),
          ),
          Paint()
            ..color = corBarra.withValues(alpha: _numExtra('barOpacity', 1.0)),
        );
        if (_numExtra('barBorderWidth', 0) > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              barRect,
              Radius.circular(_numExtra('barRadius', 4)),
            ),
            Paint()
              ..color = _converterCor(
                config.configExtra['barBorderColor'],
                const Color(0xFF0F172A),
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = _numExtra('barBorderWidth', 0),
          );
        }
        if (config.mostrarValores && largura > 24) {
          _desenharTextoCentralizado(
            canvas,
            _formatarNumero(valor),
            Offset(
              math.min(rect.right - 18, barRect.right + 22),
              barRect.center.dy,
            ),
            const TextStyle(fontSize: 10, color: Color(0xFF334155)),
            maxWidth: 48,
          );
        }
      }
      return;
    }

    final slotWidth = rect.width / quantidade;
    final gap = slotWidth * _numExtra('barGap', 0.08).clamp(0.0, 0.75);
    final barWidth =
        (slotWidth - gap) * _numExtra('barWidthFactor', 0.82).clamp(0.2, 1.0);
    for (int i = 0; i < quantidade; i++) {
      final item = dados[i];
      final valor = ((item['value'] ?? 0) as num).toDouble();
      final altura = _normalizar(valor, maxValor) * rect.height;
      final left = rect.left + i * slotWidth + (slotWidth - barWidth) / 2;
      final barRect = Rect.fromLTWH(
        left,
        rect.bottom - altura,
        barWidth,
        altura,
      );
      final barColorMode = config.configExtra['barColorMode'] ?? 'categoria';
      final baseColor = barColorMode == 'unica' || _usarCorPorMetrica
          ? _corMetricaPrincipal()
          : _converterCor(item['color']);
      final corBarra = _corDoItem(_conditionalColor(valor, baseColor), i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          barRect,
          Radius.circular(_numExtra('barRadius', 4)),
        ),
        Paint()
          ..color = corBarra.withValues(alpha: _numExtra('barOpacity', 1.0)),
      );
      if (_numExtra('barBorderWidth', 0) > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            barRect,
            Radius.circular(_numExtra('barRadius', 4)),
          ),
          Paint()
            ..color = _converterCor(
              config.configExtra['barBorderColor'],
              const Color(0xFF0F172A),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = _numExtra('barBorderWidth', 0),
        );
      }

      if (config.mostrarValores && altura > 18) {
        _desenharTextoCentralizado(
          canvas,
          _formatarNumero(valor),
          Offset(barRect.center.dx, math.max(rect.top + 8, barRect.top - 8)),
          const TextStyle(fontSize: 10, color: Color(0xFF334155)),
          maxWidth: slotWidth,
        );
      }

      if (config.mostrarRotulos) {
        final label = item['label'].toString();
        textPainter.text = TextSpan(
          text: label.length > 8 ? '${label.substring(0, 8)}.' : label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
        );
        textPainter.layout(maxWidth: slotWidth);
        textPainter.paint(canvas, Offset(left, rect.bottom + 8));
      }
    }
  }

  void _desenharBarrasAgrupadas(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados, {
    required bool horizontal,
  }) {
    if (dados.isEmpty) return;
    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    final primary = _corMetricaPrincipal();
    final secondary = _corMetricaSecundaria();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (horizontal) {
      final slot = rect.height / dados.length;
      final groupGap = slot * _numExtra('barGap', 0.08).clamp(0.0, 0.6);
      final barHeight = (slot - groupGap) / 2;
      for (int i = 0; i < dados.length; i++) {
        final v1 = ((dados[i]['value'] ?? 0) as num).toDouble();
        final v2 = ((dados[i]['value2'] ?? 0) as num).toDouble();
        final top = rect.top + i * slot + groupGap / 2;
        final r1 = Rect.fromLTWH(
          rect.left,
          top,
          rect.width * _normalizar(v1, maxValor),
          barHeight,
        );
        final r2 = Rect.fromLTWH(
          rect.left,
          top + barHeight,
          rect.width * _normalizar(v2, maxValor),
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r1,
            Radius.circular(_numExtra('barRadius', 4)),
          ),
          Paint()..color = _corDoItem(_conditionalColor(v1, primary), i),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r2,
            Radius.circular(_numExtra('barRadius', 4)),
          ),
          Paint()..color = _corDoItem(secondary, i),
        );
      }
      return;
    }

    final slot = rect.width / dados.length;
    final groupGap = slot * _numExtra('barGap', 0.08).clamp(0.0, 0.6);
    final width =
        ((slot - groupGap) / 2) *
        _numExtra('barWidthFactor', 0.82).clamp(0.2, 1.0);
    for (int i = 0; i < dados.length; i++) {
      final item = dados[i];
      final v1 = ((item['value'] ?? 0) as num).toDouble();
      final v2 = ((item['value2'] ?? 0) as num).toDouble();
      final groupLeft = rect.left + i * slot + groupGap / 2;
      final r1 = Rect.fromLTWH(
        groupLeft,
        rect.bottom - rect.height * _normalizar(v1, maxValor),
        width,
        rect.height * _normalizar(v1, maxValor),
      );
      final r2 = Rect.fromLTWH(
        groupLeft + width,
        rect.bottom - rect.height * _normalizar(v2, maxValor),
        width,
        rect.height * _normalizar(v2, maxValor),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r1, Radius.circular(_numExtra('barRadius', 4))),
        Paint()..color = _corDoItem(_conditionalColor(v1, primary), i),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r2, Radius.circular(_numExtra('barRadius', 4))),
        Paint()..color = _corDoItem(secondary, i),
      );
      if (config.mostrarValores) {
        _desenharTextoCentralizado(
          canvas,
          _formatarNumero(v1),
          Offset(r1.center.dx, math.max(rect.top + 7, r1.top - 7)),
          TextStyle(
            fontSize: _numExtra('labelFontSize', 10),
            color: _converterCor(
              config.configExtra['labelColor'],
              const Color(0xFF334155),
            ),
          ),
          maxWidth: width + 8,
        );
        _desenharTextoCentralizado(
          canvas,
          _formatarNumero(v2),
          Offset(r2.center.dx, math.max(rect.top + 7, r2.top - 7)),
          TextStyle(
            fontSize: _numExtra('labelFontSize', 10),
            color: _converterCor(
              config.configExtra['labelColor'],
              const Color(0xFF334155),
            ),
          ),
          maxWidth: width + 8,
        );
      }
      if (config.mostrarRotulos) {
        final label = item['label'].toString();
        textPainter.text = TextSpan(
          text: label.length > 12 ? '${label.substring(0, 12)}...' : label,
          style: TextStyle(
            fontSize: _numExtra('xAxisFontSize', 9),
            color: _converterCor(
              config.configExtra['xAxisColor'],
              const Color(0xFF475569),
            ),
          ),
        );
        textPainter.layout(maxWidth: slot);
        textPainter.paint(
          canvas,
          Offset(rect.left + i * slot, rect.bottom + 8),
        );
      }
    }
  }

  void _desenharBarrasEmpilhadas(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados, {
    required bool horizontal,
    required bool percentual,
  }) {
    final quantidade = dados.length;
    if (quantidade == 0) return;
    final maxValor = percentual ? 1.0 : _maxValorEmpilhado(dados);
    _desenharGrade(canvas, rect, percentual ? 100 : maxValor);
    final primaryColor = _corMetricaPrincipal();
    final secondaryColor = _corMetricaSecundaria();
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (horizontal) {
      final slotHeight = rect.height / quantidade;
      final gap = slotHeight * _numExtra('barGap', 0.08).clamp(0.0, 0.75);
      final barHeight = slotHeight - gap;
      for (int i = 0; i < quantidade; i++) {
        final item = dados[i];
        final v1 = ((item['value'] ?? 0) as num).toDouble().abs();
        final v2 = ((item['value2'] ?? 0) as num).toDouble().abs();
        final total = math.max(1.0, v1 + v2);
        final base = percentual ? total : maxValor;
        final w1 = rect.width * (v1 / base);
        final w2 = rect.width * (v2 / base);
        final top = rect.top + i * slotHeight + gap / 2;
        final r1 = Rect.fromLTWH(rect.left, top, w1, barHeight);
        final r2 = Rect.fromLTWH(rect.left + w1, top, w2, barHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r1, const Radius.circular(5)),
          Paint()
            ..color = _corDoItem(
              primaryColor,
              i,
            ).withValues(alpha: _numExtra('barOpacity', 1.0)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r2, const Radius.circular(5)),
          Paint()
            ..color = _corDoItem(
              secondaryColor,
              i,
            ).withValues(alpha: _numExtra('barOpacity', 1.0)),
        );
        if (config.mostrarValores && barHeight > 14) {
          final label = percentual
              ? '${((v1 / total) * 100).toStringAsFixed(0)}% / ${((v2 / total) * 100).toStringAsFixed(0)}%'
              : '${_formatarNumero(v1)} + ${_formatarNumero(v2)}';
          _desenharTextoCentralizado(
            canvas,
            label,
            Offset(rect.left + math.max(40, w1 + w2) / 2, r1.center.dy),
            const TextStyle(
              fontSize: 10,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
            maxWidth: math.max(70, w1 + w2),
          );
        }
      }
      return;
    }

    final slotWidth = rect.width / quantidade;
    final gap = slotWidth * _numExtra('barGap', 0.08).clamp(0.0, 0.75);
    final barWidth =
        (slotWidth - gap) * _numExtra('barWidthFactor', 0.82).clamp(0.2, 1.0);
    for (int i = 0; i < quantidade; i++) {
      final item = dados[i];
      final v1 = ((item['value'] ?? 0) as num).toDouble().abs();
      final v2 = ((item['value2'] ?? 0) as num).toDouble().abs();
      final total = math.max(1.0, v1 + v2);
      final base = percentual ? total : maxValor;
      final h1 = rect.height * (v1 / base);
      final h2 = rect.height * (v2 / base);
      final left = rect.left + i * slotWidth + (slotWidth - barWidth) / 2;
      final r1 = Rect.fromLTWH(left, rect.bottom - h1, barWidth, h1);
      final r2 = Rect.fromLTWH(left, rect.bottom - h1 - h2, barWidth, h2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r1, const Radius.circular(5)),
        Paint()
          ..color = _corDoItem(
            primaryColor,
            i,
          ).withValues(alpha: _numExtra('barOpacity', 1.0)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r2, const Radius.circular(5)),
        Paint()
          ..color = _corDoItem(
            secondaryColor,
            i,
          ).withValues(alpha: _numExtra('barOpacity', 1.0)),
      );
      if (config.mostrarRotulos) {
        final label = item['label'].toString();
        textPainter.text = TextSpan(
          text: label.length > 8 ? '${label.substring(0, 8)}.' : label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
        );
        textPainter.layout(maxWidth: slotWidth);
        textPainter.paint(canvas, Offset(left, rect.bottom + 8));
      }
      if (config.mostrarValores && _boolExtra('showTotalLabels', false)) {
        _desenharTextoCentralizado(
          canvas,
          percentual ? '100%' : _formatarNumero(v1 + v2),
          Offset(r2.center.dx, math.max(rect.top + 8, r2.top - 8)),
          TextStyle(
            fontSize: _numExtra('labelFontSize', 10),
            color: _converterCor(
              config.configExtra['labelColor'],
              const Color(0xFF334155),
            ),
            fontWeight: FontWeight.w700,
          ),
          maxWidth: slotWidth,
        );
      }
    }
  }

  void _desenharLinhaOuArea(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
    bool area,
  ) {
    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    if (dados.length < 2) return;

    List<Offset> pointsFor(String key) {
      return List.generate(dados.length, (index) {
        final value = ((dados[index][key] ?? 0) as num).toDouble();
        final x = rect.left + (rect.width / (dados.length - 1)) * index;
        final y = rect.bottom - _normalizar(value, maxValor) * rect.height;
        return Offset(x, y);
      });
    }

    Path pathFor(List<Offset> points) {
      final interpolation =
          config.configExtra['lineInterpolation']?.toString() ?? 'linear';
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];
        if (interpolation == 'step') {
          path
            ..lineTo(current.dx, previous.dy)
            ..lineTo(current.dx, current.dy);
        } else if (interpolation == 'smooth') {
          final midpoint = (previous.dx + current.dx) / 2;
          path.cubicTo(
            midpoint,
            previous.dy,
            midpoint,
            current.dy,
            current.dx,
            current.dy,
          );
        } else {
          path.lineTo(current.dx, current.dy);
        }
      }
      return path;
    }

    final series = <({String key, Color color})>[
      (key: 'value', color: _corMetricaPrincipal()),
      if (dados.any((item) => item.containsKey('value2')))
        (key: 'value2', color: _corMetricaSecundaria()),
    ];

    for (final serie in series) {
      final points = pointsFor(serie.key);
      final path = pathFor(points);
      if (area) {
        final areaPath = Path.from(path)
          ..lineTo(points.last.dx, rect.bottom)
          ..lineTo(points.first.dx, rect.bottom)
          ..close();
        canvas.drawPath(
          areaPath,
          Paint()
            ..color = serie.color.withValues(
              alpha: _numExtra('areaOpacity', 0.28),
            ),
        );
      }

      _drawStyledPath(
        canvas,
        path,
        Paint()
          ..color = serie.color
          ..strokeWidth = _numExtra(
            'lineWidth',
            (config.configExtra['espessuraLinha'] ?? 3.0).toDouble(),
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      final showMarkers =
          config.configExtra['markerVisible'] as bool? ??
          config.configExtra['mostrarPontos'] as bool? ??
          true;
      if (showMarkers) {
        for (int i = 0; i < points.length; i++) {
          final point = points[i];
          _drawMarker(
            canvas,
            point,
            _numExtra('markerSize', 4),
            _corDoItem(serie.color, i),
          );
          if (config.mostrarValores) {
            final value = ((dados[i][serie.key] ?? 0) as num).toDouble();
            _desenharTextoCentralizado(
              canvas,
              _formatarNumero(value),
              point.translate(0, serie.key == 'value' ? -14 : 14),
              TextStyle(
                fontSize: _numExtra('labelFontSize', 10),
                color: _converterCor(
                  config.configExtra['labelColor'],
                  const Color(0xFF334155),
                ),
              ),
              maxWidth: 62,
            );
          }
        }
      }
    }

    if (config.mostrarRotulos) {
      final painter = TextPainter(textDirection: TextDirection.ltr);
      final rotation = _numExtra('xAxisRotation', 0) * math.pi / 180;
      for (int i = 0; i < dados.length; i++) {
        final label = dados[i]['label']?.toString() ?? '';
        painter.text = TextSpan(
          text: label.length > 10 ? '${label.substring(0, 10)}...' : label,
          style: TextStyle(
            fontSize: _numExtra('xAxisFontSize', 9),
            color: _converterCor(
              config.configExtra['xAxisColor'],
              const Color(0xFF475569),
            ),
          ),
        );
        painter.layout(maxWidth: math.max(44, rect.width / dados.length));
        final x = rect.left + (rect.width / (dados.length - 1)) * i;
        canvas.save();
        canvas.translate(x, rect.bottom + 8);
        canvas.rotate(rotation);
        painter.paint(canvas, Offset(-painter.width / 2, 0));
        canvas.restore();
      }
    }
  }

  void _drawStyledPath(Canvas canvas, Path path, Paint paint) {
    final style = config.configExtra['lineStyle']?.toString() ?? 'solid';
    if (style == 'solid') {
      canvas.drawPath(path, paint);
      return;
    }
    final dash = style == 'dotted' ? 2.0 : 8.0;
    final gap = style == 'dotted' ? 5.0 : 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  void _drawMarker(Canvas canvas, Offset point, double size, Color color) {
    final shape = config.configExtra['markerShape']?.toString() ?? 'circle';
    final paint = Paint()..color = color;
    if (shape == 'square') {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: size * 2, height: size * 2),
        paint,
      );
    } else if (shape == 'diamond') {
      final path = Path()
        ..moveTo(point.dx, point.dy - size)
        ..lineTo(point.dx + size, point.dy)
        ..lineTo(point.dx, point.dy + size)
        ..lineTo(point.dx - size, point.dy)
        ..close();
      canvas.drawPath(path, paint);
    } else if (shape == 'triangle') {
      final path = Path()
        ..moveTo(point.dx, point.dy - size)
        ..lineTo(point.dx + size, point.dy + size)
        ..lineTo(point.dx - size, point.dy + size)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      canvas.drawCircle(point, size, paint);
    }
  }

  void _desenharAreaEmpilhada(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados, {
    required bool percentual,
  }) {
    if (dados.length < 2) return;
    final maxValor = percentual ? 1.0 : _maxValorEmpilhado(dados);
    _desenharGrade(canvas, rect, percentual ? 100 : maxValor);

    List<Offset> pontosBase = [];
    List<Offset> pontosTopo = [];
    for (int i = 0; i < dados.length; i++) {
      final v1 = ((dados[i]['value'] ?? 0) as num).toDouble().abs();
      final v2 = ((dados[i]['value2'] ?? 0) as num).toDouble().abs();
      final total = math.max(1.0, v1 + v2);
      final base = percentual ? total : maxValor;
      final x = rect.left + (rect.width / (dados.length - 1)) * i;
      final yBase = rect.bottom - (v1 / base) * rect.height;
      final yTopo = rect.bottom - ((v1 + v2) / base) * rect.height;
      pontosBase.add(Offset(x, yBase));
      pontosTopo.add(Offset(x, yTopo));
    }

    Path area1 = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(pontosBase.first.dx, pontosBase.first.dy);
    for (final ponto in pontosBase.skip(1)) {
      area1.lineTo(ponto.dx, ponto.dy);
    }
    area1
      ..lineTo(rect.right, rect.bottom)
      ..close();

    Path area2 = Path()..moveTo(pontosBase.first.dx, pontosBase.first.dy);
    for (final ponto in pontosBase.skip(1)) {
      area2.lineTo(ponto.dx, ponto.dy);
    }
    for (final ponto in pontosTopo.reversed) {
      area2.lineTo(ponto.dx, ponto.dy);
    }
    area2.close();

    canvas.drawPath(
      area1,
      Paint()..color = _corMetricaPrincipal().withValues(alpha: 0.35),
    );
    canvas.drawPath(
      area2,
      Paint()..color = _corMetricaSecundaria().withValues(alpha: 0.42),
    );
    canvas.drawPath(
      Path()..addPolygon(pontosTopo, false),
      Paint()
        ..color = _corMetricaSecundaria()
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _desenharDispersao(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final xValues = dados
        .map((d) => ((d['value'] ?? 0) as num).toDouble())
        .toList();
    final hasY = dados.any((item) => item.containsKey('value2'));
    final yValues = List<double>.generate(
      dados.length,
      (index) => hasY
          ? ((dados[index]['value2'] ?? 0) as num).toDouble()
          : index.toDouble() + 1,
    );
    final xMin = xValues.reduce(math.min);
    final xMax = xValues.reduce(math.max);
    final yMin = yValues.reduce(math.min);
    final yMax = yValues.reduce(math.max);
    _desenharGrade(canvas, rect, yMax <= 0 ? 1 : yMax);

    if (_boolExtra('showQuadrants', false)) {
      final xAverage = xValues.reduce((a, b) => a + b) / xValues.length;
      final yAverage = yValues.reduce((a, b) => a + b) / yValues.length;
      final x =
          rect.left +
          ((xAverage - xMin) / math.max(0.000001, xMax - xMin)) * rect.width;
      final y =
          rect.bottom -
          ((yAverage - yMin) / math.max(0.000001, yMax - yMin)) * rect.height;
      final quadrantPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        quadrantPaint,
      );
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        quadrantPaint,
      );
    }

    final plotted = <Offset>[];
    for (int i = 0; i < dados.length; i++) {
      final x =
          rect.left +
          ((xValues[i] - xMin) / math.max(0.000001, xMax - xMin)) * rect.width;
      final y =
          rect.bottom -
          ((yValues[i] - yMin) / math.max(0.000001, yMax - yMin)) * rect.height;
      final point = Offset(x, y);
      plotted.add(point);
      canvas.drawCircle(
        point,
        _numExtra('bubbleSize', 7),
        Paint()
          ..color = _corDoItem(
            _conditionalColor(
              yValues[i],
              _converterCor(
                _usarCorPorMetrica
                    ? config.configExtra['corMetricaPrincipal']
                    : dados[i]['color'],
                const Color(0xFFEF4444),
              ),
            ),
            i,
          ).withValues(alpha: _numExtra('bubbleOpacity', 0.82)),
      );
    }

    if ((_boolExtra('regressionLine', false) ||
            _boolExtra('trendLine', false)) &&
        dados.length >= 2) {
      final meanX = xValues.reduce((a, b) => a + b) / xValues.length;
      final meanY = yValues.reduce((a, b) => a + b) / yValues.length;
      var numerator = 0.0;
      var denominator = 0.0;
      for (int i = 0; i < xValues.length; i++) {
        numerator += (xValues[i] - meanX) * (yValues[i] - meanY);
        denominator += math.pow(xValues[i] - meanX, 2).toDouble();
      }
      final slope = denominator == 0 ? 0.0 : numerator / denominator;
      final intercept = meanY - slope * meanX;
      double yFor(double x) => slope * x + intercept;
      final startY =
          rect.bottom -
          ((yFor(xMin) - yMin) / math.max(0.000001, yMax - yMin)) * rect.height;
      final endY =
          rect.bottom -
          ((yFor(xMax) - yMin) / math.max(0.000001, yMax - yMin)) * rect.height;
      canvas.drawLine(
        Offset(rect.left, startY),
        Offset(rect.right, endY),
        Paint()
          ..color = _converterCor(
            config.configExtra['regressionColor'],
            const Color(0xFFEF4444),
          )
          ..strokeWidth = 2,
      );
    }
  }

  void _desenharRadar(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final quantidade = math.min(dados.length, 8);
    if (quantidade < 3) {
      _desenharLinhaOuArea(canvas, rect, dados, true);
      return;
    }

    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * 0.42;
    final maxValor = _maxValor(dados);
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke;

    for (int level = 1; level <= 4; level++) {
      final path = Path();
      for (int i = 0; i < quantidade; i++) {
        final angle = -math.pi / 2 + (2 * math.pi / quantidade) * i;
        final p =
            center +
            Offset(math.cos(angle), math.sin(angle)) * radius * (level / 4);
        if (i == 0)
          path.moveTo(p.dx, p.dy);
        else
          path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    void drawSeries(String key, Color color) {
      final dataPath = Path();
      for (int i = 0; i < quantidade; i++) {
        final valor = ((dados[i][key] ?? 0) as num).toDouble();
        final angle = -math.pi / 2 + (2 * math.pi / quantidade) * i;
        final p =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                radius *
                (valor / maxValor).clamp(0.0, 1.0);
        if (i == 0) {
          dataPath.moveTo(p.dx, p.dy);
        } else {
          dataPath.lineTo(p.dx, p.dy);
        }
        if (_boolExtra('markerVisible', true)) {
          _drawMarker(canvas, p, _numExtra('markerSize', 4), color);
        }
      }
      dataPath.close();
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = color.withValues(alpha: _numExtra('areaOpacity', 0.22)),
      );
      canvas.drawPath(
        dataPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _numExtra('lineWidth', 2.5),
      );
    }

    drawSeries('value', _corMetricaPrincipal(const Color(0xFF14B8A6)));
    if (dados.any((item) => item.containsKey('value2'))) {
      drawSeries('value2', _corMetricaSecundaria());
    }
  }

  void _desenharPizza(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
    bool rosca,
  ) {
    final total = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble().abs(),
    );
    if (total <= 0) return;

    final lado = math.min(rect.width, rect.height);
    final pieRect = Rect.fromCenter(
      center: rect.center,
      width: lado * 0.86,
      height: lado * 0.86,
    );
    double inicio = _numExtra('pieStartAngle', -90) * math.pi / 180;

    for (int i = 0; i < dados.length; i++) {
      final item = dados[i];
      final valor = ((item['value'] ?? 0) as num).toDouble().abs();
      final sweep = (valor / total) * math.pi * 2;
      final midAngle = inicio + sweep / 2;
      final exploded = _numExtra('explodeSlice', -1).round() == i;
      final offset = exploded
          ? Offset(math.cos(midAngle), math.sin(midAngle)) *
                _numExtra('explodeDistance', 12)
          : Offset.zero;
      final sliceRect = pieRect.shift(offset);
      final baseColor = _converterCor(
        _usarCorPorMetrica
            ? config.configExtra['corMetricaPrincipal']
            : item['color'],
      );
      canvas.drawArc(
        sliceRect,
        inicio,
        sweep,
        true,
        Paint()
          ..color = _corDoItem(
            _conditionalColor(valor, baseColor),
            i,
          ).withValues(alpha: _numExtra('sliceOpacity', 1.0)),
      );
      if (_numExtra('sliceBorderWidth', 1) > 0) {
        canvas.drawArc(
          sliceRect,
          inicio,
          sweep,
          true,
          Paint()
            ..color = _converterCor(
              config.configExtra['sliceBorderColor'],
              Colors.white,
            )
            ..strokeWidth = _numExtra('sliceBorderWidth', 1)
            ..style = PaintingStyle.stroke,
        );
      }
      if (config.mostrarValores && sweep > 0.22) {
        final legacyPercent =
            config.configExtra['mostrarPorcentagem'] as bool? ?? false;
        final texto = legacyPercent
            ? '${((valor / total) * 100).toStringAsFixed(0)}%'
            : _textoRotulo(item, valor, total);
        final outside =
            config.configExtra['labelPosition']?.toString() == 'outside';
        final pos =
            rect.center +
            offset +
            Offset(math.cos(midAngle), math.sin(midAngle)) *
                (lado * (outside ? 0.47 : 0.30));
        _desenharTextoCentralizado(
          canvas,
          texto,
          pos,
          TextStyle(
            fontSize: _numExtra('labelFontSize', 11),
            color: outside
                ? _converterCor(
                    config.configExtra['labelColor'],
                    const Color(0xFF334155),
                  )
                : Colors.white,
            fontWeight: FontWeight.w700,
          ),
          maxWidth: outside ? 92 : 68,
        );
      }
      inicio += sweep;
    }

    final raioFuro = (config.configExtra['raioFuro'] ?? (rosca ? 0.58 : 0.0))
        .toDouble();
    if (raioFuro > 0) {
      canvas.drawCircle(
        rect.center,
        (lado * 0.43) * raioFuro,
        Paint()..color = config.corFundo,
      );
      final centerMode =
          config.configExtra['donutCenterMode']?.toString() ?? 'total';
      if (centerMode != 'none') {
        final text = centerMode == 'text'
            ? config.configExtra['donutCenterText']?.toString() ?? ''
            : _formatarNumero(total);
        if (text.isNotEmpty) {
          _desenharTextoCentralizado(
            canvas,
            text,
            rect.center,
            TextStyle(
              fontSize: math.max(12, lado * 0.075),
              color: config.corTextoTitulo,
              fontWeight: FontWeight.w800,
            ),
            maxWidth: lado * raioFuro * 0.62,
          );
        }
      }
    }
  }

  void _desenharGauge(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final valor = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final min = (config.configExtra['gaugeMin'] ?? 0.0).toDouble();
    final max = (config.configExtra['gaugeMax'] ?? math.max(valor, 1.0))
        .toDouble();
    final meta = (config.configExtra['gaugeMeta'] ?? max).toDouble();
    final progress = ((valor - min) / math.max(1, max - min)).clamp(0.0, 1.0);
    final metaProgress = ((meta - min) / math.max(1, max - min)).clamp(
      0.0,
      1.0,
    );
    final center = Offset(rect.center.dx, rect.bottom - rect.height * 0.08);
    final radius = math.min(rect.width, rect.height * 1.65) * 0.42;
    final gaugeRect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi;
    const sweep = math.pi;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = _numExtra('gaugeThickness', math.max(12, radius * 0.18))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final valuePaint = Paint()
      ..color = _corMetricaPrincipal()
      ..strokeWidth = backgroundPaint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final metaPaint = Paint()
      ..color = _converterCor(
        config.configExtra['corMeta'],
        const Color(0xFFEF4444),
      )
      ..strokeWidth = 3;

    canvas.drawArc(gaugeRect, start, sweep, false, backgroundPaint);
    final ruim = _converterCor(
      config.configExtra['gaugeBadColor'],
      const Color(0xFFEF4444),
    );
    final medio = _converterCor(
      config.configExtra['gaugeMidColor'],
      const Color(0xFFF59E0B),
    );
    final bom = _converterCor(
      config.configExtra['gaugeGoodColor'],
      const Color(0xFF10B981),
    );
    if (_boolExtra('gaugeMostrarFaixas', false)) {
      final rangePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = backgroundPaint.strokeWidth * 0.52
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        gaugeRect,
        start,
        sweep * 0.34,
        false,
        rangePaint..color = ruim,
      );
      canvas.drawArc(
        gaugeRect,
        start + sweep * 0.34,
        sweep * 0.33,
        false,
        rangePaint..color = medio,
      );
      canvas.drawArc(
        gaugeRect,
        start + sweep * 0.67,
        sweep * 0.33,
        false,
        rangePaint..color = bom,
      );
    }
    canvas.drawArc(gaugeRect, start, sweep * progress, false, valuePaint);

    if (_boolExtra('gaugeShowTicks', true)) {
      final tickPaint = Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 1;
      for (int i = 0; i <= 10; i++) {
        final angle = start + sweep * (i / 10);
        final inner =
            center + Offset(math.cos(angle), math.sin(angle)) * (radius + 2);
        final outer =
            center + Offset(math.cos(angle), math.sin(angle)) * (radius + 7);
        canvas.drawLine(inner, outer, tickPaint);
      }
    }

    final metaAngle = start + sweep * metaProgress;
    final p1 =
        center +
        Offset(math.cos(metaAngle), math.sin(metaAngle)) *
            (radius - backgroundPaint.strokeWidth);
    final p2 =
        center +
        Offset(math.cos(metaAngle), math.sin(metaAngle)) *
            (radius + backgroundPaint.strokeWidth * 0.35);
    canvas.drawLine(p1, p2, metaPaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: _formatarNumero(valor),
      style: TextStyle(
        fontSize: math.max(22, rect.width * 0.11),
        fontWeight: FontWeight.w600,
        color: config.corTextoTitulo,
      ),
    );
    textPainter.layout(maxWidth: rect.width);
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );

    if (config.mostrarRotulos && _boolExtra('gaugeShowScale', true)) {
      final minText = TextPainter(
        text: TextSpan(
          text: _formatarNumero(min),
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final maxText = TextPainter(
        text: TextSpan(
          text: _formatarNumero(max),
          style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      minText.paint(canvas, Offset(rect.left + 6, center.dy + 4));
      maxText.paint(
        canvas,
        Offset(rect.right - maxText.width - 6, center.dy + 4),
      );
    }
  }

  void _desenharTreemap(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final total = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble().abs(),
    );
    if (total <= 0) return;

    var remaining = rect;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < dados.length; i++) {
      final item = dados[i];
      final fraction = (((item['value'] ?? 0) as num).toDouble().abs() / total)
          .clamp(0.03, 1.0);
      Rect cell;
      if (i == dados.length - 1) {
        cell = remaining;
      } else if (remaining.width >= remaining.height) {
        final w = remaining.width * fraction;
        cell = Rect.fromLTWH(
          remaining.left,
          remaining.top,
          w,
          remaining.height,
        );
        remaining = Rect.fromLTWH(
          remaining.left + w,
          remaining.top,
          remaining.width - w,
          remaining.height,
        );
      } else {
        final h = remaining.height * fraction;
        cell = Rect.fromLTWH(remaining.left, remaining.top, remaining.width, h);
        remaining = Rect.fromLTWH(
          remaining.left,
          remaining.top + h,
          remaining.width,
          remaining.height - h,
        );
      }

      final rawValue = ((item['value'] ?? 0) as num).toDouble().abs();
      final color = _corDoItem(
        _conditionalColor(rawValue, _converterCor(item['color'])),
        i,
      ).withValues(alpha: _numExtra('treemapOpacity', 1.0));
      final spacing = _numExtra('treemapSpacing', 0);
      final visibleCell = spacing > 0 ? cell.deflate(spacing / 2) : cell;
      canvas.drawRect(visibleCell, Paint()..color = color);
      canvas.drawRect(visibleCell, border);

      if (config.mostrarRotulos &&
          visibleCell.width > 46 &&
          visibleCell.height > 28) {
        textPainter.text = TextSpan(
          text: item['label'].toString(),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout(maxWidth: visibleCell.width - 8);
        textPainter.paint(
          canvas,
          Offset(visibleCell.left + 6, visibleCell.top + 6),
        );
      }
      if (config.mostrarValores &&
          visibleCell.width > 58 &&
          visibleCell.height > 46) {
        textPainter.text = TextSpan(
          text: _textoRotulo(item, rawValue, total),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        );
        textPainter.layout(maxWidth: visibleCell.width - 8);
        textPainter.paint(
          canvas,
          Offset(
            visibleCell.left + 6,
            visibleCell.bottom - textPainter.height - 6,
          ),
        );
      }
    }
  }

  void _desenharFunnel(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final valores = dados
        .map((d) => ((d['value'] ?? 0) as num).toDouble().abs())
        .toList();
    if (valores.isEmpty) return;
    final maxValor = valores.reduce(math.max).clamp(1, double.infinity);
    final stepHeight = rect.height / dados.length;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < dados.length; i++) {
      final valor = valores[i];
      final widthTop = rect.width * (valor / maxValor).clamp(0.18, 1.0);
      final nextValue = i == dados.length - 1 ? valor : valores[i + 1];
      final widthBottom = rect.width * (nextValue / maxValor).clamp(0.18, 1.0);
      final y = rect.top + i * stepHeight;
      final path = Path()
        ..moveTo(rect.center.dx - widthTop / 2, y)
        ..lineTo(rect.center.dx + widthTop / 2, y)
        ..lineTo(rect.center.dx + widthBottom / 2, y + stepHeight - 4)
        ..lineTo(rect.center.dx - widthBottom / 2, y + stepHeight - 4)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _corDoItem(
            _converterCor(dados[i]['color']),
            i,
          ).withValues(alpha: 0.9),
      );

      if (config.mostrarValores) {
        final conversion = valores.first == 0
            ? 0.0
            : (valor / valores.first) * 100;
        final showConversion = _boolExtra('funnelShowConversion', true);
        textPainter.text = TextSpan(
          text:
              '${dados[i]['label']}  ${_formatarNumero(valor)}${showConversion ? '  (${conversion.toStringAsFixed(0)}%)' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout(maxWidth: widthTop - 12);
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            y + stepHeight / 2 - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _desenharWaterfall(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final deltas = dados
        .map((d) => ((d['value'] ?? 0) as num).toDouble())
        .toList();
    final cumulativos = <double>[0];
    for (final delta in deltas) {
      cumulativos.add(cumulativos.last + delta);
    }
    final minValor = cumulativos.reduce(math.min);
    final maxValor = cumulativos.reduce(math.max);
    final escala = math.max(1, maxValor - minValor);
    final gap = rect.width * 0.03;
    final barWidth = (rect.width - gap * (dados.length - 1)) / dados.length;
    final zeroY = rect.bottom - ((0 - minValor) / escala) * rect.height;
    final connectorPaint = Paint()
      ..color = _converterCor(
        config.configExtra['waterfallConnectorColor'],
        const Color(0xFF94A3B8),
      )
      ..strokeWidth = _numExtra('waterfallConnectorWidth', 1.2);

    canvas.drawLine(
      Offset(rect.left, zeroY),
      Offset(rect.right, zeroY),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    for (int i = 0; i < dados.length; i++) {
      final start = cumulativos[i];
      final end = cumulativos[i + 1];
      final topVal = math.max(start, end);
      final bottomVal = math.min(start, end);
      final left = rect.left + i * (barWidth + gap);
      final top = rect.bottom - ((topVal - minValor) / escala) * rect.height;
      final bottom =
          rect.bottom - ((bottomVal - minValor) / escala) * rect.height;
      final barRect = Rect.fromLTRB(left, top, left + barWidth, bottom);
      final isPositive = end >= start;
      final isLast = i == dados.length - 1;
      final color = isLast
          ? _converterCor(
              config.configExtra['waterfallTotalColor'],
              _corMetricaPrincipal(),
            )
          : isPositive
          ? _converterCor(
              config.configExtra['waterfallPositiveColor'],
              const Color(0xFF10B981),
            )
          : _converterCor(
              config.configExtra['waterfallNegativeColor'],
              const Color(0xFFEF4444),
            );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        Paint()..color = color,
      );
      if (i < dados.length - 1 && _boolExtra('waterfallShowConnectors', true)) {
        final y = rect.bottom - ((end - minValor) / escala) * rect.height;
        canvas.drawLine(
          Offset(left + barWidth, y),
          Offset(left + barWidth + gap, y),
          connectorPaint,
        );
      }
      if (config.mostrarValores) {
        _desenharTextoCentralizado(
          canvas,
          _formatarNumero(end - start),
          Offset(left + barWidth / 2, top - 9),
          const TextStyle(fontSize: 10, color: Color(0xFF334155)),
          maxWidth: barWidth + 8,
        );
      }
      if (config.mostrarRotulos) {
        _desenharTextoCentralizado(
          canvas,
          dados[i]['label']?.toString() ?? '',
          Offset(left + barWidth / 2, rect.bottom + 10),
          TextStyle(
            fontSize: _numExtra('xAxisFontSize', 9),
            color: _converterCor(
              config.configExtra['xAxisColor'],
              const Color(0xFF475569),
            ),
          ),
          maxWidth: barWidth + gap,
        );
      }
    }
  }

  void _desenharHistograma(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final valores =
        dados
            .map((d) => ((d['value'] ?? 0) as num).toDouble())
            .where((v) => v.isFinite)
            .toList()
          ..sort();
    if (valores.isEmpty) return;
    final binsMode =
        config.configExtra['histogramBinsMode']?.toString() ?? 'auto';
    final bins = binsMode == 'manual'
        ? _numExtra('histogramBins', 10).round().clamp(3, 40)
        : math.min(20, math.max(4, (math.sqrt(valores.length) * 2).round()));
    final minValor = valores.first;
    final maxValor = valores.last;
    final step = math.max(1, (maxValor - minValor) / bins);
    final counts = List<int>.filled(bins, 0);
    for (final valor in valores) {
      final index = ((valor - minValor) / step).floor().clamp(0, bins - 1);
      counts[index]++;
    }
    final relative =
        config.configExtra['histogramFrequency']?.toString() == 'relative';
    final frequencies = counts
        .map((count) => relative ? count / valores.length : count.toDouble())
        .toList();
    final maxCount = frequencies
        .reduce(math.max)
        .clamp(0.000001, double.infinity);
    final barWidth = rect.width / bins;
    for (int i = 0; i < bins; i++) {
      final h = rect.height * (frequencies[i] / maxCount);
      final bar = Rect.fromLTWH(
        rect.left + i * barWidth + 2,
        rect.bottom - h,
        barWidth - 4,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = _corMetricaPrincipal().withValues(alpha: 0.86),
      );
      if (config.mostrarValores && bar.width > 20) {
        _desenharTextoCentralizado(
          canvas,
          relative
              ? '${(frequencies[i] * 100).toStringAsFixed(0)}%'
              : counts[i].toString(),
          Offset(bar.center.dx, math.max(rect.top + 8, bar.top - 8)),
          TextStyle(
            fontSize: _numExtra('labelFontSize', 10),
            color: _converterCor(
              config.configExtra['labelColor'],
              const Color(0xFF334155),
            ),
          ),
          maxWidth: bar.width + 4,
        );
      }
    }
  }

  void _desenharBoxPlot(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final valores =
        dados
            .map((d) => ((d['value'] ?? 0) as num).toDouble())
            .where((v) => v.isFinite)
            .toList()
          ..sort();
    if (valores.length < 2) {
      _desenharBarras(canvas, rect, dados, horizontal: false);
      return;
    }

    double quantile(double q) {
      final pos = (valores.length - 1) * q;
      final lower = pos.floor();
      final upper = pos.ceil();
      if (lower == upper) return valores[lower];
      return valores[lower] + (valores[upper] - valores[lower]) * (pos - lower);
    }

    final minValor = valores.first;
    final q1 = quantile(0.25);
    final median = quantile(0.5);
    final q3 = quantile(0.75);
    final maxValor = valores.last;
    final span = math.max(1.0, maxValor - minValor);
    double yFor(double value) =>
        rect.bottom - ((value - minValor) / span) * rect.height;

    final centerX = rect.center.dx;
    final boxWidth = math.min(120.0, rect.width * 0.42);
    final box = Rect.fromLTRB(
      centerX - boxWidth / 2,
      yFor(q3),
      centerX + boxWidth / 2,
      yFor(q1),
    );
    final paint = Paint()
      ..color = _corMetricaPrincipal().withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = _corMetricaPrincipal()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, yFor(maxValor)),
      Offset(centerX, box.top),
      stroke,
    );
    canvas.drawLine(
      Offset(centerX, box.bottom),
      Offset(centerX, yFor(minValor)),
      stroke,
    );
    canvas.drawLine(
      Offset(centerX - boxWidth * 0.3, yFor(maxValor)),
      Offset(centerX + boxWidth * 0.3, yFor(maxValor)),
      stroke,
    );
    canvas.drawLine(
      Offset(centerX - boxWidth * 0.3, yFor(minValor)),
      Offset(centerX + boxWidth * 0.3, yFor(minValor)),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      stroke,
    );
    canvas.drawLine(
      Offset(box.left, yFor(median)),
      Offset(box.right, yFor(median)),
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 2.5,
    );
    if (config.mostrarValores) {
      _desenharTextoCentralizado(
        canvas,
        'Mediana ${_formatarNumero(median)}',
        Offset(centerX, box.bottom + 18),
        const TextStyle(
          fontSize: 11,
          color: Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
        maxWidth: rect.width,
      );
    }
  }

  void _desenharHeatmap(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final cols = math.sqrt(dados.length).ceil();
    final rows = (dados.length / cols).ceil();
    final cellW = rect.width / cols;
    final cellH = rect.height / rows;
    final maxValor = _maxValor(dados);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      var intensity = (valor / maxValor).clamp(0.0, 1.0);
      if (config.configExtra['heatmapScale']?.toString() == 'log') {
        intensity = math.log(1 + intensity * 9) / math.log(10);
      }
      final row = i ~/ cols;
      final col = i % cols;
      final cell = Rect.fromLTWH(
        rect.left + col * cellW,
        rect.top + row * cellH,
        cellW,
        cellH,
      ).deflate(2);
      final palette =
          config.configExtra['heatmapPalette']?.toString() ?? 'blueRed';
      final startColor = palette == 'greenRed'
          ? const Color(0xFFDCFCE7)
          : const Color(0xFFDBEAFE);
      final color = Color.lerp(startColor, const Color(0xFFEF4444), intensity)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell, const Radius.circular(6)),
        Paint()..color = color,
      );
      if (config.mostrarValores &&
          _boolExtra('heatmapShowValues', true) &&
          cellW > 46 &&
          cellH > 28) {
        textPainter.text = TextSpan(
          text: _formatarNumero(valor),
          style: TextStyle(
            color: intensity > 0.55 ? Colors.white : const Color(0xFF0F172A),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
        textPainter.layout(maxWidth: cell.width - 4);
        textPainter.paint(
          canvas,
          Offset(
            cell.center.dx - textPainter.width / 2,
            cell.center.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _desenharBullet(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final atual = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final meta = _numExtra('kpiMeta', atual * 1.18);
    final maxValor = math.max(atual, meta).clamp(1, double.infinity).toDouble();
    final track = Rect.fromLTWH(rect.left, rect.center.dy - 20, rect.width, 40);
    final ruim = Rect.fromLTWH(
      track.left,
      track.top,
      track.width * 0.45,
      track.height,
    );
    final medio = Rect.fromLTWH(
      track.left + track.width * 0.45,
      track.top,
      track.width * 0.3,
      track.height,
    );
    final bom = Rect.fromLTWH(
      track.left + track.width * 0.75,
      track.top,
      track.width * 0.25,
      track.height,
    );
    canvas.drawRect(ruim, Paint()..color = const Color(0xFFFEE2E2));
    canvas.drawRect(medio, Paint()..color = const Color(0xFFFEF3C7));
    canvas.drawRect(bom, Paint()..color = const Color(0xFFDCFCE7));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          track.left,
          track.center.dy - 8,
          track.width * (atual / maxValor),
          16,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = _corMetricaPrincipal(),
    );
    final metaX = track.left + track.width * (meta / maxValor).clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(metaX, track.top - 8),
      Offset(metaX, track.bottom + 8),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 3,
    );
    _desenharTextoCentralizado(
      canvas,
      _formatarNumero(atual),
      Offset(track.left + 36, track.top - 16),
      const TextStyle(
        fontSize: 12,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w800,
      ),
      maxWidth: 90,
    );
  }

  void _desenharCombo(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final dadosColuna = dados
        .map(
          (d) => <String, dynamic>{
            'label': d['label'],
            'value': d['value'],
            'color': d['color'],
          },
        )
        .toList();
    _desenharBarras(canvas, rect, dadosColuna, horizontal: false);
    final dadosLinha = dados
        .map(
          (d) => {
            ...d,
            'value': d.containsKey('value2')
                ? ((d['value2'] ?? 0) as num).toDouble()
                : ((d['value'] ?? 0) as num).toDouble() * 0.82,
          },
        )
        .toList();
    final linhaConfig = ChartConfig(
      id: config.id,
      tipo: 'Grafico de Linha',
      titulo: config.titulo,
      dimensao: config.dimensao,
      metrica: config.metrica,
      dados: dadosLinha,
      posicao: config.posicao,
      corFundo: config.corFundo,
      mostrarValores: false,
      mostrarRotulos: false,
      mostrarEixos: false,
      configExtra: {
        ...config.configExtra,
        'corMetricaPrincipal': _corMetricaSecundaria().toARGB32().toString(),
        'lineColor': _corMetricaSecundaria().toARGB32().toString(),
        'markerColor': _corMetricaSecundaria().toARGB32().toString(),
        'markerVisible': true,
        'mostrarPontos': true,
        if (!(config.configExtra['secondaryAxis'] as bool? ?? true))
          'yAxisMax': _maxValor(dadosColuna),
      },
    );
    _ChartPainter(
      linhaConfig,
      hoveredIndex: hoveredIndex,
      selectedLabels: selectedLabels,
    )._desenharLinhaOuArea(canvas, rect, linhaConfig.dados, false);
  }

  void _desenharRibbon(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.length < 2 || !dados.any((item) => item.containsKey('value2'))) {
      _desenharBarras(canvas, rect, dados, horizontal: false);
      return;
    }
    _desenharGrade(canvas, rect, _maxValor(dados));
    final colors = [_corMetricaPrincipal(), _corMetricaSecundaria()];
    final spacing = _numExtra('ribbonSpacing', 0.12).clamp(0.0, 0.4);
    final bandHeight = math.max(10.0, rect.height * (0.28 - spacing * 0.2));

    for (int series = 0; series < 2; series++) {
      final centers = <Offset>[];
      for (int i = 0; i < dados.length; i++) {
        final v1 = ((dados[i]['value'] ?? 0) as num).toDouble();
        final v2 = ((dados[i]['value2'] ?? 0) as num).toDouble();
        final firstRank = v1 >= v2 ? 0 : 1;
        final rank = series == firstRank ? 0 : 1;
        final x = rect.left + (rect.width / (dados.length - 1)) * i;
        final y = rect.top + rect.height * (rank == 0 ? 0.30 : 0.70);
        centers.add(Offset(x, y));
      }
      final path = Path()
        ..moveTo(centers.first.dx, centers.first.dy - bandHeight / 2);
      for (int i = 1; i < centers.length; i++) {
        final previous = centers[i - 1];
        final current = centers[i];
        final mid = (previous.dx + current.dx) / 2;
        path.cubicTo(
          mid,
          previous.dy - bandHeight / 2,
          mid,
          current.dy - bandHeight / 2,
          current.dx,
          current.dy - bandHeight / 2,
        );
      }
      for (int i = centers.length - 1; i >= 0; i--) {
        final current = centers[i];
        if (i == centers.length - 1) {
          path.lineTo(current.dx, current.dy + bandHeight / 2);
        } else {
          final next = centers[i + 1];
          final mid = (current.dx + next.dx) / 2;
          path.cubicTo(
            mid,
            next.dy + bandHeight / 2,
            mid,
            current.dy + bandHeight / 2,
            current.dx,
            current.dy + bandHeight / 2,
          );
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = colors[series].withValues(alpha: 0.72),
      );
      _desenharTextoCentralizado(
        canvas,
        series == 0
            ? config.metrica
            : config.configExtra['metricaSecundaria']?.toString() ??
                  'Segunda metrica',
        centers.last.translate(-34, 0),
        const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        maxWidth: 110,
      );
    }

    if (config.mostrarRotulos) {
      for (int i = 0; i < dados.length; i++) {
        _desenharTextoCentralizado(
          canvas,
          dados[i]['label']?.toString() ?? '',
          Offset(
            rect.left + (rect.width / (dados.length - 1)) * i,
            rect.bottom + 9,
          ),
          TextStyle(
            fontSize: _numExtra('xAxisFontSize', 9),
            color: _converterCor(
              config.configExtra['xAxisColor'],
              const Color(0xFF475569),
            ),
          ),
          maxWidth: math.max(42, rect.width / dados.length),
        );
      }
    }
  }

  void _desenharAnalytics(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final values = dados
        .map((item) => ((item['value'] ?? 0) as num).toDouble())
        .toList();
    final sorted = List<double>.from(values)..sort();
    final maxValue = _maxValor(dados);
    final color = _converterCor(
      config.configExtra['analyticsColor'],
      const Color(0xFFEF4444),
    );
    final lines = <({String label, double value})>[];
    if (_boolExtra('analyticsAverage', false)) {
      lines.add((
        label: 'Media',
        value: values.reduce((a, b) => a + b) / values.length,
      ));
    }
    if (_boolExtra('analyticsMin', false)) {
      lines.add((label: 'Min', value: sorted.first));
    }
    if (_boolExtra('analyticsMax', false)) {
      lines.add((label: 'Max', value: sorted.last));
    }
    if (_boolExtra('analyticsMedian', false)) {
      final middle = sorted.length ~/ 2;
      final median = sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2;
      lines.add((label: 'Mediana', value: median));
    }
    if (_boolExtra('analyticsTarget', false)) {
      lines.add((label: 'Meta', value: _numExtra('analyticsTargetValue', 0)));
    }

    for (final line in lines) {
      final y = rect.bottom - _normalizar(line.value, maxValue) * rect.height;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = color
          ..strokeWidth = 1.5,
      );
      _desenharTextoCentralizado(
        canvas,
        '${line.label} ${_formatarNumero(line.value)}',
        Offset(rect.right - 48, y - 8),
        TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
        maxWidth: 104,
      );
    }

    if (_boolExtra('trendLine', false) && dados.length > 2) {
      final meanX = (dados.length - 1) / 2;
      final meanY = values.reduce((a, b) => a + b) / values.length;
      var numerator = 0.0;
      var denominator = 0.0;
      for (int i = 0; i < values.length; i++) {
        numerator += (i - meanX) * (values[i] - meanY);
        denominator += math.pow(i - meanX, 2).toDouble();
      }
      final slope = denominator == 0 ? 0.0 : numerator / denominator;
      final intercept = meanY - slope * meanX;
      final start = intercept;
      final end = intercept + slope * (values.length - 1);
      canvas.drawLine(
        Offset(
          rect.left,
          rect.bottom - _normalizar(start, maxValue) * rect.height,
        ),
        Offset(
          rect.right,
          rect.bottom - _normalizar(end, maxValue) * rect.height,
        ),
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..strokeWidth = 2,
      );
    }
  }

  void _desenharAnomalias(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.length < 4) return;
    final values = dados
        .map((item) => ((item['value'] ?? 0) as num).toDouble())
        .toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    final deviation = math.sqrt(variance);
    final maxValue = _maxValor(dados);
    for (int i = 0; i < values.length; i++) {
      if ((values[i] - mean).abs() < deviation * 1.5) continue;
      final point = Offset(
        rect.left + (rect.width / (values.length - 1)) * i,
        rect.bottom - _normalizar(values[i], maxValue) * rect.height,
      );
      canvas.drawCircle(
        point,
        8,
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.18),
      );
      canvas.drawCircle(point, 4, Paint()..color = const Color(0xFFEF4444));
    }
  }

  void _desenharSankey(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final maxValor = _maxValor(dados);
    final leftX = rect.left + rect.width * 0.12;
    final rightX = rect.right - rect.width * 0.12;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final sources = dados
        .map((item) => item['label'].toString())
        .toSet()
        .take(8)
        .toList();
    final targets = dados
        .map(
          (item) =>
              item['secondaryLabel']?.toString() ??
              item['label']?.toString() ??
              'Destino',
        )
        .toSet()
        .take(8)
        .toList();
    double nodeY(List<String> values, String value) {
      final index = math.max(0, values.indexOf(value));
      return rect.top +
          rect.height * (index + 0.5) / math.max(1, values.length);
    }

    for (int i = 0; i < dados.length; i++) {
      final source = dados[i]['label'].toString();
      final target = dados[i]['secondaryLabel']?.toString() ?? source;
      if (!sources.contains(source) || !targets.contains(target)) continue;
      final sourceY = nodeY(sources, source);
      final targetY = nodeY(targets, target);
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final stroke = 4 + 18 * (valor / maxValor);
      final path = Path()
        ..moveTo(leftX, sourceY)
        ..cubicTo(
          rect.center.dx - rect.width * 0.12,
          sourceY,
          rect.center.dx + rect.width * 0.12,
          targetY,
          rightX,
          targetY,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = _converterCor(dados[i]['color']).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }

    for (int i = 0; i < sources.length; i++) {
      final y = nodeY(sources, sources[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(leftX, y), width: 10, height: 30),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF2563EB),
      );
      textPainter.text = TextSpan(
        text: sources[i],
        style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
      );
      textPainter.layout(maxWidth: rect.width * 0.22);
      textPainter.paint(
        canvas,
        Offset(leftX - textPainter.width - 10, y - textPainter.height / 2),
      );
    }
    for (int i = 0; i < targets.length; i++) {
      final y = nodeY(targets, targets[i]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(rightX, y), width: 10, height: 30),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF10B981),
      );
      textPainter.text = TextSpan(
        text: targets[i],
        style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
      );
      textPainter.layout(maxWidth: rect.width * 0.22);
      textPainter.paint(
        canvas,
        Offset(rightX + 10, y - textPainter.height / 2),
      );
    }
  }

  void _desenharGantt(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final maxValor = _maxValor(dados);
    final rowH = rect.height / dados.length;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final start = rect.left + rect.width * ((i % 4) / 10);
      final width = math.max(36.0, rect.width * 0.72 * (valor / maxValor));
      final bar = Rect.fromLTWH(
        start,
        rect.top + i * rowH + rowH * 0.25,
        width,
        rowH * 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(999)),
        Paint()
          ..color = _converterCor(dados[i]['color']).withValues(alpha: 0.88),
      );
      textPainter.text = TextSpan(
        text: dados[i]['label'].toString(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
      );
      textPainter.layout(maxWidth: rect.width * 0.32);
      textPainter.paint(canvas, Offset(rect.left, bar.top - 2));
    }
  }

  void _desenharNetwork(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) * 0.36;
    final labels = <String>{};
    for (final item in dados) {
      labels.add(item['label'].toString());
      labels.add(
        item['secondaryLabel']?.toString() ?? item['label'].toString(),
      );
      if (labels.length >= 12) break;
    }
    final nodes = labels.take(12).toList();
    final points = <String, Offset>{};
    for (int i = 0; i < nodes.length; i++) {
      final angle = -math.pi / 2 + (2 * math.pi / nodes.length) * i;
      points[nodes[i]] =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }
    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4;
    for (final item in dados) {
      final source = points[item['label'].toString()];
      final target =
          points[item['secondaryLabel']?.toString() ??
              item['label'].toString()];
      if (source == null || target == null || source == target) continue;
      canvas.drawLine(source, target, linePaint);
    }
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < nodes.length; i++) {
      final point = points[nodes[i]]!;
      canvas.drawCircle(
        point,
        9,
        Paint()..color = _converterCor(dados[i % dados.length]['color']),
      );
      textPainter.text = TextSpan(
        text: nodes[i],
        style: const TextStyle(fontSize: 9, color: Color(0xFF334155)),
      );
      textPainter.layout(maxWidth: rect.width * 0.18);
      textPainter.paint(canvas, point + Offset(-textPainter.width / 2, 12));
    }
  }

  void _desenharDecompositionTree(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final root = Rect.fromCenter(
      center: Offset(rect.left + rect.width * 0.18, rect.center.dy),
      width: math.min(120.0, rect.width * 0.24),
      height: 54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(root, const Radius.circular(12)),
      Paint()..color = const Color(0xFF2563EB),
    );
    _desenharTextoCentralizado(
      canvas,
      'Total',
      root.center,
      const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: root.width - 12,
    );

    final sources = dados
        .map((item) => item['label'].toString())
        .toSet()
        .take(4)
        .toList();
    final nodes = sources.length;
    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;
    for (int i = 0; i < nodes; i++) {
      final y = rect.top + (rect.height / (nodes + 1)) * (i + 1);
      final node = Rect.fromCenter(
        center: Offset(rect.left + rect.width * 0.54, y),
        width: math.min(130.0, rect.width * 0.26),
        height: 44,
      );
      canvas.drawLine(
        root.centerRight,
        Offset(node.left, node.center.dy),
        linePaint,
      );
      final sourceItems = dados
          .where((item) => item['label'].toString() == sources[i])
          .toList();
      final color = _converterCor(sourceItems.first['color']);
      canvas.drawRRect(
        RRect.fromRectAndRadius(node, const Radius.circular(10)),
        Paint()..color = color.withValues(alpha: 0.16),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(node, const Radius.circular(10)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      _desenharTextoCentralizado(
        canvas,
        sources[i],
        node.center,
        const TextStyle(
          color: Color(0xFF334155),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        maxWidth: node.width - 12,
      );

      final target = sourceItems.first['secondaryLabel']?.toString();
      if (target == null || target == sources[i]) continue;
      final child = Rect.fromCenter(
        center: Offset(rect.left + rect.width * 0.84, y),
        width: math.min(112.0, rect.width * 0.22),
        height: 36,
      );
      canvas.drawLine(node.centerRight, child.centerLeft, linePaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(child, const Radius.circular(8)),
        Paint()..color = color.withValues(alpha: 0.10),
      );
      _desenharTextoCentralizado(
        canvas,
        target,
        child.center,
        const TextStyle(
          color: Color(0xFF475569),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: child.width - 10,
      );
    }
  }

  void _desenharSunburst(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    if (dados.isEmpty) return;
    final total = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble().abs(),
    );
    if (total == 0) return;
    final outer = math.min(rect.width, rect.height) * 0.40;
    final innerRect = Rect.fromCircle(
      center: rect.center,
      radius: outer * 0.62,
    );
    final outerRect = Rect.fromCircle(center: rect.center, radius: outer);
    var start = -math.pi / 2;
    for (int i = 0; i < dados.length; i++) {
      final value = ((dados[i]['value'] ?? 0) as num).toDouble().abs();
      final sweep = 2 * math.pi * value / total;
      final color = _converterCor(dados[i]['color']);
      canvas.drawArc(
        innerRect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer * 0.34,
      );
      canvas.drawArc(
        outerRect,
        start,
        sweep,
        false,
        Paint()
          ..color = color.withValues(
            alpha: dados[i]['secondaryLabel'] == null ? 0.52 : 0.78,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer * 0.24,
      );
      start += sweep;
    }
    canvas.drawCircle(
      rect.center,
      outer * 0.24,
      Paint()..color = config.corFundo,
    );
    _desenharTextoCentralizado(
      canvas,
      _formatarValor(total),
      rect.center,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: outer * 0.42,
    );
  }

  void _desenharMapa(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final type = config.tipo.toLowerCase();
    final isFilled =
        type.contains('preenchido') ||
        type.contains('shape') ||
        type.contains('corop');
    final isHeat = type.contains('calor') || _boolExtra('mapHeatLayer', false);
    final mapStyle = config.configExtra['mapStyle']?.toString() ?? 'light';
    final backgroundColor = mapStyle == 'dark'
        ? const Color(0xFF172033)
        : mapStyle == 'satellite'
        ? const Color(0xFF335B4A)
        : const Color(0xFFE0F2FE);
    final bg = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      bg,
    );
    final maxValor = _maxValor(dados);
    final roadPaint = Paint()
      ..color = (mapStyle == 'dark' ? Colors.white : const Color(0xFF64748B))
          .withValues(alpha: 0.20)
      ..strokeWidth = 1.2;
    for (int i = 1; i <= 4; i++) {
      final y = rect.top + rect.height * i / 5;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y - rect.height * 0.08),
        roadPaint,
      );
    }
    final regioes = [
      Rect.fromLTWH(
        rect.left + rect.width * 0.10,
        rect.top + rect.height * 0.22,
        rect.width * 0.34,
        rect.height * 0.32,
      ),
      Rect.fromLTWH(
        rect.left + rect.width * 0.44,
        rect.top + rect.height * 0.30,
        rect.width * 0.42,
        rect.height * 0.38,
      ),
      Rect.fromLTWH(
        rect.left + rect.width * 0.25,
        rect.top + rect.height * 0.56,
        rect.width * 0.28,
        rect.height * 0.22,
      ),
    ];

    for (int i = 0; i < regioes.length; i++) {
      final valor = dados.isEmpty
          ? 0.0
          : ((dados[i % dados.length]['value'] ?? 0) as num).toDouble();
      final intensity = (valor / maxValor).clamp(0.0, 1.0);
      final color = isFilled
          ? Color.lerp(
              const Color(0xFFBAE6FD),
              const Color(0xFF0369A1),
              intensity,
            )!
          : const Color(0xFFBAE6FD);
      final regionPath = Path()
        ..moveTo(regioes[i].left, regioes[i].center.dy)
        ..quadraticBezierTo(
          regioes[i].center.dx,
          regioes[i].top - 8,
          regioes[i].right,
          regioes[i].center.dy,
        )
        ..quadraticBezierTo(
          regioes[i].center.dx,
          regioes[i].bottom + 8,
          regioes[i].left,
          regioes[i].center.dy,
        )
        ..close();
      canvas.drawPath(regionPath, Paint()..color = color);
      canvas.drawPath(
        regionPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    if (isFilled) return;

    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final x = rect.left + rect.width * (0.18 + ((i * 37) % 65) / 100);
      final y = rect.top + rect.height * (0.22 + ((i * 29) % 55) / 100);
      final r =
          _numExtra('mapBubbleSize', 12) *
          (0.45 + 0.75 * (valor / maxValor).clamp(0.0, 1.0));
      final opacity = _numExtra('mapOpacity', 0.82);
      if (isHeat) {
        canvas.drawCircle(
          Offset(x, y),
          r * 2.4,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFEF4444).withValues(alpha: opacity * 0.55),
                    const Color(0xFFF59E0B).withValues(alpha: opacity * 0.22),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(center: Offset(x, y), radius: r * 2.4),
                ),
        );
        continue;
      }
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = _corDoItem(
            _converterCor(dados[i]['color'], const Color(0xFF2563EB)),
            i,
          ).withValues(alpha: opacity * 0.48),
      );
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = _corDoItem(
            _converterCor(dados[i]['color'], const Color(0xFF1D4ED8)),
            i,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.selectedLabels != selectedLabels;
  }
}

class _TabelaVisual extends StatelessWidget {
  final ChartConfig config;

  const _TabelaVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final headerColor = _visualColor(
      config.configExtra['headerColor'],
      const Color(0xFF1D4ED8),
    );
    final totalColor = _visualColor(
      config.configExtra['totalColor'],
      const Color(0xFFFDE047),
    );
    final rowColorA = _visualColor(
      config.configExtra['rowColorA'],
      const Color(0xFFFFFFFF),
    );
    final rowColorB = _visualColor(
      config.configExtra['rowColorB'],
      const Color(0xFFF1F5F9),
    );
    final gridColor = _visualColor(
      config.configExtra['gridColor'],
      const Color(0xFFE2E8F0),
    );
    final rowTextColor = _visualColor(
      config.configExtra['rowTextColor'],
      const Color(0xFF0F172A),
    );
    final rowHeight = ((config.configExtra['rowHeight'] ?? 34) as num)
        .toDouble();
    final headerTextColor = _visualColor(
      config.configExtra['headerTextColor'],
      Colors.white,
    );
    final headerFontSize = ((config.configExtra['headerFontSize'] ?? 12) as num)
        .toDouble();
    final headerHeight = ((config.configExtra['headerHeight'] ?? 36) as num)
        .toDouble();
    final gridWidth = ((config.configExtra['gridWidth'] ?? 1) as num)
        .toDouble();
    final zebraRows = config.configExtra['zebraRows'] as bool? ?? true;
    final showTotals = config.configExtra['showTotals'] as bool? ?? true;
    final dataBars =
        config.configExtra['conditionalDataBars'] as bool? ?? false;
    final icons = config.configExtra['conditionalIcons'] as bool? ?? false;
    final rows = config.dados;
    final total = rows.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final maxValue = rows.isEmpty
        ? 1.0
        : rows
              .map((item) => ((item['value'] ?? 0) as num).toDouble().abs())
              .reduce(math.max)
              .clamp(1, double.infinity)
              .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: headerColor,
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  config.dimensao,
                  style: TextStyle(
                    color: headerTextColor,
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  config.metrica,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: headerTextColor,
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final item = rows[index];
              final even = index.isEven;
              return Container(
                height: rowHeight,
                decoration: BoxDecoration(
                  color: !zebraRows || even ? rowColorA : rowColorB,
                  border: Border(
                    bottom: BorderSide(color: gridColor, width: gridWidth),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['label'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                        ).copyWith(color: rowTextColor),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          if (dataBars)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (((item['value'] ?? 0) as num)
                                                .toDouble()
                                                .abs() /
                                            maxValue)
                                        .clamp(0.0, 1.0),
                                child: Container(
                                  color: const Color(
                                    0xFF60A5FA,
                                  ).withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (icons) ...[
                                Icon(
                                  ((item['value'] ?? 0) as num).toDouble() >=
                                          total / math.max(1, rows.length)
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 14,
                                  color:
                                      ((item['value'] ?? 0) as num)
                                              .toDouble() >=
                                          total / math.max(1, rows.length)
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  _formatarValorVisual(
                                    config,
                                    ((item['value'] ?? 0) as num).toDouble(),
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ).copyWith(color: rowTextColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (showTotals)
          Container(
            color: totalColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Total",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _formatarValorVisual(config, total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MatrizVisual extends StatelessWidget {
  final ChartConfig config;

  const _MatrizVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final rows = config.dados;
    final hasValue2 = rows.any((item) => item.containsKey('value2'));
    final total = rows.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final headerColor = _visualColor(
      config.configExtra['headerColor'],
      const Color(0xFF1E293B),
    );
    final gridColor = _visualColor(
      config.configExtra['gridColor'],
      const Color(0xFFE2E8F0),
    );
    final headerTextColor = _visualColor(
      config.configExtra['headerTextColor'],
      Colors.white,
    );
    final rowColorA = _visualColor(
      config.configExtra['rowColorA'],
      Colors.white,
    );
    final rowColorB = _visualColor(
      config.configExtra['rowColorB'],
      const Color(0xFFF8FAFC),
    );
    final rowTextColor = _visualColor(
      config.configExtra['rowTextColor'],
      const Color(0xFF0F172A),
    );
    final rowHeight = ((config.configExtra['rowHeight'] ?? 34) as num)
        .toDouble();
    final headerHeight = ((config.configExtra['headerHeight'] ?? 36) as num)
        .toDouble();
    final expanded = config.configExtra['matrixExpanded'] as bool? ?? false;
    final showTotals = config.configExtra['showTotals'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: headerColor,
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  config.dimensao,
                  style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  config.metrica,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: headerTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasValue2)
                Expanded(
                  child: Text(
                    config.configExtra['metricaSecundaria']?.toString() ??
                        'Segunda metrica',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: headerTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    '%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: headerTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final item = rows[index];
              final value = ((item['value'] ?? 0) as num).toDouble();
              final percent = total == 0 ? 0.0 : value / total;
              return Container(
                height: expanded ? rowHeight + 12 : rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index.isEven ? rowColorA : rowColorB,
                  border: Border(bottom: BorderSide(color: gridColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: rowTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (expanded)
                                  Text(
                                    item['secondaryLabel']?.toString() ??
                                        'Subtotal ${_formatarValorVisual(config, value)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: rowTextColor.withValues(
                                        alpha: 0.64,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatarValorVisual(config, value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        hasValue2
                            ? _formatarValorVisual(
                                config,
                                ((item['value2'] ?? 0) as num).toDouble(),
                              )
                            : '${(percent * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: rowTextColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (showTotals)
          Container(
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total geral',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _formatarValorVisual(config, total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProgressBarVisual extends StatelessWidget {
  final ChartConfig config;

  const _ProgressBarVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final value = config.dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final meta = ((config.configExtra['kpiMeta'] ?? value * 1.25) as num)
        .toDouble()
        .clamp(1.0, double.infinity);
    final progress = (value / meta).clamp(0.0, 1.0);
    final color = _visualColor(
      config.configExtra['corMetricaPrincipal'] ??
          config.configExtra['corPrincipal'],
      const Color(0xFF10B981),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: config.corTextoTitulo,
                    fontSize: constraints.maxHeight < 150 ? 24 : 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: constraints.maxHeight < 150 ? 16 : 24,
                    value: progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: color,
                  ),
                ),
                if (config.mostrarValores) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_formatarValor(value)} de ${_formatarValor(meta)}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentacaoVisual extends StatefulWidget {
  final ChartConfig config;
  final Set<String>? selecionadosExternos;
  final ValueChanged<Set<String>>? onChanged;

  const _SegmentacaoVisual({
    required this.config,
    this.selecionadosExternos,
    this.onChanged,
  });

  @override
  State<_SegmentacaoVisual> createState() => _SegmentacaoVisualState();
}

class _SegmentacaoVisualState extends State<_SegmentacaoVisual> {
  final Set<String> _selecionados = {};
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  String _query = '';
  RangeValues? _range;

  @override
  void dispose() {
    _searchController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _emit(Set<String> next) {
    if (widget.onChanged != null) {
      widget.onChanged!(next);
    } else {
      setState(() {
        _selecionados
          ..clear()
          ..addAll(next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final selectedColor = _visualColor(
      config.configExtra['slicerSelectedColor'] ??
          config.configExtra['corPrincipal'],
      const Color(0xFF0F5592),
    );
    final itemColor = _visualColor(
      config.configExtra['slicerItemColor'],
      const Color(0xFFE5E7EB),
    );
    final hoverColor = _visualColor(
      config.configExtra['slicerHoverColor'],
      const Color(0xFFDBEAFE),
    );
    final permiteMultipla =
        config.configExtra['segmentacaoMultipla'] as bool? ?? true;
    final estilo = config.configExtra['slicerStyle']?.toString() ?? 'botoes';
    final mostrarBusca = config.configExtra['slicerSearch'] as bool? ?? false;
    final placeholder =
        config.configExtra['slicerPlaceholder']?.toString() ?? 'Buscar';
    final selecionados = widget.selecionadosExternos ?? _selecionados;
    final values = config.dados.map((d) => d['label'].toString()).toList();
    final visibleValues = values
        .where((value) => value.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final itens = visibleValues.map((value) {
      final selected = selecionados.contains(value);
      return InkWell(
        borderRadius: BorderRadius.circular(
          (config.configExtra['chipRadius'] ?? 8).toDouble(),
        ),
        hoverColor: hoverColor,
        onTap: () {
          final proximos = Set<String>.from(selecionados);
          if (!permiteMultipla) proximos.clear();
          if (selected && proximos.contains(value)) {
            proximos.remove(value);
          } else {
            proximos.add(value);
          }
          _emit(proximos);
        },
        child: Container(
          width: estilo == 'lista' ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: estilo == 'tags' ? 10 : 12,
            vertical: estilo == 'tags' ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? selectedColor : itemColor,
            borderRadius: BorderRadius.circular(
              estilo == 'tags'
                  ? 999
                  : (config.configExtra['chipRadius'] ?? 8).toDouble(),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }).toList();

    if (estilo == 'dropdown') {
      return DropdownButtonFormField<String>(
        key: ValueKey(selecionados.isNotEmpty ? selecionados.first : 'none'),
        initialValue: selecionados.isNotEmpty ? selecionados.first : null,
        decoration: InputDecoration(labelText: placeholder),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: (v) {
          final next = v == null ? <String>{} : {v};
          _emit(next);
        },
      );
    }

    if (estilo == 'between' && values.length > 1) {
      final max = (values.length - 1).toDouble();
      final current = _range ?? RangeValues(0, max);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${values[current.start.round()]} - ${values[current.end.round()]}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          RangeSlider(
            values: current,
            min: 0,
            max: max,
            divisions: values.length - 1,
            onChanged: (range) {
              setState(() => _range = range);
              _emit(
                values
                    .sublist(range.start.round(), range.end.round() + 1)
                    .toSet(),
              );
            },
          ),
        ],
      );
    }

    if ((estilo == 'before' || estilo == 'after') && values.length > 1) {
      final max = (values.length - 1).toDouble();
      final selectedIndex = selecionados.isEmpty
          ? (estilo == 'before' ? max : 0.0)
          : values
                .indexOf(selecionados.first)
                .clamp(0, values.length - 1)
                .toDouble();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${estilo == 'before' ? 'Ate' : 'A partir de'} ${values[selectedIndex.round()]}',
          ),
          Slider(
            value: selectedIndex,
            min: 0,
            max: max,
            divisions: values.length - 1,
            onChanged: (value) {
              final index = value.round();
              _emit(
                estilo == 'before'
                    ? values.sublist(0, index + 1).toSet()
                    : values.sublist(index).toSet(),
              );
            },
          ),
        ],
      );
    }

    if (estilo == 'relativeDate' || estilo == 'relativeTime') {
      final options = estilo == 'relativeDate'
          ? const {
              '7': 'Ultimos 7 itens',
              '30': 'Ultimos 30 itens',
              '90': 'Ultimos 90 itens',
            }
          : const {
              '6': 'Ultimas 6 horas',
              '12': 'Ultimas 12 horas',
              '24': 'Ultimas 24 horas',
            };
      return DropdownButtonFormField<String>(
        initialValue: options.keys.first,
        decoration: const InputDecoration(labelText: 'Periodo relativo'),
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (raw) {
          final amount = int.tryParse(raw ?? '') ?? values.length;
          _emit(values.skip(math.max(0, values.length - amount)).toSet());
        },
      );
    }

    if (estilo == 'input') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: placeholder,
                prefixIcon: const Icon(Icons.edit_outlined),
                isDense: true,
              ),
              onSubmitted: (_) {
                final query = _inputController.text.trim().toLowerCase();
                _emit(
                  values
                      .where((value) => value.toLowerCase().contains(query))
                      .toSet(),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Aplicar filtro',
            onPressed: () {
              final query = _inputController.text.trim().toLowerCase();
              _emit(
                values
                    .where((value) => value.toLowerCase().contains(query))
                    .toSet(),
              );
            },
            icon: const Icon(Icons.check),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrarBusca) ...[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
        ],
        if (config.configExtra['slicerSelectAll'] as bool? ?? true)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _emit(
                selecionados.length == values.length
                    ? <String>{}
                    : values.toSet(),
              ),
              icon: Icon(
                selecionados.length == values.length
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
              label: Text(
                selecionados.length == values.length
                    ? 'Limpar selecao'
                    : 'Selecionar tudo',
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 8, children: itens),
          ),
        ),
      ],
    );
  }
}

class _CartaoKpiVisual extends StatelessWidget {
  final ChartConfig config;

  const _CartaoKpiVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final value = config.dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    final legacyPrefix = config.configExtra['prefixo']?.toString() ?? '';
    final legacySuffix = config.configExtra['sufixo']?.toString() ?? '';
    final prefix = legacyPrefix.isNotEmpty
        ? legacyPrefix
        : config.configExtra['numberPrefix']?.toString() ?? '';
    final suffix = legacySuffix.isNotEmpty
        ? legacySuffix
        : config.configExtra['numberSuffix']?.toString() ?? '';
    final decimals = ((config.configExtra['decimais'] ?? 0) as num).round();
    final showMeta = config.configExtra['kpiShowMeta'] as bool? ?? false;
    final meta = ((config.configExtra['kpiMeta'] ?? 0) as num).toDouble();
    final previous = ((config.configExtra['kpiPrevious'] ?? 0) as num)
        .toDouble();
    final showTrend = config.configExtra['kpiShowTrend'] as bool? ?? false;
    final direction =
        config.configExtra['kpiDirection']?.toString() ?? 'higherIsBetter';
    final rawTrendUp = previous <= 0 || value >= previous;
    final trendPositive = direction == 'lowerIsBetter'
        ? !rawTrendUp
        : rawTrendUp;
    final showPercent = config.configExtra['kpiShowPercent'] as bool? ?? true;
    final metaColor = _visualColor(
      config.configExtra['kpiMetaColor'],
      const Color(0xFF10B981),
    );
    final valueColor = _visualColor(
      config.configExtra['corMetricaPrincipal'] ??
          config.configExtra['corPrincipal'],
      config.corTextoTitulo,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxNumberSize = constraints.maxHeight < 160 ? 34.0 : 52.0;
        final configuredSize = (config.configExtra['kpiFontSize'] ?? 44.0)
            .toDouble();

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$prefix${_formatarValorVisual(config, value, decimalsOverride: decimals, includeAffixes: false)}$suffix',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: configuredSize.clamp(18.0, maxNumberSize),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (config.mostrarRotulos) ...[
                  const SizedBox(height: 8),
                  Text(
                    config.metrica,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: config.corTextoTitulo.withValues(alpha: 0.72),
                      fontSize: 16,
                    ),
                  ),
                ],
                if (showMeta) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Meta: $prefix${_formatarValorVisual(config, meta, decimalsOverride: decimals, includeAffixes: false)}$suffix${showPercent && meta != 0 ? '  (${((value / meta) * 100).toStringAsFixed(1)}%)' : ''}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: metaColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (showTrend) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        rawTrendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: trendPositive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        previous <= 0 || !showPercent
                            ? 'Sem comparativo'
                            : '${(((value - previous) / previous) * 100).toStringAsFixed(1)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: trendPositive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KeyInfluencersVisual extends StatelessWidget {
  final ChartConfig config;

  const _KeyInfluencersVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(config.dados)
      ..sort(
        (a, b) => ((b['value'] ?? 0) as num).toDouble().abs().compareTo(
          ((a['value'] ?? 0) as num).toDouble().abs(),
        ),
      );
    final top = sorted.take(5).toList();
    final maxValue = top.isEmpty
        ? 1.0
        : top
              .map((item) => ((item['value'] ?? 0) as num).toDouble().abs())
              .reduce(math.max)
              .clamp(1, double.infinity)
              .toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'O que mais influencia ${config.metrica}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = top[index];
              final value = ((item['value'] ?? 0) as num).toDouble();
              final color = _visualColor(
                item['color'],
                const Color(0xFF2563EB),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        value >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 17,
                        color: value >= 0
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item['label']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _formatarValorVisual(config, value),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: (value.abs() / maxValue).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: color,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SmartNarrativeVisual extends StatelessWidget {
  final ChartConfig config;

  const _SmartNarrativeVisual({required this.config});

  @override
  Widget build(BuildContext context) {
    final values = config.dados
        .map((item) => ((item['value'] ?? 0) as num).toDouble())
        .toList();
    if (values.isEmpty) return const _SemDadosVisual();
    final total = values.reduce((a, b) => a + b);
    final average = total / values.length;
    var topIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[topIndex]) topIndex = i;
    }
    final first = values.first;
    final last = values.last;
    final change = first == 0 ? 0.0 : ((last - first) / first) * 100;
    return SingleChildScrollView(
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: config.corTextoTitulo,
            fontSize: 13,
            height: 1.45,
          ),
          children: [
            const TextSpan(
              text: 'Resumo automatico\n',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            TextSpan(text: 'O total de ${config.metrica} e '),
            TextSpan(
              text: _formatarValorVisual(config, total),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text:
                  ', com media de ${_formatarValorVisual(config, average)} por ${config.dimensao}. ',
            ),
            TextSpan(
              text: config.dados[topIndex]['label']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text:
                  ' apresenta o maior valor (${_formatarValorVisual(config, values[topIndex])}). ',
            ),
            TextSpan(
              text:
                  'No periodo visivel, a variacao foi de ${change.toStringAsFixed(1)}%.',
              style: TextStyle(
                color: change >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatarValorVisual(
  ChartConfig config,
  double value, {
  int? decimalsOverride,
  bool includeAffixes = true,
}) {
  final units = config.configExtra['displayUnits']?.toString() ?? 'auto';
  final decimals =
      decimalsOverride ??
      ((config.configExtra['decimalPlaces'] ?? 1) as num).round().clamp(0, 6);
  var divisor = 1.0;
  var unitSuffix = '';
  if (units == 'billion' || (units == 'auto' && value.abs() >= 1000000000)) {
    divisor = 1000000000;
    unitSuffix = ' Bi';
  } else if (units == 'million' ||
      (units == 'auto' && value.abs() >= 1000000)) {
    divisor = 1000000;
    unitSuffix = ' Mi';
  } else if (units == 'thousand' || (units == 'auto' && value.abs() >= 1000)) {
    divisor = 1000;
    unitSuffix = ' Mil';
  }
  final normalized = value / divisor;
  final text = normalized == normalized.roundToDouble() && decimals == 0
      ? normalized.round().toString()
      : normalized.toStringAsFixed(decimals);
  if (!includeAffixes) return '$text$unitSuffix';
  final prefix = config.configExtra['numberPrefix']?.toString() ?? '';
  final suffix = config.configExtra['numberSuffix']?.toString() ?? '';
  return '$prefix$text$unitSuffix$suffix';
}

String _formatarValor(double valor) {
  if (valor.abs() >= 1000000)
    return '${(valor / 1000000).toStringAsFixed(1)} Mi';
  if (valor.abs() >= 1000) return '${(valor / 1000).toStringAsFixed(1)} Mil';
  return valor == valor.toInt()
      ? valor.toInt().toString()
      : valor.toStringAsFixed(2);
}

Color _visualColor(dynamic value, Color fallback) {
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    if (value.startsWith('#')) {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    }
    final parsed = int.tryParse(value);
    if (parsed != null) return Color(parsed);
  }
  return fallback;
}
