import 'dart:math';

import 'package:flutter/material.dart';

class StarSchemaScreen extends StatefulWidget {
  final Map<String, dynamic> summary;

  const StarSchemaScreen({super.key, required this.summary});

  @override
  State<StarSchemaScreen> createState() => _StarSchemaScreenState();
}

class _StarSchemaScreenState extends State<StarSchemaScreen> {
  late final List<String> _dimensoes;
  late final List<String> _metricas;
  late final List<_StarRelation> _relacoes;

  @override
  void initState() {
    super.initState();
    _dimensoes = List<String>.from(widget.summary['dimensoes'] ?? []);
    _metricas = List<String>.from(widget.summary['metricas'] ?? []);
    _relacoes = _dimensoes
        .map(
          (dimensao) => _StarRelation(
            dimensao: dimensao,
            cardinalidade: '1:N',
            chaveDimensao: 'ID_$dimensao',
            chaveFato: 'FK_$dimensao',
            ativa: true,
            origem: 'IA',
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Modelo Estrela'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          TextButton.icon(
            onPressed: _restaurarModeloAutomatico,
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(isDesktop ? 'Restaurar IA' : 'IA'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _dimensoes.isEmpty && _metricas.isEmpty
          ? const Center(
              child: Text(
                'Sem dados suficientes para modelagem.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : Padding(
              padding: EdgeInsets.all(isDesktop ? 24 : 14),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 7, child: _buildDiagramPanel()),
                        const SizedBox(width: 18),
                        SizedBox(width: 390, child: _buildEditorPanel()),
                      ],
                    )
                  : ListView(
                      children: [
                        SizedBox(height: 560, child: _buildDiagramPanel()),
                        const SizedBox(height: 16),
                        _buildEditorPanel(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildDiagramPanel() {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Relacionamentos detectados',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'A modelagem inicial foi sugerida automaticamente pela IA.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _StarSchemaPainter(relacoes: _relacoes),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: _TabelaFato(metricas: _metricas),
                    ),
                    ..._posicionarDimensoes(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _posicionarDimensoes(Size size) {
    final ativas = _relacoes.where((relacao) => relacao.ativa).toList();
    if (ativas.isEmpty) return [];

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.34;
    final widgets = <Widget>[];

    for (int index = 0; index < ativas.length; index++) {
      final relacao = ativas[index];
      final angle = (-pi / 2) + (2 * pi / ativas.length) * index;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      widgets.add(
        Positioned(
          left: (x - 82).clamp(0, max(0, size.width - 164)),
          top: (y - 50).clamp(0, max(0, size.height - 100)),
          child: _TabelaDimensao(
            relacao: relacao,
            onEdit: () => _editarRelacao(relacao),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildEditorPanel() {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          final relationList = ListView.separated(
            shrinkWrap: !hasBoundedHeight,
            physics: hasBoundedHeight
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: _relacoes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final relacao = _relacoes[index];
              return _RelationCard(
                relacao: relacao,
                onEdit: () => _editarRelacao(relacao),
                onToggle: (value) => setState(() => relacao.ativa = value),
              );
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editor de relacoes',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use esta area quando precisar corrigir manualmente uma relacao inferida pela IA.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 16),
              _ResumoModelo(relacoes: _relacoes),
              const SizedBox(height: 16),
              if (hasBoundedHeight)
                Expanded(child: relationList)
              else
                relationList,
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _adicionarRelacao,
                icon: const Icon(Icons.add_link_outlined),
                label: const Text('Adicionar relacao manual'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _restaurarModeloAutomatico() {
    setState(() {
      _relacoes
        ..clear()
        ..addAll(
          _dimensoes.map(
            (dimensao) => _StarRelation(
              dimensao: dimensao,
              cardinalidade: '1:N',
              chaveDimensao: 'ID_$dimensao',
              chaveFato: 'FK_$dimensao',
              ativa: true,
              origem: 'IA',
            ),
          ),
        );
    });
  }

  Future<void> _adicionarRelacao() async {
    final nova = _StarRelation(
      dimensao: _dimensoes.isNotEmpty ? _dimensoes.first : 'Nova_Dimensao',
      cardinalidade: '1:N',
      chaveDimensao: _dimensoes.isNotEmpty ? 'ID_${_dimensoes.first}' : 'ID',
      chaveFato: _dimensoes.isNotEmpty ? 'FK_${_dimensoes.first}' : 'FK',
      ativa: true,
      origem: 'Manual',
    );

    final salva = await _showRelacaoDialog(nova);
    if (salva != null) {
      setState(() => _relacoes.add(salva));
    }
  }

  Future<void> _editarRelacao(_StarRelation relacao) async {
    final copia = relacao.copy();
    final salva = await _showRelacaoDialog(copia);
    if (salva == null) return;

    setState(() {
      relacao
        ..dimensao = salva.dimensao
        ..cardinalidade = salva.cardinalidade
        ..chaveDimensao = salva.chaveDimensao
        ..chaveFato = salva.chaveFato
        ..observacao = salva.observacao
        ..ativa = salva.ativa
        ..origem = salva.origem == 'IA' ? 'Ajustada' : salva.origem;
    });
  }

  Future<_StarRelation?> _showRelacaoDialog(_StarRelation relacao) {
    final dimensaoController = TextEditingController(text: relacao.dimensao);
    final chaveDimController = TextEditingController(
      text: relacao.chaveDimensao,
    );
    final chaveFatoController = TextEditingController(text: relacao.chaveFato);
    final observacaoController = TextEditingController(
      text: relacao.observacao,
    );
    var cardinalidade = relacao.cardinalidade;
    var ativa = relacao.ativa;

    return showDialog<_StarRelation>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar relacao'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: dimensaoController,
                        decoration: const InputDecoration(
                          labelText: 'Tabela dimensao',
                          prefixIcon: Icon(Icons.table_chart_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: cardinalidade,
                        decoration: const InputDecoration(
                          labelText: 'Cardinalidade',
                          prefixIcon: Icon(Icons.call_split_outlined),
                        ),
                        items: const ['1:N', 'N:1', '1:1', 'N:N']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => cardinalidade = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: chaveDimController,
                        decoration: const InputDecoration(
                          labelText: 'Chave da dimensao',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: chaveFatoController,
                        decoration: const InputDecoration(
                          labelText: 'Chave na fato',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: observacaoController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Observacao',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Relacao ativa no modelo'),
                        value: ativa,
                        onChanged: (value) =>
                            setDialogState(() => ativa = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      relacao
                        ..dimensao = dimensaoController.text.trim().isEmpty
                            ? relacao.dimensao
                            : dimensaoController.text.trim()
                        ..cardinalidade = cardinalidade
                        ..chaveDimensao = chaveDimController.text.trim()
                        ..chaveFato = chaveFatoController.text.trim()
                        ..observacao = observacaoController.text.trim()
                        ..ativa = ativa
                        ..origem = relacao.origem == 'IA'
                            ? 'Ajustada'
                            : relacao.origem,
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      dimensaoController.dispose();
      chaveDimController.dispose();
      chaveFatoController.dispose();
      observacaoController.dispose();
    });
  }
}

class _StarRelation {
  String dimensao;
  String cardinalidade;
  String chaveDimensao;
  String chaveFato;
  String observacao;
  bool ativa;
  String origem;

  _StarRelation({
    required this.dimensao,
    required this.cardinalidade,
    required this.chaveDimensao,
    required this.chaveFato,
    this.observacao = '',
    required this.ativa,
    required this.origem,
  });

  _StarRelation copy() {
    return _StarRelation(
      dimensao: dimensao,
      cardinalidade: cardinalidade,
      chaveDimensao: chaveDimensao,
      chaveFato: chaveFato,
      observacao: observacao,
      ativa: ativa,
      origem: origem,
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ResumoModelo extends StatelessWidget {
  final List<_StarRelation> relacoes;

  const _ResumoModelo({required this.relacoes});

  @override
  Widget build(BuildContext context) {
    final ativas = relacoes.where((relacao) => relacao.ativa).length;
    final ajustadas = relacoes
        .where((relacao) => relacao.origem != 'IA')
        .length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniMetric(label: 'Ativas', value: ativas.toString()),
        _MiniMetric(label: 'Total', value: relacoes.length.toString()),
        _MiniMetric(label: 'Ajustadas', value: ajustadas.toString()),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationCard extends StatelessWidget {
  final _StarRelation relacao;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  const _RelationCard({
    required this.relacao,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = relacao.ativa
        ? const Color(0xFF2563EB)
        : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: relacao.ativa
              ? const Color(0xFFF8FAFC)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    relacao.dimensao,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(value: relacao.ativa, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(text: relacao.cardinalidade, color: color),
                _Tag(text: relacao.origem, color: const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${relacao.chaveDimensao} -> ${relacao.chaveFato}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            if (relacao.observacao.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                relacao.observacao,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TabelaFato extends StatelessWidget {
  final List<String> metricas;

  const _TabelaFato({required this.metricas});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Text(
              'FATO_ANALISE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLine(
                  icon: Icons.key_rounded,
                  text: 'ID_Fato (PK)',
                  color: Color(0xFFF59E0B),
                ),
                const Divider(height: 14),
                ...metricas
                    .take(6)
                    .map(
                      (metrica) => _FieldLine(
                        icon: Icons.functions_rounded,
                        text: metrica,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                if (metricas.length > 6)
                  Text(
                    '+${metricas.length - 6} metricas',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
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

class _TabelaDimensao extends StatelessWidget {
  final _StarRelation relacao;
  final VoidCallback onEdit;

  const _TabelaDimensao({required this.relacao, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 164,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF14B8A6), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF14B8A6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(
                'DIM_${relacao.dimensao}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLine(
                    icon: Icons.key_rounded,
                    text: '${relacao.chaveDimensao} (PK)',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 6),
                  _Tag(
                    text: relacao.cardinalidade,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FieldLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StarSchemaPainter extends CustomPainter {
  final List<_StarRelation> relacoes;

  _StarSchemaPainter({required this.relacoes});

  @override
  void paint(Canvas canvas, Size size) {
    final ativas = relacoes.where((relacao) => relacao.ativa).toList();
    if (ativas.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.34;

    for (int index = 0; index < ativas.length; index++) {
      final relacao = ativas[index];
      final angle = (-pi / 2) + (2 * pi / ativas.length) * index;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final paint = Paint()
        ..color = _colorFor(relacao.cardinalidade).withValues(alpha: 0.58)
        ..strokeWidth = relacao.cardinalidade == 'N:N' ? 3 : 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(center, end, paint);
      _drawCardinality(canvas, center, end, relacao.cardinalidade);
    }
  }

  Color _colorFor(String cardinalidade) {
    switch (cardinalidade) {
      case 'N:N':
        return const Color(0xFFEF4444);
      case '1:1':
        return const Color(0xFF10B981);
      case 'N:1':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  void _drawCardinality(
    Canvas canvas,
    Offset center,
    Offset end,
    String cardinalidade,
  ) {
    final midpoint = Offset(
      center.dx + (end.dx - center.dx) * 0.58,
      center.dy + (end.dy - center.dy) * 0.58,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: cardinalidade,
        style: TextStyle(
          color: _colorFor(cardinalidade),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromLTWH(
      midpoint.dx - painter.width / 2 - 6,
      midpoint.dy - painter.height / 2 - 3,
      painter.width + 12,
      painter.height + 6,
    );
    final bg = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      bg,
    );
    painter.paint(
      canvas,
      Offset(midpoint.dx - painter.width / 2, midpoint.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _StarSchemaPainter oldDelegate) =>
      oldDelegate.relacoes != relacoes;
}
