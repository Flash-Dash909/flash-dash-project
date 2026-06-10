import 'package:flutter/material.dart';
import '../../upload/screens/upload_screen.dart';

class ProjetosScreen extends StatelessWidget {
  final String usuarioNome; // <- ADICIONE ESSA VARIÁVEL
  final String usuarioId;
  const ProjetosScreen({
    super.key,
    required this.usuarioNome,
    required this.usuarioId,
  });

  @override
  Widget build(BuildContext context) {
    // Dados de exemplo para os projetos
    final meusProjetos = [
      {'nome': 'Performance Q1', 'cor': Colors.blue},
      {'nome': 'Vendas Regionais', 'cor': Colors.green},
      {'nome': 'Análise de Custos', 'cor': Colors.orange},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Projetos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Número de colunas no grid
            crossAxisSpacing: 16, // Espaçamento horizontal entre os itens
            mainAxisSpacing: 16, // Espaçamento vertical entre os itens
          ),
          // +1 para o botão de "Novo Projeto"
          itemCount: meusProjetos.length + 1,
          itemBuilder: (context, index) {
            // O primeiro item (index 0) será o botão de "Novo Projeto"
            if (index == 0) {
              return Card(
                elevation: 4,
                color: Colors.blue.shade100,
                child: InkWell(
                  // Torna o card clicável com efeito visual
                  onTap: () {
                    // Navega para a tela de Upload
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadScreen(
                          usuarioNome: usuarioNome,
                          usuarioId: usuarioId,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Icon(Icons.add, size: 48, color: Colors.blue),
                  ),
                ),
              );
            } else {
              // Os outros itens serão cards para os projetos existentes
              // index - 1 para ajustar ao índice da lista meusProjetos
              final projeto = meusProjetos[index - 1];
              return Card(
                elevation: 4,
                color: projeto['cor'] as Color?,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projeto['nome'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
