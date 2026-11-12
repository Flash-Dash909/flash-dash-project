import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/calculated_metric.dart';

void main() {
  test('avalia moedas, percentuais e precedencia de operadores', () {
    final row = <String, dynamic>{'Receita': 'R\$ 1.234,50', 'Margem': '25%'};
    final metrics = {
      'Resultado': const CalculatedMetric(
        name: 'Resultado',
        formula: '[Receita] * [Margem] + 10',
      ),
    };

    expect(
      resolveMetricValue(row, 'Resultado', metrics),
      closeTo(318.625, 0.001),
    );
  });

  test('valida campos inexistentes e parenteses incompletos', () {
    expect(
      validateCalculatedMetric(
        name: 'Ticket medio',
        formula: '[Receita] / ([Pedidos]',
        baseMetrics: const ['Receita', 'Pedidos'],
        calculatedMetrics: const {},
      ),
      contains('parenteses'),
    );
    expect(
      validateCalculatedMetric(
        name: 'Ticket medio',
        formula: '[Campo inexistente] / 2',
        baseMetrics: const ['Receita'],
        calculatedMetrics: const {},
      ),
      contains('nao encontrada'),
    );
  });

  test('bloqueia referencia circular entre metricas', () {
    final existing = {
      'Metrica A': const CalculatedMetric(
        name: 'Metrica A',
        formula: '[Metrica B] + 1',
      ),
    };

    expect(
      validateCalculatedMetric(
        name: 'Metrica B',
        formula: '[Metrica A] + 1',
        baseMetrics: const ['Receita'],
        calculatedMetrics: existing,
      ),
      contains('circular'),
    );
  });

  test('divisao por zero retorna zero sem quebrar o visual', () {
    final metrics = {
      'Taxa': const CalculatedMetric(
        name: 'Taxa',
        formula: '[Receita] / [Pedidos]',
      ),
    };

    expect(
      resolveMetricValue({'Receita': 100, 'Pedidos': 0}, 'Taxa', metrics),
      0,
    );
  });
}
