import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/api_config.dart';
import '../../fontes/screens/fontes_dados_screen.dart';
import '../../processamento/screens/star_schema_screen.dart';
import '../../upload/screens/upload_screen.dart';
import '../dashboard_manager.dart';

class DashboardDataScreen extends StatefulWidget {
  const DashboardDataScreen({super.key});

  @override
  State<DashboardDataScreen> createState() => _DashboardDataScreenState();
}

class _DashboardDataScreenState extends State<DashboardDataScreen> {
  bool _combinando = false;

  @override
  void initState() {
    super.initState();
    final atual = DashboardManager.dadosFonteAtual;
    if (atual != null) {
      DashboardManager.registrarFonteDashboard(atual);
    }
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, dynamic> get _dataAtual =>
      DashboardManager.dadosFonteAtual ?? <String, dynamic>{};

  Map<String, dynamic> _summary(Map<String, dynamic> data) {
    final raw = data['summary'] ?? data['dados_planilha']?['summary'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _registros(Map<String, dynamic> data) {
    final raw =
        data['dados_limpos'] ??
        data['dados_brutos'] ??
        data['dados_planilha']?['dados_limpos'] ??
        data['dados_planilha']?['dados_brutos'] ??
        const [];
    return raw is List
        ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
  }

  List<String> _idsDeOrigem(Map<String, dynamic> data) {
    final summary = _summary(data);
    final raw = summary['fontes_origem'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .where((item) => item != null && item.toString().trim().isNotEmpty)
          .map((item) => item.toString())
          .toSet()
          .toList();
    }
    final id = DashboardManager.fonteIdDe(data);
    return id == null ? <String>[] : <String>[id];
  }

  Future<void> _adicionarFonte() async {
    final dataAnterior = DashboardManager.dadosFonteAtual;
    final novaFonte = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const UploadScreen(retornarFonte: true),
      ),
    );
    if (!mounted || novaFonte == null) return;

    DashboardManager.registrarFonteDashboard(
      novaFonte,
      tornarAtiva: dataAnterior == null,
    );
    if (dataAnterior == null) {
      setState(() {});
      return;
    }

    final novaId = DashboardManager.fonteIdDe(novaFonte);
    final ids = <String>{
      for (final fonte in DashboardManager.fontesDashboard)
        ..._idsDeOrigem(fonte),
      ?novaId,
    }.toList();
    if (ids.length < 2) {
      setState(() {});
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
        body: json.encode({'fonte_ids': ids, 'nome': 'Modelo do dashboard'}),
      );
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map) {
        final message = decoded is Map
            ? (decoded['detail'] ?? decoded['message'])?.toString()
            : null;
        throw Exception(
          message ?? 'Nao foi possivel relacionar automaticamente as fontes.',
        );
      }

      final combinado = Map<String, dynamic>.from(decoded);
      DashboardManager.registrarFonteDashboard(combinado);
      final combinadoId = DashboardManager.fonteIdDe(combinado);
      final colunasCombinadas = <String>{
        if (_summary(combinado)['cleaned_columns'] is List)
          ...(_summary(combinado)['cleaned_columns'] as List).map(
            (item) => item.toString(),
          ),
      };
      if (combinadoId != null) {
        for (final grafico in DashboardManager.graficosAtivos) {
          final fonteDoGrafico = grafico.configExtra['fonteId']?.toString();
          final camposNecessarios = <String>{
            grafico.dimensao,
            grafico.metrica,
            if (grafico.configExtra['metricasAdicionais'] is List)
              ...(grafico.configExtra['metricasAdicionais'] as List).map(
                (item) => item.toString(),
              ),
          };
          if ((fonteDoGrafico == null || ids.contains(fonteDoGrafico)) &&
              colunasCombinadas.containsAll(camposNecessarios)) {
            grafico.configExtra['fonteId'] = combinadoId;
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fonte adicionada e relacionada automaticamente ao modelo.',
          ),
        ),
      );
    } catch (error) {
      DashboardManager.registrarFonteDashboard(dataAnterior);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A fonte foi adicionada ao dashboard, mas ficou independente. '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _combinando = false);
    }
  }

  Future<void> _abrirModelo() async {
    final data = _dataAtual;
    final summary = _summary(data);
    final fonteId = DashboardManager.fonteIdDe(data);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StarSchemaScreen(summary: summary, fonteId: fonteId),
      ),
    );
    if (mounted) setState(() {});
  }

  void _selecionarFonte(String? fonteId) {
    if (fonteId == null) return;
    setState(() => DashboardManager.ativarFonteDashboard(fonteId));
  }

  @override
  Widget build(BuildContext context) {
    final fontes = DashboardManager.fontesDashboard;
    final data = _dataAtual;
    final fonteId = DashboardManager.fonteIdDe(data);
    final summary = _summary(data);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 800;
    final sourceSelector = DropdownButtonFormField<String>(
      key: ValueKey(fonteId),
      initialValue:
          fontes.any((item) => DashboardManager.fonteIdDe(item) == fonteId)
          ? fonteId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tabela ou modelo ativo',
        prefixIcon: Icon(Icons.table_view_rounded),
      ),
      items: fontes
          .map(
            (item) => DropdownMenuItem(
              value: DashboardManager.fonteIdDe(item),
              child: Text(
                DashboardManager.nomeFonteDe(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _selecionarFonte,
    );
    final sourceActions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          icon: Icons.table_rows_rounded,
          label: '${summary['total_rows'] ?? 0} linhas',
        ),
        _InfoChip(
          icon: Icons.view_column_rounded,
          label: '${summary['total_columns'] ?? 0} colunas',
        ),
        FilledButton.icon(
          onPressed: _combinando ? null : _adicionarFonte,
          icon: _combinando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_link_rounded),
          label: const Text('Adicionar fonte'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados do dashboard'),
        actions: [
          IconButton(
            onPressed: data.isEmpty ? null : _abrirModelo,
            tooltip: 'Editar modelo estrela',
            icon: const Icon(Icons.account_tree_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: data.isEmpty
          ? _EmptyData(onAdd: _adicionarFonte)
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 32 : 16,
                      18,
                      desktop ? 32 : 16,
                      14,
                    ),
                    child: desktop
                        ? Row(
                            children: [
                              Expanded(child: sourceSelector),
                              const SizedBox(width: 16),
                              sourceActions,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              sourceSelector,
                              const SizedBox(height: 12),
                              sourceActions,
                            ],
                          ),
                  ),
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(
                        icon: Icon(Icons.table_chart_outlined),
                        text: 'Dados tratados',
                      ),
                      Tab(
                        icon: Icon(Icons.dataset_linked_outlined),
                        text: 'Fontes vinculadas',
                      ),
                      Tab(
                        icon: Icon(Icons.account_tree_outlined),
                        text: 'Modelo estrela',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TabelaTratada(registros: _registros(data)),
                        _FontesVinculadas(
                          fontes: fontes,
                          ativaId: fonteId,
                          onSelect: _selecionarFonte,
                        ),
                        _ModeloEstrela(summary: summary, onEdit: _abrirModelo),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TabelaTratada extends StatelessWidget {
  final List<Map<String, dynamic>> registros;

  const _TabelaTratada({required this.registros});

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return const Center(child: Text('Nenhum registro tratado disponivel.'));
    }
    final colunas = <String>{
      for (final linha in registros.take(100))
        ...linha.keys.map((item) => item.toString()),
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            registros.length > 250
                ? 'Previa das primeiras 250 de ${registros.length} linhas.'
                : '${registros.length} linhas tratadas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                  columns: colunas
                      .map(
                        (coluna) => DataColumn(
                          label: Text(
                            coluna,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                                (coluna) => DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 70,
                                      maxWidth: 220,
                                    ),
                                    child: Text(
                                      '${linha[coluna] ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _FontesVinculadas extends StatelessWidget {
  final List<Map<String, dynamic>> fontes;
  final String? ativaId;
  final ValueChanged<String?> onSelect;

  const _FontesVinculadas({
    required this.fontes,
    required this.ativaId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: fontes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = fontes[index];
        final id = DashboardManager.fonteIdDe(data);
        final fonte = data['fonte'];
        final summaryRaw = data['dados_planilha']?['summary'];
        final summary = summaryRaw is Map ? summaryRaw : const {};
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                id == ativaId ? Icons.check_rounded : Icons.table_view_rounded,
              ),
            ),
            title: Text(
              DashboardManager.nomeFonteDe(data),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${summary['total_rows'] ?? 0} linhas | '
              '${summary['total_columns'] ?? 0} colunas',
            ),
            selected: id == ativaId,
            onTap: () => onSelect(id),
            trailing: fonte is Map && id != null
                ? IconButton(
                    tooltip: 'Abrir detalhes',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FonteDadosDetalheScreen(
                          fonteId: id,
                          nome: DashboardManager.nomeFonteDe(data),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _ModeloEstrela extends StatelessWidget {
  final Map<String, dynamic> summary;
  final VoidCallback onEdit;

  const _ModeloEstrela({required this.summary, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final modeloRaw = summary['modelo_estrela'];
    final modelo = modeloRaw is Map
        ? Map<String, dynamic>.from(modeloRaw)
        : <String, dynamic>{};
    final fatoRaw = modelo['tabela_fato'];
    final fato = fatoRaw is Map ? fatoRaw : const {};
    final dimensoes = modelo['tabelas_dimensao'] is List
        ? modelo['tabelas_dimensao'] as List
        : const [];
    final relacoes = modelo['relacionamentos'] is List
        ? modelo['relacionamentos'] as List
        : const [];

    if (modelo.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_tree_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('Esta fonte ainda nao possui um modelo relacional.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Abrir modelagem'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Estrutura relacional',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar relacoes'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.hub_rounded)),
            title: Text(fato['nome']?.toString() ?? 'Tabela fato'),
            subtitle: Text(
              '${(fato['medidas'] as List?)?.length ?? 0} medidas',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Tabelas de dimensao',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ...dimensoes.map((raw) {
          final item = raw is Map ? raw : const {};
          return Card(
            child: ListTile(
              leading: const Icon(Icons.table_rows_rounded),
              title: Text(item['nome']?.toString() ?? 'Dimensao'),
              subtitle: Text(
                'Chave: ${item['chave_primaria'] ?? 'nao definida'}',
              ),
            ),
          );
        }),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Relacionamentos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (relacoes.isEmpty)
          const Text('Nenhum relacionamento ativo.')
        else
          ...relacoes.map((raw) {
            final item = raw is Map ? raw : const {};
            return Card(
              child: ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(
                  '${item['origem'] ?? 'Origem'}  '
                  '${item['cardinalidade'] ?? ''}  '
                  '${item['destino'] ?? 'Destino'}',
                ),
                subtitle: Text(
                  '${item['chave_origem'] ?? '-'} -> '
                  '${item['chave_destino'] ?? '-'}',
                ),
                trailing: item['ativa'] == false
                    ? const Chip(label: Text('Inativa'))
                    : const Chip(label: Text('Ativa')),
              ),
            );
          }),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(label));
  }
}

class _EmptyData extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyData({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dataset_linked_outlined, size: 58),
            const SizedBox(height: 14),
            Text(
              'Nenhuma fonte vinculada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione uma planilha para consultar os dados tratados e criar graficos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Adicionar fonte'),
            ),
          ],
        ),
      ),
    );
  }
}
