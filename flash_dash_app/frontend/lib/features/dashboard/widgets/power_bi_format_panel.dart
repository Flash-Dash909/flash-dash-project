import 'package:flutter/material.dart';

import '../../../core/visual_config.dart';

class PowerBiFormatPanel extends StatefulWidget {
  final String visualType;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const PowerBiFormatPanel({
    super.key,
    required this.visualType,
    required this.value,
    required this.onChanged,
  });

  @override
  State<PowerBiFormatPanel> createState() => _PowerBiFormatPanelState();
}

class _PowerBiFormatPanelState extends State<PowerBiFormatPanel> {
  static const _colors = <Color>[
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
    Color(0xFF64748B),
    Color(0xFF0F172A),
    Color(0xFFF8FAFC),
    Colors.white,
  ];

  VisualCapabilities get caps => VisualCapabilities(widget.visualType);

  @override
  void initState() {
    super.initState();
    _ensureDefaults();
  }

  @override
  void didUpdateWidget(covariant PowerBiFormatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualType != widget.visualType ||
        !identical(oldWidget.value, widget.value)) {
      _ensureDefaults();
    }
  }

  void _ensureDefaults() {
    final defaults = PowerBiVisualConfig.defaultsFor(widget.visualType);
    for (final entry in defaults.entries) {
      widget.value.putIfAbsent(entry.key, () => entry.value);
    }
  }

  T _get<T>(String key, T fallback) {
    final value = widget.value[key];
    return value is T ? value : fallback;
  }

  double _number(String key, double fallback) {
    final value = widget.value[key];
    return value is num ? value.toDouble() : fallback;
  }

  void _set(String key, dynamic value) {
    setState(() => widget.value[key] = value);
    widget.onChanged(Map<String, dynamic>.from(widget.value));
  }

  Color _color(String key, Color fallback) {
    final value = widget.value[key];
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is String) {
      final parsed = value.startsWith('#')
          ? int.tryParse(value.replaceFirst('#', '0xFF'))
          : int.tryParse(value);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _section('Dados', Icons.dataset_outlined, [
          _dropdown('Unidades de exibicao', 'displayUnits', const {
            'auto': 'Automatico',
            'none': 'Sem abreviar',
            'thousand': 'Mil',
            'million': 'Milhao',
            'billion': 'Bilhao',
          }),
          _slider('Casas decimais', 'decimalPlaces', 0, 6, divisions: 6),
          _text('Prefixo numerico', 'numberPrefix'),
          _text('Sufixo numerico', 'numberSuffix'),
          _dropdown('Ordenacao', 'categorySort', const {
            'valueDesc': 'Valor decrescente',
            'valueAsc': 'Valor crescente',
            'categoryAsc': 'Categoria A-Z',
            'categoryDesc': 'Categoria Z-A',
          }),
          if (caps.supportsSmallMultiples) ...[
            _switch('Pequenos multiplos', 'smallMultiplesEnabled'),
            if (_get('smallMultiplesEnabled', false))
              _slider(
                'Colunas da grade',
                'smallMultiplesColumns',
                1,
                6,
                divisions: 5,
              ),
            if (_get('smallMultiplesEnabled', false))
              _switch('Compartilhar escala', 'smallMultiplesSharedScale'),
          ],
        ]),
        _section('Aparencia', Icons.palette_outlined, [
          _dropdown('Paleta', 'paletteMode', const {
            'categorical': 'Categorica',
            'monochrome': 'Monocromatica',
            'complementary': 'Complementar',
            'analogous': 'Analoga',
            'gradient': 'Gradiente',
          }),
          _colorPicker('Fundo da area de plotagem', 'plotBackgroundColor'),
          _slider(
            'Opacidade do fundo',
            'plotBackgroundOpacity',
            0,
            1,
            divisions: 20,
          ),
          _switch('Contorno da plotagem', 'plotBorderVisible'),
          if (_get('plotBorderVisible', false)) ...[
            _colorPicker('Cor do contorno', 'plotBorderColor'),
            _slider(
              'Espessura do contorno',
              'plotBorderWidth',
              0,
              8,
              divisions: 16,
            ),
          ],
          _switch('Evitar colisao de textos', 'responsiveLabels'),
          ..._appearanceSpecificControls(),
        ]),
        if (caps.usesLegend)
          _section('Legenda', Icons.view_list_outlined, [
            _text('Titulo da legenda', 'legendTitle'),
            _slider('Tamanho da fonte', 'legendFontSize', 8, 24, divisions: 16),
            _colorPicker('Cor do texto', 'legendColor'),
            _slider(
              'Tamanho do marcador',
              'legendMarkerSize',
              5,
              20,
              divisions: 15,
            ),
            _switch('Mostrar valores na legenda', 'legendShowValues'),
          ]),
        _section('Rotulos', Icons.text_fields_outlined, [
          _dropdown('Conteudo', 'labelContent', const {
            'value': 'Valor',
            'category': 'Categoria',
            'percent': 'Percentual',
            'categoryValue': 'Categoria + valor',
            'categoryPercent': 'Categoria + percentual',
            'valuePercent': 'Valor + percentual',
          }),
          _dropdown('Posicao', 'labelPosition', const {
            'auto': 'Automatico',
            'inside': 'Dentro',
            'outside': 'Fora',
            'center': 'Centro',
            'start': 'Inicio',
            'end': 'Fim',
          }),
          _slider('Tamanho da fonte', 'labelFontSize', 8, 28, divisions: 20),
          _colorPicker('Cor do rotulo', 'labelColor'),
          _switch('Fundo do rotulo', 'labelBackground'),
          if (_get('labelBackground', false)) ...[
            _colorPicker('Cor do fundo', 'labelBackgroundColor'),
            _slider(
              'Opacidade do fundo',
              'labelBackgroundOpacity',
              0,
              1,
              divisions: 20,
            ),
          ],
          if (caps.isBar || caps.isColumn || caps.isArea)
            _switch('Rotulo do total', 'showTotalLabels'),
        ]),
        if (caps.usesAxes)
          _section('Eixos', Icons.straighten_outlined, [
            _text('Titulo do eixo X', 'xAxisTitle'),
            _text('Titulo do eixo Y', 'yAxisTitle'),
            _slider('Fonte do eixo X', 'xAxisFontSize', 7, 22, divisions: 15),
            _slider(
              'Rotacao dos rotulos X',
              'xAxisRotation',
              -90,
              90,
              divisions: 12,
            ),
            _colorPicker('Cor do eixo X', 'xAxisColor'),
            _slider('Fonte do eixo Y', 'yAxisFontSize', 7, 22, divisions: 15),
            _colorPicker('Cor do eixo Y', 'yAxisColor'),
            _optionalNumber('Minimo do eixo Y', 'yAxisMin'),
            _optionalNumber('Maximo do eixo Y', 'yAxisMax'),
            _dropdown('Escala', 'axisScale', const {
              'linear': 'Linear',
              'log': 'Logaritmica',
            }),
            _switch('Linhas de grade', 'gridVisible'),
            if (_get('gridVisible', true)) ...[
              _colorPicker('Cor da grade', 'gridColor'),
              _slider('Espessura da grade', 'gridWidth', 0.5, 4, divisions: 14),
              _slider('Quantidade de linhas', 'gridCount', 2, 10, divisions: 8),
            ],
            if (caps.isCombo) _switch('Eixo Y secundario', 'secondaryAxis'),
            _switch('Zoom de eixo', 'zoomEnabled'),
          ]),
        _section('Interacoes', Icons.touch_app_outlined, [
          _switch('Tooltip', 'tooltipEnabled'),
          if (_get('tooltipEnabled', true)) ...[
            _switch('Categoria no tooltip', 'tooltipCategory'),
            _switch('Valor no tooltip', 'tooltipValue'),
            if (caps.supportsSecondMetric)
              _switch('Segunda metrica no tooltip', 'tooltipSecondaryValue'),
            _colorPicker('Fundo do tooltip', 'tooltipBackgroundColor'),
            _colorPicker('Texto do tooltip', 'tooltipTextColor'),
          ],
          _switch('Filtrar outros visuais', 'interactionFilter'),
          _switch('Realcar selecao', 'interactionHighlight'),
          _switch('Multisselecao', 'interactionMultiSelect'),
          _switch('Drill-through', 'interactionDrillthrough'),
          _switch('Modo de foco', 'interactionFocusMode'),
          _switch('Ordenacao pelo cabecalho', 'interactionSort'),
        ]),
        _section('Animacoes', Icons.animation_outlined, [
          _switch('Animar visual', 'animationEnabled'),
          if (_get('animationEnabled', true)) ...[
            _dropdown('Entrada', 'animationIn', const {
              'fade': 'Fade',
              'zoom': 'Zoom',
              'slide': 'Slide',
              'instant': 'Instantanea',
            }),
            _slider(
              'Duracao (ms)',
              'animationDuration',
              100,
              1400,
              divisions: 13,
            ),
            _dropdown('Curva', 'animationCurve', const {
              'easeOut': 'Suave',
              'linear': 'Linear',
              'bounce': 'Bounce',
            }),
          ],
        ]),
        _section('Avancado', Icons.auto_graph_outlined, [
          _dropdown('Formatacao condicional', 'conditionalMode', const {
            'none': 'Desativada',
            'gradient': 'Gradiente',
            'rules': 'Regras',
          }),
          if (_get('conditionalMode', 'none') != 'none') ...[
            _numberField('Valor minimo', 'conditionalMin'),
            _colorPicker('Cor minima', 'conditionalMinColor'),
            _colorPicker('Cor intermediaria', 'conditionalMidColor'),
            _numberField('Valor maximo', 'conditionalMax'),
            _colorPicker('Cor maxima', 'conditionalMaxColor'),
          ],
          if (caps.supportsAnalytics) ...[
            _switch('Linha de media', 'analyticsAverage'),
            _switch('Linha de minimo', 'analyticsMin'),
            _switch('Linha de maximo', 'analyticsMax'),
            _switch('Linha de mediana', 'analyticsMedian'),
            _switch('Linha de meta', 'analyticsTarget'),
            if (_get('analyticsTarget', false))
              _numberField('Valor da meta', 'analyticsTargetValue'),
            _colorPicker('Cor das analises', 'analyticsColor'),
            if (caps.isLine || caps.isArea || caps.isScatter)
              _switch('Linha de tendencia', 'trendLine'),
            if (caps.isLine || caps.isArea)
              _switch('Previsao', 'forecastEnabled'),
            if (caps.isLine)
              _switch('Deteccao de anomalias', 'anomalyDetection'),
          ],
          ..._advancedSpecificControls(),
        ]),
      ],
    );
  }

  List<Widget> _appearanceSpecificControls() {
    if (caps.isBar || caps.isColumn || caps.isRibbon) {
      return [
        _slider(
          'Transparencia das barras',
          'barOpacity',
          0.1,
          1,
          divisions: 18,
        ),
        _slider('Espacamento', 'barGap', 0, 0.45, divisions: 18),
        _slider('Largura relativa', 'barWidthFactor', 0.2, 1, divisions: 16),
        _slider('Raio dos cantos', 'barRadius', 0, 20, divisions: 20),
        _slider('Borda das barras', 'barBorderWidth', 0, 8, divisions: 16),
        if (_number('barBorderWidth', 0) > 0)
          _colorPicker('Cor da borda', 'barBorderColor'),
        if (caps.isRibbon)
          _slider('Espaco entre fitas', 'ribbonSpacing', 0, 0.4, divisions: 16),
      ];
    }
    if (caps.isLine || caps.isArea || caps.isCombo || caps.isRadar) {
      return [
        _slider('Espessura da linha', 'lineWidth', 1, 10, divisions: 18),
        _dropdown('Estilo da linha', 'lineStyle', const {
          'solid': 'Solida',
          'dashed': 'Tracejada',
          'dotted': 'Pontilhada',
        }),
        _dropdown('Interpolacao', 'lineInterpolation', const {
          'linear': 'Reta',
          'smooth': 'Suave',
          'step': 'Degraus',
        }),
        _switch('Marcadores', 'markerVisible'),
        if (_get('markerVisible', true)) ...[
          _slider('Tamanho dos marcadores', 'markerSize', 2, 14, divisions: 12),
          _dropdown('Forma do marcador', 'markerShape', const {
            'circle': 'Circulo',
            'square': 'Quadrado',
            'diamond': 'Diamante',
            'triangle': 'Triangulo',
          }),
        ],
        if (caps.isArea || caps.isCombo)
          _slider('Opacidade da area', 'areaOpacity', 0, 1, divisions: 20),
      ];
    }
    if (caps.isPie || caps.isDonut) {
      return [
        _slider(
          'Transparencia das fatias',
          'sliceOpacity',
          0.1,
          1,
          divisions: 18,
        ),
        _slider('Contorno das fatias', 'sliceBorderWidth', 0, 8, divisions: 16),
        _colorPicker('Cor do contorno', 'sliceBorderColor'),
        _slider('Angulo inicial', 'pieStartAngle', -180, 180, divisions: 24),
        _slider('Fatia destacada', 'explodeSlice', -1, 20, divisions: 21),
        if (_number('explodeSlice', -1) >= 0)
          _slider(
            'Distancia da fatia',
            'explodeDistance',
            0,
            40,
            divisions: 20,
          ),
        if (caps.isDonut) ...[
          _slider('Raio interno', 'raioFuro', 0, 0.9, divisions: 18),
          _dropdown('Conteudo central', 'donutCenterMode', const {
            'none': 'Vazio',
            'total': 'Total',
            'text': 'Texto',
          }),
          if (_get('donutCenterMode', 'total') == 'text')
            _text('Texto central', 'donutCenterText'),
        ],
      ];
    }
    if (caps.isTreemap) {
      return [
        _slider('Espaco entre blocos', 'treemapSpacing', 0, 16, divisions: 16),
        _slider('Padding dos blocos', 'treemapPadding', 0, 20, divisions: 20),
        _switch('Exibir hierarquia', 'treemapHierarchy'),
        _switch('Agrupar valores pequenos', 'treemapGroupSmall'),
      ];
    }
    if (caps.isGauge) {
      return [
        _numberField('Valor minimo', 'gaugeMin'),
        _numberField('Valor maximo', 'gaugeMax'),
        _numberField('Meta', 'gaugeMeta'),
        _slider('Espessura do arco', 'gaugeThickness', 6, 40, divisions: 17),
        _switch('Mostrar escala', 'gaugeShowScale'),
        _switch('Mostrar marcacoes', 'gaugeShowTicks'),
        _switch('Faixas de desempenho', 'gaugeMostrarFaixas'),
        _colorPicker('Faixa ruim', 'gaugeBadColor'),
        _colorPicker('Faixa media', 'gaugeMidColor'),
        _colorPicker('Faixa boa', 'gaugeGoodColor'),
      ];
    }
    if (caps.isKpi || caps.isProgress || caps.isBullet) {
      return [
        _slider('Tamanho do valor', 'kpiFontSize', 18, 96, divisions: 26),
        _switch('Mostrar meta', 'kpiShowMeta'),
        if (_get('kpiShowMeta', false)) _numberField('Meta', 'kpiMeta'),
        _switch('Mostrar tendencia', 'kpiShowTrend'),
        if (_get('kpiShowTrend', false))
          _numberField('Valor anterior', 'kpiPrevious'),
        _switch('Mostrar percentual', 'kpiShowPercent'),
        _dropdown('Direcao positiva', 'kpiDirection', const {
          'higherIsBetter': 'Maior e melhor',
          'lowerIsBetter': 'Menor e melhor',
        }),
      ];
    }
    if (caps.isTable || caps.isMatrix) {
      return [
        _colorPicker('Fundo do cabecalho', 'headerColor'),
        _colorPicker('Texto do cabecalho', 'headerTextColor'),
        _slider('Altura do cabecalho', 'headerHeight', 24, 72, divisions: 24),
        _slider('Altura das linhas', 'rowHeight', 22, 72, divisions: 25),
        _switch('Linhas alternadas', 'zebraRows'),
        _colorPicker('Linha impar', 'rowColorA'),
        _colorPicker('Linha par', 'rowColorB'),
        _colorPicker('Cor da grade', 'gridColor'),
        _slider('Espessura da grade', 'gridWidth', 0, 4, divisions: 16),
        _switch('Totais gerais', 'showTotals'),
        if (caps.isMatrix) _switch('Subtotais', 'showSubtotals'),
        if (caps.isMatrix) _switch('Expandir hierarquia', 'matrixExpanded'),
        _switch('Congelar cabecalho', 'freezeHeaders'),
        _switch('Barras de dados', 'conditionalDataBars'),
        _switch('Icones condicionais', 'conditionalIcons'),
      ];
    }
    if (caps.isSlicer) {
      return [
        _dropdown('Estilo', 'slicerStyle', const {
          'dropdown': 'Dropdown',
          'lista': 'Lista',
          'botoes': 'Botoes',
          'tags': 'Tags',
          'between': 'Intervalo',
          'before': 'Antes de',
          'after': 'Depois de',
          'relativeDate': 'Data relativa',
          'relativeTime': 'Hora relativa',
          'datePicker': 'Seletor de data',
          'input': 'Entrada livre',
        }),
        _switch('Selecao multipla', 'segmentacaoMultipla'),
        _switch('Selecionar tudo', 'slicerSelectAll'),
        _switch('Campo de busca', 'slicerSearch'),
        _switch('Botao aplicar', 'slicerApplyButton'),
        _text('Placeholder', 'slicerPlaceholder'),
        _colorPicker('Cor do item', 'slicerItemColor'),
        _colorPicker('Cor selecionada', 'slicerSelectedColor'),
        _colorPicker('Cor no hover', 'slicerHoverColor'),
      ];
    }
    if (caps.isMap || caps.isHeatmap) {
      return [
        _dropdown('Estilo do mapa', 'mapStyle', const {
          'light': 'Claro',
          'dark': 'Escuro',
          'road': 'Ruas',
          'satellite': 'Satelite',
        }),
        _switch('Agrupar pontos', 'mapCluster'),
        _switch('Camada de calor', 'mapHeatLayer'),
        _slider('Tamanho das bolhas', 'mapBubbleSize', 4, 36, divisions: 16),
        _slider('Opacidade', 'mapOpacity', 0.1, 1, divisions: 18),
      ];
    }
    return const [];
  }

  List<Widget> _advancedSpecificControls() {
    if (caps.isScatter) {
      return [
        _slider('Tamanho das bolhas', 'bubbleSize', 3, 24, divisions: 21),
        _slider('Opacidade das bolhas', 'bubbleOpacity', 0.1, 1, divisions: 18),
        _switch('Linha de regressao', 'regressionLine'),
        _switch('Quadrantes de media', 'showQuadrants'),
      ];
    }
    if (caps.isWaterfall) {
      return [
        _colorPicker('Aumentos', 'waterfallPositiveColor'),
        _colorPicker('Reducoes', 'waterfallNegativeColor'),
        _colorPicker('Total', 'waterfallTotalColor'),
        _switch('Conectores', 'waterfallShowConnectors'),
        _colorPicker('Cor dos conectores', 'waterfallConnectorColor'),
      ];
    }
    if (caps.isFunnel) {
      return [
        _switch('Taxa de conversao', 'funnelShowConversion'),
        _dropdown('Posicao dos rotulos', 'funnelLabelPosition', const {
          'inside': 'Interno',
          'outside': 'Externo',
        }),
        _switch('Cores em gradiente', 'funnelGradient'),
      ];
    }
    if (caps.isHistogram) {
      return [
        _dropdown('Faixas', 'histogramBinsMode', const {
          'auto': 'Automatico',
          'manual': 'Manual',
        }),
        if (_get('histogramBinsMode', 'auto') == 'manual')
          _slider(
            'Quantidade de faixas',
            'histogramBins',
            3,
            40,
            divisions: 37,
          ),
        _dropdown('Frequencia', 'histogramFrequency', const {
          'absolute': 'Absoluta',
          'relative': 'Relativa',
        }),
      ];
    }
    return const [];
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF2563EB), size: 21),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _switch(String label, String key) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: _get(key, false),
      onChanged: (value) => _set(key, value),
    );
  }

  Widget _dropdown(String label, String key, Map<String, String> options) {
    final current = widget.value[key]?.toString();
    final safeValue = options.containsKey(current)
        ? current
        : options.keys.first;
    return DropdownButtonFormField<String>(
      key: ValueKey('$key-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) _set(key, value);
      },
    );
  }

  Widget _slider(
    String label,
    String key,
    double min,
    double max, {
    int? divisions,
  }) {
    final current = _number(key, min).clamp(min, max);
    final integer = divisions != null && (max - min) == divisions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${integer ? current.round() : current.toStringAsFixed(max <= 1 ? 2 : 1)}',
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (value) => _set(key, integer ? value.round() : value),
        ),
      ],
    );
  }

  Widget _text(String label, String key) {
    final value = widget.value[key]?.toString() ?? '';
    return TextFormField(
      key: ValueKey('$key-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (value) => _set(key, value),
    );
  }

  Widget _numberField(String label, String key) {
    final value = _number(key, 0);
    return TextFormField(
      key: ValueKey('$key-$value'),
      initialValue: value.toString(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.replaceAll(',', '.'));
        if (parsed != null) _set(key, parsed);
      },
    );
  }

  Widget _optionalNumber(String label, String key) {
    final value = widget.value[key];
    return TextFormField(
      key: ValueKey('$key-$value'),
      initialValue: value is num ? value.toString() : '',
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Automatico',
        isDense: true,
      ),
      onChanged: (raw) {
        if (raw.trim().isEmpty) {
          _set(key, null);
          return;
        }
        final parsed = double.tryParse(raw.replaceAll(',', '.'));
        if (parsed != null) _set(key, parsed);
      },
    );
  }

  Widget _colorPicker(String label, String key) {
    final current = _color(key, _colors.first);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors.map((color) {
            final selected = current.toARGB32() == color.toARGB32();
            return Tooltip(
              message:
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _set(key, color.toARGB32().toString()),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      width: selected ? 3 : 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
