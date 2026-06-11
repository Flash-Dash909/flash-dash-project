import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dashboard_manager.dart';

class ChartRenderer extends StatelessWidget {
  final ChartConfig config;
  final Set<String>? filtrosSelecionados;
  final ValueChanged<Set<String>>? onSegmentacaoChanged;

  const ChartRenderer({
    super.key,
    required this.config,
    this.filtrosSelecionados,
    this.onSegmentacaoChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (config.dados.isEmpty) return const Center(child: Text("Sem dados"));
    final tipo = config.tipo.toLowerCase();

    if (tipo.contains('matriz')) return _MatrizVisual(config: config);
    if (tipo.contains('tabela')) return _TabelaVisual(config: config);
    if (tipo.contains('segment')) {
      return _SegmentacaoVisual(
        config: config,
        selecionadosExternos: filtrosSelecionados,
        onChanged: onSegmentacaoChanged,
      );
    }
    if (tipo.contains('cartao') || tipo.contains('kpi')) {
      return _CartaoKpiVisual(config: config);
    }
    if (tipo.contains('progress')) return _ProgressBarVisual(config: config);

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _ChartPainter(config),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final ChartConfig config;

  _ChartPainter(this.config);

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

  String _formatarNumero(double valor) {
    if (valor.abs() >= 1000000)
      return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor.abs() >= 1000) return '${(valor / 1000).toStringAsFixed(1)}k';
    return valor == valor.toInt()
        ? valor.toInt().toString()
        : valor.toStringAsFixed(1);
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
        tipo.contains('combo');
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
    if (tipo.contains('mapa')) {
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
      return;
    }

    _desenharBarras(
      canvas,
      chartRect,
      dados,
      horizontal: tipo.contains('barras'),
    );
  }

  double _maxValor(List<Map<String, dynamic>> dados) {
    final valores = dados
        .map((d) => ((d['value'] ?? 0) as num).toDouble())
        .toList();
    if (valores.isEmpty) return 1;
    final maximo = valores.reduce(math.max);
    return maximo <= 0 ? 1 : maximo;
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
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = rect.bottom - (rect.height / 4) * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      textPainter.text = TextSpan(
        text: _formatarNumero((maxValor / 4) * i),
        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
      );
      textPainter.layout(maxWidth: 38);
      textPainter.paint(canvas, Offset(0, y - 7));
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

    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    final quantidade = dados.length;
    if (quantidade == 0) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    if (horizontal) {
      final gap = rect.height * _numExtra('barGap', 0.04);
      final barHeight = (rect.height - gap * (quantidade - 1)) / quantidade;
      for (int i = 0; i < quantidade; i++) {
        final item = dados[i];
        final valor = ((item['value'] ?? 0) as num).toDouble();
        final largura = (valor / maxValor) * rect.width;
        final top = rect.top + i * (barHeight + gap);
        final barRect = Rect.fromLTWH(rect.left, top, largura, barHeight);
        final barColorMode = config.configExtra['barColorMode'] ?? 'categoria';
        final corBarra = barColorMode == 'unica'
            ? _converterCor(
                config.configExtra['barColor'],
                const Color(0xFF2563EB),
              )
            : _converterCor(item['color']);
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
          Paint()
            ..color = corBarra.withValues(alpha: _numExtra('barOpacity', 1.0)),
        );
        if (_numExtra('barBorderWidth', 0) > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
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

    final gap = rect.width * _numExtra('barGap', 0.04);
    final barWidth = (rect.width - gap * (quantidade - 1)) / quantidade;
    for (int i = 0; i < quantidade; i++) {
      final item = dados[i];
      final valor = ((item['value'] ?? 0) as num).toDouble();
      final altura = (valor / maxValor) * rect.height;
      final left = rect.left + i * (barWidth + gap);
      final barRect = Rect.fromLTWH(
        left,
        rect.bottom - altura,
        barWidth,
        altura,
      );
      final barColorMode = config.configExtra['barColorMode'] ?? 'categoria';
      final corBarra = barColorMode == 'unica'
          ? _converterCor(
              config.configExtra['barColor'],
              const Color(0xFF2563EB),
            )
          : _converterCor(item['color']);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
        Paint()
          ..color = corBarra.withValues(alpha: _numExtra('barOpacity', 1.0)),
      );
      if (_numExtra('barBorderWidth', 0) > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
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
          maxWidth: barWidth + gap,
        );
      }

      if (config.mostrarRotulos) {
        final label = item['label'].toString();
        textPainter.text = TextSpan(
          text: label.length > 8 ? '${label.substring(0, 8)}.' : label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
        );
        textPainter.layout(maxWidth: barWidth + gap);
        textPainter.paint(canvas, Offset(left, rect.bottom + 8));
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
    final primaryColor = _converterCor(
      config.configExtra['barColor'],
      const Color(0xFF2563EB),
    );
    final secondaryColor = _converterCor(
      config.configExtra['stackColor'],
      const Color(0xFFF59E0B),
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (horizontal) {
      final gap = rect.height * _numExtra('barGap', 0.04);
      final barHeight = (rect.height - gap * (quantidade - 1)) / quantidade;
      for (int i = 0; i < quantidade; i++) {
        final item = dados[i];
        final v1 = ((item['value'] ?? 0) as num).toDouble().abs();
        final v2 = ((item['value2'] ?? 0) as num).toDouble().abs();
        final total = math.max(1.0, v1 + v2);
        final base = percentual ? total : maxValor;
        final w1 = rect.width * (v1 / base);
        final w2 = rect.width * (v2 / base);
        final top = rect.top + i * (barHeight + gap);
        final r1 = Rect.fromLTWH(rect.left, top, w1, barHeight);
        final r2 = Rect.fromLTWH(rect.left + w1, top, w2, barHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r1, const Radius.circular(5)),
          Paint()
            ..color = primaryColor.withValues(
              alpha: _numExtra('barOpacity', 1.0),
            ),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r2, const Radius.circular(5)),
          Paint()
            ..color = secondaryColor.withValues(
              alpha: _numExtra('barOpacity', 1.0),
            ),
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

    final gap = rect.width * _numExtra('barGap', 0.04);
    final barWidth = (rect.width - gap * (quantidade - 1)) / quantidade;
    for (int i = 0; i < quantidade; i++) {
      final item = dados[i];
      final v1 = ((item['value'] ?? 0) as num).toDouble().abs();
      final v2 = ((item['value2'] ?? 0) as num).toDouble().abs();
      final total = math.max(1.0, v1 + v2);
      final base = percentual ? total : maxValor;
      final h1 = rect.height * (v1 / base);
      final h2 = rect.height * (v2 / base);
      final left = rect.left + i * (barWidth + gap);
      final r1 = Rect.fromLTWH(left, rect.bottom - h1, barWidth, h1);
      final r2 = Rect.fromLTWH(left, rect.bottom - h1 - h2, barWidth, h2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r1, const Radius.circular(5)),
        Paint()
          ..color = primaryColor.withValues(
            alpha: _numExtra('barOpacity', 1.0),
          ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r2, const Radius.circular(5)),
        Paint()
          ..color = secondaryColor.withValues(
            alpha: _numExtra('barOpacity', 1.0),
          ),
      );
      if (config.mostrarRotulos) {
        final label = item['label'].toString();
        textPainter.text = TextSpan(
          text: label.length > 8 ? '${label.substring(0, 8)}.' : label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
        );
        textPainter.layout(maxWidth: barWidth + gap);
        textPainter.paint(canvas, Offset(left, rect.bottom + 8));
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

    final pontos = <Offset>[];
    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final x = rect.left + (rect.width / (dados.length - 1)) * i;
      final y = rect.bottom - (valor / maxValor) * rect.height;
      pontos.add(Offset(x, y));
    }

    final path = Path()..moveTo(pontos.first.dx, pontos.first.dy);
    for (final ponto in pontos.skip(1)) {
      path.lineTo(ponto.dx, ponto.dy);
    }

    if (area) {
      final areaPath = Path.from(path)
        ..lineTo(pontos.last.dx, rect.bottom)
        ..lineTo(pontos.first.dx, rect.bottom)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.18),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = _converterCor(
          config.configExtra['lineColor'],
          const Color(0xFF2563EB),
        )
        ..strokeWidth = (config.configExtra['espessuraLinha'] ?? 3.0).toDouble()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (config.configExtra['mostrarPontos'] ?? true) {
      for (int i = 0; i < pontos.length; i++) {
        final ponto = pontos[i];
        canvas.drawCircle(
          ponto,
          _numExtra('markerSize', 4),
          Paint()
            ..color = _converterCor(
              config.configExtra['markerColor'],
              const Color(0xFF2563EB),
            ),
        );
        if (config.mostrarValores) {
          final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
          _desenharTextoCentralizado(
            canvas,
            _formatarNumero(valor),
            ponto.translate(0, -14),
            const TextStyle(fontSize: 10, color: Color(0xFF334155)),
            maxWidth: 54,
          );
        }
      }
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
      Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.35),
    );
    canvas.drawPath(
      area2,
      Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.42),
    );
    canvas.drawPath(
      Path()..addPolygon(pontosTopo, false),
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _desenharDispersao(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    if (dados.isEmpty) return;

    final random = math.Random(7);
    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final x = rect.left + (rect.width / math.max(1, dados.length - 1)) * i;
      final y = rect.bottom - (valor / maxValor) * rect.height;
      final jitter = (random.nextDouble() - 0.5) * 16;
      canvas.drawCircle(
        Offset(x + jitter, y),
        5,
        Paint()
          ..color = _converterCor(
            dados[i]['color'],
            const Color(0xFFEF4444),
          ).withValues(alpha: 0.85),
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

    final dataPath = Path();
    for (int i = 0; i < quantidade; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final angle = -math.pi / 2 + (2 * math.pi / quantidade) * i;
      final p =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              radius *
              (valor / maxValor);
      if (i == 0)
        dataPath.moveTo(p.dx, p.dy);
      else
        dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();
    canvas.drawPath(
      dataPath,
      Paint()..color = const Color(0xFF14B8A6).withValues(alpha: 0.22),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = const Color(0xFF14B8A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _desenharPizza(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
    bool rosca,
  ) {
    final total = dados.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );
    if (total <= 0) return;

    final lado = math.min(rect.width, rect.height);
    final pieRect = Rect.fromCenter(
      center: rect.center,
      width: lado * 0.86,
      height: lado * 0.86,
    );
    double inicio = -math.pi / 2;

    for (final item in dados) {
      final valor = ((item['value'] ?? 0) as num).toDouble();
      final sweep = (valor / total) * math.pi * 2;
      final midAngle = inicio + sweep / 2;
      canvas.drawArc(
        pieRect,
        inicio,
        sweep,
        true,
        Paint()
          ..color = _converterCor(
            item['color'],
          ).withValues(alpha: _numExtra('sliceOpacity', 1.0)),
      );
      if (config.mostrarValores && sweep > 0.22) {
        final mostrarPorcentagem =
            config.configExtra['mostrarPorcentagem'] as bool? ?? false;
        final texto = mostrarPorcentagem
            ? '${((valor / total) * 100).toStringAsFixed(0)}%'
            : _formatarNumero(valor);
        final pos =
            rect.center +
            Offset(math.cos(midAngle), math.sin(midAngle)) * (lado * 0.30);
        _desenharTextoCentralizado(
          canvas,
          texto,
          pos,
          const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          maxWidth: 58,
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
      ..strokeWidth = math.max(12, radius * 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final valuePaint = Paint()
      ..color = _converterCor(
        config.configExtra['corPrincipal'],
        const Color(0xFF2563EB),
      )
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

    if (config.mostrarRotulos) {
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

      final color = _converterCor(
        item['color'],
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
          text: _formatarNumero(((item['value'] ?? 0) as num).toDouble()),
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
          ..color = _converterCor(dados[i]['color']).withValues(alpha: 0.9),
      );

      if (config.mostrarValores) {
        textPainter.text = TextSpan(
          text: '${dados[i]['label']}  ${_formatarNumero(valor)}',
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
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.2;

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
          ? const Color(0xFF2563EB)
          : isPositive
          ? const Color(0xFF10B981)
          : const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        Paint()..color = color,
      );
      if (i < dados.length - 1) {
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
    final bins = math.min(
      10,
      math.max(4, (math.sqrt(valores.length) * 2).round()),
    );
    final minValor = valores.first;
    final maxValor = valores.last;
    final step = math.max(1, (maxValor - minValor) / bins);
    final counts = List<int>.filled(bins, 0);
    for (final valor in valores) {
      final index = ((valor - minValor) / step).floor().clamp(0, bins - 1);
      counts[index]++;
    }
    final maxCount = counts
        .reduce(math.max)
        .toDouble()
        .clamp(1, double.infinity);
    final barWidth = rect.width / bins;
    for (int i = 0; i < bins; i++) {
      final h = rect.height * (counts[i] / maxCount);
      final bar = Rect.fromLTWH(
        rect.left + i * barWidth + 2,
        rect.bottom - h,
        barWidth - 4,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = const Color(0xFF7C3AED).withValues(alpha: 0.86),
      );
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
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF2563EB)
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
      final intensity = (valor / maxValor).clamp(0.0, 1.0);
      final row = i ~/ cols;
      final col = i % cols;
      final cell = Rect.fromLTWH(
        rect.left + col * cellW,
        rect.top + row * cellH,
        cellW,
        cellH,
      ).deflate(2);
      final color = Color.lerp(
        const Color(0xFFDBEAFE),
        const Color(0xFFEF4444),
        intensity,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell, const Radius.circular(6)),
        Paint()..color = color,
      );
      if (config.mostrarValores && cellW > 46 && cellH > 28) {
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
      Paint()..color = const Color(0xFF2563EB),
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
    _desenharBarras(canvas, rect, dados, horizontal: false);
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
        'lineColor': const Color(0xFFEF4444).value.toString(),
        'mostrarPontos': true,
      },
    );
    _ChartPainter(
      linhaConfig,
    )._desenharLinhaOuArea(canvas, rect, linhaConfig.dados, false);
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
    final nodePaint = Paint()..color = const Color(0xFF2563EB);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < dados.length; i++) {
      final y = rect.top + (rect.height / math.max(1, dados.length - 1)) * i;
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final stroke = 4 + 18 * (valor / maxValor);
      final path = Path()
        ..moveTo(leftX, y)
        ..cubicTo(
          rect.center.dx - 80,
          y,
          rect.center.dx + 80,
          rect.center.dy,
          rightX,
          rect.center.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = _converterCor(dados[i]['color']).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
      canvas.drawCircle(Offset(leftX, y), 6, nodePaint);
      textPainter.text = TextSpan(
        text: dados[i]['label'].toString(),
        style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
      );
      textPainter.layout(maxWidth: rect.width * 0.28);
      textPainter.paint(canvas, Offset(leftX + 10, y - 7));
    }
    canvas.drawCircle(
      Offset(rightX, rect.center.dy),
      10,
      Paint()..color = const Color(0xFF10B981),
    );
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
    final nodes = math.min(dados.length, 10);
    final points = <Offset>[];
    for (int i = 0; i < nodes; i++) {
      final angle = -math.pi / 2 + (2 * math.pi / nodes) * i;
      points.add(center + Offset(math.cos(angle), math.sin(angle)) * radius);
    }
    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4;
    for (final point in points) {
      canvas.drawLine(center, point, linePaint);
    }
    canvas.drawCircle(center, 14, Paint()..color = const Color(0xFF2563EB));
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        9,
        Paint()..color = _converterCor(dados[i]['color']),
      );
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

    final nodes = math.min(dados.length, 6);
    final linePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5;
    for (int i = 0; i < nodes; i++) {
      final y = rect.top + (rect.height / (nodes + 1)) * (i + 1);
      final node = Rect.fromCenter(
        center: Offset(rect.left + rect.width * 0.68, y),
        width: math.min(150.0, rect.width * 0.32),
        height: 44,
      );
      canvas.drawLine(
        root.centerRight,
        Offset(node.left, node.center.dy),
        linePaint,
      );
      final color = _converterCor(dados[i]['color']);
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
        dados[i]['label'].toString(),
        node.center,
        const TextStyle(
          color: Color(0xFF334155),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        maxWidth: node.width - 12,
      );
    }
  }

  void _desenharSunburst(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    _desenharPizza(canvas, rect, dados, true);
    final outer = math.min(rect.width, rect.height) * 0.36;
    canvas.drawCircle(
      rect.center,
      outer * 0.45,
      Paint()..color = config.corFundo,
    );
    canvas.drawCircle(
      rect.center,
      outer * 0.20,
      Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.18),
    );
  }

  void _desenharMapa(
    Canvas canvas,
    Rect rect,
    List<Map<String, dynamic>> dados,
  ) {
    final isCoropletico = config.tipo.toLowerCase().contains('corop');
    final bg = Paint()..color = const Color(0xFFE0F2FE);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      bg,
    );
    final maxValor = _maxValor(dados);
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
      final color = isCoropletico
          ? Color.lerp(
              const Color(0xFFBAE6FD),
              const Color(0xFF0369A1),
              intensity,
            )!
          : const Color(0xFFBAE6FD);
      canvas.drawOval(regioes[i], Paint()..color = color);
    }

    if (isCoropletico) return;

    for (int i = 0; i < dados.length; i++) {
      final valor = ((dados[i]['value'] ?? 0) as num).toDouble();
      final x = rect.left + rect.width * (0.18 + ((i * 37) % 65) / 100);
      final y = rect.top + rect.height * (0.22 + ((i * 29) % 55) / 100);
      final r = 5 + 16 * (valor / maxValor);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = const Color(0xFFDC2626),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.config != config;
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
    final rows = config.dados;
    final total = rows.fold<double>(
      0,
      (sum, item) => sum + ((item['value'] ?? 0) as num).toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  "Categoria",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "Valor",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
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
                  color: even ? rowColorA : rowColorB,
                  border: Border(bottom: BorderSide(color: gridColor)),
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
                      child: Text(
                        _formatarValor(
                          ((item['value'] ?? 0) as num).toDouble(),
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                        ).copyWith(color: rowTextColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
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
                _formatarValor(total),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Linha',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Valor',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: gridColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_right_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          Expanded(
                            child: Text(
                              item['label'].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatarValor(value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${(percent * 100).toStringAsFixed(1)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
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
                _formatarValor(total),
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

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final selectedColor = _visualColor(
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
    final itens = values.map((value) {
      final selected = selecionados.isEmpty || selecionados.contains(value);
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
          if (widget.onChanged != null) {
            widget.onChanged!(proximos);
          } else {
            setState(() {
              _selecionados
                ..clear()
                ..addAll(proximos);
            });
          }
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
        value: selecionados.isNotEmpty ? selecionados.first : null,
        decoration: InputDecoration(labelText: placeholder),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: (v) {
          final next = v == null ? <String>{} : {v};
          widget.onChanged?.call(next);
          setState(() {
            _selecionados
              ..clear()
              ..addAll(next);
          });
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrarBusca) ...[
          TextField(
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
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
    final prefix = config.configExtra['prefixo'] ?? '';
    final suffix = config.configExtra['sufixo'] ?? '';
    final decimals = ((config.configExtra['decimais'] ?? 0) as num).round();
    final showMeta = config.configExtra['kpiShowMeta'] as bool? ?? false;
    final meta = ((config.configExtra['kpiMeta'] ?? 0) as num).toDouble();
    final previous = ((config.configExtra['kpiPrevious'] ?? 0) as num)
        .toDouble();
    final showTrend = config.configExtra['kpiShowTrend'] as bool? ?? false;
    final trendUp = previous <= 0 || value >= previous;
    final metaColor = _visualColor(
      config.configExtra['kpiMetaColor'],
      const Color(0xFF10B981),
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
                      '$prefix${value.toStringAsFixed(decimals)}$suffix',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: config.corTextoTitulo,
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
                    'Meta: $prefix${meta.toStringAsFixed(decimals)}$suffix',
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
                        trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: trendUp
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        previous <= 0
                            ? 'Sem comparativo'
                            : '${(((value - previous) / previous) * 100).toStringAsFixed(1)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: trendUp
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
