import 'package:flutter/material.dart';
import 'dart:math';

class StarSchemaScreen extends StatelessWidget {
  final Map<String, dynamic> summary;

  const StarSchemaScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    List<String> dimensoes = List<String>.from(summary['dimensoes'] ?? []);
    List<String> metricas = List<String>.from(summary['metricas'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelagem Lógica: Star Schema'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.indigo.shade50,
      body: dimensoes.isEmpty && metricas.isEmpty
          ? const Center(child: Text("Sem dados suficientes para modelagem."))
          : LayoutBuilder(
              builder: (context, constraints) {
                // Dimensões da tela para calcular o centro e o raio
                final double width = constraints.maxWidth;
                final double height = constraints.maxHeight;
                final Offset center = Offset(width / 2, height / 2);
                
                // O raio define a distância das dimensões para a Tabela Fato
                final double radius = min(width, height) * 0.35; 

                return Stack(
                  children: [
                    // 1. DESENHA AS LINHAS DE RELACIONAMENTO NO FUNDO
                    CustomPaint(
                      size: Size(width, height),
                      painter: _StarSchemaLinesPainter(
                        center: center,
                        radius: radius,
                        numDimensions: dimensoes.length,
                      ),
                    ),

                    // 2. DESENHA AS TABELAS DIMENSÃO AO REDOR
                    ...List.generate(dimensoes.length, (index) {
                      final double angle = (2 * pi / dimensoes.length) * index;
                      // Calcula a posição (x, y) na borda do círculo
                      final double x = center.dx + radius * cos(angle);
                      final double y = center.dy + radius * sin(angle);

                      return Positioned(
                        left: x - 60, // Centraliza o widget na coordenada (60 é metade da largura estimada)
                        top: y - 30,  // Centraliza verticalmente
                        child: _buildTabelaDimensao(dimensoes[index]),
                      );
                    }),

                    // 3. DESENHA A TABELA FATO BEM NO CENTRO
                    Align(
                      alignment: Alignment.center,
                      child: _buildTabelaFato(metricas),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Visual da Tabela Fato (Centro)
  Widget _buildTabelaFato(List<String> metricas) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade800, width: 2),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade800,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: const Text(
              "FATO_VENDAS\n(Tabela Central)",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.key, size: 12, color: Colors.amber), SizedBox(width: 4), Text("ID_Fato (PK)", style: TextStyle(fontSize: 10))]),
                const Divider(height: 12),
                ...metricas.map((m) => Row(
                  children: [
                    const Icon(Icons.tag, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ],
                )),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Visual das Tabelas Dimensão (Ao Redor)
  Widget _buildTabelaDimensao(String nome) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade600, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Text(
              "DIM_$nome",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Row(
              children: [
                const Icon(Icons.key, size: 12, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(child: Text("ID_$nome (PK)", style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// Pintor Customizado para fazer as linhas conectando a Fato às Dimensões
class _StarSchemaLinesPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final int numDimensions;

  _StarSchemaLinesPainter({required this.center, required this.radius, required this.numDimensions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < numDimensions; i++) {
      final double angle = (2 * pi / numDimensions) * i;
      final double x = center.dx + radius * cos(angle);
      final double y = center.dy + radius * sin(angle);

      // Desenha a linha do centro exato até o centro exato de cada dimensão
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}