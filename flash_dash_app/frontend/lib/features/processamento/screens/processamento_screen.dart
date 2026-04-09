import 'package:flutter/material.dart';
import '../../resultado/screens/resultado_screen.dart';

class ProcessamentoScreen extends StatefulWidget {
  const ProcessamentoScreen({super.key});

  @override
  State<ProcessamentoScreen> createState() => _ProcessamentoScreenState();
}

class _ProcessamentoScreenState extends State<ProcessamentoScreen> {
  // O initState é executado uma vez, quando a tela é carregada
  @override
  void initState() {
    super.initState();
    _simularProcessamento();
  }

  // Simula um atraso de 3 segundos e navega para a tela de resultado
  void _simularProcessamento() async {
    await Future.delayed(const Duration(seconds: 3));
    // Se a tela ainda estiver montada, navega para a tela de Resultado
    if (mounted) {
      Navigator.pushReplacement( // Navegação que substitui a tela atual (para não voltar ao loading)
        context,
        MaterialPageRoute(builder: (context) => const ResultadoScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bolinha girando
            CircularProgressIndicator(color: Colors.blue), 
            SizedBox(height: 24),
            Text('Limpando dados...', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Ajustando tabelas...', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}