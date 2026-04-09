import 'package:flutter/material.dart';
import '../../processamento/screens/processamento_screen.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dados de exemplo para os tipos de gráfico
    final tiposGrafico = [
      {'nome': 'Pizza', 'icone': Icons.pie_chart},
      {'nome': 'Barras', 'icone': Icons.bar_chart},
      {'nome': 'Linhas', 'icone': Icons.show_chart},
      {'nome': 'Área', 'icone': Icons.multiline_chart},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Projeto: Upload'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16), // Espaçamento vertical

            // Área grande de upload
            Card(
              elevation: 4,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, size: 64, color: Colors.grey),
                    Text('Arraste seu arquivo .csv ou .xlsx aqui', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Tipos de gráfico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Lista horizontal de tipos de gráfico
            SizedBox(
              height: 100, // Define a altura da lista
              child: ListView.builder(
                scrollDirection: Axis.horizontal, // Rola horizontalmente
                itemCount: tiposGrafico.length,
                itemBuilder: (context, index) {
                  final tipo = tiposGrafico[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 16), // Espaçamento horizontal entre os cards
                    child: Card(
                      elevation: 4,
                      color: index == 0 ? Colors.blue.shade100 : Colors.white, // Destaca o primeiro card
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tipo['icone'] as IconData?, size: 40, color: Colors.blue),
                          Text(tipo['nome'] as String, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Spacer(), // Ocupa o espaço restante verticalmente

            // Botão "Processar" que leva para a próxima tela
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProcessamentoScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Processar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}