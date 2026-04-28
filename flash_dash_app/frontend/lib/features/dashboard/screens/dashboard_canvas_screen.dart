import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../dashboard_manager.dart';

class DashboardCanvasScreen extends StatefulWidget {
  const DashboardCanvasScreen({super.key});

  @override
  State<DashboardCanvasScreen> createState() => _DashboardCanvasScreenState();
}

class _DashboardCanvasScreenState extends State<DashboardCanvasScreen> {
  // --- INÍCIO DO CÓDIGO DO CHAT ---
  final List<Map<String, String>> _mensagensChat = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;

  void _abrirChatIA() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Text("Analista IA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _mensagensChat.length,
                        itemBuilder: (context, index) {
                          bool isUser = _mensagensChat[index]['remetente'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blueAccent : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: isUser ? null : Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                _mensagensChat[index]['texto']!,
                                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_isChatLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Pergunte sobre os gráficos...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _enviarMensagem(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            onPressed: () => _enviarMensagem(setModalState),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _enviarMensagem(StateSetter setModalState) async {
    String pergunta = _chatController.text.trim();
    if (pergunta.isEmpty) return;

    setModalState(() {
      _mensagensChat.add({'remetente': 'user', 'texto': pergunta});
      _chatController.clear();
      _isChatLoading = true;
    });

    // CORREÇÃO: Filtramos os dados para enviar apenas texto e números para a IA.
    // Isso evita o erro de conversão do objeto "Color" para JSON.
    List<Map<String, dynamic>> contextoDashboard = DashboardManager.graficosAtivos.map((g) {
      var dadosLimposParaIA = g.dados.map((d) => {
        "label": d['label'],
        "value": d['value']
      }).toList();

      return {
        "titulo_grafico": g.titulo,
        "dados": dadosLimposParaIA
      };
    }).toList();

    try {
      var uri = Uri.parse('http://127.0.0.1:8000/chat-ia');
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "mensagem": pergunta,
          "contexto_dashboard": contextoDashboard
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        setModalState(() {
          _mensagensChat.add({'remetente': 'ia', 'texto': data['resposta']});
          _isChatLoading = false;
        });
      } else {
        throw Exception("Erro no servidor FastAPI: Código ${response.statusCode}");
      }
    } catch (e) {
      setModalState(() {
        _mensagensChat.add({'remetente': 'ia', 'texto': '⚠️ Erro de conexão com a IA.'});
        _isChatLoading = false;
      });
      // Imprime o erro exato no terminal do Flutter para facilitar futuras depurações
      print("❌ ERRO NO ENVIO DO CHAT: $e"); 
    }
  }

  // --- TELA PRINCIPAL DO DASHBOARD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash-Dash: Dashboard'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _abrirChatIA,
            tooltip: "Chat com a IA",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: "Atualizar layout",
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[200],
        child: Stack(
          children: DashboardManager.graficosAtivos.map((config) {
            return Positioned(
              left: config.posicao.dx,
              top: config.posicao.dy,
              child: _buildResizableDraggableChart(config),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // --- MÉTODOS DOS GRÁFICOS ---
  void _abrirConfiguracoes(ChartConfig config) {
    TextEditingController tituloController = TextEditingController(text: config.titulo);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Configurações do Gráfico"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Título:"),
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              const Text("Cor de Fundo:"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _botaoCor(config, Colors.white, "Branco"),
                  _botaoCor(config, Colors.grey.shade100, "Cinza"),
                  _botaoCor(config, Colors.blue.shade50, "Azul"),
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  config.titulo = tituloController.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  Widget _botaoCor(ChartConfig config, Color cor, String nome) {
    return GestureDetector(
      onTap: () {
        setState(() {
          config.corFundo = cor;
        });
        Navigator.pop(context);
        _abrirConfiguracoes(config);
      },
      child: CircleAvatar(backgroundColor: cor, radius: 20, child: Icon(Icons.check, color: config.corFundo == cor ? Colors.black : Colors.transparent, size: 16)),
    );
  }

  Widget _buildResizableDraggableChart(ChartConfig config) {
    return Container(
      width: config.tamanho.width,
      height: config.tamanho.height,
      child: Card(
        color: config.corFundo,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.blueAccent.withOpacity(0.1),
              child: Row(
                children: [
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        config.posicao += details.delta;
                      });
                    },
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Icon(Icons.open_with, size: 18, color: Colors.blueGrey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                       onPanUpdate: (details) {
                        setState(() {
                          config.posicao += details.delta;
                        });
                      },
                      child: Text(
                        config.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _abrirConfiguracoes(config),
                    child: const Icon(Icons.more_vert, size: 18, color: Colors.blueGrey),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        DashboardManager.graficosAtivos.remove(config);
                      });
                    },
                    child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _renderGraficoMini(config, constraints);
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double novaLargura = config.tamanho.width + details.delta.dx;
                    double novaAltura = config.tamanho.height + details.delta.dy;
                    config.tamanho = Size(
                      novaLargura > 200 ? novaLargura : 200,
                      novaAltura > 200 ? novaAltura : 200,
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
                  ),
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: Icon(Icons.open_in_full, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderGraficoMini(ChartConfig config, BoxConstraints constraints) {
    if (config.dados.isEmpty) return const Center(child: Text("Sem dados"));

    bool isPizzaOuRosca = config.tipo.contains('Pizza') || config.tipo.contains('Rosca');

    if (isPizzaOuRosca) {
      double menorLado = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
      double raioDinamico = menorLado * 0.35;

      return PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: config.tipo.contains('Rosca') ? raioDinamico * 0.6 : 0,
          sections: config.dados.map((d) {
            return PieChartSectionData(
              value: d['value'],
              color: d['color'],
              radius: raioDinamico,
              title: '${d['label']}\n${d['value'].toInt()}',
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: config.dados.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: config.dados.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value['value'],
                color: e.value['color'],
                width: constraints.maxWidth / (config.dados.length * 2.5),
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < config.dados.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Text(
                      config.dados[value.toInt()]['label'].toString().substring(0, config.dados[value.toInt()]['label'].toString().length > 5 ? 5 : config.dados[value.toInt()]['label'].toString().length),
                      style: const TextStyle(fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}