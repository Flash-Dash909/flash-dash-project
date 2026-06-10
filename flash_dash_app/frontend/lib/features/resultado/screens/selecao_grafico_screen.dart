import 'package:flutter/material.dart';

import '../../dashboard/dashboard_manager.dart';
import '../../processamento/screens/etl_history_screen.dart';
import 'metricas_screen.dart';

class SelecaoGraficoScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const SelecaoGraficoScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    DashboardManager.dadosFonteAtual = data;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final colunasGrid = isDesktop ? 4 : 2;
    final paddingGlobal = isDesktop ? 40.0 : 16.0;

    final tiposGraficos = [
      {
        "nome": "Grafico de Barras",
        "icone": Icons.bar_chart_rounded,
        "cor": Colors.amber.shade700,
      },
      {
        "nome": "Grafico de Colunas",
        "icone": Icons.leaderboard_rounded,
        "cor": Colors.cyan.shade600,
      },
      {
        "nome": "Grafico de Pizza",
        "icone": Icons.pie_chart_rounded,
        "cor": Colors.pinkAccent.shade400,
      },
      {
        "nome": "Grafico de Rosca",
        "icone": Icons.donut_large_rounded,
        "cor": Colors.green.shade600,
      },
      {
        "nome": "Grafico de Linha",
        "icone": Icons.show_chart_rounded,
        "cor": Colors.blue.shade600,
      },
      {
        "nome": "Grafico de Area",
        "icone": Icons.area_chart_rounded,
        "cor": Colors.purple.shade500,
      },
      {
        "nome": "Dispersao",
        "icone": Icons.bubble_chart_rounded,
        "cor": Colors.red.shade500,
      },
      {
        "nome": "Radar",
        "icone": Icons.track_changes_rounded,
        "cor": Colors.teal.shade500,
      },
      {
        "nome": "Tabela",
        "icone": Icons.table_rows_rounded,
        "cor": Colors.indigo.shade600,
      },
      {
        "nome": "Segmentacao",
        "icone": Icons.filter_alt_rounded,
        "cor": Colors.blueGrey.shade600,
      },
      {
        "nome": "Cartao KPI",
        "icone": Icons.scoreboard_rounded,
        "cor": Colors.lime.shade700,
      },
      {
        "nome": "Gauge",
        "icone": Icons.speed_rounded,
        "cor": Colors.deepOrange.shade600,
      },
      {
        "nome": "Treemap",
        "icone": Icons.grid_view_rounded,
        "cor": Colors.green.shade800,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de Graficos')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(paddingGlobal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Qual visualizacao deseja criar?",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Escolha o visual e personalize antes de inserir no dashboard.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  _botaoLogsETL(context),
                ],
              )
            else ...[
              const Text(
                "Qual visualizacao deseja criar?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Escolha o visual e personalize antes de inserir no dashboard.",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _botaoLogsETL(context),
            ],
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: colunasGrid,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: tiposGraficos.length,
              itemBuilder: (context, index) {
                final grafico = tiposGraficos[index];
                final cor = grafico['cor'] as Color;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MetricasScreen(
                          data: data,
                          tipoGrafico: grafico['nome'] as String,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            grafico['icone'] as IconData,
                            size: 36,
                            color: cor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          grafico['nome'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
}
