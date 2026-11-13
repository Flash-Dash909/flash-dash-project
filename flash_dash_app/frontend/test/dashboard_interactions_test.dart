import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/dashboard/dashboard_manager.dart';
import 'package:frontend/features/dashboard/screens/dashboard_canvas_screen.dart';

ChartConfig _visual({
  String id = 'visual-1',
  String tipo = 'Grafico de Colunas',
  Size tamanho = const Size(420, 280),
  Map<String, dynamic>? extra,
}) {
  return ChartConfig(
    id: id,
    tipo: tipo,
    titulo: tipo == 'Segmentacao'
        ? 'Filtro de categoria'
        : 'Vendas por categoria',
    dimensao: 'categoria',
    metrica: 'vendas',
    dados: const [
      {'label': 'A', 'value': 120.0, 'value2': 30.0},
      {'label': 'B', 'value': 90.0, 'value2': 22.0},
    ],
    posicao: const Offset(24, 24),
    tamanho: tamanho,
    configExtra: {
      'metricaSecundaria': 'quantidade',
      'secondaryScaleMode': 'automatico',
      'minWidth': 80.0,
      'minHeight': 80.0,
      ...?extra,
    },
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  Size viewport = const Size(1366, 768),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const DashboardCanvasScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    DashboardManager.graficosAtivos.clear();
    DashboardManager.limparFontesDashboard();
    DashboardManager.resetarPaginas();
  });

  tearDown(() {
    DashboardManager.graficosAtivos.clear();
    DashboardManager.limparFontesDashboard();
    DashboardManager.resetarPaginas();
  });

  testWidgets('edita visual pequeno com escala automatica sem excecao', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.graficosAtivos = [_visual(tamanho: const Size(120, 110))];

    await _pumpDashboard(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Opcoes do visual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formatar visual'));
    await tester.pumpAndSettle();

    expect(find.text('Escala da segunda metrica'), findsOneWidget);
    expect(find.text('Automatica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu do visual permite excluir apenas o grafico escolhido', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.graficosAtivos = [
      _visual(id: 'manter'),
      _visual(id: 'excluir')..posicao = const Offset(500, 24),
    ];

    await _pumpDashboard(tester);
    await tester.tap(find.byTooltip('Opcoes do visual').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir visual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(DashboardManager.graficosAtivos.map((item) => item.id), ['manter']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setas esquerda e direita navegam entre paginas', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.restaurarPaginas(const ['Resumo', 'Estoque', 'Clientes']);

    await _pumpDashboard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(DashboardManager.paginaAtual, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(DashboardManager.paginaAtual, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botao global limpa filtros de segmentacao', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.graficosAtivos = [_visual(tipo: 'Segmentacao')];

    await _pumpDashboard(tester);
    final clearFinder = find.widgetWithIcon(
      IconButton,
      Icons.filter_alt_off_rounded,
    );
    var clearButton = tester.widget<IconButton>(clearFinder.first);
    expect(clearButton.onPressed, isNull);

    await tester.tap(find.text('A'));
    await tester.pump();
    clearButton = tester.widget<IconButton>(clearFinder.first);
    expect(clearButton.onPressed, isNotNull);

    await tester.tap(clearFinder.first);
    await tester.pump();
    clearButton = tester.widget<IconButton>(clearFinder.first);
    expect(clearButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('apresentacao usa encaixe responsivo e bloqueia edicao', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.graficosAtivos = [_visual()];

    for (final viewport in const [
      Size(1024, 768),
      Size(1366, 768),
      Size(1920, 1080),
      Size(2560, 1080),
    ]) {
      await _pumpDashboard(tester, viewport: viewport);
      await tester.tap(find.byIcon(Icons.slideshow_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sair'), findsOneWidget);
      expect(find.byType(FittedBox), findsWidgets);
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byTooltip('Opcoes do visual'), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Falha na apresentacao em ${viewport.width}x${viewport.height}',
      );

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    }
  });
}
