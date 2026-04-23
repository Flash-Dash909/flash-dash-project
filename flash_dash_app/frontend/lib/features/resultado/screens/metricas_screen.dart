import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// Importações do teu novo módulo de Dashboard
import '../../dashboard/dashboard_manager.dart';
import '../../dashboard/screens/dashboard_canvas_screen.dart';

class MetricasScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String tipoGrafico;

  const MetricasScreen({super.key, required this.data, required this.tipoGrafico});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  String? dimensaoSelecionada;
  String? metricaSelecionada;

  @override
  void initState() {
    super.initState();
    // Agora pegamos nas listas separadas que o Python nos enviou!
    List<String> dimensoes = List<String>.from(widget.data['dados_planilha']['summary']['dimensoes'] ?? []);
    List<String> metricas = List<String>.from(widget.data['dados_planilha']['summary']['metricas'] ?? []);

    if (dimensoes.isNotEmpty) dimensaoSelecionada = dimensoes.first;
    if (metricas.isNotEmpty) metricaSelecionada = metricas.first;
  }

  // Função que recalcula o Top 5 em tempo real quando o utilizador muda os menus
  List<Map<String, dynamic>> _recalcularGrafico() {
    List<dynamic> rawData = widget.data['dados_planilha']['dados_completos'] ?? [];

    if (rawData.isEmpty || dimensaoSelecionada == null || metricaSelecionada == null) {
      return List<Map<String, dynamic>>.from(widget.data['dados_planilha']['chart_data'] ?? []);
    }

    Map<String, double> agrupado = {};
    for (var row in rawData) {
      String dim = row[dimensaoSelecionada].toString();
      var rawVal = row[metricaSelecionada];
      double val = 0.0;
      
      if (rawVal is num) {
        val = rawVal.toDouble();
      } else if (rawVal is String) {
        val = double.tryParse(rawVal) ?? 0.0;
      }
      
      agrupado[dim] = (agrupado[dim] ?? 0) + val;
    }

    var entries = agrupado.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value)); // Ordena do maior para o menor
    var top5 = entries.take(5).toList();

    List<Color> cores = [
      const Color(0xFF1E293B), const Color(0xFF748AA1), 
      const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFFF59E0B)
    ];

    return top5.asMap().entries.map((entry) {
      return {
        "label": entry.value.key,
        "value": entry.value.value,
        "color": cores[entry.key % cores.length],
      };
    }).toList();
  }

  // Função que constrói o desenho correto baseado na escolha anterior
  Widget _construirGrafico(List<Map<String, dynamic>> dados) {
    if (dados.isEmpty) return const Center(child: Text("Sem dados para apresentar."));

    // Se for Pizza ou Rosca
    if (widget.tipoGrafico.contains('Pizza') || widget.tipoGrafico.contains('Rosca')) {
      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: widget.tipoGrafico.contains('Rosca') ? 50 : 0, // A rosca tem um buraco no meio
          sections: dados.map((item) {
            return PieChartSectionData(
              color: item['color'] as Color,
              value: item['value'] as double,
              title: item['label'],
              radius: widget.tipoGrafico.contains('Rosca') ? 60 : 100,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      );
    }

    // Se for Barras ou Colunas
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: dados.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value['value'] as double,
                color: entry.value['color'] as Color,
                width: 35,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dados.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dados[value.toInt()]['label'],
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> dimensoes = List<String>.from(widget.data['dados_planilha']['summary']['dimensoes'] ?? []);
    List<String> metricas = List<String>.from(widget.data['dados_planilha']['summary']['metricas'] ?? []);
    
    var dadosProcessados = _recalcularGrafico();

    return Scaffold(
      appBar: AppBar(title: Text('Configurar: ${widget.tipoGrafico}')),
      body: SingleChildScrollView( // Permite fazer scroll no ecrã inteiro
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. Escolha a Dimensão (Eixo X - Textos/Categorias):", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: dimensaoSelecionada,
              items: dimensoes.map((col) => DropdownMenuItem(value: col, child: Text(col))).toList(),
              onChanged: (val) => setState(() => dimensaoSelecionada = val),
            ),
            const SizedBox(height: 16),
            const Text("2. Escolha a Métrica (Eixo Y - Valores Numéricos):", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: metricaSelecionada,
              items: metricas.map((col) => DropdownMenuItem(value: col, child: Text(col))).toList(),
              onChanged: (val) => setState(() => metricaSelecionada = val),
            ),
            const SizedBox(height: 30),
            
            const Text("Pré-visualização do Gráfico:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Cartão com tamanho fixo para conter o gráfico
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                height: 350, // Tamanho controlado para não estourar o ecrã
                padding: const EdgeInsets.all(20),
                child: _construirGrafico(dadosProcessados),
              ),
            ),

            const SizedBox(height: 30),
            
            // BOTÃO NOVO: Adiciona ao Dashboard e navega para a tela de montagem
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (dimensaoSelecionada == null || metricaSelecionada == null) return;
                  
                  // Instancia o modelo configurado
                  final novoGrafico = ChartConfig(
                    id: DateTime.now().toString(),
                    tipo: widget.tipoGrafico,
                    dimensao: dimensaoSelecionada!,
                    metrica: metricaSelecionada!,
                    dados: dadosProcessados,
                  );
                  
                  // Salva na memória
                  DashboardManager.graficosAtivos.add(novoGrafico);
                  
                  // Navega para o quadro branco do Dashboard
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardCanvasScreen()),
                  );
                },
                icon: const Icon(Icons.dashboard_customize),
                label: const Text("Adicionar Gráfico ao Dashboard", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}