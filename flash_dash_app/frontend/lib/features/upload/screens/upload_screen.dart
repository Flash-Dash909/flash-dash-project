import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:http/http.dart' as http;
import '../../resultado/screens/selecao_grafico_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  String _responseMessage = "Nenhum arquivo enviado ainda.";

  Future<void> _pickAndUploadFile() async {
    // 1. Abre a janela com o prefixo 'fp.' corretamente aplicado
    fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _responseMessage = "Enviando arquivo para o motor Python...";
      });

      try {
        var file = result.files.first;
        var uri = Uri.parse('http://127.0.0.1:8000/analisar-planilha');
        var request = http.MultipartRequest('POST', uri);

        request.files.add(http.MultipartFile.fromBytes(
          'arquivo',
          file.bytes!,
          filename: file.name,
        ));

        var response = await request.send();
        var responseData = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          var jsonResponse = json.decode(responseData);
          
          setState(() {
            _responseMessage = "✅ Sucesso! Redirecionando...";
          });

          // ADICIONE ISTO AQUI:
          if (mounted) {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => SelecaoGraficoScreen(data: jsonResponse), // AQUI
           ),
         );
       }
        }
      } catch (e) {
        setState(() {
          _responseMessage = "❌ Falha na conexão.\nO backend Python está rodando?\nErro: $e";
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash-Dash: Nova Fonte de Dados'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndUploadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Selecionar Planilha (Excel/CSV)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _responseMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}