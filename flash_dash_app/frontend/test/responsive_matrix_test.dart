import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/dashboard/dashboard_manager.dart';
import 'package:frontend/features/dashboard/screens/dashboard_canvas_screen.dart';
import 'package:frontend/features/dashboard/screens/dashboard_data_screen.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/processamento/screens/etl_history_screen.dart';
import 'package:frontend/features/processamento/screens/star_schema_screen.dart';
import 'package:frontend/features/resultado/screens/metricas_screen.dart';
import 'package:frontend/features/resultado/screens/selecao_grafico_screen.dart';
import 'package:frontend/features/upload/screens/upload_screen.dart';

class _ScreenCase {
  final String name;
  final Widget Function() build;

  const _ScreenCase(this.name, this.build);
}

void main() {
  final processedData = <String, dynamic>{
    'summary': {
      'dimensoes': ['Data', 'Produto', 'Regiao', 'Cliente'],
      'metricas': ['Faturamento', 'Quantidade', 'Margem'],
      'colunas_data': ['Data'],
    },
    'dados_brutos': [
      {
        'Data': '2026-01-01',
        'Produto': 'Produto com nome extenso',
        'Regiao': 'Nordeste',
        'Cliente': 'Cliente Alpha',
        'Faturamento': 2500000,
        'Quantidade': 120,
        'Margem': 0.24,
      },
      {
        'Data': '2026-02-01',
        'Produto': 'Produto B',
        'Regiao': 'Sudeste',
        'Cliente': 'Cliente Beta',
        'Faturamento': 1800000,
        'Quantidade': 95,
        'Margem': 0.21,
      },
    ],
  };

  late List<_ScreenCase> screens;

  setUp(() {
    DashboardManager.usuarioAtualId = null;
    DashboardManager.tokenAutenticacao = null;
    DashboardManager.graficosAtivos.clear();
    DashboardManager.metricasCalculadas.clear();
    DashboardManager.limparFontesDashboard();
    screens = [
      _ScreenCase('home', () => const HomeScreen()),
      _ScreenCase('fontes', () => const UploadScreen()),
      _ScreenCase(
        'biblioteca de graficos',
        () => SelecaoGraficoScreen(data: processedData),
      ),
      _ScreenCase(
        'metricas',
        () => MetricasScreen(
          data: processedData,
          tipoGrafico: 'Colunas Empilhadas',
        ),
      ),
      _ScreenCase(
        'logs ETL',
        () => EtlHistoryScreen(
          logsEtl: const [
            {
              'fase': 'Extracao',
              'icone': 'upload',
              'descricao': 'Fonte carregada com sucesso.',
            },
            {
              'fase': 'Transformacao',
              'icone': 'cleaning',
              'descricao':
                  'Tipos normalizados, duplicatas removidas e campos sensiveis pseudonimizados.',
            },
            {
              'fase': 'Carga',
              'icone': 'check_circle',
              'descricao': 'Tabela final pronta para analise.',
            },
          ],
          summary: Map<String, dynamic>.from(processedData['summary'] as Map),
        ),
      ),
      _ScreenCase(
        'modelo estrela',
        () => StarSchemaScreen(
          summary: Map<String, dynamic>.from(processedData['summary'] as Map),
        ),
      ),
      _ScreenCase('dados do dashboard', () {
        final data = <String, dynamic>{
          ...processedData,
          'fonte': {
            'id': 'fonte-responsiva',
            'nome_arquivo': 'vendas_tratadas.xlsx',
          },
        };
        DashboardManager.registrarFonteDashboard(data);
        return const DashboardDataScreen();
      }),
      _ScreenCase('canvas do dashboard', () {
        DashboardManager.graficosAtivos = [
          ChartConfig(
            id: 'grafico-teste',
            tipo: 'Grafico de Colunas',
            titulo: 'Faturamento por produto',
            dimensao: 'Produto',
            metrica: 'Faturamento',
            dados: const [
              {'label': 'Produto A', 'value': 2500000.0, 'value2': 120.0},
              {'label': 'Produto B', 'value': 1800000.0, 'value2': 95.0},
            ],
            posicao: const Offset(40, 40),
            tamanho: const Size(560, 320),
          ),
        ];
        return const DashboardCanvasScreen();
      }),
    ];
  });

  final viewports = <String, Size>{
    'mobile compacto': const Size(320, 568),
    'mobile pequeno': const Size(360, 640),
    'mobile': const Size(390, 844),
    'mobile grande': const Size(412, 915),
    'tablet retrato': const Size(768, 1024),
    'tablet paisagem': const Size(1024, 768),
    'desktop': const Size(1366, 768),
    'desktop amplo': const Size(1920, 1080),
  };

  for (final viewport in viewports.entries) {
    testWidgets('telas criticas sem overflow em ${viewport.key}', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final screen in screens) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: screen.build(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final exceptions = <Object>[];
        Object? exception;
        while ((exception = tester.takeException()) != null) {
          exceptions.add(exception!);
        }
        expect(
          exceptions,
          isEmpty,
          reason: '${screen.name} falhou em ${viewport.key}: $exceptions',
        );
      }
    });
  }

  testWidgets('metricas suporta texto ampliado em celular', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: MetricasScreen(data: processedData, tipoGrafico: 'Cartao KPI'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
  });
}
