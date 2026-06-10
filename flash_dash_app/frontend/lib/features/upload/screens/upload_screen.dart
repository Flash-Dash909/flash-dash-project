import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../resultado/screens/selecao_grafico_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _fontesDeDados = [
    {
      "nome": "Excel",
      "descricao": "XLSX e XLS",
      "icone": Icons.table_chart_rounded,
      "cor": const Color(0xFF217346),
      "tipo": "excel",
      "extensoes": ["xlsx", "xls"],
    },
    {
      "nome": "CSV / TSV",
      "descricao": "CSV, TSV e TXT",
      "icone": Icons.dataset_rounded,
      "cor": const Color(0xFF10B981),
      "tipo": "csv_tsv",
      "extensoes": ["csv", "tsv", "txt"],
    },
    {
      "nome": "JSON",
      "descricao": "JSON e NDJSON",
      "icone": Icons.data_object_rounded,
      "cor": const Color(0xFFF59E0B),
      "tipo": "json",
      "extensoes": ["json", "ndjson"],
    },
    {
      "nome": "Parquet",
      "descricao": "Arquivo columnar",
      "icone": Icons.view_column_rounded,
      "cor": const Color(0xFF2563EB),
      "tipo": "parquet",
      "extensoes": ["parquet"],
    },
    {
      "nome": "Google Sheets",
      "descricao": "URL publicada CSV",
      "icone": Icons.grid_on_rounded,
      "cor": const Color(0xFF0F9D58),
      "tipo": "google_sheets",
      "url": true,
    },
    {
      "nome": "API REST",
      "descricao": "JSON ou CSV por URL",
      "icone": Icons.api_rounded,
      "cor": const Color(0xFF7C3AED),
      "tipo": "api_rest",
      "url": true,
    },
    {
      "nome": "PostgreSQL",
      "descricao": "Export CSV/JSON",
      "icone": Icons.storage_rounded,
      "cor": const Color(0xFF336791),
      "tipo": "postgresql_export",
      "extensoes": ["csv", "json", "ndjson"],
    },
    {
      "nome": "MySQL",
      "descricao": "Export CSV/JSON",
      "icone": Icons.dns_rounded,
      "cor": const Color(0xFF00758F),
      "tipo": "mysql_export",
      "extensoes": ["csv", "json", "ndjson"],
    },
    {
      "nome": "Salesforce",
      "descricao": "Relatorio CSV",
      "icone": Icons.cloud_rounded,
      "cor": const Color(0xFF00A1E0),
      "tipo": "salesforce_export",
      "extensoes": ["csv", "xlsx", "json"],
    },
    {
      "nome": "Stripe",
      "descricao": "Export CSV",
      "icone": Icons.payments_rounded,
      "cor": const Color(0xFF635BFF),
      "tipo": "stripe_export",
      "extensoes": ["csv", "json"],
    },
  ];

  Future<void> _selecionarArquivo(Map<String, dynamic> fonte) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: List<String>.from(fonte["extensoes"]),
        withData: true,
      );

      if (result == null) return;

      setState(() => _isLoading = true);

      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (fileBytes == null) {
        throw Exception("Nao foi possivel ler o arquivo selecionado.");
      }

      final uri = Uri.parse('http://127.0.0.1:8000/analisar-planilha');
      final request = http.MultipartRequest('POST', uri);
      request.fields['fonte_tipo'] = fonte["tipo"];
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      await _tratarResposta(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _conectarUrl(Map<String, dynamic> fonte) async {
    final controller = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("Conectar ${fonte['nome']}"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "URL",
              hintText: "https://...",
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text("Conectar"),
            ),
          ],
        );
      },
    );

    if (url == null || url.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/analisar-url'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'url': url,
          'fonte_tipo': fonte["tipo"],
          'nome': '${fonte["tipo"]}.json',
        }),
      );

      await _tratarResposta(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tratarResposta(http.Response response) async {
    final data = json.decode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && data['status'] != 'error') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelecaoGraficoScreen(data: data),
        ),
      );
      return;
    }

    throw Exception(
      data['message'] ?? data['detail'] ?? "Erro no motor Python.",
    );
  }

  void _abrirFonte(Map<String, dynamic> fonte) {
    if (fonte["url"] == true) {
      _conectarUrl(fonte);
    } else {
      _selecionarArquivo(fonte);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 800;
    int colunasGrid = isDesktop ? 5 : (screenWidth >= 600 ? 3 : 2);
    double paddingGlobal = isDesktop ? 40.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Conectar Fonte de Dados')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Processando fonte de dados...",
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(paddingGlobal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Onde estao os seus dados?",
                    style: TextStyle(
                      fontSize: isDesktop ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Escolha uma fonte para iniciar a extracao e limpeza automatica.",
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colunasGrid,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isDesktop ? 1.08 : 1.0,
                    ),
                    itemCount: _fontesDeDados.length,
                    itemBuilder: (context, index) {
                      final fonte = _fontesDeDados[index];
                      final Color cor = fonte['cor'];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: cor.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _abrirFonte(fonte),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    fonte['icone'],
                                    size: 34,
                                    color: cor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  fonte['nome'],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fonte['descricao'],
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
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
