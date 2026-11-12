import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/dashboard/dashboard_manager.dart';
import 'package:frontend/features/dashboard/widgets/chart_renderer.dart';

void main() {
  const chartTypes = <String>[
    'Tabela',
    'Matriz',
    'Cartao KPI',
    'Segmentacao',
    'Grafico de Barras',
    'Grafico de Colunas',
    'Barras Empilhadas',
    'Colunas Empilhadas',
    'Barras 100%',
    'Colunas 100%',
    'Ribbon Chart',
    'Grafico de Linha',
    'Grafico de Area',
    'Area Empilhada',
    'Area 100%',
    'Combo Linha + Coluna',
    'Dispersao',
    'Histograma',
    'Box Plot',
    'Heatmap',
    'Grafico de Pizza',
    'Grafico de Rosca',
    'Treemap',
    'Waterfall',
    'Funnel',
    'Gauge',
    'Bullet Chart',
    'Progress Bar',
    'Azure Maps',
    'Mapa Basico',
    'Mapa Preenchido',
    'Shape Map',
    'Mapa de Calor',
    'Sunburst',
    'Decomposition Tree',
    'Principais Influenciadores',
    'Narrativa Inteligente',
    'Deteccao de Anomalias',
    'Radar',
    'Sankey',
    'Network Graph',
    'Timeline/Gantt',
  ];

  final sampleData = List<Map<String, dynamic>>.generate(6, (index) {
    return {
      'label': 'Categoria ${index + 1}',
      'secondaryLabel': 'Grupo ${(index % 2) + 1}',
      'value': (index + 1) * 1250.0,
      'value2': (6 - index) * 35.0,
      'start': index * 2,
      'end': index * 2 + 3,
      'color': Colors.primaries[index].toARGB32().toString(),
    };
  });

  for (final size in const [Size(320, 220), Size(900, 500)]) {
    testWidgets(
      'catalogo renderiza todos os visuais em ${size.width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final type in chartTypes) {
          final config = ChartConfig(
            id: type,
            tipo: type,
            titulo: type,
            dimensao: 'Categoria',
            metrica: 'Receita',
            dados: sampleData,
            posicao: Offset.zero,
            tamanho: size,
            configExtra: const {
              'animationEnabled': false,
              'secondaryScaleMode': 'automatico',
            },
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox.fromSize(
                  size: size,
                  child: ChartRenderer(config: config),
                ),
              ),
            ),
          );
          await tester.pump();

          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason: 'Falha ao renderizar $type em $size',
          );
        }
      },
    );
  }
}
