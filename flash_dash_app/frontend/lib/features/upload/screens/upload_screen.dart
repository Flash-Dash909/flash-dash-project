import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/widgets/app_logo.dart';
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
    {
      "nome": "SharePoint",
      "descricao": "Link CSV/XLSX",
      "icone": Icons.folder_shared_rounded,
      "cor": const Color(0xFF0369A1),
      "tipo": "sharepoint_link",
      "url": true,
    },
    {
      "nome": "OneDrive",
      "descricao": "Link compartilhado",
      "icone": Icons.cloud_queue_rounded,
      "cor": const Color(0xFF0078D4),
      "tipo": "onedrive_link",
      "url": true,
    },
    {
      "nome": "Google Drive",
      "descricao": "Link CSV/XLSX",
      "icone": Icons.add_to_drive_rounded,
      "cor": const Color(0xFF1A73E8),
      "tipo": "google_drive_link",
      "url": true,
    },
    {
      "nome": "HubSpot",
      "descricao": "Export CSV",
      "icone": Icons.handshake_rounded,
      "cor": const Color(0xFFFF7A59),
      "tipo": "hubspot_export",
      "extensoes": ["csv", "xlsx", "json"],
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

      final uri = Uri.parse('https://flash-dash-project-7.onrender.com/analisar-planilha');
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
        Uri.parse('https://flash-dash-project-7.onrender.com/analisar-url'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 800;
    double paddingGlobal = isDesktop ? 40.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Fonte de Dados'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogo(size: 32, opacity: 0.82),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    "Processando fonte de dados...",
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
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
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Escolha uma fonte para iniciar a extracao e limpeza automatica.",
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 210 : 185,
                      mainAxisExtent: isDesktop ? 188 : 174,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _fontesDeDados.length,
                    itemBuilder: (context, index) {
                      final fonte = _fontesDeDados[index];
                      final Color cor = fonte['cor'];

                      return Card(
                        color: isDark ? const Color(0xFF111827) : Colors.white,
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
                            padding: EdgeInsets.all(isDesktop ? 16 : 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cor.withValues(
                                      alpha: isDark ? 0.18 : 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    fonte['icone'],
                                    size: isDesktop ? 34 : 30,
                                    color: cor,
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 12 : 10),
                                Text(
                                  fonte['nome'],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14 : 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fonte['descricao'],
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 12 : 11,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.66,
                                    ),
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
