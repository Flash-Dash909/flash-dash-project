import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/dashboard/dashboard_manager.dart';
import 'package:frontend/features/home/screens/home_screen.dart';
import 'package:frontend/features/resultado/screens/metricas_screen.dart';
import 'package:frontend/core/app_theme_controller.dart';
import 'package:frontend/main.dart';

void main() {
  tearDown(() {
    AppThemeController.themeMode.value = ThemeMode.system;
    DashboardManager.usuarioAtualId = null;
    DashboardManager.tokenAutenticacao = null;
  });

  testWidgets('Flash Dash inicia na autenticacao em desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlashDashApp());
    await tester.pumpAndSettle();

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flash Dash inicia sem overflow em celular', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlashDashApp());
    await tester.pumpAndSettle();

    expect(find.text('ENTRAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home mantém configuracoes, perfil e fontes funcionais', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardManager.usuarioAtualId = null;
    DashboardManager.tokenAutenticacao = null;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    await tester.tap(find.text('Configurações'));
    await tester.pump();
    expect(find.text('Tema'), findsOneWidget);

    await tester.tap(find.text('Perfil').first);
    await tester.pump();
    expect(find.text('Editar perfil'), findsOneWidget);

    await tester.tap(find.text('Fontes de Dados').first);
    await tester.pump();
    expect(find.text('Conectar Nova Fonte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login e cadastro mantem contraste no tema escuro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppThemeController.themeMode.value = ThemeMode.dark;

    await tester.pumpWidget(const FlashDashApp());
    await tester.pumpAndSettle();

    final email = tester.widget<TextField>(
      find.widgetWithText(TextField, 'E-mail'),
    );
    final context = tester.element(find.byType(TextField).first);
    final scheme = Theme.of(context).colorScheme;
    expect(email.style?.color, scheme.onSurface);
    expect(email.decoration?.fillColor, scheme.surfaceContainerHighest);

    await tester.tap(find.text('Não tem uma conta? Cadastre-se'));
    await tester.pump();
    expect(find.text('Nome completo'), findsOneWidget);
    expect(find.text('CADASTRAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Perfil e configuracoes abrem no celular em tema escuro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppThemeController.themeMode.value = ThemeMode.dark;
    DashboardManager.usuarioAtualId = null;
    DashboardManager.tokenAutenticacao = null;

    await tester.pumpWidget(const FlashDashApp());
    await tester.pump();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home inicial');

    tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Menu aberto');
    await tester.tap(find.text('Perfil').last);
    await tester.pump();
    expect(find.text('Editar perfil'), findsOneWidget);
    final perfilException = tester.takeException();
    if (perfilException is FlutterError) {
      fail(perfilException.toStringDeep());
    }
    expect(perfilException, isNull);

    tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurações').last);
    await tester.pump();
    expect(find.text('Tema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tela de metricas nao estoura seletores no desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MetricasScreen(
          tipoGrafico: 'Grafico de Linha',
          data: {
            'summary': {
              'dimensoes': ['REQUISITANTE'],
              'metricas': ['km - saida', 'km - retorno'],
            },
            'dados_brutos': [
              {
                'REQUISITANTE': 'Equipe Alpha',
                'km - saida': 1600000,
                'km - retorno': 800000,
              },
              {
                'REQUISITANTE': 'Equipe Beta',
                'km - saida': 1200000,
                'km - retorno': 650000,
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dados do grafico'), findsOneWidget);
    expect(find.text('km - retorno'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tela de metricas permanece responsiva no celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MetricasScreen(
          tipoGrafico: 'Grafico de Linha',
          data: {
            'summary': {
              'dimensoes': ['REQUISITANTE COM NOME MUITO EXTENSO'],
              'metricas': [
                'Quilometragem completa de saida',
                'Quilometragem completa de retorno',
              ],
            },
            'dados_brutos': [
              {
                'REQUISITANTE COM NOME MUITO EXTENSO': 'Equipe Alpha',
                'Quilometragem completa de saida': 1600000,
                'Quilometragem completa de retorno': 800000,
              },
              {
                'REQUISITANTE COM NOME MUITO EXTENSO': 'Equipe Beta',
                'Quilometragem completa de saida': 1200000,
                'Quilometragem completa de retorno': 650000,
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dados do grafico'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
