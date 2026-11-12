class CalculatedMetric {
  final String name;
  final String formula;

  const CalculatedMetric({required this.name, required this.formula});

  Map<String, dynamic> toJson() => {'name': name, 'formula': formula};

  static CalculatedMetric? fromJson(dynamic value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim();
    final formula = value['formula']?.toString().trim();
    if (name == null || name.isEmpty || formula == null || formula.isEmpty) {
      return null;
    }
    return CalculatedMetric(name: name, formula: formula);
  }
}

double resolveMetricValue(
  Map<dynamic, dynamic> row,
  String metric,
  Map<String, CalculatedMetric> calculatedMetrics, [
  Set<String> evaluationStack = const {},
]) {
  final calculated = calculatedMetrics[metric];
  if (calculated != null) {
    if (evaluationStack.contains(metric)) {
      throw FormatException('Referencia circular envolvendo "$metric".');
    }
    return FormulaEvaluator(row, calculatedMetrics, {
      ...evaluationStack,
      metric,
    }).evaluate(calculated.formula);
  }
  return numericValue(row[metric]);
}

double numericValue(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw == null) return 0;
  final original = raw.toString().trim();
  final percentage = original.contains('%');
  final negative = original.startsWith('(') && original.endsWith(')');
  final text = original
      .replaceAll('R\$', '')
      .replaceAll(r'$', '')
      .replaceAll('€', '')
      .replaceAll('£', '')
      .replaceAll('¥', '')
      .replaceAll('%', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll(' ', '')
      .trim();
  if (text.isEmpty) return 0;

  var normalized = text;
  if (normalized.contains(',') && normalized.contains('.')) {
    normalized = normalized.lastIndexOf(',') > normalized.lastIndexOf('.')
        ? normalized.replaceAll('.', '').replaceAll(',', '.')
        : normalized.replaceAll(',', '');
  } else if (normalized.contains(',')) {
    final thousands = RegExp(r'^[+-]?\d{1,3}(,\d{3})+$');
    normalized = thousands.hasMatch(normalized)
        ? normalized.replaceAll(',', '')
        : normalized.replaceAll(',', '.');
  } else if (RegExp(r'^[+-]?\d{1,3}(\.\d{3})+$').hasMatch(normalized)) {
    normalized = normalized.replaceAll('.', '');
  }
  var value = double.tryParse(normalized) ?? 0;
  if (negative) value *= -1;
  if (percentage) value /= 100;
  return value;
}

class FormulaEvaluator {
  final Map<dynamic, dynamic> row;
  final Map<String, CalculatedMetric> calculatedMetrics;
  final Set<String> evaluationStack;
  late final List<_Token> _tokens;
  int _index = 0;

  FormulaEvaluator(
    this.row,
    this.calculatedMetrics, [
    this.evaluationStack = const {},
  ]);

  double evaluate(String formula) {
    _tokens = _Tokenizer(formula).scan();
    _index = 0;
    if (_tokens.isEmpty) {
      throw const FormatException('A formula esta vazia.');
    }
    final value = _parseExpression();
    if (!_isAtEnd) {
      throw FormatException('Trecho inesperado: "${_tokens[_index].value}".');
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (_match('+') || _match('-')) {
      final operator = _previous.value;
      final right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (_match('*') || _match('/')) {
      final operator = _previous.value;
      final right = _parseFactor();
      if (operator == '*') {
        value *= right;
      } else {
        value = right == 0 ? 0 : value / right;
      }
    }
    return value;
  }

  double _parseFactor() {
    if (_match('-')) return -_parseFactor();
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) {
        throw const FormatException('Feche todos os parenteses da formula.');
      }
      return value;
    }
    if (_isAtEnd) {
      throw const FormatException('A formula termina com um operador.');
    }

    final token = _advance();
    if (token.type == _TokenType.number) {
      return double.tryParse(token.value.replaceAll(',', '.')) ?? 0;
    }
    if (token.type == _TokenType.metric) {
      return resolveMetricValue(
        row,
        token.value,
        calculatedMetrics,
        evaluationStack,
      );
    }
    throw FormatException('Valor inesperado: "${token.value}".');
  }

  bool _match(String value) {
    if (_isAtEnd || _tokens[_index].value != value) return false;
    _index++;
    return true;
  }

  _Token _advance() => _tokens[_index++];

  _Token get _previous => _tokens[_index - 1];

  bool get _isAtEnd => _index >= _tokens.length;
}

enum _TokenType { number, operatorSymbol, metric }

class _Token {
  final _TokenType type;
  final String value;

  const _Token(this.type, this.value);
}

class _Tokenizer {
  final String source;

  const _Tokenizer(this.source);

  List<_Token> scan() {
    final tokens = <_Token>[];
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (char.trim().isEmpty) {
        i++;
        continue;
      }
      if ('+-*/()'.contains(char)) {
        tokens.add(_Token(_TokenType.operatorSymbol, char));
        i++;
        continue;
      }
      if (char == '[') {
        final end = source.indexOf(']', i + 1);
        if (end == -1) {
          throw const FormatException('Feche a metrica com "]".');
        }
        final metric = source.substring(i + 1, end).trim();
        if (metric.isEmpty) {
          throw const FormatException('A metrica entre colchetes esta vazia.');
        }
        tokens.add(_Token(_TokenType.metric, metric));
        i = end + 1;
        continue;
      }
      if (_isNumberChar(char)) {
        final start = i;
        while (i < source.length && _isNumberChar(source[i])) {
          i++;
        }
        tokens.add(_Token(_TokenType.number, source.substring(start, i)));
        continue;
      }
      throw FormatException('Caractere nao permitido: "$char".');
    }
    return tokens;
  }

  bool _isNumberChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || char == '.' || char == ',';
  }
}

String? validateCalculatedMetric({
  required String name,
  required String formula,
  required Iterable<String> baseMetrics,
  required Map<String, CalculatedMetric> calculatedMetrics,
}) {
  final cleanName = name.trim();
  final cleanFormula = formula.trim();
  if (cleanName.length < 2) {
    return 'Informe um nome com pelo menos 2 caracteres.';
  }
  if (cleanFormula.isEmpty) return 'Monte a formula antes de salvar.';
  if (baseMetrics.contains(cleanName)) {
    return 'O nome ja pertence a uma metrica da fonte.';
  }
  if (calculatedMetrics.containsKey(cleanName)) {
    return 'Ja existe uma metrica calculada com este nome.';
  }

  try {
    final tokens = _Tokenizer(cleanFormula).scan();
    final references = tokens
        .where((token) => token.type == _TokenType.metric)
        .map((token) => token.value)
        .toSet();
    final available = {...baseMetrics, ...calculatedMetrics.keys, cleanName};
    final missing = references
        .where((item) => !available.contains(item))
        .toList();
    if (missing.isNotEmpty) {
      return 'Metrica nao encontrada: ${missing.join(', ')}.';
    }

    final candidateMetrics = Map<String, CalculatedMetric>.from(
      calculatedMetrics,
    )..[cleanName] = CalculatedMetric(name: cleanName, formula: cleanFormula);
    final sample = <String, dynamic>{
      for (final metric in baseMetrics) metric: 1.0,
    };
    resolveMetricValue(sample, cleanName, candidateMetrics);
    return null;
  } on FormatException catch (error) {
    return error.message.toString();
  }
}
