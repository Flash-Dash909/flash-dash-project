import 'package:flutter/material.dart';

class DashboardBuilderScreen extends StatefulWidget {
  const DashboardBuilderScreen({super.key});

  @override
  State<DashboardBuilderScreen> createState() => _DashboardBuilderScreenState();
}

class _DashboardBuilderScreenState extends State<DashboardBuilderScreen> {
  // Lista que guardará todos os gráficos adicionados ao dash
  List<Map<String, dynamic>> graficosNoDash = [];

  void _adicionarNovoGrafico() {
    setState(() {
      graficosNoDash.add({
        "id": DateTime.now().toString(),
        "posicao": const Offset(50, 50),
        "tamanho": const Size(300, 250),
        "titulo": "Gráfico ${graficosNoDash.length + 1}",
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash-Dash: Construtor'),
        actions: [
          IconButton(icon: const Icon(Icons.add_chart), onPressed: _adicionarNovoGrafico),
          IconButton(icon: const Icon(Icons.save), onPressed: () => _salvarNoSupabase()),
        ],
      ),
      body: Container(
        color: Colors.grey[200], // Fundo para parecer um quadro negro
        child: Stack(
          children: graficosNoDash.map((config) {
            return Positioned(
              left: config['posicao'].dx,
              top: config['posicao'].dy,
              child: GestureDetector(
                // Lógica para MOVER
                onPanUpdate: (details) {
                  setState(() {
                    config['posicao'] += details.delta;
                  });
                },
                child: Container(
                  width: config['tamanho'].width,
                  height: config['tamanho'].height,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(config['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Icon(Icons.drag_indicator, size: 16),
                        ],
                      ),
                      const Divider(),
                      const Expanded(child: Center(child: Text("Aqui entra o Gráfico"))),
                      // Ícone no canto inferior direito para REDIMENSIONAR
                      Align(
                        alignment: Alignment.bottomRight,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              config['tamanho'] = Size(
                                config['tamanho'].width + details.delta.dx,
                                config['tamanho'].height + details.delta.dy,
                              );
                            });
                          },
                          child: const Icon(Icons.open_in_full, size: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _salvarNoSupabase() {
    // Aqui vamos transformar a lista 'graficosNoDash' em JSON e enviar para o banco
    print("Salvando layout...");
  }
}