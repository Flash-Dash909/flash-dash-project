import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../../../core/download_service.dart';
import '../../dashboard/dashboard_manager.dart';
import '../../resultado/screens/selecao_grafico_screen.dart';

class FontesDadosScreen extends StatefulWidget {
  final VoidCallback onConectar;

  const FontesDadosScreen({super.key, required this.onConectar});

  @override
  State<FontesDadosScreen> createState() => _FontesDadosScreenState();
}

class _FontesDadosScreenState extends State<FontesDadosScreen> {
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _fontes = [];
  bool _combinando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Uri _uri(String path) {
    final usuarioId = DashboardManager.usuarioAtualId;
    return Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: usuarioId == null ? null : {'usuario_id': usuarioId},
    );
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final response = await http.get(
        _uri('/fontes-dados'),
        headers: DashboardManager.authHeaders,
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao carregar fontes.');
      }
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      _fontes = (decoded as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _excluir(Map<String, dynamic> fonte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir fonte?'),
        content: Text('A fonte "${fonte['nome_arquivo']}" sera removida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final response = await http.delete(
      _uri('/fontes-dados/${fonte['id']}'),
      headers: DashboardManager.authHeaders,
    );
    if (response.statusCode == 200) await _carregar();
  }

  Future<void> _combinarFontes() async {
    final selecionadas = <String>{};
    final nomeController = TextEditingController(text: 'Modelo combinado');
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Conectar planilhas'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Escolha pelo menos duas fontes. O Flash Dash detectara as chaves e a cardinalidade automaticamente.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do modelo',
                    prefixIcon: Icon(Icons.account_tree_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _fontes.length,
                    itemBuilder: (_, index) {
                      final fonte = _fontes[index];
                      final id = fonte['id']?.toString() ?? '';
                      return CheckboxListTile(
                        value: selecionadas.contains(id),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          fonte['nome_arquivo']?.toString() ?? 'Fonte',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${fonte['summary']?['total_rows'] ?? '-'} linhas',
                        ),
                        onChanged: id.isEmpty
                            ? null
                            : (checked) => setDialogState(() {
                                if (checked == true) {
                                  selecionadas.add(id);
                                } else {
                                  selecionadas.remove(id);
                                }
                              }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: selecionadas.length < 2
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.link_rounded),
              label: Text('Conectar (${selecionadas.length})'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || !mounted) {
      nomeController.dispose();
      return;
    }

    setState(() => _combinando = true);
    try {
      final response = await http.post(
        _uri('/fontes-dados/combinar'),
        headers: {
          'Content-Type': 'application/json',
          ...DashboardManager.authHeaders,
        },
        body: json.encode({
          'fonte_ids': selecionadas.toList(),
          'nome': nomeController.text.trim().isEmpty
              ? 'Modelo combinado'
              : nomeController.text.trim(),
        }),
      );
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map) {
        final message = decoded is Map
            ? (decoded['detail'] ?? decoded['message'])?.toString()
            : null;
        throw Exception(message ?? 'Nao foi possivel conectar as fontes.');
      }
      final data = Map<String, dynamic>.from(decoded);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SelecaoGraficoScreen(data: data)),
      );
      await _carregar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      nomeController.dispose();
      if (mounted) setState(() => _combinando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 800;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 40 : 16,
            vertical: desktop ? 24 : 16,
          ),
          child: Flex(
            direction: desktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: desktop
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: desktop ? FlexFit.tight : FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fontes de Dados',
                      style: TextStyle(
                        fontSize: desktop ? 28 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulte o resultado da limpeza e exporte os dados.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              SizedBox(width: desktop ? 16 : 0, height: desktop ? 0 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: desktop ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  IconButton.outlined(
                    onPressed: _carregar,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Atualizar',
                  ),
                  OutlinedButton.icon(
                    onPressed: _fontes.length >= 2 && !_combinando
                        ? _combinarFontes
                        : null,
                    icon: _combinando
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_tree_rounded),
                    label: const Text('Combinar'),
                  ),
                  FilledButton.icon(
                    onPressed: widget.onConectar,
                    icon: const Icon(Icons.add_link_rounded),
                    label: Text(desktop ? 'Conectar Nova Fonte' : 'Conectar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _conteudo(desktop)),
      ],
    );
  }

  Widget _conteudo(bool desktop) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_fontes.isEmpty) {
      return const Center(child: Text('Nenhuma fonte importada.'));
    }
    return ListView.separated(
      padding: EdgeInsets.all(desktop ? 40 : 16),
      itemCount: _fontes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final fonte = _fontes[index];
        final summary = fonte['summary'] is Map
            ? Map<String, dynamic>.from(fonte['summary'])
            : <String, dynamic>{};
        final linhas = summary['total_rows'] ?? '-';
        final colunas = summary['total_columns'] ?? '-';
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FonteDadosDetalheScreen(
                  fonteId: fonte['id'].toString(),
                  nome: fonte['nome_arquivo']?.toString() ?? 'Fonte',
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.table_view_rounded)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fonte['nome_arquivo']?.toString() ?? 'Fonte',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$linhas linhas  |  $colunas colunas  |  ${fonte['tamanho_kb'] ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (desktop) const Chip(label: Text('Tratado')),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'excluir') _excluir(fonte);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'excluir',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Excluir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FonteDadosDetalheScreen extends StatefulWidget {
  final String fonteId;
  final String nome;

  const FonteDadosDetalheScreen({
    super.key,
    required this.fonteId,
    required this.nome,
  });

  @override
  State<FonteDadosDetalheScreen> createState() =>
      _FonteDadosDetalheScreenState();
}

class _FonteDadosDetalheScreenState extends State<FonteDadosDetalheScreen> {
  Map<String, dynamic>? _fonte;
  String? _erro;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Uri _uri(String path, [Map<String, String>? extras]) {
    final query = <String, String>{...?extras};
    final usuarioId = DashboardManager.usuarioAtualId;
    if (usuarioId != null) query['usuario_id'] = usuarioId;
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<void> _carregar() async {
    try {
      final response = await http.get(
        _uri('/fontes-dados/${widget.fonteId}'),
        headers: DashboardManager.authHeaders,
      );
      if (response.statusCode != 200) {
        throw Exception('Nao foi possivel abrir a fonte.');
      }
      _fonte = Map<String, dynamic>.from(
        json.decode(utf8.decode(response.bodyBytes)),
      );
    } catch (e) {
      _erro = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _exportar(String formato) async {
    setState(() => _exportando = true);
    try {
      final response = await http.get(
        _uri('/fontes-dados/${widget.fonteId}/exportar', {'formato': formato}),
        headers: DashboardManager.authHeaders,
      );
      if (response.statusCode != 200) throw Exception('Falha ao exportar.');
      final ext = formato == 'excel' ? 'xlsx' : formato;
      final mime =
          {
            'csv': 'text/csv',
            'xlsx':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'json': 'application/json',
            'pdf': 'application/pdf',
            'parquet': 'application/octet-stream',
          }[ext] ??
          'application/octet-stream';
      await DownloadService.save(
        bytes: Uint8List.fromList(response.bodyBytes),
        name: '${widget.nome}_tratado',
        extension: ext,
        mimeType: mime,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _usarNoDashboard() {
    final fonte = _fonte;
    if (fonte == null) return;
    final summary = fonte['summary'] is Map
        ? Map<String, dynamic>.from(fonte['summary'])
        : <String, dynamic>{};
    final dados = fonte['dados_limpos'] ?? fonte['dados_brutos'] ?? const [];
    final modelo = fonte['modelo_estrela'] ?? summary['modelo_estrela'];
    final data = <String, dynamic>{
      'status': 'sucesso',
      'fonte': fonte,
      'dados_planilha': {
        'status': 'success',
        'summary': summary,
        'dados_brutos': dados,
        'dados_limpos': dados,
        'etl_logs': fonte['etl_logs'] ?? const [],
        'modelo_estrela': modelo,
      },
    };
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelecaoGraficoScreen(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fonte = _fonte;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nome, overflow: TextOverflow.ellipsis),
        actions: [
          if (_exportando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            onPressed: fonte == null ? null : _usarNoDashboard,
            tooltip: 'Usar no dashboard',
            icon: const Icon(Icons.add_chart_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Exportar',
            icon: const Icon(Icons.download_rounded),
            onSelected: _exportar,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
              PopupMenuItem(value: 'csv', child: Text('CSV')),
              PopupMenuItem(value: 'json', child: Text('JSON')),
              PopupMenuItem(value: 'pdf', child: Text('PDF')),
              PopupMenuItem(value: 'parquet', child: Text('Parquet')),
            ],
          ),
        ],
      ),
      body: fonte == null
          ? Center(
              child: _erro == null
                  ? const CircularProgressIndicator()
                  : Text(_erro!),
            )
          : _buildDetalhe(fonte),
    );
  }

  Widget _buildDetalhe(Map<String, dynamic> fonte) {
    final registrosRaw = fonte['dados_limpos'] ?? fonte['dados_brutos'] ?? [];
    final registros = (registrosRaw as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final colunas = registros.isEmpty
        ? <String>[]
        : registros.first.keys.map((e) => e.toString()).toList();
    final logs = (fonte['etl_logs'] as List?) ?? const [];
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Dados tratados'),
              Tab(text: 'Etapas da limpeza'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                registros.isEmpty
                    ? const Center(child: Text('Nenhum registro disponivel.'))
                    : Column(
                        children: [
                          if (registros.length > 250)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Previa das primeiras 250 de ${registros.length} linhas.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: DataTable(
                                    columns: colunas
                                        .map(
                                          (c) => DataColumn(
                                            label: Text(
                                              c,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    rows: registros
                                        .take(250)
                                        .map(
                                          (linha) => DataRow(
                                            cells: colunas
                                                .map(
                                                  (c) => DataCell(
                                                    ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 220,
                                                          ),
                                                      child: Text(
                                                        '${linha[c] ?? ''}',
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final log = logs[index] is Map
                        ? Map<String, dynamic>.from(logs[index])
                        : {'descricao': logs[index].toString()};
                    return ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981),
                      ),
                      title: Text(log['fase']?.toString() ?? 'Tratamento'),
                      subtitle: Text(
                        log['descricao']?.toString() ??
                            log['mensagem']?.toString() ??
                            'Concluido',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
