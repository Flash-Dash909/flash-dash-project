class VisualCapabilities {
  final String type;

  const VisualCapabilities(this.type);

  String get normalized => type.toLowerCase();

  bool get isTable => normalized.contains('tabela');
  bool get isMatrix => normalized.contains('matriz');
  bool get isSlicer => normalized.contains('segment');
  bool get isKpi => normalized.contains('kpi') || normalized.contains('cartao');
  bool get isGauge => normalized.contains('gauge');
  bool get isProgress => normalized.contains('progress');
  bool get isBullet => normalized.contains('bullet');
  bool get isPie => normalized.contains('pizza');
  bool get isDonut => normalized.contains('rosca');
  bool get isTreemap => normalized.contains('treemap');
  bool get isFunnel => normalized.contains('funnel');
  bool get isWaterfall => normalized.contains('waterfall');
  bool get isScatter => normalized.contains('dispers');
  bool get isHistogram => normalized.contains('histograma');
  bool get isBoxPlot => normalized.contains('box');
  bool get isHeatmap => normalized.contains('heatmap');
  bool get isRadar => normalized.contains('radar');
  bool get isRibbon => normalized.contains('ribbon');
  bool get isCombo => normalized.contains('combo');
  bool get isLine => normalized.contains('linha') && !isCombo;
  bool get isArea => normalized.contains('area');
  bool get isBar => normalized.contains('barra');
  bool get isColumn => normalized.contains('coluna') && !isCombo;
  bool get isMap => normalized.contains('mapa') || normalized.contains('map');
  bool get isAnomaly => normalized.contains('anomalia');
  bool get isSankey => normalized.contains('sankey');
  bool get isGantt =>
      normalized.contains('gantt') || normalized.contains('timeline');
  bool get isHierarchy =>
      normalized.contains('decomposition') || normalized.contains('sunburst');

  bool get usesAxes =>
      isBar ||
      isColumn ||
      isLine ||
      isArea ||
      isCombo ||
      isScatter ||
      isHistogram ||
      isWaterfall ||
      isBoxPlot ||
      isRibbon ||
      isAnomaly;

  bool get usesLegend =>
      !isTable &&
      !isMatrix &&
      !isSlicer &&
      !isKpi &&
      !isGauge &&
      !isProgress &&
      !isBullet &&
      !isHistogram &&
      !isWaterfall &&
      !isFunnel &&
      !isGantt &&
      !isHierarchy;

  bool get supportsSecondMetric =>
      normalized.contains('empilh') ||
      normalized.contains('100%') ||
      isCombo ||
      isScatter ||
      isRadar ||
      isRibbon;

  bool get supportsAnalytics =>
      isBar ||
      isColumn ||
      isLine ||
      isArea ||
      isCombo ||
      isScatter ||
      isHistogram ||
      isWaterfall ||
      isAnomaly;

  bool get supportsSmallMultiples =>
      isBar || isColumn || isLine || isArea || isCombo;
}

class PowerBiVisualConfig {
  static const List<String> palette = [
    '4280822251',
    '4280900496',
    '4294924067',
    '4294198070',
    '4287323894',
    '4279553178',
    '4293679512',
    '4284769380',
  ];

