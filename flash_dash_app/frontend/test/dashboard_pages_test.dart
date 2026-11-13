import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/dashboard/dashboard_manager.dart';

void main() {
  tearDown(() {
    DashboardManager.graficosAtivos.clear();
    DashboardManager.limparFontesDashboard();
    DashboardManager.resetarPaginas();
  });

  test('restaura nomes e limita a pagina atual', () {
    DashboardManager.restaurarPaginas(const [
      'Resumo',
      'Estoque',
      'Fornecedores',
    ], pagina: 8);

    expect(DashboardManager.paginasDashboard, const [
      'Resumo',
      'Estoque',
      'Fornecedores',
    ]);
    expect(DashboardManager.paginaAtual, 2);
    expect(DashboardManager.nomePaginaAtual, 'Fornecedores');
  });

  test('grafico preserva a pagina atribuida', () {
    final grafico = ChartConfig(
      id: 'grafico-1',
      tipo: 'Grafico de Barras',
      titulo: 'Estoque',
      dimensao: 'produto',
      metrica: 'estoque_atual',
      dados: const [],
      posicao: Offset.zero,
      pagina: 2,
    );

    expect(grafico.pagina, 2);
  });

  test('registra e alterna entre fontes do mesmo dashboard', () {
    final vendas = <String, dynamic>{
      'fonte': {'id': 'vendas', 'nome_arquivo': 'vendas.xlsx'},
    };
    final estoque = <String, dynamic>{
      'fonte': {'id': 'estoque', 'nome_arquivo': 'estoque.csv'},
    };

    DashboardManager.registrarFonteDashboard(vendas);
    DashboardManager.registrarFonteDashboard(estoque, tornarAtiva: false);

    expect(
      DashboardManager.fonteIdsDashboard,
      containsAll(['vendas', 'estoque']),
    );
    expect(
      DashboardManager.fonteIdDe(DashboardManager.dadosFonteAtual),
      'vendas',
    );

    DashboardManager.ativarFonteDashboard('estoque');

    expect(
      DashboardManager.fonteIdDe(DashboardManager.dadosFonteAtual),
      'estoque',
    );
    expect(
      DashboardManager.nomeFonteDe(DashboardManager.dadosFonteAtual!),
      'estoque.csv',
    );
  });
}
