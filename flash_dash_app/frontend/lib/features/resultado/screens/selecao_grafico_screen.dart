import 'package:flutter/material.dart';
import 'metricas_screen.dart';
import '../../processamento/screens/etl_history_screen.dart'; // Importa a tela da Timeline

class SelecaoGraficoScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const SelecaoGraficoScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Nova lista com Ícones e esquema de cores moderno
    final List<Map<String, dynamic>> tiposGraficos = [
      {
        "nome": "Gráfico de Barras",
        "icone": Icons.bar_chart_rounded,
        "corPrincipal": Colors.amber.shade700,
        "corFundo": Colors.amber.shade50
      },
      {
        "nome": "Gráfico de Pizza",
        "icone": Icons.pie_chart_rounded,
        "corPrincipal": Colors.pinkAccent.shade400,
        "corFundo": Colors.pink.shade50
      },
      {
        "nome": "Gráfico de Colunas",
        "icone": Icons.leaderboard_rounded,
        "corPrincipal": Colors.cyan.shade600,
        "corFundo": Colors.cyan.shade50
      },
      {
        "nome": "Gráfico de Rosca",
        "icone": Icons.donut_large_rounded,
        "corPrincipal": Colors.green.shade600,
        "corFundo": Colors.green.shade50
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash-Dash: Novo Gráfico'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Qual visualização deseja criar?", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            const SizedBox(height: 12),
            
            // --- BOTÃO DA LINHA DO TEMPO ETL AQUI ---
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  // Pega os logs e o sumário
                  List<dynamic> logs = data['dados_planilha']['etl_logs'] ?? [];
                  Map<String, dynamic> summary = data['dados_planilha']['summary'] ?? {}; // <-- Pega o sumário
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // <-- Passa o sumário junto
                      builder: (context) => EtlHistoryScreen(logsEtl: logs, summary: summary), 
                    ),
                  );
                },
                icon: const Icon(Icons.account_tree, color: Colors.blueGrey),
                label: const Text(
                  "Ver Pipeline de Transformação (ETL)", 
                  style: TextStyle(color: Colors.blueGrey, decoration: TextDecoration.underline)
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            // Grid de Botões Modernos
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1, // Deixa eles mais "quadradinhos" e compactos
              ),
              itemCount: tiposGraficos.length,
              itemBuilder: (context, index) {
                final grafico = tiposGraficos[index];
                return Material(
                  color: grafico['corFundo'],
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MetricasScreen(
                            data: data,
                            tipoGrafico: grafico['nome'],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: grafico['corPrincipal'].withOpacity(0.3), width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: grafico['corPrincipal'].withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              grafico['icone'],
                              size: 42,
                              color: grafico['corPrincipal'],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            grafico['nome'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.blueGrey.shade800
                            ),
                          ),
                        ],
                      ),
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
}