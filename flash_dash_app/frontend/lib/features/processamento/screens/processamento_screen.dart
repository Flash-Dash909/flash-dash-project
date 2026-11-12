import 'package:flutter/material.dart';
import '../../resultado/screens/selecao_grafico_screen.dart';

class ProcessamentoScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProcessamentoScreen({super.key, required this.data});

  @override
  State<ProcessamentoScreen> createState() => _ProcessamentoScreenState();
}

class _ProcessamentoScreenState extends State<ProcessamentoScreen> {
  @override
  void initState() {
    super.initState();
    _simularProcessamento();
  }

  void _simularProcessamento() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SelecaoGraficoScreen(data: widget.data),
        ),
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
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Limpando dados...',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Ajustando tabelas...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
