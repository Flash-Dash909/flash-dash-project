import 'package:flutter/material.dart';

import '../../../core/widgets/app_logo.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../processamento/screens/etl_history_screen.dart';
import 'metricas_screen.dart';

class SelecaoGraficoScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const SelecaoGraficoScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    DashboardManager.dadosFonteAtual = data;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final paddingGlobal = isDesktop ? 40.0 : 16.0;

    final categorias = _categoriasGraficos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Graficos'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogo(size: 32, opacity: 0.82),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(paddingGlobal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Qual visualizacao deseja criar?",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Escolha o visual e personalize antes de inserir no dashboard.",
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                  _botaoLogsETL(context),
                ],
              )
            else ...[
              Text(
                "Qual visualizacao deseja criar?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Escolha o visual e personalize antes de inserir no dashboard.",
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 16),
              _botaoLogsETL(context),
            ],
            const SizedBox(height: 32),
            ...categorias.map(
              (categoria) => _buildCategoria(context, categoria, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botaoLogsETL(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        final logs = data['dados_planilha']?['etl_logs'] ?? [];
        final summary = data['dados_planilha']?['summary'] ?? {};
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EtlHistoryScreen(
              logsEtl: logs,
              summary: Map<String, dynamic>.from(summary),
            ),
          ),
        );
      },
      icon: const Icon(Icons.account_tree, color: Color(0xFF2563EB)),
      label: const Text(
        "Ver Logs ETL",
        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Map<String, dynamic>> _categoriasGraficos() {
    Map<String, dynamic> item(
      String nome,
      IconData icone,
      Color cor, {
      String status = 'Disponivel',
    }) {
      return {'nome': nome, 'icone': icone, 'cor': cor, 'status': status};
    }

    return [
      {
        'categoria': 'Dados',
        'icone': Icons.dataset_outlined,
        'itens': [
          item('Tabela', Icons.table_rows_rounded, Colors.indigo.shade600),
          item('Matriz', Icons.view_module_rounded, Colors.blueGrey.shade700),
          item('Cartao KPI', Icons.scoreboard_rounded, Colors.green.shade700),
          item(
            'Segmentacao',
            Icons.filter_alt_rounded,
            Colors.blueGrey.shade600,
          ),
        ],
      },
      {
        'categoria': 'Comparacao',
        'icone': Icons.compare_arrows_rounded,
        'itens': [
          item(
            'Grafico de Barras',
            Icons.bar_chart_rounded,
            Colors.amber.shade700,
          ),
          item(
            'Grafico de Colunas',
            Icons.leaderboard_rounded,
            Colors.cyan.shade600,
          ),
          item(
            'Barras Empilhadas',
            Icons.stacked_bar_chart_rounded,
            Colors.orange.shade700,
          ),
          item(
            'Colunas Empilhadas',
            Icons.stacked_bar_chart_rounded,
            Colors.lightBlue.shade700,
          ),
          item(
            'Barras 100%',
            Icons.align_horizontal_left_rounded,
            Colors.deepOrange.shade500,
          ),
          item(
            'Colunas 100%',
            Icons.align_vertical_bottom_rounded,
            const Color(0xFF0284C7),
          ),
          item(
            'Ribbon Chart',
            Icons.swap_vert_circle_outlined,
            Colors.indigo.shade500,
          ),
        ],
      },
      {
        'categoria': 'Tendencia',
        'icone': Icons.trending_up_rounded,
        'itens': [
          item(
            'Grafico de Linha',
            Icons.show_chart_rounded,
            Colors.blue.shade600,
          ),
          item(
            'Grafico de Area',
            Icons.area_chart_rounded,
            Colors.purple.shade500,
          ),
          item(
            'Area Empilhada',
            Icons.area_chart_outlined,
            Colors.deepPurple.shade500,
          ),
          item(
            'Area 100%',
            Icons.stacked_line_chart_rounded,
            Colors.purple.shade700,
          ),
          item(
            'Combo Linha + Coluna',
            Icons.add_chart_rounded,
            Colors.teal.shade600,
          ),
        ],
      },
      {
        'categoria': 'Distribuicao',
        'icone': Icons.scatter_plot_rounded,
        'itens': [
          item('Dispersao', Icons.bubble_chart_rounded, Colors.red.shade500),
          item(
            'Histograma',
            Icons.insert_chart_outlined_rounded,
            Colors.deepPurple.shade400,
          ),
          item('Box Plot', Icons.inventory_2_outlined, Colors.brown.shade500),
          item('Heatmap', Icons.grid_4x4_rounded, Colors.redAccent.shade400),
        ],
      },
      {
        'categoria': 'Composicao',
        'icone': Icons.pie_chart_outline_rounded,
        'itens': [
          item(
            'Grafico de Pizza',
            Icons.pie_chart_rounded,
            Colors.pinkAccent.shade400,
          ),
          item(
            'Grafico de Rosca',
            Icons.donut_large_rounded,
            Colors.green.shade600,
          ),
          item('Treemap', Icons.grid_view_rounded, Colors.green.shade800),
          item(
            'Waterfall',
            Icons.waterfall_chart_rounded,
            Colors.blueGrey.shade700,
          ),
          item('Funnel', Icons.filter_list_rounded, Colors.orange.shade600),
        ],
      },
      {
        'categoria': 'Performance',
        'icone': Icons.speed_rounded,
        'itens': [
          item('Gauge', Icons.speed_rounded, Colors.deepOrange.shade600),
          item(
            'Bullet Chart',
            Icons.linear_scale_rounded,
            Colors.blue.shade700,
          ),
          item(
            'Progress Bar',
            Icons.horizontal_rule_rounded,
            Colors.green.shade700,
          ),
        ],
      },
      {
        'categoria': 'Geografico',
        'icone': Icons.public_rounded,
        'itens': [
          item('Azure Maps', Icons.location_on_outlined, Colors.cyan.shade700),
          item('Mapa Basico', Icons.place_outlined, Colors.blue.shade700),
          item('Mapa Preenchido', Icons.map_outlined, Colors.teal.shade700),
          item('Shape Map', Icons.polyline_outlined, Colors.green.shade700),
          item(
            'Mapa de Calor',
            Icons.blur_on_rounded,
            Colors.deepOrange.shade600,
          ),
        ],
      },
      {
        'categoria': 'Hierarquia',
        'icone': Icons.account_tree_outlined,
        'itens': [
          item('Sunburst', Icons.brightness_7_outlined, Colors.amber.shade800),
          item(
            'Decomposition Tree',
            Icons.account_tree_rounded,
            Colors.indigo.shade700,
          ),
          item(
            'Principais Influenciadores',
            Icons.insights_rounded,
            Colors.blue.shade800,
          ),
          item(
            'Narrativa Inteligente',
            Icons.article_outlined,
            Colors.blueGrey.shade700,
          ),
          item(
            'Deteccao de Anomalias',
            Icons.notification_important_outlined,
            Colors.red.shade600,
          ),
        ],
      },
      {
        'categoria': 'Avancados',
        'icone': Icons.auto_graph_rounded,
        'itens': [
          item('Radar', Icons.track_changes_rounded, Colors.teal.shade500),
          item('Sankey', Icons.hub_outlined, Colors.purple.shade700),
          item(
            'Network Graph',
            Icons.device_hub_rounded,
            Colors.blueGrey.shade800,
          ),
          item(
            'Timeline/Gantt',
            Icons.view_timeline_rounded,
            Colors.orange.shade800,
          ),
        ],
      },
    ];
  }

  Widget _buildCategoria(
    BuildContext context,
    Map<String, dynamic> categoria,
    bool isDesktop,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final itens = List<Map<String, dynamic>>.from(categoria['itens'] as List);

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                categoria['icone'] as IconData,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                categoria['categoria'] as String,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isDesktop ? 220 : 185,
              mainAxisExtent: isDesktop ? 150 : 136,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final grafico = itens[index];
              return _buildGraficoCard(context, grafico, isDesktop);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoCard(
    BuildContext context,
    Map<String, dynamic> grafico,
    bool isDesktop,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cor = grafico['cor'] as Color;
    return Card(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cor.withValues(alpha: 0.42), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetricasScreen(
              data: data,
              tipoGrafico: grafico['nome'] as String,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 14 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  grafico['icone'] as IconData,
                  size: isDesktop ? 30 : 26,
                  color: cor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                grafico['nome'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
