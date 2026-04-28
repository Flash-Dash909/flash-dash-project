import 'package:flutter/material.dart';
import 'star_schema_screen.dart'; // Importa a tela que acabamos de criar

class EtlHistoryScreen extends StatelessWidget {
  final List<dynamic> logsEtl;
  final Map<String, dynamic> summary;

  const EtlHistoryScreen({super.key, required this.logsEtl, required this.summary});

  // Mapeia o nome do ícone vindo do Python para um IconData real do Flutter
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'upload': return Icons.cloud_upload_outlined;
      case 'cleaning': return Icons.cleaning_services_outlined;
      case 'text_format': return Icons.spellcheck;
      case 'schema': return Icons.account_tree_outlined;
      case 'check_circle': return Icons.check_circle_outline;
      default: return Icons.memory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log de Transformação (ETL)'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      
      // CORPO DA TELA: A LINHA DO TEMPO
      body: logsEtl.isEmpty
          ? const Center(child: Text("Nenhum histórico de ETL encontrado."))
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: logsEtl.length,
              itemBuilder: (context, index) {
                final log = logsEtl[index];
                bool isLast = index == logsEtl.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // COLUNA DA LINHA DO TEMPO (Timeline)
                      SizedBox(
                        width: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isLast ? Colors.green : Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIcon(log['icone'] ?? ''),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 3,
                                  color: Colors.blueAccent.withOpacity(0.3),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // COLUNA DO CONTEÚDO (O Log em si)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0, left: 12.0),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['fase'] ?? 'Processamento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    log['descricao'] ?? '',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
      // BOTÃO FIXO NO FUNDO DA TELA
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StarSchemaScreen(summary: summary),
              ),
            );
          },
          icon: const Icon(Icons.hub), // Ícone de conexões/rede
          label: const Text("Ver Modelagem Star Schema Automática", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}