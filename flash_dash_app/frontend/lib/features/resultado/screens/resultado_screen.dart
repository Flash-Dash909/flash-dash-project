import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 

class ResultadoScreen extends StatelessWidget {
  const ResultadoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dadosGrafico = [
      PieChartSectionData(value: 30, color: Colors.blue, title: 'Produto A', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: 20, color: Colors.green, title: 'Produto B', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: 15, color: Colors.orange, title: 'Produto C', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: 35, color: Colors.purple, title: 'Produto D', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      // 1. ADICIONAMOS O SCROLL AQUI:
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Icon(Icons.filter_alt_outlined, color: Colors.blue),
                ],
              ),
              const SizedBox(height: 16),

              AspectRatio(
                aspectRatio: 1.3,
                child: PieChart(
                  PieChartData(
                    sections: dadosGrafico,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 4,
                color: Colors.red.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Análise da IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Os produtos D e A geram a maior parte da receita. Considere aumentar os investimentos neles. O produto C tem o menor volume, avalie se vale a pena mantê-lo.',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 2. TROCAMOS O SPACER() POR UM SIZEDBOX FIXO AQUI:
              const SizedBox(height: 32), 

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FloatingActionButton(
                    onPressed: () {},
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.swap_horiz),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download),
                    label: const Text('Baixar Tabela'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              // Adicionamos um respiro extra no final da tela para os botões não ficarem colados no rodapé
              const SizedBox(height: 24), 
            ],
          ),
        ),
      ),
    );
  }
}