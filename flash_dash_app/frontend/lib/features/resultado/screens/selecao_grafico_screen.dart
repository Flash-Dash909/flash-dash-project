import 'package:flutter/material.dart';
import 'metricas_screen.dart';
import '../../processamento/screens/etl_history_screen.dart';

class SelecaoGraficoScreen extends StatelessWidget {
  
  final Map<String, dynamic> data;
  final String usuarioNome; // <- ADICIONE AQUI
  final String usuarioId; // <- ADICIONE AQUI
  const SelecaoGraficoScreen({super.key, required this.data, required this.usuarioNome, required this.usuarioId});

  @override
  Widget build(BuildContext context) {
    // Responsividade
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 800;
    int colunasGrid = isDesktop ? 4 : 2; // 4 colunas no PC, 2 no Celular
    double paddingGlobal = isDesktop ? 40.0 : 16.0;

    final List<Map<String, dynamic>> tiposGraficos = [
      {"nome": "Gráfico de Barras", "icone": Icons.bar_chart_rounded, "cor": Colors.amber.shade700, "funciona": true},
      {"nome": "Gráfico de Colunas", "icone": Icons.leaderboard_rounded, "cor": Colors.cyan.shade600, "funciona": true},
      {"nome": "Gráfico de Pizza", "icone": Icons.pie_chart_rounded, "cor": Colors.pinkAccent.shade400, "funciona": true},
      {"nome": "Gráfico de Rosca", "icone": Icons.donut_large_rounded, "cor": Colors.green.shade600, "funciona": true},
      {"nome": "Gráfico de Linha", "icone": Icons.show_chart_rounded, "cor": Colors.blue.shade600, "funciona": false},
      {"nome": "Gráfico de Área", "icone": Icons.area_chart_rounded, "cor": Colors.purple.shade500, "funciona": false},
      {"nome": "Dispersão", "icone": Icons.bubble_chart_rounded, "cor": Colors.red.shade500, "funciona": false},
      {"nome": "Radar", "icone": Icons.track_changes_rounded, "cor": Colors.teal.shade500, "funciona": false},
    ];

    void mostrarEmBreve() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📊 Visualização em desenvolvimento.'), backgroundColor: Color(0xFF2563EB), duration: Duration(seconds: 2)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de Gráficos')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(paddingGlobal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No celular, empilhamos os textos e o botão. No PC, ficam lado a lado.
            if (isDesktop)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Qual visualização deseja criar?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text("Escolha a melhor forma de representar seus dados limpos.", style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade600)),
                    ],
                  ),
                  _botaoLogsETL(context),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Qual visualização deseja criar?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text("Escolha a melhor forma de representar seus dados limpos.", style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade600)),
                  const SizedBox(height: 16),
                  _botaoLogsETL(context),
                ],
              ),
            
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
                final bool funciona = grafico['funciona'];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: funciona ? grafico['cor'].withOpacity(0.5) : const Color(0xFFE2E8F0), width: funciona ? 2 : 1),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: funciona 
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => MetricasScreen(data: data, tipoGrafico: grafico['nome'], usuarioNome: usuarioNome, usuarioId: usuarioId)))
                      : mostrarEmBreve,
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: funciona ? grafico['cor'].withOpacity(0.1) : Colors.grey.shade100, shape: BoxShape.circle),
                                child: Icon(grafico['icone'], size: 36, color: funciona ? grafico['cor'] : Colors.grey.shade400),
                              ),
                              const SizedBox(height: 12),
                              Text(grafico['nome'], textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: funciona ? const Color(0xFF0F172A) : Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        if (!funciona) Positioned(top: 12, right: 12, child: Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400)),
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
        List<dynamic> logs = data['dados_planilha']['etl_logs'] ?? [];
        Map<String, dynamic> summary = data['dados_planilha']['summary'] ?? {};
        Navigator.push(context, MaterialPageRoute(builder: (context) => EtlHistoryScreen(logsEtl: logs, summary: summary)));
      },
      icon: const Icon(Icons.account_tree, color: Color(0xFF2563EB)),
      label: const Text("Ver Logs ETL", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
    );
  }
}