import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../resultado/screens/selecao_grafico_screen.dart'; // <-- Ponto extra removido daqui!

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;

  // Lista de conexões para "Vender a Visão"
  final List<Map<String, dynamic>> _fontesDeDados = [
    {"nome": "Excel / CSV", "icone": Icons.table_view_rounded, "cor": Colors.green.shade600, "ativo": true},
    {"nome": "Google Sheets", "icone": Icons.grid_on_rounded, "cor": Colors.teal.shade500, "ativo": false},
    {"nome": "PostgreSQL", "icone": Icons.storage_rounded, "cor": Colors.blue.shade700, "ativo": false},
    {"nome": "MySQL", "icone": Icons.dns_rounded, "cor": Colors.orange.shade600, "ativo": false},
    {"nome": "API REST", "icone": Icons.api_rounded, "cor": Colors.purple.shade500, "ativo": false},
    {"nome": "Salesforce", "icone": Icons.cloud_rounded, "cor": Colors.lightBlue.shade500, "ativo": false},
    {"nome": "MongoDB", "icone": Icons.dataset_rounded, "cor": Colors.green.shade800, "ativo": false},
    {"nome": "Stripe", "icone": Icons.payments_rounded, "cor": Colors.indigo.shade500, "ativo": false},
  ];

  // =========================================================
  // SUA LÓGICA DE UPLOAD REAL PARA O BACKEND FASTAPI
  // =========================================================
  Future<void> _selecionarArquivoExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null) {
        setState(() => _isLoading = true); // Só mostra o loading se ele escolheu um arquivo
        
        var fileBytes = result.files.first.bytes;
        var fileName = result.files.first.name;

        if (fileBytes != null) {
          // Envia para o motor Python
          var uri = Uri.parse('http://127.0.0.1:8000/analisar-planilha');
          var request = http.MultipartRequest('POST', uri);
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ));

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            // Decodifica a resposta com suporte a acentos
            final data = json.decode(utf8.decode(response.bodyBytes));
            
            // Navega para a tela de Seleção de Gráficos (a biblioteca bonitona)
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelecaoGraficoScreen(data: data),
              ),
            );
          } else {
            throw Exception("Erro no motor Python (FastAPI): Código ${response.statusCode}");
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarMensagemEmBreve() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Integração disponível apenas na versão PRO/Futura.'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Fonte de Dados'),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Processando via Pandas e IA...", style: TextStyle(color: Colors.blueGrey))
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Onde estão os seus dados?",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Selecione uma fonte para iniciar a extração (ETL).",
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _fontesDeDados.length,
                    itemBuilder: (context, index) {
                      final fonte = _fontesDeDados[index];
                      final bool isAtivo = fonte['ativo'];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isAtivo ? fonte['cor'] : const Color(0xFFE2E8F0), width: isAtivo ? 2 : 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isAtivo ? _selecionarArquivoExcel : _mostrarMensagemEmBreve,
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(fonte['icone'], size: 48, color: isAtivo ? fonte['cor'] : Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      fonte['nome'],
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.w600,
                                        color: isAtivo ? const Color(0xFF0F172A) : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isAtivo)
                                Positioned(
                                  top: 12, right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                    child: const Text("PRO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}