import 'package:flutter/material.dart';

import 'star_schema_screen.dart';

class EtlHistoryScreen extends StatelessWidget {
  final List<dynamic> logsEtl;
  final Map<String, dynamic> summary;

  const EtlHistoryScreen({
    super.key,
    required this.logsEtl,
    required this.summary,
  });

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'upload':
        return Icons.cloud_upload_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'text_format':
        return Icons.spellcheck_rounded;
      case 'schema':
        return Icons.account_tree_outlined;
      case 'check_circle':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.memory_rounded;
    }
  }

  Color _getColor(String iconName, bool isLast) {
    if (isLast) return const Color(0xFF10B981);
    switch (iconName) {
      case 'upload':
        return const Color(0xFF2563EB);
      case 'cleaning':
        return const Color(0xFF14B8A6);
      case 'text_format':
        return const Color(0xFFF59E0B);
      case 'schema':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  int get _totalDimensoes =>
      List<dynamic>.from(summary['dimensoes'] ?? []).length;

  int get _totalMetricas =>
      List<dynamic>.from(summary['metricas'] ?? []).length;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;
    final horizontalPadding = isDesktop ? 40.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Auditoria ETL'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _abrirModeloEstrela(context),
              icon: const Icon(Icons.hub_outlined),
              label: Text(isDesktop ? 'Modelo estrela' : 'Modelo'),
            ),
          ),
        ],
      ),
      body: logsEtl.isEmpty
          ? const Center(
              child: Text(
                'Nenhum historico de ETL encontrado.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      28,
                      horizontalPadding,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linha do tempo dos dados',
                          style: TextStyle(
                            fontSize: isDesktop ? 28 : 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cada etapa mostra como a fonte foi extraida, limpa, padronizada e preparada para analise.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _ResumoCard(
                              icon: Icons.route_outlined,
                              title: 'Etapas',
                              value: logsEtl.length.toString(),
                              color: const Color(0xFF2563EB),
                            ),
                            _ResumoCard(
                              icon: Icons.category_outlined,
                              title: 'Dimensoes',
                              value: _totalDimensoes.toString(),
                              color: const Color(0xFF7C3AED),
                            ),
                            _ResumoCard(
                              icon: Icons.functions_rounded,
                              title: 'Metricas',
                              value: _totalMetricas.toString(),
                              color: const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    120,
                  ),
                  sliver: SliverList.builder(
                    itemCount: logsEtl.length,
                    itemBuilder: (context, index) {
                      final log = Map<String, dynamic>.from(logsEtl[index]);
                      final isLast = index == logsEtl.length - 1;
                      final iconName = log['icone']?.toString() ?? '';
                      final color = _getColor(iconName, isLast);

                      return _TimelineItem(
                        icon: _getIcon(iconName),
                        color: color,
                        isLast: isLast,
                        index: index + 1,
                        title: log['fase']?.toString() ?? 'Processamento',
                        description: log['descricao']?.toString() ?? '',
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            14,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: FilledButton.icon(
            onPressed: () => _abrirModeloEstrela(context),
            icon: const Icon(Icons.hub_outlined),
            label: const Text('Ver e ajustar modelo estrela'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _abrirModeloEstrela(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StarSchemaScreen(summary: summary),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ResumoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLast;
  final int index;
  final String title;
  final String description;

  const _TimelineItem({
    required this.icon,
    required this.color,
    required this.isLast,
    required this.index,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 12, bottom: 18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Etapa $index',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.42,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