  static Map<String, dynamic> defaultsFor(String type) {
    final caps = VisualCapabilities(type);
    final defaults = <String, dynamic>{
      'displayUnits': 'auto',
      'decimalPlaces': 1,
      'numberPrefix': '',
      'numberSuffix': '',
      'categorySort': 'valueDesc',
      'responsiveLabels': true,
      'plotBackgroundColor': '4294967295',
      'plotBackgroundOpacity': 0.0,
      'plotBorderVisible': false,
      'plotBorderColor': '4293059304',
      'plotBorderWidth': 1.0,
      'seriesPalette': List<String>.from(palette),
      'paletteMode': 'categorical',
      'legendTitle': '',
      'legendFontSize': 10.0,
      'legendColor': '4283322996',
      'legendMarkerSize': 9.0,
      'legendShowValues': false,
      'labelContent': 'value',
      'labelPosition': 'auto',
      'labelFontSize': 10.0,
      'labelColor': '4281545523',
      'labelBackground': false,
      'labelBackgroundColor': '4294967295',
      'labelBackgroundOpacity': 0.82,
      'showTotalLabels': false,
      'gridVisible': caps.usesAxes,
      'gridColor': '4293059304',
      'gridWidth': 1.0,
      'gridCount': 4,
      'xAxisTitle': '',
      'yAxisTitle': '',
      'xAxisFontSize': 9.0,
      'yAxisFontSize': 9.0,
      'xAxisColor': '4284769380',
      'yAxisColor': '4284769380',
      'xAxisRotation': 0.0,
      'yAxisMin': null,
      'yAxisMax': null,
      'axisScale': 'linear',
      'secondaryAxis': caps.isCombo,
      'zoomEnabled': false,
      'tooltipEnabled': true,
      'tooltipCategory': true,
      'tooltipValue': true,
      'tooltipSecondaryValue': true,
      'tooltipBackgroundColor': '4280032284',
      'tooltipTextColor': '4294967295',
      'interactionFilter': true,
      'interactionHighlight': true,
      'interactionMultiSelect': true,
      'interactionDrillthrough': false,
      'interactionFocusMode': true,
      'interactionSort': true,
      'animationEnabled': true,
      'animationDuration': 420,
      'animationCurve': 'easeOut',
      'animationIn': 'fade',
      'animationUpdate': 'smooth',
      'conditionalMode': 'none',
      'conditionalMin': 0.0,
      'conditionalMax': 100.0,
      'conditionalMinColor': '4294198070',
      'conditionalMidColor': '4294924067',
      'conditionalMaxColor': '4280900496',
      'analyticsAverage': false,
      'analyticsMin': false,
      'analyticsMax': false,
      'analyticsMedian': false,
      'analyticsTarget': false,
      'analyticsTargetValue': 0.0,
      'analyticsColor': '4294198070',
      'trendLine': false,
      'forecastEnabled': false,
      'anomalyDetection': false,
      'smallMultiplesEnabled': false,
      'smallMultiplesColumns': 2,
      'smallMultiplesSharedScale': true,
    };

    if (caps.isBar || caps.isColumn || caps.isRibbon) {
      defaults.addAll({
        'barOpacity': 1.0,
        'barGap': 0.08,
        'barBorderWidth': 0.0,
        'barBorderColor': '4280032284',
        'barRadius': 4.0,
        'barWidthFactor': 0.82,
        'stackOrder': 'natural',
        'showConnectors': caps.isRibbon,
        'ribbonSpacing': 0.12,
      });
    }

    if (caps.isLine || caps.isArea || caps.isCombo || caps.isRadar) {
      defaults.addAll({
        'lineWidth': 3.0,
        'lineStyle': 'solid',
        'lineInterpolation': 'linear',
        'markerVisible': true,
        'markerSize': 4.0,
        'markerShape': 'circle',
        'areaOpacity': caps.isArea ? 0.32 : 0.16,
        'areaBorderVisible': true,
      });
    }

    if (caps.isPie || caps.isDonut) {
      defaults.addAll({
        'sliceOpacity': 1.0,
        'sliceBorderWidth': 1.0,
        'sliceBorderColor': '4294967295',
        'explodeSlice': -1,
        'explodeDistance': 12.0,
        'pieStartAngle': -90.0,
        'raioFuro': caps.isDonut ? 0.58 : 0.0,
        'donutCenterMode': caps.isDonut ? 'total' : 'none',
        'donutCenterText': '',
        'groupSmallSlices': false,
        'smallSliceThreshold': 3.0,
      });
    }

    if (caps.isTreemap) {
      defaults.addAll({
        'treemapSpacing': 2.0,
        'treemapPadding': 4.0,
        'treemapHierarchy': true,
        'treemapGroupSmall': false,
        'treemapSmallThreshold': 2.0,
      });
    }

    if (caps.isGauge) {
      defaults.addAll({
        'gaugeMin': 0.0,
        'gaugeMax': 100.0,
        'gaugeMeta': 80.0,
        'gaugeMostrarFaixas': true,
        'gaugeThickness': 18.0,
        'gaugeShowScale': true,
        'gaugeShowTicks': true,
        'gaugeBadColor': '4294198070',
        'gaugeMidColor': '4294924067',
        'gaugeGoodColor': '4280900496',
      });
    }

    if (caps.isKpi || caps.isProgress || caps.isBullet) {
      defaults.addAll({
        'kpiShowMeta': false,
        'kpiMeta': 0.0,
        'kpiShowTrend': false,
        'kpiPrevious': 0.0,
        'kpiShowPercent': true,
        'kpiDirection': 'higherIsBetter',
        'kpiIcon': 'auto',
        'kpiFontSize': 44.0,
      });
    }

    if (caps.isTable || caps.isMatrix) {
      defaults.addAll({
        'headerColor': '4280109794',
        'headerTextColor': '4294967295',
        'headerFontSize': 12.0,
        'headerHeight': 36.0,
        'rowColorA': '4294967295',
        'rowColorB': '4293980400',
        'rowTextColor': '4281545523',
        'rowHeight': 34.0,
        'gridColor': '4293059304',
        'gridWidth': 1.0,
        'zebraRows': true,
        'showTotals': true,
        'showSubtotals': caps.isMatrix,
        'freezeHeaders': true,
        'conditionalDataBars': false,
        'conditionalIcons': false,
        'conditionalFontColor': false,
        'matrixExpanded': false,
        'matrixCompactLayout': true,
      });
    }

    if (caps.isSlicer) {
      defaults.addAll({
        'slicerStyle': 'botoes',
        'segmentacaoMultipla': true,
        'slicerSelectAll': true,
        'slicerSearch': true,
        'slicerPlaceholder': 'Buscar',
        'slicerApplyButton': false,
        'slicerOrientation': 'horizontal',
        'slicerItemColor': '4293322470',
        'slicerSelectedColor': '4280822251',
        'slicerHoverColor': '4292734719',
      });
    }

    if (caps.isScatter) {
      defaults.addAll({
        'bubbleSize': 7.0,
        'bubbleOpacity': 0.82,
        'regressionLine': false,
        'regressionColor': '4294198070',
        'showQuadrants': false,
      });
    }

    if (caps.isFunnel) {
      defaults.addAll({
        'funnelShowConversion': true,
        'funnelLabelPosition': 'inside',
        'funnelGradient': false,
      });
    }

    if (caps.isWaterfall) {
      defaults.addAll({
        'waterfallPositiveColor': '4280900496',
        'waterfallNegativeColor': '4294198070',
        'waterfallTotalColor': '4280822251',
        'waterfallConnectorColor': '4288585374',
        'waterfallConnectorWidth': 1.0,
        'waterfallShowConnectors': true,
      });
    }

    if (caps.isHistogram) {
      defaults.addAll({
        'histogramBinsMode': 'auto',
        'histogramBins': 10,
        'histogramFrequency': 'absolute',
      });
    }

    if (caps.isHeatmap || caps.isMap) {
      defaults.addAll({
        'heatmapPalette': 'blueRed',
        'heatmapScale': 'linear',
        'heatmapShowValues': true,
        'mapStyle': 'light',
        'mapCluster': true,
        'mapHeatLayer': caps.isHeatmap,
        'mapBubbleSize': 12.0,
        'mapOpacity': 0.82,
      });
    }

    return defaults;
  }

  static Map<String, dynamic> merge(
    String type,
    Map<String, dynamic>? current,
  ) {
    return <String, dynamic>{
      ...defaultsFor(type),
      if (current != null) ...current,
    };
  }
}
