import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dashboard_manager.dart';

class ChartRenderer extends StatelessWidget {
  final ChartConfig config;

  const ChartRenderer({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    if (config.dados.isEmpty) return const Center(child: Text("Sem dados"));

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

  String _formatarNumero(double valor) {
    if (valor.abs() >= 1000000)
      return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor.abs() >= 1000) return '${(valor / 1000).toStringAsFixed(1)}k';
    return valor == valor.toInt()
        ? valor.toInt().toString()
        : valor.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dados = config.dados;
    final tipo = config.tipo.toLowerCase();
    final paddingLeft = config.mostrarEixos ? 42.0 : 10.0;
    final paddingBottom = config.mostrarRotulos ? 34.0 : 12.0;
    final chartRect = Rect.fromLTWH(
      paddingLeft,
      8,
      math.max(1, size.width - paddingLeft - 12),
      math.max(1, size.height - paddingBottom - 16),
    );

    if (tipo.contains('pizza') || tipo.contains('rosca')) {
      _desenharPizza(canvas, chartRect, dados, tipo.contains('rosca'));
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
    if (tipo.contains('linha') ||
        tipo.contains('área') ||
        tipo.contains('area')) {
      _desenharLinhaOuArea(
        canvas,
        chartRect,
        dados,
        tipo.contains('área') || tipo.contains('area'),
      );
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
    final maxValor = _maxValor(dados);
    _desenharGrade(canvas, rect, maxValor);
    final quantidade = dados.length;
    if (quantidade == 0) return;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    if (horizontal) {
      final gap = rect.height * 0.04;
      final barHeight = (rect.height - gap * (quantidade - 1)) / quantidade;
      for (int i = 0; i < quantidade; i++) {
        final item = dados[i];
        final valor = ((item['value'] ?? 0) as num).toDouble();
        final largura = (valor / maxValor) * rect.width;
        final top = rect.top + i * (barHeight + gap);
        final barRect = Rect.fromLTWH(rect.left, top, largura, barHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
          Paint()..color = _converterCor(item['color']),
        );
      }
      return;
    }

    final gap = rect.width * 0.04;
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
        Paint()..color = _converterCor(item['color']),
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
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = (config.configExtra['espessuraLinha'] ?? 3.0).toDouble()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (config.configExtra['mostrarPontos'] ?? true) {
      for (final ponto in pontos) {
        canvas.drawCircle(ponto, 4, Paint()..color = const Color(0xFF2563EB));
      }
    }
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
      canvas.drawArc(
        pieRect,
        inicio,
        sweep,
        true,
        Paint()..color = _converterCor(item['color']),
      );
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

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.config != config;
  }
}
